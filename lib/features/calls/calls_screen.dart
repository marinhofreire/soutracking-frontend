import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/bridge_client.dart';

// ── Screen ─────────────────────────────────────────────────────────────────────
//
// Dados 100% reais, vindos de GET {bridgeUrl}/soufind/chamados (proxy do
// soutracking-bridge pro endpoint /api/v1/operador/dashboard do SouFind,
// filtrado pelo b2b_cliente_id do SouTracking). Nada de fixture/mock aqui.
//
// Limitacoes conhecidas (dado real disponivel hoje, sem inventar o resto):
// - Sem nome/telefone do cliente (a API do painel operador nao devolve isso)
// - Sem SLA/ETA (nao existe esse calculo no backend ainda)
// - Sem sugestao de despacho por IA (nao existe esse algoritmo ainda)
// - Acoes (aceitar/iniciar/finalizar) ainda nao estao conectadas aqui --
//   criar/despachar OS de verdade dispara WhatsApp real pro parceiro, entao
//   por enquanto essa tela e so leitura.

class CallsScreen extends ConsumerWidget {
  const CallsScreen({super.key, this.onClose});
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(chamadosProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(onClose: onClose),
        const SizedBox(height: 10),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => _ErrorState(message: '$err'),
            data: (result) => _Body(result: result),
          ),
        ),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({this.onClose});
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF176EEB).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.headset_mic_rounded, color: Color(0xFF176EEB), size: 20),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chamados', style: TextStyle(color: Color(0xFF1F2A44), fontWeight: FontWeight.w900, fontSize: 18)),
              SizedBox(height: 1),
              Text('OS reais do SouFind vinculadas ao SouTracking',
                  style: TextStyle(color: Color(0xFF60718D), fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        IconButton(
          onPressed: () => ref.invalidate(chamadosProvider),
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Atualizar',
          style: IconButton.styleFrom(foregroundColor: const Color(0xFF60718D)),
        ),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Fechar',
          style: IconButton.styleFrom(foregroundColor: const Color(0xFF60718D)),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 28),
          const SizedBox(height: 8),
          Text('Falha ao carregar chamados: $message',
              style: const TextStyle(color: Color(0xFF60718D), fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.result});
  final ChamadosResult result;

  @override
  Widget build(BuildContext context) {
    final os = result.os;
    final aguardando = os.where((o) => o.status == 'aguardando').toList();
    final andamento = os.where((o) => o.status == 'em_andamento').toList();
    final finalizados = os.where((o) => o.status == 'finalizada' || o.status == 'cancelada').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KpiBar(stats: result.stats, volume: os.fold(0.0, (s, o) => s + o.valor)),
        const SizedBox(height: 10),
        SizedBox(
          height: 130,
          child: Row(
            children: [
              Expanded(flex: 6, child: _HourlyRealChart(os: os)),
              const SizedBox(width: 10),
              Expanded(flex: 4, child: _CategoryChart(os: os)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (os.isEmpty)
          const Expanded(
            child: _EmptyState(
              title: 'Nenhum chamado ainda',
              subtitle: 'Assim que uma OS real for aberta pra esse cliente no SouFind, ela aparece aqui.',
            ),
          )
        else
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _KanbanColumn(title: 'Aguardando', color: const Color(0xFF9DB1CC), icon: Icons.hourglass_empty_rounded, os: aguardando),
                const SizedBox(width: 8),
                _KanbanColumn(title: 'Em andamento', color: const Color(0xFF176EEB), icon: Icons.directions_car_rounded, os: andamento),
                const SizedBox(width: 8),
                _KanbanColumn(title: 'Finalizado', color: const Color(0xFF526684), icon: Icons.check_circle_rounded, os: finalizados),
              ],
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: const Color(0xFF176EEB).withValues(alpha: 0.08), shape: BoxShape.circle),
              child: const Icon(Icons.inbox_outlined, color: Color(0xFF9DB1CC), size: 20),
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w800, fontSize: 12.5)),
            const SizedBox(height: 3),
            Text(subtitle, textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF60718D), fontWeight: FontWeight.w600, fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}

// ── KPI bar ────────────────────────────────────────────────────────────────────

class _KpiBar extends StatelessWidget {
  const _KpiBar({required this.stats, required this.volume});
  final ChamadosStats stats;
  final double volume;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDDE5F0))),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _kpi('Total hoje', '${stats.total}', const Color(0xFF526684), Icons.receipt_long_rounded),
            const VerticalDivider(width: 1, color: Color(0xFFE8EFF7)),
            _kpi('Aguardando', '${stats.aguardando}', const Color(0xFF9DB1CC), Icons.hourglass_empty_rounded),
            const VerticalDivider(width: 1, color: Color(0xFFE8EFF7)),
            _kpi('Em andamento', '${stats.emAndamento}', const Color(0xFF176EEB), Icons.directions_car_rounded),
            const VerticalDivider(width: 1, color: Color(0xFFE8EFF7)),
            _kpi('Finalizadas', '${stats.finalizadas}', const Color(0xFF10B981), Icons.check_circle_outline_rounded),
            const VerticalDivider(width: 1, color: Color(0xFFE8EFF7)),
            _kpi('Volume hoje', 'R\$ ${volume.toStringAsFixed(0)}', const Color(0xFF526684), Icons.attach_money_rounded),
          ],
        ),
      ),
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
                  Text(label, style: const TextStyle(color: Color(0xFF60718D), fontSize: 10.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Charts (derivados de dado real, sem numero inventado) ───────────────────────

class _HourlyRealChart extends StatelessWidget {
  const _HourlyRealChart({required this.os});
  final List<ChamadoOs> os;

  @override
  Widget build(BuildContext context) {
    final counts = List<int>.filled(24, 0);
    for (final o in os) {
      counts[o.criadoEm.hour]++;
    }
    final maxCount = counts.isEmpty ? 0 : counts.reduce((a, b) => a > b ? a : b);

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDDE5F0))),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chamados por hora (hoje)', style: TextStyle(color: Color(0xFF1F2A44), fontWeight: FontWeight.w800, fontSize: 11.5)),
          const SizedBox(height: 6),
          Expanded(
            child: maxCount == 0
                ? const Center(
                    child: Text('Sem chamados hoje ainda',
                        style: TextStyle(color: Color(0xFF9DB1CC), fontSize: 11, fontWeight: FontWeight.w600)),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (int h = 0; h < 24; h += 2)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1.5),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  height: maxCount == 0 ? 2 : (counts[h] / maxCount) * 70 + 2,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF176EEB).withValues(alpha: counts[h] == 0 ? 0.15 : 0.85),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text('${h}h', style: const TextStyle(color: Color(0xFF9DB1CC), fontSize: 8, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChart extends StatelessWidget {
  const _CategoryChart({required this.os});
  final List<ChamadoOs> os;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final o in os) counts[o.tipo] = (counts[o.tipo] ?? 0) + 1;
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDDE5F0))),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Por categoria', style: TextStyle(color: Color(0xFF1F2A44), fontWeight: FontWeight.w800, fontSize: 11.5)),
          const SizedBox(height: 6),
          Expanded(
            child: entries.isEmpty
                ? const Center(
                    child: Text('Sem dado ainda',
                        style: TextStyle(color: Color(0xFF9DB1CC), fontSize: 11, fontWeight: FontWeight.w600)),
                  )
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final e in entries.take(4)) ...[
                        _CategoryBar(label: e.key, count: e.value, total: os.length),
                        const SizedBox(height: 4),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.label, required this.count, required this.total});
  final String label;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF526684), fontSize: 10, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: const Color(0xFFE8EFF7),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF176EEB)),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('$count', style: const TextStyle(color: Color(0xFF1F2A44), fontSize: 10, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

// ── Kanban column ──────────────────────────────────────────────────────────────

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({required this.title, required this.color, required this.icon, required this.os});
  final String title;
  final Color color;
  final IconData icon;
  final List<ChamadoOs> os;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: const BorderRadius.vertical(top: Radius.circular(11))),
              child: Row(
                children: [
                  Icon(icon, size: 13, color: color),
                  const SizedBox(width: 6),
                  Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11.5)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
                    child: Text('${os.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: os.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('Nenhum', style: TextStyle(color: color.withValues(alpha: 0.40), fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: os.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) => _OsCard(os: os[i], color: color),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── OS card ────────────────────────────────────────────────────────────────────

class _OsCard extends StatelessWidget {
  const _OsCard({required this.os, required this.color});
  final ChamadoOs os;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(os.criadoEm).inMinutes;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDE5F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(os.bookingNumber, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(os.tipo, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF526684), fontSize: 10.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 5),
          if (os.origem.isNotEmpty)
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 11, color: Color(0xFF9DB1CC)),
              const SizedBox(width: 4),
              Expanded(child: Text(os.origem, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF60718D), fontSize: 10, fontWeight: FontWeight.w600))),
            ]),
          if (os.parceiro != null) ...[
            const SizedBox(height: 5),
            Row(children: [
              const Icon(Icons.support_agent_rounded, size: 11, color: Color(0xFF9DB1CC)),
              const SizedBox(width: 4),
              Expanded(child: Text(os.parceiro!, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF526684), fontSize: 10.5, fontWeight: FontWeight.w600))),
            ]),
          ],
          const SizedBox(height: 5),
          Row(
            children: [
              Text('R\$ ${os.valor.toStringAsFixed(0)}',
                  style: const TextStyle(color: Color(0xFF1F2A44), fontWeight: FontWeight.w800, fontSize: 11)),
              const SizedBox(width: 6),
              Text('${elapsed}min', style: const TextStyle(color: Color(0xFF9DB1CC), fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
