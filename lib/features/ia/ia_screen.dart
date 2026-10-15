import 'package:flutter/material.dart';
import '../../ui/module_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/bridge_client.dart';
import '../../data/bridge_config.dart';

// ── Screen ─────────────────────────────────────────────────────────────────────

class IaScreen extends ConsumerWidget {
  const IaScreen({super.key, this.onClose});
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      _buildContents(context, ref);

  Widget _buildContents(BuildContext context, WidgetRef ref) {
    final ia = ref.watch(iaProvider), config = ref.watch(bridgeConfigProvider);
    final status = switch (ia.status) {
      BridgeConnectionStatus.connected => 'Conectado',
      BridgeConnectionStatus.connecting => 'Conectando…',
      BridgeConnectionStatus.error => 'Erro de conexão',
      BridgeConnectionStatus.disconnected =>
        config.isConfigured ? 'Desconectado' : 'Modo demonstração'
    };
    return ModuleScaffold(
        title: 'IA Operacional',
        subtitle: 'Gestão autônoma com aprovação humana.',
        navigation:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const ModuleSectionLabel('Atividade'),
          ModuleCard(
              title: 'Resumo',
              child: Column(children: [
                ModuleDetailRow('Modo', 'IA'),
                ModuleDetailRow('Aprovações pendentes', '${ia.pending.length}')
              ])),
          SizedBox(height: 280, child: _ActionLog(ia: ia))
        ]),
        scrollContent: false,
        content: _ApprovalQueue(ia: ia),
        detail: _AutonomyCard(config: config),
        headerActions: [
          ModuleStatusChip(status,
              tone: ia.status == BridgeConnectionStatus.connected
                  ? ModuleTone.success
                  : ModuleTone.neutral),
          IconButton(
              tooltip: 'Atualizar',
              onPressed: () => ref.read(iaProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh_rounded))
        ]);
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _ApprovalQueue extends ConsumerWidget {
  const _ApprovalQueue({required this.ia});
  final IaState ia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ia.pending;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
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
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.pending_actions_rounded,
                      color: Color(0xFFF59E0B), size: 14),
                ),
                const SizedBox(width: 8),
                const Text('Fila de aprovação',
                    style: TextStyle(
                        color: Color(0xFF1F2A44),
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                const SizedBox(width: 8),
                if (pending.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(999)),
                    child: Text('${pending.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                const Spacer(),
                const Icon(Icons.lock_outline_rounded,
                    size: 13, color: Color(0xFF9DB1CC)),
                const SizedBox(width: 4),
                const Text('Gestor humano aprova',
                    style: TextStyle(
                        color: Color(0xFF9DB1CC),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600)),
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
                        Icon(Icons.check_circle_outline_rounded,
                            size: 40, color: Color(0xFF10B981)),
                        SizedBox(height: 8),
                        Text('Nenhuma aprovação pendente',
                            style: TextStyle(
                                color: Color(0xFF60718D),
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                        SizedBox(height: 2),
                        Text(
                            'A IA está operando dentro da autonomia configurada',
                            style: TextStyle(
                                color: Color(0xFF9DB1CC), fontSize: 11)),
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
      IaEventType.sugestao => (
          Icons.auto_awesome_rounded,
          const Color(0xFF176EEB)
        ),
      IaEventType.alerta => (
          Icons.warning_amber_rounded,
          const Color(0xFFEF4444)
        ),
      IaEventType.status => (
          Icons.info_outline_rounded,
          const Color(0xFF526684)
        ),
      IaEventType.acao => (Icons.bolt_rounded, const Color(0xFF10B981)),
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
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: cardColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(7)),
                child: Icon(iconData, color: cardColor, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.titulo,
                      style: const TextStyle(
                          color: Color(0xFF1F2A44),
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5)),
                  if (event.entidade != null)
                    Text(event.entidade!,
                        style: TextStyle(
                            color: cardColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700)),
                ],
              )),
              Text('${elapsed}min',
                  style: const TextStyle(
                      color: Color(0xFF9DB1CC), fontSize: 10.5)),
            ],
          ),
          const SizedBox(height: 7),
          Text(event.descricao,
              style: const TextStyle(
                  color: Color(0xFF526684), fontSize: 11.5, height: 1.4)),
          if (event.valor != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF176EEB).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: const Color(0xFF176EEB).withValues(alpha: 0.20)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.attach_money_rounded,
                      size: 13, color: Color(0xFF176EEB)),
                  Text('Valor: R\$ ${event.valor!.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Color(0xFF176EEB),
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(iaProvider.notifier).rejeitar(event.id),
                  icon: const Icon(Icons.close_rounded, size: 13),
                  label: const Text('Rejeitar', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    fixedSize: const Size.fromHeight(33),
                    visualDensity: VisualDensity.standard,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    foregroundColor: const Color(0xFFEF4444),
                    side: BorderSide(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.40)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () =>
                      ref.read(iaProvider.notifier).aprovar(event.id),
                  icon: const Icon(Icons.check_rounded, size: 13),
                  label: const Text('Aprovar e executar',
                      style: TextStyle(fontSize: 11)),
                  style: FilledButton.styleFrom(
                    fixedSize: const Size.fromHeight(33),
                    visualDensity: VisualDensity.standard,
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
        borderRadius: BorderRadius.circular(9),
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
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7)),
                  child: const Icon(Icons.history_rounded,
                      color: Color(0xFF10B981), size: 14),
                ),
                const SizedBox(width: 8),
                const Expanded(
                    child: Text('Log de ações',
                        style: TextStyle(
                            color: Color(0xFF1F2A44),
                            fontWeight: FontWeight.w600,
                            fontSize: 13))),
                Text('${log.length} registros',
                    style: const TextStyle(
                        color: Color(0xFF9DB1CC), fontSize: 11)),
              ],
            ),
          ),
          Expanded(
            child: log.isEmpty
                ? const Center(
                    child: Text('Nenhuma ação registrada',
                        style: TextStyle(color: Color(0xFF9DB1CC))))
                : ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: log.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFEEF3FA)),
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
      IaEventType.acao => (Icons.bolt_rounded, const Color(0xFF10B981)),
      IaEventType.alerta => (
          Icons.warning_amber_rounded,
          const Color(0xFFF59E0B)
        ),
      IaEventType.sugestao => (
          event.aprovado == true
              ? Icons.check_circle_rounded
              : Icons.cancel_rounded,
          event.aprovado == true
              ? const Color(0xFF10B981)
              : const Color(0xFFEF4444)
        ),
      IaEventType.status => (
          Icons.info_outline_rounded,
          const Color(0xFF526684)
        ),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF1F2A44),
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5)),
                if (event.entidade != null)
                  Text(event.entidade!,
                      style: const TextStyle(
                          color: Color(0xFF9DB1CC), fontSize: 10.5)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(timeAgo,
              style: const TextStyle(color: Color(0xFF9DB1CC), fontSize: 10.5)),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

// ── Autonomy card ──────────────────────────────────────────────────────────────

class _AutonomyCard extends ConsumerWidget {
  const _AutonomyCard({required this.config});
  final BridgeConfig config;

  static const _labels = <String, String>{
    'alertas': 'Criar alertas',
    'cercas': 'Criar cercas',
    'despacho': 'Despachar parceiros',
    'whatsapp': 'Enviar WhatsApp',
    'relatorios': 'Gerar relatórios',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                    color: const Color(0xFF176EEB).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(7)),
                child: const Icon(Icons.tune_rounded,
                    color: Color(0xFF176EEB), size: 14),
              ),
              const SizedBox(width: 8),
              const Expanded(
                  child: Text('Autonomia da IA',
                      style: TextStyle(
                          color: Color(0xFF1F2A44),
                          fontWeight: FontWeight.w600,
                          fontSize: 13))),
            ],
          ),
          const SizedBox(height: 10),
          for (final entry in _labels.entries) ...[
            _AutonomyRow(
              label: entry.value,
              key_: entry.key,
              value: config.autonomy[entry.key] ?? false,
              onChanged: (v) {
                ref
                    .read(bridgeConfigProvider.notifier)
                    .setAutonomy(entry.key, v);
                ref.read(bridgeConfigProvider.notifier).save(
                      ref.read(bridgeConfigProvider).copyWith(
                        autonomy: {
                          ...ref.read(bridgeConfigProvider).autonomy,
                          entry.key: v
                        },
                      ),
                    );
              },
            ),
            if (entry.key != 'relatorios')
              const Divider(height: 1, color: Color(0xFFEEF3FA)),
          ],
        ],
      ),
    );
  }
}

class _AutonomyRow extends StatelessWidget {
  const _AutonomyRow(
      {required this.label,
      required this.key_,
      required this.value,
      required this.onChanged});
  final String label;
  final String key_;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: Color(0xFF526684),
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5))),
            const SizedBox(width: 8),
            _IaToggle(value: value, onChanged: onChanged)
          ]),
          const SizedBox(height: 5),
          ModuleStatusChip(value ? 'Autônomo' : 'Requer aprovação',
              tone: value ? ModuleTone.success : ModuleTone.neutral)
        ]));
  }
}

class _IaToggle extends StatelessWidget {
  const _IaToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
        toggled: value,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
              width: 36,
              height: 28,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 32,
                  height: 18,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: value
                        ? const Color(0xFF176EEB)
                        : const Color(0xFFE0E6EF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Align(
                      alignment:
                          value ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle))),
                ),
              )),
        ),
      );
}
