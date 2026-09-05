import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../data/bridge_client.dart';
import '../../data/bridge_config.dart';
import '../../data/models.dart';
import '../../state/session_state.dart';

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

// ── Mapeamento do modelo real do bridge (BridgeRule) pro modelo de UI ──────
// O bridge nao guarda contagem de execucoes nem ultima execucao por regra
// ainda (so o log de disparo passa pelo terminal do pm2) -- por isso esses
// campos ficam honestamente zerados/nulos, em vez de inventar numero.
_TriggerType _triggerTypeFromEvento(String tipoEvento) {
  return switch (tipoEvento) {
    'deviceOverspeed' => _TriggerType.speed,
    'geofenceExit' || 'geofenceEnter' => _TriggerType.geofence,
    'ignitionOn' || 'ignitionOff' => _TriggerType.ignition,
    'deviceOffline' || 'deviceUnknown' => _TriggerType.noComm,
    _ => _TriggerType.scheduled,
  };
}

String _triggerLabelFromEvento(String tipoEvento) {
  return switch (tipoEvento) {
    'deviceOverspeed' => 'Velocidade',
    'geofenceExit' => 'Cerca (saída)',
    'geofenceEnter' => 'Cerca (entrada)',
    'ignitionOn' => 'Ignição ligada',
    'ignitionOff' => 'Ignição desligada',
    'deviceOffline' => 'Sem comunicação',
    'any' => 'Qualquer evento',
    _ => tipoEvento,
  };
}

_ActionType _actionTypeFromTipo(String acaoTipo) {
  return switch (acaoTipo) {
    'bloquear_motor' => _ActionType.block,
    'notificar' => _ActionType.whatsapp,
    _ => _ActionType.notify,
  };
}

_AutoRule _autoRuleFromBridgeRule(BridgeRule r) {
  return _AutoRule(
    id: r.id,
    name: r.descricao.isNotEmpty
        ? r.descricao
        : '${_triggerLabelFromEvento(r.tipoEvento)} — ${r.deviceName}',
    triggerType: _triggerTypeFromEvento(r.tipoEvento),
    triggerLabel: _triggerLabelFromEvento(r.tipoEvento),
    condition: r.deviceName,
    actions: [_actionTypeFromTipo(r.acaoTipo)],
    executions: 0, // bridge nao conta disparos por regra ainda
    lastRun: null, // idem
    active: r.ativo,
  );
}

// ── Providers ──────────────────────────────────────────────────────────────────

final _logProvider    = StateProvider<List<_ExecLog>>((ref) => const []);
final _tabProvider    = StateProvider<int>((ref) => 0);
final _builderOpen    = StateProvider<bool>((ref) => false);

// ── Screen ─────────────────────────────────────────────────────────────────────

class AutomationsScreen extends ConsumerWidget {
  const AutomationsScreen({super.key, this.onClose});
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(bridgeRulesProvider);
    final rules = rulesAsync.valueOrNull?.map(_autoRuleFromBridgeRule).toList() ?? const <_AutoRule>[];
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
            onPressed: () => ref.invalidate(bridgeRulesProvider),
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
                  onSaved: () {
                    ref.read(_builderOpen.notifier).state = false;
                    ref.invalidate(bridgeRulesProvider);
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
        onToggle: (v) async {
          final config = ref.read(bridgeConfigProvider);
          final ok = await setBridgeRuleActive(config: config, ruleId: rules[i].id, ativo: v);
          if (ok) ref.invalidate(bridgeRulesProvider);
        },
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
  const _RuleBuilder({required this.onClose, required this.onSaved});
  final VoidCallback onClose;
  final VoidCallback onSaved;

  @override
  ConsumerState<_RuleBuilder> createState() => _RuleBuilderState();
}

// Mapa trigger de UI -> tipoEvento real que o motor de regras entende
// (ver _relevantEventTypes no bridge). Fora daqui (odometer/temperature/
// battery/harshBrake/scheduled) o bridge ainda nao tem esse tipo de evento
// implementado -- por isso esses ficam desabilitados no seletor por ora.
const _triggerToEventoReal = <_TriggerType, String>{
  _TriggerType.speed: 'deviceOverspeed',
  _TriggerType.geofence: 'geofenceExit',
  _TriggerType.ignition: 'ignitionOn',
  _TriggerType.noComm: 'deviceOffline',
};

class _RuleBuilderState extends ConsumerState<_RuleBuilder> {
  final _nameCtrl = TextEditingController();
  _TriggerType _trigger = _TriggerType.speed;
  int? _selectedDeviceId;
  final Set<_ActionType> _actions = {_ActionType.alert};
  bool _saving = false;
  String? _error;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesProvider);
    final devices = devicesAsync.valueOrNull ?? const <TraccarDevice>[];
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
                          initialValue: _triggerToEventoReal.containsKey(_trigger) ? _trigger : _TriggerType.speed,
                          decoration: const InputDecoration(labelText: 'Tipo de evento', isDense: true, border: InputBorder.none),
                          items: _triggerToEventoReal.keys
                              .map((t) => DropdownMenuItem(value: t, child: Text(_triggerLabels[t]!)))
                              .toList(),
                          onChanged: (v) => setState(() => _trigger = v!),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          initialValue: _selectedDeviceId,
                          decoration: const InputDecoration(labelText: 'Veículo', isDense: true, border: InputBorder.none),
                          items: devices
                              .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name)))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedDeviceId = v),
                        ),
                      ]),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                    ],
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
                      onPressed: (_saving || _actions.isEmpty || _nameCtrl.text.trim().isEmpty || _selectedDeviceId == null)
                          ? null
                          : _save,
                      icon: _saving
                          ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded, size: 15),
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

  Future<void> _save() async {
    final deviceId = _selectedDeviceId;
    if (deviceId == null) return;
    final devices = ref.read(devicesProvider).valueOrNull ?? const <TraccarDevice>[];
    final deviceName = devices.where((d) => d.id == deviceId).map((d) => d.name).firstOrNull
        ?? 'Dispositivo $deviceId';
    final config = ref.read(bridgeConfigProvider);
    if (config.bridgeUrl.isEmpty || config.bridgeApiKey.isEmpty) {
      setState(() => _error = 'Bridge não configurado.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final uri = Uri.parse('${config.bridgeUrl}/rules');
      final resp = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${config.bridgeApiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'deviceId': deviceId,
          'deviceName': deviceName,
          'condicao': {'tipoEvento': _triggerToEventoReal[_trigger]},
          'acao': {'tipo': _actions.contains(_ActionType.block) ? 'bloquear_motor' : 'notificar'},
          'descricao': _nameCtrl.text.trim(),
        }),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        setState(() { _saving = false; _error = 'Falha ao criar regra (HTTP ${resp.statusCode}).'; });
        return;
      }
      widget.onSaved();
    } catch (err) {
      setState(() { _saving = false; _error = 'Falha ao criar regra: $err'; });
    }
  }
}
