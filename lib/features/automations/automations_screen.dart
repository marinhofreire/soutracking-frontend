import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Data model ─────────────────────────────────────────────────────────────────

enum _TriggerType { speed, geofence, ignition, noComm, odometer, temperature, battery, harshBrake, scheduled }
enum _ActionType  { whatsapp, alert, createTicket, notify, block, report }

class _AutoRule {
  _AutoRule({
    required this.id,
    required this.name,
    required this.triggerType,
    required this.triggerLabel,
    required this.condition,
    required this.actions,
    required this.executions,
    required this.lastRun,
    this.active = true,
    this.hasError = false,
  });
  final String id;
  final String name;
  final _TriggerType triggerType;
  final String triggerLabel;
  final String condition;
  final List<_ActionType> actions;
  final int executions;
  final DateTime? lastRun;
  bool active;
  final bool hasError;
}

class _ExecLog {
  const _ExecLog({required this.ruleId, required this.ruleName, required this.timestamp, required this.result, required this.detail});
  final String ruleId;
  final String ruleName;
  final DateTime timestamp;
  final bool result;
  final String detail;
}

List<_AutoRule> _buildDemoRules() {
  final now = DateTime.now();
  return [
    _AutoRule(id: 'r1', name: 'Velocidade excessiva', triggerType: _TriggerType.speed,
      triggerLabel: 'Velocidade', condition: '> 120 km/h',
      actions: [_ActionType.whatsapp, _ActionType.alert],
      executions: 47, lastRun: now.subtract(const Duration(hours: 2, minutes: 14))),
    _AutoRule(id: 'r2', name: 'Saída de cerca — Base SP', triggerType: _TriggerType.geofence,
      triggerLabel: 'Cerca "Base SP"', condition: 'Saída detectada',
      actions: [_ActionType.whatsapp, _ActionType.createTicket],
      executions: 12, lastRun: now.subtract(const Duration(hours: 5))),
    _AutoRule(id: 'r3', name: 'Ignição fora do horário', triggerType: _TriggerType.ignition,
      triggerLabel: 'Ignição', condition: 'Entre 23h e 06h',
      actions: [_ActionType.alert, _ActionType.notify],
      executions: 8, lastRun: now.subtract(const Duration(days: 1, hours: 3))),
    _AutoRule(id: 'r4', name: 'Veículo sem comunicação', triggerType: _TriggerType.noComm,
      triggerLabel: 'Sem GPS', condition: '> 30 minutos',
      actions: [_ActionType.alert],
      executions: 23, lastRun: now.subtract(const Duration(hours: 8))),
    _AutoRule(id: 'r5', name: 'Revisão por hodômetro', triggerType: _TriggerType.odometer,
      triggerLabel: 'Hodômetro', condition: 'A cada 10.000 km',
      actions: [_ActionType.createTicket, _ActionType.notify],
      executions: 3, lastRun: now.subtract(const Duration(days: 12))),
    _AutoRule(id: 'r6', name: 'Temperatura alta — Baú frio', triggerType: _TriggerType.temperature,
      triggerLabel: 'Temperatura', condition: '> 8 °C (baú)',
      actions: [_ActionType.alert, _ActionType.whatsapp],
      executions: 5, lastRun: now.subtract(const Duration(days: 2)),
      active: false),
    _AutoRule(id: 'r7', name: 'Bateria baixa', triggerType: _TriggerType.battery,
      triggerLabel: 'Tensão', condition: '< 11.8 V',
      actions: [_ActionType.alert, _ActionType.createTicket],
      executions: 9, lastRun: now.subtract(const Duration(hours: 18))),
    _AutoRule(id: 'r8', name: 'Freio brusco detectado', triggerType: _TriggerType.harshBrake,
      triggerLabel: 'Telemetria', condition: 'Desaceleração > 0.5g',
      actions: [_ActionType.notify],
      executions: 31, lastRun: now.subtract(const Duration(hours: 1))),
    _AutoRule(id: 'r9', name: 'Relatório semanal de frota', triggerType: _TriggerType.scheduled,
      triggerLabel: 'Agendamento', condition: 'Toda segunda-feira 08h',
      actions: [_ActionType.report, _ActionType.whatsapp],
      executions: 6, lastRun: now.subtract(const Duration(days: 6)),
      hasError: true),
  ];
}

List<_ExecLog> _buildDemoLog() {
  final now = DateTime.now();
  return [
    _ExecLog(ruleId: 'r8', ruleName: 'Freio brusco detectado', timestamp: now.subtract(const Duration(hours: 1)), result: true, detail: 'HB20 ABC-2345 — km 47 Rod. Bandeirantes'),
    _ExecLog(ruleId: 'r1', ruleName: 'Velocidade excessiva', timestamp: now.subtract(const Duration(hours: 2, minutes: 14)), result: true, detail: 'Strada XYZ-9981 — 134 km/h — WhatsApp enviado'),
    _ExecLog(ruleId: 'r4', ruleName: 'Veículo sem comunicação', timestamp: now.subtract(const Duration(hours: 8)), result: true, detail: 'Caminhão Frio 01 — 35min offline — Alerta criado'),
    _ExecLog(ruleId: 'r9', ruleName: 'Relatório semanal de frota', timestamp: now.subtract(const Duration(days: 6)), result: false, detail: 'Falha ao gerar PDF — servidor de relatórios indisponível'),
    _ExecLog(ruleId: 'r3', ruleName: 'Ignição fora do horário', timestamp: now.subtract(const Duration(days: 1, hours: 3)), result: true, detail: 'Fiat Uno LMN-5544 — ignição 02:47 — Alerta enviado'),
    _ExecLog(ruleId: 'r2', ruleName: 'Saída de cerca — Base SP', timestamp: now.subtract(const Duration(hours: 5)), result: true, detail: 'VW Gol PRQ-1122 — saiu de "Base SP" — Chamado aberto'),
    _ExecLog(ruleId: 'r7', ruleName: 'Bateria baixa', timestamp: now.subtract(const Duration(hours: 18)), result: true, detail: 'Tracker ID 142 — 11.4V — Chamado criado'),
    _ExecLog(ruleId: 'r1', ruleName: 'Velocidade excessiva', timestamp: now.subtract(const Duration(hours: 26)), result: true, detail: 'Camionete QRS-7788 — 128 km/h — WhatsApp enviado'),
  ];
}

// ── Providers ──────────────────────────────────────────────────────────────────

final _rulesProvider  = StateProvider<List<_AutoRule>>((ref) => _buildDemoRules());
final _logProvider    = StateProvider<List<_ExecLog>>((ref) => _buildDemoLog());
final _tabProvider    = StateProvider<int>((ref) => 0);
final _builderOpen    = StateProvider<bool>((ref) => false);

// ── Screen ─────────────────────────────────────────────────────────────────────

class AutomationsScreen extends ConsumerWidget {
  const AutomationsScreen({super.key, this.onClose});
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules   = ref.watch(_rulesProvider);
    final log     = ref.watch(_logProvider);
    final tab     = ref.watch(_tabProvider);
    final builder = ref.watch(_builderOpen);

    final active   = rules.where((r) => r.active).length;
    final errors   = rules.where((r) => r.hasError).length;
    final todayExec = log.where((l) => DateTime.now().difference(l.timestamp).inHours < 24).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: const Color(0xFF176EEB).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.bolt_rounded, color: Color(0xFF176EEB), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Automações', style: TextStyle(color: Color(0xFF1F2A44), fontWeight: FontWeight.w900, fontSize: 18)),
              SizedBox(height: 1),
              Text('Regras, gatilhos e ações automáticas', style: TextStyle(color: Color(0xFF60718D), fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          )),
          if (errors > 0)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.30)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline_rounded, size: 13, color: Color(0xFFEF4444)),
                const SizedBox(width: 5),
                Text('$errors erro${errors != 1 ? 's' : ''}', style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w800, fontSize: 11)),
              ]),
            ),
          FilledButton.icon(
            onPressed: () => ref.read(_builderOpen.notifier).state = true,
            icon: const Icon(Icons.add_rounded, size: 15),
            label: const Text('Nova regra', style: TextStyle(fontSize: 12)),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF176EEB), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () => ref.invalidate(_rulesProvider),
            icon: const Icon(Icons.refresh_rounded),
            style: IconButton.styleFrom(foregroundColor: const Color(0xFF60718D)),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            style: IconButton.styleFrom(foregroundColor: const Color(0xFF60718D)),
          ),
        ]),
        const SizedBox(height: 10),

        // ── KPI bar ──────────────────────────────────────────────────────────
        _KpiBar(total: rules.length, active: active, todayExec: todayExec, errors: errors),
        const SizedBox(height: 10),

        // ── Tabs ─────────────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFDDE5F0))),
          padding: const EdgeInsets.all(4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _tabBtn(ref, 0, 'Regras', Icons.rule_rounded, tab),
            _tabBtn(ref, 1, 'Histórico', Icons.history_rounded, tab),
          ]),
        ),
        const SizedBox(height: 10),

        // ── Content ───────────────────────────────────────────────────────────
        Expanded(
          child: Stack(
            children: [
              tab == 0
                  ? _RulesList(rules: rules)
                  : _ExecHistory(log: log),
              if (builder)
                _RuleBuilder(
                  onClose: () => ref.read(_builderOpen.notifier).state = false,
                  onSave: (r) {
                    ref.read(_rulesProvider.notifier).update((list) => [...list, r]);
                    ref.read(_builderOpen.notifier).state = false;
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabBtn(WidgetRef ref, int index, String label, IconData icon, int current) {
    final active = current == index;
    return GestureDetector(
      onTap: () => ref.read(_tabProvider.notifier).state = index,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF176EEB) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: active ? Colors.white : const Color(0xFF60718D)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: active ? Colors.white : const Color(0xFF60718D), fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      ),
    );
  }
}

// ── KPI bar ────────────────────────────────────────────────────────────────────

class _KpiBar extends StatelessWidget {
  const _KpiBar({required this.total, required this.active, required this.todayExec, required this.errors});
  final int total, active, todayExec, errors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDDE5F0))),
      child: IntrinsicHeight(child: Row(children: [
        _kpi('Total de regras',  '$total',    const Color(0xFF526684),  Icons.rule_rounded),
        const VerticalDivider(width: 1, color: Color(0xFFE8EFF7)),
        _kpi('Ativas',           '$active',   const Color(0xFF10B981),  Icons.toggle_on_rounded),
        const VerticalDivider(width: 1, color: Color(0xFFE8EFF7)),
        _kpi('Pausadas',         '${total - active}', const Color(0xFF9DB1CC), Icons.pause_circle_outline_rounded),
        const VerticalDivider(width: 1, color: Color(0xFFE8EFF7)),
        _kpi('Disparos hoje',    '$todayExec',const Color(0xFF176EEB),  Icons.bolt_rounded),
        const VerticalDivider(width: 1, color: Color(0xFFE8EFF7)),
        _kpi('Erros',            '$errors',   errors > 0 ? const Color(0xFFEF4444) : const Color(0xFF9DB1CC), Icons.error_outline_rounded),
      ])),
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Container(width: 30, height: 30,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 15)),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18)),
            Text(label, style: const TextStyle(color: Color(0xFF60718D), fontSize: 10.5, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }
}

// ── Rules list ─────────────────────────────────────────────────────────────────

class _RulesList extends ConsumerWidget {
  const _RulesList({required this.rules});
  final List<_AutoRule> rules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: rules.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _RuleCard(
        rule: rules[i],
        onToggle: (v) => ref.read(_rulesProvider.notifier).update((list) {
          final updated = List<_AutoRule>.from(list);
          updated[i].active = v;
          return updated;
        }),
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.rule, required this.onToggle});
  final _AutoRule rule;
  final ValueChanged<bool> onToggle;

  static const _triggerIcons = <_TriggerType, IconData>{
    _TriggerType.speed:      Icons.speed_rounded,
    _TriggerType.geofence:   Icons.fence_rounded,
    _TriggerType.ignition:   Icons.key_rounded,
    _TriggerType.noComm:     Icons.signal_wifi_off_rounded,
    _TriggerType.odometer:   Icons.route_rounded,
    _TriggerType.temperature:Icons.thermostat_rounded,
    _TriggerType.battery:    Icons.battery_alert_rounded,
    _TriggerType.harshBrake: Icons.emergency_share_rounded,
    _TriggerType.scheduled:  Icons.schedule_rounded,
  };

  static const _actionIcons = <_ActionType, (IconData, Color)>{
    _ActionType.whatsapp:     (Icons.chat_bubble_rounded,        Color(0xFF25D366)),
    _ActionType.alert:        (Icons.notification_important_rounded, Color(0xFFF59E0B)),
    _ActionType.createTicket: (Icons.headset_mic_rounded,        Color(0xFF176EEB)),
    _ActionType.notify:       (Icons.notifications_rounded,      Color(0xFF7C3AED)),
    _ActionType.block:        (Icons.block_rounded,              Color(0xFFEF4444)),
    _ActionType.report:       (Icons.analytics_rounded,          Color(0xFF526684)),
  };

  static const _actionLabels = <_ActionType, String>{
    _ActionType.whatsapp:     'WhatsApp',
    _ActionType.alert:        'Alerta',
    _ActionType.createTicket: 'Chamado',
    _ActionType.notify:       'Notificar',
    _ActionType.block:        'Bloquear',
    _ActionType.report:       'Relatório',
  };

  @override
  Widget build(BuildContext context) {
    final r = rule;
    final trigIcon = _triggerIcons[r.triggerType] ?? Icons.bolt_rounded;
    final color = r.active
        ? const Color(0xFF176EEB)
        : const Color(0xFF9DB1CC);
    final lastRunStr = r.lastRun == null ? 'Nunca' : _timeAgo(r.lastRun!);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: r.hasError
            ? const Color(0xFFEF4444).withValues(alpha: 0.40)
            : r.active
                ? const Color(0xFFDDE5F0)
                : const Color(0xFFEEF0F5)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Trigger icon
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(trigIcon, color: color, size: 18),
          ),
          const SizedBox(width: 12),

          // Name + condition
          Expanded(
            flex: 4,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(r.name, style: TextStyle(
                  color: r.active ? const Color(0xFF1F2A44) : const Color(0xFF9DB1CC),
                  fontWeight: FontWeight.w800, fontSize: 13,
                )),
                if (r.hasError) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.10), borderRadius: BorderRadius.circular(4)),
                    child: const Text('Erro', style: TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ],
              ]),
              const SizedBox(height: 3),
              Row(children: [
                Icon(trigIcon, size: 11, color: const Color(0xFF9DB1CC)),
                const SizedBox(width: 4),
                Text('${r.triggerLabel}  ${r.condition}',
                    style: const TextStyle(color: Color(0xFF60718D), fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),

          // Arrow
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.arrow_forward_rounded, size: 14, color: color.withValues(alpha: 0.50)),
          ),

          // Actions chips
          Expanded(
            flex: 3,
            child: Wrap(spacing: 5, runSpacing: 4, children: [
              for (final a in r.actions)
                Builder(builder: (_) {
                  final (icon, aColor) = _actionIcons[a]!;
                  final label = _actionLabels[a]!;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: aColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: aColor.withValues(alpha: 0.25)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, size: 10, color: aColor),
                      const SizedBox(width: 4),
                      Text(label, style: TextStyle(color: aColor, fontWeight: FontWeight.w700, fontSize: 10)),
                    ]),
                  );
                }),
            ]),
          ),

          // Stats
          Expanded(
            flex: 2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${r.executions}× disparado', style: const TextStyle(color: Color(0xFF526684), fontSize: 11, fontWeight: FontWeight.w700)),
              Text('Último: $lastRunStr', style: const TextStyle(color: Color(0xFF9DB1CC), fontSize: 10.5)),
            ]),
          ),

          const SizedBox(width: 12),

          // Toggle
          Switch(
            value: r.active,
            onChanged: onToggle,
            activeThumbColor: const Color(0xFF10B981),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60) return '${d.inMinutes}min';
    if (d.inHours   < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}

// ── Execution history ─────────────────────────────────────────────────────────

class _ExecHistory extends StatelessWidget {
  const _ExecHistory({required this.log});
  final List<_ExecLog> log;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDDE5F0))),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE8EFF7)))),
          child: Row(children: [
            const Text('Histórico de execuções', style: TextStyle(color: Color(0xFF1F2A44), fontWeight: FontWeight.w800, fontSize: 13)),
            const Spacer(),
            Text('${log.length} registros', style: const TextStyle(color: Color(0xFF9DB1CC), fontSize: 11)),
          ]),
        ),
        Expanded(child: ListView.separated(
          padding: const EdgeInsets.all(10),
          itemCount: log.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEEF3FA)),
          itemBuilder: (_, i) {
            final e = log[i];
            final timeAgo = _timeAgo(e.timestamp);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: e.result ? const Color(0xFF10B981).withValues(alpha: 0.10) : const Color(0xFFEF4444).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(e.result ? Icons.check_rounded : Icons.close_rounded, size: 14,
                      color: e.result ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.ruleName, style: const TextStyle(color: Color(0xFF1F2A44), fontWeight: FontWeight.w700, fontSize: 12)),
                  Text(e.detail, style: const TextStyle(color: Color(0xFF60718D), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                const SizedBox(width: 10),
                Text(timeAgo, style: const TextStyle(color: Color(0xFF9DB1CC), fontSize: 11)),
              ]),
            );
          },
        )),
      ]),
    );
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60) return '${d.inMinutes}min';
    if (d.inHours   < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}

// ── Rule builder (overlay) ─────────────────────────────────────────────────────

class _RuleBuilder extends ConsumerStatefulWidget {
  const _RuleBuilder({required this.onClose, required this.onSave});
  final VoidCallback onClose;
  final ValueChanged<_AutoRule> onSave;

  @override
  ConsumerState<_RuleBuilder> createState() => _RuleBuilderState();
}

class _RuleBuilderState extends ConsumerState<_RuleBuilder> {
  final _nameCtrl = TextEditingController();
  _TriggerType _trigger = _TriggerType.speed;
  final _conditionCtrl = TextEditingController(text: '> 120 km/h');
  final Set<_ActionType> _actions = {_ActionType.alert};
  int _idCounter = 100;

  static const _triggerLabels = <_TriggerType, String>{
    _TriggerType.speed:       'Velocidade',
    _TriggerType.geofence:    'Cerca geográfica',
    _TriggerType.ignition:    'Ignição',
    _TriggerType.noComm:      'Sem comunicação',
    _TriggerType.odometer:    'Hodômetro',
    _TriggerType.temperature: 'Temperatura',
    _TriggerType.battery:     'Tensão de bateria',
    _TriggerType.harshBrake:  'Freio brusco',
    _TriggerType.scheduled:   'Agendamento',
  };

  static const _actionLabels = <_ActionType, (String, IconData, Color)>{
    _ActionType.whatsapp:     ('WhatsApp',  Icons.chat_bubble_rounded,         Color(0xFF25D366)),
    _ActionType.alert:        ('Alerta',    Icons.notification_important_rounded,Color(0xFFF59E0B)),
    _ActionType.createTicket: ('Chamado',   Icons.headset_mic_rounded,          Color(0xFF176EEB)),
    _ActionType.notify:       ('Notificar', Icons.notifications_rounded,        Color(0xFF7C3AED)),
    _ActionType.report:       ('Relatório', Icons.analytics_rounded,            Color(0xFF526684)),
  };

  @override
  void dispose() {
    _nameCtrl.dispose();
    _conditionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.25),
        child: Center(
          child: Container(
            width: 520,
            constraints: const BoxConstraints(maxHeight: 560),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 14, 14, 13),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE8EFF7)))),
                  child: Row(children: [
                    Container(width: 30, height: 30,
                      decoration: BoxDecoration(color: const Color(0xFF176EEB).withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.add_rounded, color: Color(0xFF176EEB), size: 16)),
                    const SizedBox(width: 10),
                    const Text('Nova regra', style: TextStyle(color: Color(0xFF1F2A44), fontWeight: FontWeight.w900, fontSize: 15)),
                    const Spacer(),
                    IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close_rounded), style: IconButton.styleFrom(foregroundColor: const Color(0xFF60718D))),
                  ]),
                ),
                // Body
                Flexible(child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome da regra',
                        prefixIcon: Icon(Icons.label_rounded, size: 18),
                        filled: true, fillColor: Color(0xFFF7F9FD),
                        border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFDDE5F0))),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFDDE5F0))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sectionLabel('SE — Gatilho'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(color: const Color(0xFFF7F9FD), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFDDE5F0))),
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        DropdownButtonFormField<_TriggerType>(
                          initialValue: _trigger,
                          decoration: const InputDecoration(labelText: 'Tipo de evento', isDense: true, border: InputBorder.none),
                          items: _TriggerType.values.map((t) => DropdownMenuItem(value: t, child: Text(_triggerLabels[t]!))).toList(),
                          onChanged: (v) => setState(() => _trigger = v!),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _conditionCtrl,
                          decoration: const InputDecoration(labelText: 'Condição', hintText: 'ex: > 120 km/h', isDense: true, border: InputBorder.none),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    _sectionLabel('ENTÃO — Ações'),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final entry in _actionLabels.entries)
                        Builder(builder: (_) {
                          final (label, icon, color) = entry.value;
                          final selected = _actions.contains(entry.key);
                          return GestureDetector(
                            onTap: () => setState(() {
                              if (selected) { _actions.remove(entry.key); }
                              else { _actions.add(entry.key); }
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: selected ? color.withValues(alpha: 0.12) : const Color(0xFFF7F9FD),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: selected ? color : const Color(0xFFDDE5F0), width: selected ? 1.5 : 1),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(icon, size: 13, color: selected ? color : const Color(0xFF9DB1CC)),
                                const SizedBox(width: 6),
                                Text(label, style: TextStyle(color: selected ? color : const Color(0xFF9DB1CC), fontWeight: FontWeight.w700, fontSize: 12)),
                              ]),
                            ),
                          );
                        }),
                    ]),
                  ]),
                )),
                // Footer
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE8EFF7)))),
                  child: Row(children: [
                    OutlinedButton(
                      onPressed: widget.onClose,
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF526684), side: const BorderSide(color: Color(0xFFDDE5F0)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
                      child: const Text('Cancelar'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _actions.isEmpty || _nameCtrl.text.trim().isEmpty ? null : _save,
                      icon: const Icon(Icons.check_rounded, size: 15),
                      label: const Text('Criar regra'),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF176EEB), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Row(children: [
    Container(width: 3, height: 14, decoration: BoxDecoration(color: const Color(0xFF176EEB), borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(text, style: const TextStyle(color: Color(0xFF1F2A44), fontWeight: FontWeight.w800, fontSize: 12.5)),
  ]);

  void _save() {
    final rule = _AutoRule(
      id: 'r${++_idCounter}',
      name: _nameCtrl.text.trim(),
      triggerType: _trigger,
      triggerLabel: const {
        _TriggerType.speed: 'Velocidade', _TriggerType.geofence: 'Cerca',
        _TriggerType.ignition: 'Ignição', _TriggerType.noComm: 'Sem GPS',
        _TriggerType.odometer: 'Hodômetro', _TriggerType.temperature: 'Temperatura',
        _TriggerType.battery: 'Tensão', _TriggerType.harshBrake: 'Telemetria',
        _TriggerType.scheduled: 'Agendamento',
      }[_trigger]!,
      condition: _conditionCtrl.text.trim(),
      actions: _actions.toList(),
      executions: 0,
      lastRun: null,
    );
    widget.onSave(rule);
  }
}
