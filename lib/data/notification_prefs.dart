import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kEmailAlerts = 'notif_email_alerts';
const _kPushAlerts = 'notif_push_alerts';
const _kPerMenuPrefix = 'notif_menu_';

/// Um item de notificação configurável, agrupado por menu do app.
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.menuGroup,
    required this.label,
    required this.description,
    this.defaultEnabled = true,
  });

  final String id;
  final String menuGroup;
  final String label;
  final String description;
  final bool defaultEnabled;
}

/// Catálogo de notificações que fazem sentido pra cada menu ativo hoje.
/// Financeiro/Estoque/MDVR ficam de fora por enquanto (menus ainda não
/// finalizados nesta fase).
const List<NotificationItem> notificationCatalog = [
  NotificationItem(
    id: 'alerts_overspeed',
    menuGroup: 'Alertas',
    label: 'Excesso de velocidade',
    description: 'Avisar quando um veículo ultrapassar o limite configurado.',
  ),
  NotificationItem(
    id: 'alerts_no_communication',
    menuGroup: 'Alertas',
    label: 'Sem comunicação',
    description: 'Avisar quando um rastreador parar de enviar posição.',
  ),
  NotificationItem(
    id: 'alerts_low_battery',
    menuGroup: 'Alertas',
    label: 'Bateria do rastreador baixa',
    description: 'Avisar quando a bateria interna do dispositivo estiver fraca.',
  ),
  NotificationItem(
    id: 'alerts_ignition_off_hours',
    menuGroup: 'Alertas',
    label: 'Ignição fora do horário',
    description: 'Avisar quando o veículo ligar fora da janela permitida.',
    defaultEnabled: false,
  ),
  NotificationItem(
    id: 'geofence_enter',
    menuGroup: 'Cercas',
    label: 'Entrada em cerca',
    description: 'Avisar quando um veículo entrar numa área monitorada.',
  ),
  NotificationItem(
    id: 'geofence_exit',
    menuGroup: 'Cercas',
    label: 'Saída de cerca',
    description: 'Avisar quando um veículo sair de uma área monitorada.',
  ),
  NotificationItem(
    id: 'maintenance_due_soon',
    menuGroup: 'Manutenção',
    label: 'Manutenção próxima do vencimento',
    description: 'Avisar quando faltar pouco km ou tempo pra revisão agendada.',
  ),
  NotificationItem(
    id: 'maintenance_overdue',
    menuGroup: 'Manutenção',
    label: 'Manutenção vencida',
    description: 'Avisar quando uma manutenção passar do prazo/km previsto.',
  ),
  NotificationItem(
    id: 'devices_offline',
    menuGroup: 'Equipamentos',
    label: 'Equipamento ficou offline',
    description: 'Avisar quando um rastreador passar muito tempo sem conexão.',
  ),
  NotificationItem(
    id: 'devices_back_online',
    menuGroup: 'Equipamentos',
    label: 'Equipamento voltou a comunicar',
    description: 'Avisar quando um rastreador que estava offline volta a responder.',
    defaultEnabled: false,
  ),
  NotificationItem(
    id: 'commands_executed',
    menuGroup: 'Comandos',
    label: 'Comando executado',
    description: 'Confirmar quando um bloqueio/desbloqueio for aplicado com sucesso.',
  ),
  NotificationItem(
    id: 'reports_ready',
    menuGroup: 'Relatórios',
    label: 'Relatório agendado pronto',
    description: 'Avisar quando um relatório programado terminar de gerar.',
    defaultEnabled: false,
  ),
  NotificationItem(
    id: 'tickets_new',
    menuGroup: 'Chamados',
    label: 'Novo chamado aberto',
    description: 'Avisar a central quando um chamado novo entrar na fila.',
  ),
  NotificationItem(
    id: 'tickets_sla_critical',
    menuGroup: 'Chamados',
    label: 'SLA crítico',
    description: 'Avisar quando um chamado estiver perto de estourar o prazo.',
  ),
  NotificationItem(
    id: 'communication_new_message',
    menuGroup: 'Comunicação',
    label: 'Nova mensagem no canal',
    description: 'Avisar quando chegar mensagem nova de um cliente/parceiro.',
  ),
  NotificationItem(
    id: 'ai_suggestion',
    menuGroup: 'IA Operacional',
    label: 'Nova sugestão da IA',
    description: 'Avisar quando a IA identificar algo que precisa de atenção.',
    defaultEnabled: false,
  ),
  NotificationItem(
    id: 'tpms_out_of_range',
    menuGroup: 'TPMS',
    label: 'Pneu fora da faixa ideal',
    description: 'Avisar quando pressão ou temperatura do pneu sair do normal.',
  ),
];

class NotificationPrefs {
  const NotificationPrefs({
    this.emailEnabled = true,
    this.pushEnabled = true,
    this.perItem = const {},
  });

  final bool emailEnabled;
  final bool pushEnabled;
  final Map<String, bool> perItem;

  bool isEnabled(String itemId) {
    final override = perItem[itemId];
    if (override != null) return override;
    final item = notificationCatalog.where((i) => i.id == itemId).firstOrNull;
    return item?.defaultEnabled ?? true;
  }

  NotificationPrefs copyWith({
    bool? emailEnabled,
    bool? pushEnabled,
    Map<String, bool>? perItem,
  }) {
    return NotificationPrefs(
      emailEnabled: emailEnabled ?? this.emailEnabled,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      perItem: perItem ?? this.perItem,
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEmailAlerts, emailEnabled);
    await p.setBool(_kPushAlerts, pushEnabled);
    for (final item in notificationCatalog) {
      final value = perItem[item.id];
      if (value != null) {
        await p.setBool('$_kPerMenuPrefix${item.id}', value);
      }
    }
  }

  static Future<NotificationPrefs> load() async {
    final p = await SharedPreferences.getInstance();
    final perItem = <String, bool>{};
    for (final item in notificationCatalog) {
      final key = '$_kPerMenuPrefix${item.id}';
      if (p.containsKey(key)) {
        perItem[item.id] = p.getBool(key) ?? item.defaultEnabled;
      }
    }
    return NotificationPrefs(
      emailEnabled: p.getBool(_kEmailAlerts) ?? true,
      pushEnabled: p.getBool(_kPushAlerts) ?? true,
      perItem: perItem,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

final notificationPrefsProvider =
    StateNotifierProvider<NotificationPrefsNotifier, NotificationPrefs>(
  (ref) => NotificationPrefsNotifier(),
);

class NotificationPrefsNotifier extends StateNotifier<NotificationPrefs> {
  NotificationPrefsNotifier() : super(const NotificationPrefs()) {
    _load();
  }

  Future<void> _load() async => state = await NotificationPrefs.load();

  Future<void> save(NotificationPrefs prefs) async {
    await prefs.save();
    state = prefs;
  }

  void setItemEnabled(String itemId, bool value) {
    final updated = Map<String, bool>.from(state.perItem)..[itemId] = value;
    state = state.copyWith(perItem: updated);
  }

  void setEmailEnabled(bool value) => state = state.copyWith(emailEnabled: value);
  void setPushEnabled(bool value) => state = state.copyWith(pushEnabled: value);
}
