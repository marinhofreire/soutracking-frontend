import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/bridge_client.dart';
import '../../data/bridge_config.dart';

// ── Screen ─────────────────────────────────────────────────────────────────────

class IaScreen extends ConsumerWidget {
  const IaScreen({super.key, this.onClose});
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ia     = ref.watch(iaProvider);
    final config = ref.watch(bridgeConfigProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(ia: ia, config: config, onClose: onClose,
            onRefresh: () => ref.read(iaProvider.notifier).refresh()),
        const SizedBox(height: 10),
        _KpiBar(ia: ia, config: config),
        const SizedBox(height: 10),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: approval queue
              Expanded(
                flex: 6,
                child: _ApprovalQueue(ia: ia),
              ),
              const SizedBox(width: 10),
              // Right: log + autonomy
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    Expanded(child: _ActionLog(ia: ia)),
                    const SizedBox(height: 10),
                    _AutonomyCard(config: config),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.ia, required this.config, required this.onRefresh, this.onClose});
  final IaState ia;
  final BridgeConfig config;
  final VoidCallback onRefresh;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = switch (ia.status) {
      BridgeConnectionStatus.connected    => ('Conectado', const Color(0xFF10B981)),
      BridgeConnectionStatus.connecting   => ('Conectando…', const Color(0xFFF59E0B)),
      BridgeConnectionStatus.error        => ('Erro de conexão', const Color(0xFFEF4444)),
      BridgeConnectionStatus.disconnected => config.isConfigured
          ? ('Desconectado', const Color(0xFFEF4444))
          : ('Modo demonstração', const Color(0xFF9DB1CC)),
    };

    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF176EEB).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF176EEB), size: 20),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('IA Operacional', style: TextStyle(color: Color(0xFF1F2A44), fontWeight: FontWeight.w900, fontSize: 18)),
              SizedBox(height: 1),
              Text('Gestão autônoma com aprovação humana', style: TextStyle(color: Color(0xFF60718D), fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        // Status chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: statusColor.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 6, height: 6,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onRefresh,
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

// ── KPI bar ────────────────────────────────────────────────────────────────────

class _KpiBar extends StatelessWidget {
  const _KpiBar({required this.ia, required this.config});
  final IaState ia;
  final BridgeConfig config;

  @override
  Widget build(BuildContext context) {
    final acoesHoje = ia.events.where((e) => !e.requerAprovacao || e.aprovado == true).length;
    final pendentes = ia.pending.length;
    final taxa = ia.acertosHoje == 0 ? '--' : '${((ia.acertosHoje / (ia.acertosHoje + 1)) * 100).toStringAsFixed(0)}%';
    final tokens = ia.tokensUsed == 0 ? '--' : _fmt(ia.tokensUsed);

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDDE5F0))),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _kpi('Ações hoje',    '$acoesHoje', const Color(0xFF176EEB),  Icons.bolt_rounded),
            const VerticalDivider(width: 1, color: Color(0xFFE8EFF7)),
            _kpi('Aprovações',    '$pendentes', pendentes > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981), Icons.pending_actions_rounded),
            const VerticalDivider(width: 1, color: Color(0xFFE8EFF7)),
            _kpi('Taxa de acerto', taxa,        const Color(0xFF10B981),  Icons.verified_rounded),
            const VerticalDivider(width: 1, color: Color(0xFFE8EFF7)),
            _kpi('Tokens usados', tokens,       const Color(0xFF526684),  Icons.data_usage_rounded),
            const VerticalDivider(width: 1, color: Color(0xFFE8EFF7)),
            _kpi('Modo',
              config.aiMode == AiMode.bridge ? 'Bridge' : 'Demo',
              config.aiMode == AiMode.bridge ? const Color(0xFF176EEB) : const Color(0xFF9DB1CC),
              Icons.hub_rounded,
            ),
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
              width: 30, height: 30,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18)),
                Text(label, style: const TextStyle(color: Color(0xFF60718D), fontSize: 10.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}

// ── Approval queue ─────────────────────────────────────────────────────────────

class _ApprovalQueue extends ConsumerWidget {
  const _ApprovalQueue({required this.ia});
  final IaState ia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ia.pending;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE8EFF7))),
            ),
            child: Row(
              children: [
                Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.pending_actions_rounded, color: Color(0xFFF59E0B), size: 14),
                ),
                const SizedBox(width: 8),
                const Text('Fila de aprovação', style: TextStyle(color: Color(0xFF1F2A44), fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(width: 8),
                if (pending.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(999)),
                    child: Text('${pending.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                const Spacer(),
                const Icon(Icons.lock_outline_rounded, size: 13, color: Color(0xFF9DB1CC)),
                const SizedBox(width: 4),
                const Text('Gestor humano aprova', style: TextStyle(color: Color(0xFF9DB1CC), fontSize: 10.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          // List
          Expanded(
            child: pending.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 40, color: Color(0xFF10B981)),
                        SizedBox(height: 8),
                        Text('Nenhuma aprovação pendente', style: TextStyle(color: Color(0xFF60718D), fontWeight: FontWeight.w700, fontSize: 13)),
                        SizedBox(height: 2),
                        Text('A IA está operando dentro da autonomia configurada', style: TextStyle(color: Color(0xFF9DB1CC), fontSize: 11)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: pending.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _ApprovalCard(event: pending[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalCard extends ConsumerWidget {
  const _ApprovalCard({required this.event});
  final IaBridgeEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (iconData, cardColor) = switch (event.type) {
      IaEventType.sugestao => (Icons.auto_awesome_rounded,    const Color(0xFF176EEB)),
      IaEventType.alerta   => (Icons.warning_amber_rounded,   const Color(0xFFEF4444)),
      IaEventType.status   => (Icons.info_outline_rounded,    const Color(0xFF526684)),
      IaEventType.acao     => (Icons.bolt_rounded,            const Color(0xFF10B981)),
    };
    final elapsed = DateTime.now().difference(event.timestamp).inMinutes;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cardColor.withValues(alpha: 0.20)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: cardColor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(7)),
                child: Icon(iconData, color: cardColor, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.titulo, style: const TextStyle(color: Color(0xFF1F2A44), fontWeight: FontWeight.w800, fontSize: 12.5)),
                  if (event.entidade != null)
                    Text(event.entidade!, style: TextStyle(color: cardColor, fontSize: 10.5, fontWeight: FontWeight.w700)),
                ],
              )),
              Text('${elapsed}min', style: const TextStyle(color: Color(0xFF9DB1CC), fontSize: 10.5)),
            ],
          ),
          const SizedBox(height: 7),
          Text(event.descricao, style: const TextStyle(color: Color(0xFF526684), fontSize: 11.5, height: 1.4)),
          if (event.valor != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF176EEB).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF176EEB).withValues(alpha: 0.20)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.attach_money_rounded, size: 13, color: Color(0xFF176EEB)),
                  Text('Valor: R\$ ${event.valor!.toStringAsFixed(2)}',
                      style: const TextStyle(color: Color(0xFF176EEB), fontWeight: FontWeight.w800, fontSize: 11.5)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ref.read(iaProvider.notifier).rejeitar(event.id),
                  icon: const Icon(Icons.close_rounded, size: 13),
                  label: const Text('Rejeitar', style: TextStyle(fontSize: 11.5)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    foregroundColor: const Color(0xFFEF4444),
                    side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.40)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => ref.read(iaProvider.notifier).aprovar(event.id),
                  icon: const Icon(Icons.check_rounded, size: 13),
                  label: const Text('Aprovar e executar', style: TextStyle(fontSize: 11.5)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    backgroundColor: const Color(0xFF176EEB),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Action log ─────────────────────────────────────────────────────────────────

class _ActionLog extends StatelessWidget {
  const _ActionLog({required this.ia});
  final IaState ia;

  @override
  Widget build(BuildContext context) {
    final log = ia.log;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE8EFF7))),
            ),
            child: Row(
              children: [
                Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
                  child: const Icon(Icons.history_rounded, color: Color(0xFF10B981), size: 14),
                ),
                const SizedBox(width: 8),
                const Text('Log de ações', style: TextStyle(color: Color(0xFF1F2A44), fontWeight: FontWeight.w800, fontSize: 13)),
                const Spacer(),
                Text('${log.length} registros', style: const TextStyle(color: Color(0xFF9DB1CC), fontSize: 11)),
              ],
            ),
          ),
          Expanded(
            child: log.isEmpty
                ? const Center(child: Text('Nenhuma ação registrada', style: TextStyle(color: Color(0xFF9DB1CC))))
                : ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: log.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEEF3FA)),
                    itemBuilder: (_, i) => _LogEntry(event: log[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LogEntry extends StatelessWidget {
  const _LogEntry({required this.event});
  final IaBridgeEvent event;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (event.type) {
      IaEventType.acao     => (Icons.bolt_rounded,            const Color(0xFF10B981)),
      IaEventType.alerta   => (Icons.warning_amber_rounded,   const Color(0xFFF59E0B)),
      IaEventType.sugestao => (event.aprovado == true
          ? Icons.check_circle_rounded
          : Icons.cancel_rounded,
          event.aprovado == true ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
      IaEventType.status   => (Icons.info_outline_rounded,    const Color(0xFF526684)),
    };

    final timeAgo = _timeAgo(event.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.titulo,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF1F2A44), fontWeight: FontWeight.w700, fontSize: 11.5)),
                if (event.entidade != null)
                  Text(event.entidade!, style: const TextStyle(color: Color(0xFF9DB1CC), fontSize: 10.5)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(timeAgo, style: const TextStyle(color: Color(0xFF9DB1CC), fontSize: 10.5)),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24)   return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

// ── Autonomy card ──────────────────────────────────────────────────────────────

class _AutonomyCard extends ConsumerWidget {
  const _AutonomyCard({required this.config});
  final BridgeConfig config;

  static const _labels = <String, String>{
    'alertas':    'Criar alertas',
    'cercas':     'Criar cercas',
    'despacho':   'Despachar parceiros',
    'whatsapp':   'Enviar WhatsApp',
    'relatorios': 'Gerar relatórios',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(color: const Color(0xFF176EEB).withValues(alpha: 0.10), borderRadius: BorderRadius.circular(7)),
                child: const Icon(Icons.tune_rounded, color: Color(0xFF176EEB), size: 14),
              ),
              const SizedBox(width: 8),
              const Text('Autonomia da IA', style: TextStyle(color: Color(0xFF1F2A44), fontWeight: FontWeight.w800, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          for (final entry in _labels.entries) ...[
            _AutonomyRow(
              label: entry.value,
              key_: entry.key,
              value: config.autonomy[entry.key] ?? false,
              onChanged: (v) {
                ref.read(bridgeConfigProvider.notifier).setAutonomy(entry.key, v);
                ref.read(bridgeConfigProvider.notifier).save(
                  ref.read(bridgeConfigProvider).copyWith(
                    autonomy: {...ref.read(bridgeConfigProvider).autonomy, entry.key: v},
                  ),
                );
              },
            ),
            if (entry.key != 'relatorios') const Divider(height: 1, color: Color(0xFFEEF3FA)),
          ],
        ],
      ),
    );
  }
}

class _AutonomyRow extends StatelessWidget {
  const _AutonomyRow({required this.label, required this.key_, required this.value, required this.onChanged});
  final String label;
  final String key_;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Color(0xFF526684), fontWeight: FontWeight.w600, fontSize: 11.5)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: value
                  ? const Color(0xFF10B981).withValues(alpha: 0.10)
                  : const Color(0xFF9DB1CC).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value ? 'Autônomo' : 'Requer aprovação',
              style: TextStyle(
                color: value ? const Color(0xFF10B981) : const Color(0xFF9DB1CC),
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF10B981),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
