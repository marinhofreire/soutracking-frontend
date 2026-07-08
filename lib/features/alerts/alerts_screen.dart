import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/display_text_formatter.dart';
import '../../data/models.dart';
import '../../state/session_state.dart';
import 'models/alert_models.dart';

final alertsEventsByPeriodProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, period) async {
  final session = ref.watch(sessionProvider);
  if (!session.isAuthenticated) {
    return [];
  }
  final client = ref.watch(traccarClientProvider);
  final now = DateTime.now();
  final from = _periodStart(period, now);
  try {
    return await client.getReport(
      path: '/reports/events',
      cookie: session.cookie,
      authHeader: session.authHeader,
      from: from,
      to: now,
    );
  } catch (error) {
    throw Exception('N\u00e3o foi poss\u00edvel carregar alertas: $error');
  }
});

final alertsRealDevicesProvider =
    FutureProvider<List<TraccarDevice>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (!session.isAuthenticated) {
    return [];
  }
  final client = ref.watch(traccarClientProvider);
  try {
    return await client.getDevices(
      cookie: session.cookie,
      authHeader: session.authHeader,
    );
  } catch (error) {
    throw Exception('N\u00e3o foi poss\u00edvel carregar alertas: $error');
  }
});

final notificationsManagementProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (!session.isAuthenticated) return [];
  final client = ref.watch(traccarClientProvider);
  return await client.getList(
    path: '/notifications',
    cookie: session.cookie,
    authHeader: session.authHeader,
  );
});

DateTime _periodStart(String period, DateTime now) {
  switch (period) {
    case 'Hoje':
      return DateTime(now.year, now.month, now.day);
    case '7 dias':
      return now.subtract(const Duration(days: 7));
    case '30 dias':
      return now.subtract(const Duration(days: 30));
    default:
      return now.subtract(const Duration(days: 7));
  }
}

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  String _period = 'Hoje';
  String _typeFilter = 'Todos';
  String _vehicleFilter = 'Todos';
  bool _saving = false;

  String? _dlgType;
  bool _dlgWeb = true;
  bool _dlgMail = false;
  bool _dlgSms = false;
  bool _dlgAlways = true;

  static const List<MapEntry<String, String>> _notifTypes = [
    MapEntry('deviceOverspeed', 'Excesso de velocidade'),
    MapEntry('geofenceEnter', 'Entrada em cerca'),
    MapEntry('geofenceExit', 'Saída de cerca'),
    MapEntry('alarm', 'Alarme'),
    MapEntry('ignitionOn', 'Ignição ligada'),
    MapEntry('ignitionOff', 'Ignição desligada'),
    MapEntry('deviceMoving', 'Veículo em movimento'),
    MapEntry('deviceStopped', 'Veículo parado'),
    MapEntry('deviceOffline', 'Dispositivo offline'),
    MapEntry('deviceOnline', 'Dispositivo online'),
    MapEntry('deviceFuelDrop', 'Queda de combustível'),
    MapEntry('maintenance', 'Manutenção programada'),
    MapEntry('textMessage', 'Mensagem de texto'),
    MapEntry('driverChanged', 'Troca de motorista'),
  ];

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(alertsRealDevicesProvider);
    final eventsAsync = ref.watch(alertsEventsByPeriodProvider(_period));
    final notifRulesAsync = ref.watch(notificationsManagementProvider);
    final notificationsAsync = ref.watch(notificationsProvider);
    final permissionsAsync = ref.watch(permissionsProvider);
    final ruleFilter = _resolveRuleFilter(
      notificationsAsync: notificationsAsync,
      permissionsAsync: permissionsAsync,
    );

    final devices = devicesAsync.valueOrNull ?? [];
    final events = eventsAsync.valueOrNull ?? [];
    final records = _mapEvents(events, devices, ruleFilter: ruleFilter);
    final summary = _buildSummary(records);

    final vehicleOptions = <String>[
      'Todos',
      ...{for (final r in records) r.vehicle},
    ];
    final typeOptions = <String>[
      'Todos',
      ...{for (final r in records) r.type},
    ];
    final selVehicle =
        vehicleOptions.contains(_vehicleFilter) ? _vehicleFilter : 'Todos';
    final selType =
        typeOptions.contains(_typeFilter) ? _typeFilter : 'Todos';
    final filtered = records.where((r) {
      if (selType != 'Todos' && r.type != selType) return false;
      if (selVehicle != 'Todos' && r.vehicle != selVehicle) return false;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alertas',
                    style: TextStyle(
                      color: Color(0xFF1F2A44),
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Gerencie regras de notificação e visualize eventos.',
                    style: TextStyle(color: Color(0xFF5A6B84), fontSize: 13),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => _openCreateAlertDialog(devices),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Criar Alerta'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _AlertsKpiRow(summary: summary),
        const SizedBox(height: 20),
        _SectionCard(
          icon: Icons.notifications_outlined,
          iconColor: const Color(0xFF176EEB),
          title: 'Regras de Notificação',
          subtitle: 'Alertas configurados no sistema',
          action: IconButton(
            tooltip: 'Atualizar',
            onPressed: () => ref.invalidate(notificationsManagementProvider),
            icon: const Icon(Icons.refresh_rounded, size: 18),
          ),
          child: notifRulesAsync.when(
            data: (rules) =>
                _NotifRulesTable(rules: rules, onDelete: _deleteNotification),
            loading: () => const _InlineLoader(),
            error: (_, __) => const _InlineError(
                message: 'Não foi possível carregar regras'),
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          icon: Icons.history_rounded,
          iconColor: const Color(0xFF7B2FC4),
          title: 'Eventos Recentes',
          subtitle: 'Histórico de alertas disparados',
          action: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PeriodChips(
                selected: _period,
                options: const ['Hoje', '7 dias', '30 dias'],
                onChanged: (v) => setState(() {
                  _period = v;
                  _typeFilter = 'Todos';
                  _vehicleFilter = 'Todos';
                }),
              ),
              if (typeOptions.length > 1) ...[
                const SizedBox(width: 8),
                _DropFilter(
                  label: 'Tipo',
                  value: selType,
                  options: typeOptions,
                  onChanged: (v) => setState(() => _typeFilter = v),
                ),
              ],
              if (vehicleOptions.length > 1) ...[
                const SizedBox(width: 8),
                _DropFilter(
                  label: 'Veículo',
                  value: selVehicle,
                  options: vehicleOptions,
                  onChanged: (v) => setState(() => _vehicleFilter = v),
                ),
              ],
            ],
          ),
          child: eventsAsync.when(
            data: (_) => _EventsTable(records: filtered),
            loading: () => const _InlineLoader(),
            error: (_, __) => const _InlineError(
                message: 'Não foi possível carregar eventos'),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _openCreateAlertDialog(List<TraccarDevice> devices) async {
    setState(() {
      _dlgType = null;
      _dlgWeb = true;
      _dlgMail = false;
      _dlgSms = false;
      _dlgAlways = true;
    });

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: StatefulBuilder(
              builder: (ctx, setModal) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Criar Alerta',
                              style: TextStyle(
                                color: Color(0xFF1F2A44),
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Configure uma regra de notificação no Traccar.',
                              style: TextStyle(
                                  color: Color(0xFF5A6B84), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFE8EEF6)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _AlertFormSection(
                            icon: Icons.warning_amber_rounded,
                            iconColor: const Color(0xFFE67E22),
                            title: 'Tipo de Evento',
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: _dlgType,
                                decoration: const InputDecoration(
                                  labelText: 'Selecione o tipo de alerta *',
                                ),
                                items: _notifTypes
                                    .map((e) => DropdownMenuItem(
                                        value: e.key, child: Text(e.value)))
                                    .toList(),
                                onChanged: (v) =>
                                    setModal(() => _dlgType = v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _AlertFormSection(
                            icon: Icons.tune_rounded,
                            iconColor: const Color(0xFF176EEB),
                            title: 'Configurações',
                            children: [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Sempre notificar'),
                                subtitle: const Text(
                                    'Aplica a todos os dispositivos'),
                                value: _dlgAlways,
                                onChanged: (v) =>
                                    setModal(() => _dlgAlways = v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _AlertFormSection(
                            icon: Icons.notifications_active_rounded,
                            iconColor: const Color(0xFF18A558),
                            title: 'Canais de Notificação',
                            children: [
                              _ChannelToggle(
                                icon: Icons.web_rounded,
                                label: 'Web (plataforma)',
                                value: _dlgWeb,
                                onChanged: (v) =>
                                    setModal(() => _dlgWeb = v),
                              ),
                              _ChannelToggle(
                                icon: Icons.email_outlined,
                                label: 'Email',
                                value: _dlgMail,
                                onChanged: (v) =>
                                    setModal(() => _dlgMail = v),
                              ),
                              _ChannelToggle(
                                icon: Icons.sms_rounded,
                                label: 'SMS',
                                value: _dlgSms,
                                onChanged: (v) =>
                                    setModal(() => _dlgSms = v),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(dialogContext).pop(),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: (_saving || _dlgType == null)
                            ? null
                            : () async {
                                final ok = await _saveNotification();
                                if (ok && dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop();
                                }
                              },
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined, size: 18),
                        label:
                            Text(_saving ? 'Salvando...' : 'Salvar Alerta'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _saveNotification() async {
    if (_dlgType == null) return false;
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    setState(() => _saving = true);
    final notificators = <String>[
      if (_dlgWeb) 'web',
      if (_dlgMail) 'mail',
      if (_dlgSms) 'sms',
    ];
    try {
      await client.createEntity(
        path: '/notifications',
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'type': _dlgType!,
          'always': _dlgAlways,
          'notificators': notificators.join(','),
          'web': _dlgWeb,
          'mail': _dlgMail,
          'sms': _dlgSms,
        },
      );
      ref.invalidate(notificationsManagementProvider);
      ref.invalidate(notificationsProvider);
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alerta criado com sucesso.')),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteNotification(int id) async {
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    try {
      await client.deleteEntity(
        path: '/notifications/$id',
        cookie: session.cookie,
        authHeader: session.authHeader,
      );
      ref.invalidate(notificationsManagementProvider);
      ref.invalidate(notificationsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alerta removido.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao remover: $e')),
      );
    }
  }

  List<AlertRecord> _mapEvents(
      List<Map<String, dynamic>> events, List<TraccarDevice> devices,
      {required _AlertRuleFilter ruleFilter}) {
    final devicesById = <int, TraccarDevice>{
      for (final item in devices) item.id: item
    };
    final records = <AlertRecord>[];

    for (final event in events) {
      final attributes = _asMap(event['attributes']);
      final dateTime = _parseEventTime(event);
      final typeCode = (event['type'] ?? '').toString().trim();
      final deviceId =
          event['deviceId'] is int ? event['deviceId'] as int : null;
      final latitude = _resolveLatitude(event, attributes);
      final longitude = _resolveLongitude(event, attributes);
      final speedKnots = _resolveSpeedKnots(event, attributes);
      final ignition = _resolveIgnition(event, attributes);
      final battery = _resolveBattery(event, attributes);
      final address = _resolveAddress(event, attributes);
      final alertMeaning = _resolveAlertMeaning(
        eventType: typeCode,
        attributes: attributes,
        battery: battery,
      );
      if (!ruleFilter.matches(
        eventType: typeCode,
        deviceId: deviceId,
        attributes: attributes,
      )) {
        continue;
      }
      if (alertMeaning == null) {
        continue;
      }

      records.add(
        AlertRecord(
          id: _resolveEventId(event, dateTime),
          severity: alertMeaning.severity,
          type: alertMeaning.typeLabel,
          vehicle: _resolveVehicleName(deviceId, devicesById),
          description: _resolveDescription(
            event,
            attributes,
            fallback: alertMeaning.descriptionFallback,
          ),
          dateTime: dateTime,
          status: _resolveStatus(event, attributes),
          latitude: latitude,
          longitude: longitude,
          speedKnots: speedKnots,
          ignition: ignition,
          battery: battery,
          address: address,
          attributes: attributes,
        ),
      );
    }

    records.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return records;
  }

  _AlertRuleFilter _resolveRuleFilter({
    required AsyncValue<List<Map<String, dynamic>>> notificationsAsync,
    required AsyncValue<List<Map<String, dynamic>>> permissionsAsync,
  }) {
    final notifications = notificationsAsync.valueOrNull ?? const [];
    final permissions = permissionsAsync.valueOrNull ?? const [];

    if (notifications.isNotEmpty) {
      final filter = _AlertRuleFilter.fromServer(
        notifications: notifications,
        permissions: permissions,
      );
      if (filter.hasRules) {
        return filter;
      }
    }
    return _AlertRuleFilter.fallback();
  }

  AlertKpiSummary _buildSummary(List<AlertRecord> records) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    var today = 0;
    var critical = 0;
    var inAnalysis = 0;
    var resolved = 0;

    for (final item in records) {
      if (!item.dateTime.isBefore(todayStart)) {
        today++;
      }
      if (item.severity == AlertSeverity.critical) {
        critical++;
      }
      if (item.status == AlertStatus.inAnalysis) {
        inAnalysis++;
      }
      if (item.status == AlertStatus.resolved) {
        resolved++;
      }
    }

    return AlertKpiSummary(
      today: today,
      critical: critical,
      inAnalysis: inAnalysis,
      resolved: resolved,
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, mapValue) => MapEntry(key.toString(), mapValue),
      );
    }
    return const <String, dynamic>{};
  }

  DateTime _parseEventTime(Map<String, dynamic> event) {
    final candidates = <dynamic>[
      event['eventTime'],
      event['serverTime'],
      event['deviceTime'],
      event['fixTime'],
    ];
    for (final candidate in candidates) {
      if (candidate is! String || candidate.trim().isEmpty) {
        continue;
      }
      final parsed = DateTime.tryParse(candidate);
      if (parsed != null) {
        return parsed.toLocal();
      }
    }
    return DateTime.now();
  }

  String _resolveEventId(Map<String, dynamic> event, DateTime dateTime) {
    final id = event['id'];
    if (id != null) {
      return 'EVT-$id';
    }
    final deviceId = event['deviceId']?.toString() ?? 'X';
    return 'EVT-$deviceId-${dateTime.millisecondsSinceEpoch}';
  }

  String _resolveVehicleName(
    int? deviceId,
    Map<int, TraccarDevice> devicesById,
  ) {
    if (deviceId == null) {
      return 'Dispositivo';
    }
    final device = devicesById[deviceId];
    final label = formatDisplayText(device?.name, fallback: '').trim();
    if (label.isNotEmpty) {
      return label;
    }
    return 'Dispositivo $deviceId';
  }

  _ResolvedAlertMeaning? _resolveAlertMeaning({
    required String eventType,
    required Map<String, dynamic> attributes,
    required String? battery,
  }) {
    final normalized = eventType.trim().toLowerCase();
    final alarm = (attributes['alarm'] ?? '').toString().trim().toLowerCase();
    final batteryText = (battery ?? '').trim().toLowerCase();
    final batteryPercent = _parseBatteryPercent(batteryText);
    final batteryVoltage = _parseBatteryVoltage(batteryText);

    if (normalized.contains('overspeed') || alarm.contains('overspeed')) {
      return const _ResolvedAlertMeaning(
        typeLabel: 'Excesso de velocidade',
        severity: AlertSeverity.high,
        descriptionFallback: 'Veículo acima do limite configurado.',
      );
    }

    if (normalized.contains('geofenceenter') ||
        normalized.contains('geofenceexit') ||
        alarm.contains('geofence')) {
      final geofenceName =
          (attributes['geofenceName'] ?? attributes['geofence'] ?? '')
              .toString()
              .trim();
      final isExit = normalized.contains('exit');
      return _ResolvedAlertMeaning(
        typeLabel: isExit ? 'Saída de cerca' : 'Entrada em cerca',
        severity: AlertSeverity.medium,
        descriptionFallback: geofenceName.isEmpty
            ? (isExit
                ? 'Saída de cerca registrada.'
                : 'Entrada em cerca registrada.')
            : '${isExit ? 'Saída' : 'Entrada'} de cerca: $geofenceName',
      );
    }

    if (normalized.contains('panic') ||
        normalized.contains('sos') ||
        alarm.contains('panic') ||
        alarm.contains('sos')) {
      return const _ResolvedAlertMeaning(
        typeLabel: 'Botão de pânico',
        severity: AlertSeverity.critical,
        descriptionFallback: 'Acionamento manual de emergência.',
      );
    }

    if (normalized == 'alarm' ||
        alarm.contains('alarm') ||
        alarm.contains('vibration') ||
        alarm.contains('shock')) {
      return const _ResolvedAlertMeaning(
        typeLabel: 'Alarme do veículo',
        severity: AlertSeverity.high,
        descriptionFallback: 'Alarme disparado pelo rastreador.',
      );
    }

    if (normalized.contains('jammer') || alarm.contains('jammer')) {
      return const _ResolvedAlertMeaning(
        typeLabel: 'Possível bloqueador de sinal',
        severity: AlertSeverity.critical,
        descriptionFallback: 'Interferência de sinal detectada.',
      );
    }

    if (normalized.contains('powercut') ||
        normalized.contains('power cut') ||
        alarm.contains('powercut') ||
        alarm.contains('power')) {
      return const _ResolvedAlertMeaning(
        typeLabel: 'Corte de energia',
        severity: AlertSeverity.high,
        descriptionFallback:
            'Alimentação principal do rastreador interrompida.',
      );
    }

    final isBatteryLow = (batteryPercent != null && batteryPercent <= 20) ||
        (batteryVoltage != null && batteryVoltage <= 11.8) ||
        normalized.contains('lowbattery') ||
        normalized.contains('batterylow') ||
        alarm.contains('low battery');
    if (isBatteryLow) {
      return const _ResolvedAlertMeaning(
        typeLabel: 'Bateria baixa',
        severity: AlertSeverity.medium,
        descriptionFallback: 'Bateria do equipamento em nível baixo.',
      );
    }

    return null;
  }

  AlertStatus? _resolveStatus(
    Map<String, dynamic> event,
    Map<String, dynamic> attributes,
  ) {
    final statusText = (event['status'] ?? attributes['status'] ?? '')
        .toString()
        .toLowerCase();

    if (statusText.contains('resolved') ||
        statusText.contains('closed') ||
        statusText.contains('done')) {
      return AlertStatus.resolved;
    }
    if (statusText.contains('analysis') ||
        statusText.contains('investig') ||
        statusText.contains('pending')) {
      return AlertStatus.inAnalysis;
    }

    final acknowledged = event['acknowledged'] ??
        attributes['acknowledged'] ??
        attributes['ack'];
    if (_isTruthy(acknowledged)) {
      return AlertStatus.resolved;
    }

    if (statusText.isNotEmpty) {
      return AlertStatus.newAlert;
    }
    return null;
  }

  String _resolveDescription(
      Map<String, dynamic> event, Map<String, dynamic> attributes,
      {String? fallback}) {
    final candidates = <String?>[
      event['message']?.toString(),
      event['description']?.toString(),
      attributes['message']?.toString(),
      attributes['description']?.toString(),
      attributes['text']?.toString(),
    ];
    for (final candidate in candidates) {
      final value = candidate?.trim() ?? '';
      final clean = formatDisplayText(value, fallback: '').trim();
      if (clean.isNotEmpty && clean.toLowerCase() != 'null') {
        return clean;
      }
    }

    final alarm = (attributes['alarm'] ?? '').toString().trim();
    if (alarm.isNotEmpty) {
      return 'Alarme: $alarm';
    }

    final geofence =
        (attributes['geofenceName'] ?? attributes['geofence'] ?? '')
            .toString()
            .trim();
    if (geofence.isNotEmpty) {
      return 'Geocerca: $geofence';
    }

    final latitude = _asDouble(event['latitude'] ?? attributes['latitude']);
    final longitude = _asDouble(event['longitude'] ?? attributes['longitude']);
    if (latitude != null && longitude != null) {
      return 'Lat ${latitude.toStringAsFixed(5)}, Lng ${longitude.toStringAsFixed(5)}';
    }

    if (fallback != null && fallback.trim().isNotEmpty) {
      return fallback.trim();
    }

    return 'Sem descrição';
  }

  bool _isTruthy(dynamic value) {
    if (value == true) {
      return true;
    }
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  double? _parseBatteryPercent(String value) {
    if (!value.endsWith('%')) {
      return null;
    }
    return double.tryParse(
        value.replaceAll('%', '').trim().replaceAll(',', '.'));
  }

  double? _parseBatteryVoltage(String value) {
    if (!value.endsWith('v')) {
      return null;
    }
    return double.tryParse(
      value.replaceAll('v', '').trim().replaceAll(',', '.'),
    );
  }

  double? _resolveLatitude(
    Map<String, dynamic> event,
    Map<String, dynamic> attributes,
  ) {
    return _asDouble(event['latitude']) ?? _asDouble(attributes['latitude']);
  }

  double? _resolveLongitude(
    Map<String, dynamic> event,
    Map<String, dynamic> attributes,
  ) {
    return _asDouble(event['longitude']) ?? _asDouble(attributes['longitude']);
  }

  double? _resolveSpeedKnots(
    Map<String, dynamic> event,
    Map<String, dynamic> attributes,
  ) {
    return _asDouble(event['speed']) ?? _asDouble(attributes['speed']);
  }

  bool? _resolveIgnition(
    Map<String, dynamic> event,
    Map<String, dynamic> attributes,
  ) {
    final raw =
        event['ignition'] ?? attributes['ignition'] ?? attributes['ignitionOn'];
    return _asBool(raw);
  }

  String? _resolveBattery(
    Map<String, dynamic> event,
    Map<String, dynamic> attributes,
  ) {
    final raw = event['battery'] ??
        attributes['battery'] ??
        attributes['batteryLevel'] ??
        attributes['power'] ??
        attributes['batteryVoltage'];
    if (raw == null) {
      return null;
    }
    if (raw is num) {
      final value = raw.toDouble();
      if (!value.isFinite) {
        return null;
      }
      if (value > 20) {
        return '${value.toStringAsFixed(0)}%';
      }
      return '${value.toStringAsFixed(2)} V';
    }
    final text = raw.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }

  String? _resolveAddress(
    Map<String, dynamic> event,
    Map<String, dynamic> attributes,
  ) {
    final candidates = <dynamic>[
      event['address'],
      attributes['address'],
      attributes['geocoder'],
      attributes['formattedAddress'],
    ];
    for (final candidate in candidates) {
      final text = candidate?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return null;
  }

  double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  bool? _asBool(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value > 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' ||
          normalized == '1' ||
          normalized == 'on' ||
          normalized == 'ligada' ||
          normalized == 'sim') {
        return true;
      }
      if (normalized == 'false' ||
          normalized == '0' ||
          normalized == 'off' ||
          normalized == 'desligada' ||
          normalized == 'nao' ||
          normalized == 'não') {
        return false;
      }
    }
    return null;
  }
}

class _AlertRuleFilter {
  _AlertRuleFilter._({
    required this.useServerRules,
    required this.globalTypes,
    required this.deviceIdsByType,
  });

  final bool useServerRules;
  final Set<String> globalTypes;
  final Map<String, Set<int>> deviceIdsByType;

  factory _AlertRuleFilter.fallback() {
    return _AlertRuleFilter._(
      useServerRules: false,
      globalTypes: const <String>{},
      deviceIdsByType: const <String, Set<int>>{},
    );
  }

  factory _AlertRuleFilter.fromServer({
    required List<Map<String, dynamic>> notifications,
    required List<Map<String, dynamic>> permissions,
  }) {
    final globalTypes = <String>{};
    final deviceIdsByType = <String, Set<int>>{};

    final deviceIdsByGroup = <int, Set<int>>{};
    for (final permission in permissions) {
      final groupId = _asInt(permission['groupId']);
      final deviceId = _asInt(permission['deviceId']);
      if (groupId == null || deviceId == null) {
        continue;
      }
      deviceIdsByGroup.putIfAbsent(groupId, () => <int>{}).add(deviceId);
    }

    for (final notification in notifications) {
      if (!_isNotificationEnabled(notification)) {
        continue;
      }

      final type = _normalizeType(notification['type']);
      if (type.isEmpty) {
        continue;
      }

      final notificationId = _asInt(notification['id']);
      final always = _asBool(notification['always']) == true;
      if (always || notificationId == null) {
        globalTypes.add(type);
        continue;
      }

      var scoped = false;
      var hasUserOnlyLink = false;
      final typeDevices = deviceIdsByType.putIfAbsent(type, () => <int>{});

      for (final permission in permissions) {
        if (_asInt(permission['notificationId']) != notificationId) {
          continue;
        }

        scoped = true;
        final permissionDeviceId = _asInt(permission['deviceId']);
        if (permissionDeviceId != null) {
          typeDevices.add(permissionDeviceId);
        }

        final permissionGroupId = _asInt(permission['groupId']);
        if (permissionGroupId != null) {
          final groupDevices = deviceIdsByGroup[permissionGroupId];
          if (groupDevices != null && groupDevices.isNotEmpty) {
            typeDevices.addAll(groupDevices);
          }
        }

        if (permissionDeviceId == null &&
            permissionGroupId == null &&
            _asInt(permission['userId']) != null) {
          hasUserOnlyLink = true;
        }
      }

      final noDeviceScope = typeDevices.isEmpty;
      if (!scoped || hasUserOnlyLink || noDeviceScope) {
        globalTypes.add(type);
      }
    }

    return _AlertRuleFilter._(
      useServerRules: true,
      globalTypes: globalTypes,
      deviceIdsByType: deviceIdsByType,
    );
  }

  bool matches({
    required String eventType,
    required int? deviceId,
    required Map<String, dynamic> attributes,
  }) {
    final candidates = _eventTypeCandidates(eventType, attributes);
    if (candidates.isEmpty) {
      return false;
    }

    if (!useServerRules) {
      return true;
    }

    for (final candidate in candidates) {
      if (globalTypes.contains(candidate)) {
        return true;
      }
      final allowedDevices = deviceIdsByType[candidate];
      if (deviceId != null &&
          allowedDevices != null &&
          allowedDevices.contains(deviceId)) {
        return true;
      }
    }
    return false;
  }

  bool get hasRules {
    if (globalTypes.isNotEmpty) {
      return true;
    }
    for (final ids in deviceIdsByType.values) {
      if (ids.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  static Set<String> _eventTypeCandidates(
    String eventType,
    Map<String, dynamic> attributes,
  ) {
    final items = <String>{};
    final normalizedType = _normalizeType(eventType);
    if (normalizedType.isNotEmpty) {
      items.add(normalizedType);
    }

    final alarm = _normalizeType(attributes['alarm']);
    if (alarm.isNotEmpty) {
      items.add(alarm);
    }

    final event = _normalizeType(attributes['event']);
    if (event.isNotEmpty) {
      items.add(event);
    }

    return items;
  }

  static bool _isNotificationEnabled(Map<String, dynamic> notification) {
    final disabled = _asBool(notification['disabled']);
    if (disabled == true) {
      return false;
    }
    final enabled = _asBool(notification['enabled']);
    if (enabled == false) {
      return false;
    }
    return true;
  }

  static String _normalizeType(dynamic value) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    if (text.isEmpty || text == 'null') {
      return '';
    }
    return text.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  static bool? _asBool(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value > 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' ||
          normalized == '1' ||
          normalized == 'yes' ||
          normalized == 'sim' ||
          normalized == 'on') {
        return true;
      }
      if (normalized == 'false' ||
          normalized == '0' ||
          normalized == 'no' ||
          normalized == 'nao' ||
          normalized == 'off') {
        return false;
      }
    }
    return null;
  }
}


class _AlertsKpiRow extends StatelessWidget {
  const _AlertsKpiRow({required this.summary});

  final AlertKpiSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _KpiCard(
          label: 'Hoje',
          value: summary.today,
          icon: Icons.today_rounded,
          color: const Color(0xFF176EEB),
        ),
        const SizedBox(width: 12),
        _KpiCard(
          label: 'Críticos',
          value: summary.critical,
          icon: Icons.priority_high_rounded,
          color: const Color(0xFFE53935),
        ),
        const SizedBox(width: 12),
        _KpiCard(
          label: 'Em análise',
          value: summary.inAnalysis,
          icon: Icons.manage_search_rounded,
          color: const Color(0xFFE67E22),
        ),
        const SizedBox(width: 12),
        _KpiCard(
          label: 'Resolvidos',
          value: summary.resolved,
          icon: Icons.check_circle_outline_rounded,
          color: const Color(0xFF18A558),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE8EEF6)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    color: Color(0xFF1F2A44),
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF5A6B84),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EEF6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF1F2A44),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF5A6B84),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (action != null) action!,
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8EEF6)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _NotifRulesTable extends StatelessWidget {
  const _NotifRulesTable({required this.rules, required this.onDelete});

  final List<Map<String, dynamic>> rules;
  final void Function(int id) onDelete;

  @override
  Widget build(BuildContext context) {
    if (rules.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'Nenhuma regra configurada.',
            style: TextStyle(color: Color(0xFF8A99B0), fontSize: 13),
          ),
        ),
      );
    }
    return Column(
      children: rules.map((rule) {
        final id = rule['id'] as int? ?? 0;
        final type = rule['type']?.toString() ?? '-';
        final always = rule['always'] == true;
        final notificators = rule['notificators']?.toString() ?? '';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFD),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE8EEF6)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF176EEB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.notifications_outlined,
                    color: Color(0xFF176EEB), size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type,
                      style: const TextStyle(
                        color: Color(0xFF1F2A44),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${always ? 'Global' : 'Específico'} · $notificators',
                      style: const TextStyle(
                          color: Color(0xFF5A6B84), fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remover',
                onPressed: () => onDelete(id),
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: Color(0xFFE53935)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _EventsTable extends StatelessWidget {
  const _EventsTable({required this.records});

  final List<AlertRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'Nenhum evento no período.',
            style: TextStyle(color: Color(0xFF8A99B0), fontSize: 13),
          ),
        ),
      );
    }
    return Column(
      children: records.take(50).map((rec) {
        final severityColor = switch (rec.severity) {
          AlertSeverity.critical => const Color(0xFFE53935),
          AlertSeverity.high => const Color(0xFFE67E22),
          AlertSeverity.medium => const Color(0xFFF59E0B),
          AlertSeverity.low => const Color(0xFF18A558),
        };
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE8EEF6)),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 36,
                decoration: BoxDecoration(
                  color: severityColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec.type,
                      style: const TextStyle(
                        color: Color(0xFF1F2A44),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      rec.vehicle,
                      style: const TextStyle(
                          color: Color(0xFF5A6B84), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  rec.description,
                  style: const TextStyle(
                      color: Color(0xFF5A6B84), fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTime(rec.dateTime),
                style: const TextStyle(
                    color: Color(0xFF8A99B0), fontSize: 11),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$d/$mo ${h}h$m';
  }
}

class _InlineLoader extends StatelessWidget {
  const _InlineLoader();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 60,
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Color(0xFF8A99B0), fontSize: 13),
        ),
      ),
    );
  }
}

class _PeriodChips extends StatelessWidget {
  const _PeriodChips({
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  final String selected;
  final List<String> options;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: options.map((opt) {
        final isSelected = opt == selected;
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: GestureDetector(
            onTap: () => onChanged(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF176EEB)
                    : const Color(0xFFF0F4FA),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                opt,
                style: TextStyle(
                  color:
                      isSelected ? Colors.white : const Color(0xFF5A6B84),
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DropFilter extends StatelessWidget {
  const _DropFilter({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: value,
      isDense: true,
      underline: const SizedBox(),
      style: const TextStyle(
          color: Color(0xFF1F2A44), fontSize: 13),
      items: options
          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _AlertFormSection extends StatelessWidget {
  const _AlertFormSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF1F2A44),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }
}

class _ChannelToggle extends StatelessWidget {
  const _ChannelToggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF5A6B84)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
                color: Color(0xFF1F2A44), fontSize: 13),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: const Color(0xFF176EEB),
        ),
      ],
    );
  }
}

class _ResolvedAlertMeaning {
  const _ResolvedAlertMeaning({
    required this.typeLabel,
    required this.severity,
    required this.descriptionFallback,
  });

  final String typeLabel;
  final AlertSeverity severity;
  final String descriptionFallback;
}
