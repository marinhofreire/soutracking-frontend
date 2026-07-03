import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/display_text_formatter.dart';
import '../../data/models.dart';
import '../../state/session_state.dart';
import '../admin/admin_reference_ui.dart';
import 'models/alert_models.dart';
import 'widgets/alerts_filters_bar.dart';
import 'widgets/alerts_kpi_row.dart';
import 'widgets/alerts_table.dart';

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
  String _type = 'Todos';
  String _severity = 'Todas';
  String _status = 'Todos';
  String _vehicle = 'Todos';

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(alertsRealDevicesProvider);
    final listAsync = ref.watch(alertsEventsByPeriodProvider(_period));
    final notificationsAsync = ref.watch(notificationsProvider);
    final permissionsAsync = ref.watch(permissionsProvider);
    final ruleFilter = _resolveRuleFilter(
      notificationsAsync: notificationsAsync,
      permissionsAsync: permissionsAsync,
    );

    return AdminReferenceScaffold(
      title: 'Alertas',
      breadcrumbs: const ['Operação', 'Alertas'],
      selectedMenu: 'alerts',
      child: devicesAsync.when(
        data: (devices) => listAsync.when(
          data: (events) {
            final records = _mapEvents(
              events,
              devices,
              ruleFilter: ruleFilter,
            );
            final summary = _buildSummary(records);
            final filtered = _applyFilters(records);

            final periodOptions = const <String>['Hoje', '7 dias', '30 dias'];
            final typeOptions = <String>[
              'Todos',
              ...{for (final item in records) item.type},
            ];
            final severityOptions = <String>[
              'Todas',
              ...{for (final item in records) item.severity.label},
            ];
            final statusOptions = <String>[
              'Todos',
              ...{
                for (final item in records)
                  item.status?.label ?? 'Não informado',
              },
            ];
            final vehicleOptions = <String>[
              'Todos',
              ...{for (final item in records) item.vehicle},
            ];

            final selectedType =
                typeOptions.contains(_type) ? _type : typeOptions.first;
            final selectedSeverity = severityOptions.contains(_severity)
                ? _severity
                : severityOptions.first;
            final selectedStatus =
                statusOptions.contains(_status) ? _status : statusOptions.first;
            final selectedVehicle = vehicleOptions.contains(_vehicle)
                ? _vehicle
                : vehicleOptions.first;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AlertsKpiRow(summary: summary),
                const SizedBox(height: 12),
                AlertsFiltersBar(
                  period: _period,
                  type: selectedType,
                  severity: selectedSeverity,
                  status: selectedStatus,
                  vehicle: selectedVehicle,
                  periodOptions: periodOptions,
                  typeOptions: typeOptions,
                  severityOptions: severityOptions,
                  statusOptions: statusOptions,
                  vehicleOptions: vehicleOptions,
                  onPeriodChanged: (value) {
                    setState(() {
                      _period = value;
                      _type = 'Todos';
                      _severity = 'Todas';
                      _status = 'Todos';
                      _vehicle = 'Todos';
                    });
                  },
                  onTypeChanged: (value) => setState(() => _type = value),
                  onSeverityChanged: (value) =>
                      setState(() => _severity = value),
                  onStatusChanged: (value) => setState(() => _status = value),
                  onVehicleChanged: (value) => setState(() => _vehicle = value),
                ),
                const SizedBox(height: 12),
                AlertsTable(records: filtered),
              ],
            );
          },
          loading: () => const _LoadingPanel(),
          error: (error, _) => _ErrorPanel(
            message: 'N\u00e3o foi poss\u00edvel carregar alertas',
          ),
        ),
        loading: () => const _LoadingPanel(),
        error: (error, _) => _ErrorPanel(
          message: 'N\u00e3o foi poss\u00edvel carregar alertas',
        ),
      ),
    );
  }

  List<AlertRecord> _applyFilters(List<AlertRecord> records) {
    return records.where((record) {
      if (_type != 'Todos' && record.type != _type) return false;
      if (_severity != 'Todas' && record.severity.label != _severity) {
        return false;
      }
      if (_status != 'Todos') {
        final label = record.status?.label ?? 'Não informado';
        if (label != _status) return false;
      }
      if (_vehicle != 'Todos' && record.vehicle != _vehicle) return false;
      return true;
    }).toList();
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

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const AdminGlassPanel(
      child: SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AdminGlassPanel(
      child: SizedBox(
        height: 120,
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF5F738F),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
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
