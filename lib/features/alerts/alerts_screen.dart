import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  } catch (_) {
    return [];
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
  } catch (_) {
    // No menu Alertas, evita fallback mock para não inventar dados.
    return [];
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

    return AdminReferenceScaffold(
      title: 'Alertas',
      breadcrumbs: const ['Operacao', 'Alertas'],
      selectedMenu: 'alerts',
      child: devicesAsync.when(
        data: (devices) => listAsync.when(
          data: (events) {
            final records = _mapEvents(events, devices);
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
            message: 'Falha ao carregar alertas: $error',
          ),
        ),
        loading: () => const _LoadingPanel(),
        error: (error, _) => _ErrorPanel(
          message: 'Falha ao carregar veículos: $error',
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
    List<Map<String, dynamic>> events,
    List<TraccarDevice> devices,
  ) {
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

      records.add(
        AlertRecord(
          id: _resolveEventId(event, dateTime),
          severity: _resolveSeverity(typeCode, attributes),
          type: _humanizeEventType(typeCode),
          vehicle: _resolveVehicleName(deviceId, devicesById),
          description: _resolveDescription(event, attributes),
          dateTime: dateTime,
          status: _resolveStatus(event, attributes),
        ),
      );
    }

    records.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return records;
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
    final label = device?.name.trim() ?? '';
    if (label.isNotEmpty) {
      return label;
    }
    return 'Dispositivo $deviceId';
  }

  AlertSeverity _resolveSeverity(
    String eventType,
    Map<String, dynamic> attributes,
  ) {
    final normalized = eventType.toLowerCase();
    final alarm = (attributes['alarm'] ?? '').toString().toLowerCase();

    if (normalized.contains('panic') ||
        normalized.contains('sos') ||
        alarm.contains('sos') ||
        alarm.contains('panic') ||
        normalized == 'alarm') {
      return AlertSeverity.critical;
    }
    if (normalized.contains('overspeed') ||
        normalized.contains('speed') ||
        normalized.contains('geofence') ||
        normalized.contains('jammer')) {
      return AlertSeverity.high;
    }
    if (normalized.contains('ignition') ||
        normalized.contains('offline') ||
        normalized.contains('moving') ||
        normalized.contains('stopped')) {
      return AlertSeverity.medium;
    }
    return AlertSeverity.low;
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
    Map<String, dynamic> event,
    Map<String, dynamic> attributes,
  ) {
    final candidates = <String?>[
      event['message']?.toString(),
      event['description']?.toString(),
      attributes['message']?.toString(),
      attributes['description']?.toString(),
      attributes['text']?.toString(),
    ];
    for (final candidate in candidates) {
      final value = candidate?.trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
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

    return 'Sem descrição';
  }

  String _humanizeEventType(String type) {
    switch (type) {
      case 'deviceOnline':
        return 'Dispositivo online';
      case 'deviceOffline':
        return 'Dispositivo offline';
      case 'deviceUnknown':
        return 'Status desconhecido';
      case 'ignitionOn':
        return 'Ignição ligada';
      case 'ignitionOff':
        return 'Ignição desligada';
      case 'deviceMoving':
        return 'Em movimento';
      case 'deviceStopped':
        return 'Parado';
      case 'alarm':
        return 'Alarme';
      case 'commandResult':
        return 'Resultado de comando';
      case 'geofenceEnter':
        return 'Entrada em cerca';
      case 'geofenceExit':
        return 'Saída de cerca';
      case 'overspeed':
        return 'Excesso de velocidade';
      default:
        final value = type.trim();
        if (value.isEmpty) {
          return 'Evento';
        }
        final spaced = value
            .replaceAllMapped(
              RegExp(r'([a-z])([A-Z])'),
              (match) => '${match.group(1)} ${match.group(2)}',
            )
            .replaceAll('_', ' ')
            .toLowerCase();
        return spaced[0].toUpperCase() + spaced.substring(1);
    }
  }

  bool _isTruthy(dynamic value) {
    if (value == true) {
      return true;
    }
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
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
              color: Color(0xFFDDE5F0),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
