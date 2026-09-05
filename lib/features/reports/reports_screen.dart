import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:http/http.dart' as http;
import '../../data/models.dart';
import '../../state/session_state.dart';
import 'models/report_models.dart';
import 'providers/executive_summary_provider.dart';
import 'services/report_export_service.dart';
import 'widgets/executive_summary_panel.dart';
import 'widgets/reports_filters_bar.dart';
import 'widgets/reports_kpi_row.dart';
import 'widgets/reports_table.dart';

class _ReportsQueryParams {
  const _ReportsQueryParams({
    required this.from,
    required this.to,
    required this.type,
    required this.vehicle,
    required this.revision,
  });

  final DateTime from;
  final DateTime to;
  final String type;
  final String vehicle;
  final int revision;

  @override
  bool operator ==(Object other) {
    return other is _ReportsQueryParams &&
        other.from == from &&
        other.to == to &&
        other.type == type &&
        other.vehicle == vehicle &&
        other.revision == revision;
  }

  @override
  int get hashCode => Object.hash(from, to, type, vehicle, revision);
}

final reportsRealDevicesProvider =
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
    return [];
  }
});

final reportsListProvider =
    FutureProvider.family<List<ReportRecord>, _ReportsQueryParams>(
        (ref, query) async {
  final session = ref.watch(sessionProvider);
  if (!session.isAuthenticated) {
    return [];
  }

  final client = ref.watch(traccarClientProvider);
  final devices = await ref.watch(reportsRealDevicesProvider.future);
  final selectedDeviceId = _resolveSelectedDeviceId(query.vehicle, devices);

  try {
    final raw = await client.getReport(
      path: _resolveReportEndpoint(query.type),
      cookie: session.cookie,
      authHeader: session.authHeader,
      from: query.from,
      to: query.to,
      deviceId: selectedDeviceId,
    );
    return _mapReportRecords(
      rawRecords: raw,
      devices: devices,
      selectedTypeLabel: query.type,
      from: query.from,
      to: query.to,
    );
  } catch (error) {
    throw Exception('Nao foi possivel carregar relatórios: $error');
  }
});

int? _resolveSelectedDeviceId(
    String vehicleValue, List<TraccarDevice> devices) {
  if (vehicleValue == 'Todos') {
    return null;
  }

  final directId = int.tryParse(vehicleValue);
  if (directId != null) {
    for (final device in devices) {
      if (device.id == directId) {
        return directId;
      }
    }
  }

  for (final device in devices) {
    if (device.name == vehicleValue) {
      return device.id;
    }
  }

  return null;
}

String _resolveReportEndpoint(String typeLabel) {
  switch (typeLabel) {
    case 'Rotas':
      return '/reports/route';
    case 'Viagens':
      return '/reports/trips';
    case 'Paradas':
      return '/reports/stops';
    case 'Resumo':
    case 'Resumo operacional':
      return '/reports/summary';
    case 'Alertas':
      return '/reports/events';
    case 'Eventos':
    case 'Todos':
    default:
      return '/reports/events';
  }
}

ReportType _typeFromLabel(String label) {
  switch (label) {
    case 'Rotas':
      return ReportType.routes;
    case 'Viagens':
      return ReportType.trips;
    case 'Paradas':
      return ReportType.stops;
    case 'Resumo':
    case 'Resumo operacional':
      return ReportType.distance;
    case 'Alertas':
      return ReportType.alerts;
    case 'Eventos':
    case 'Todos':
    default:
      return ReportType.events;
  }
}

List<ReportRecord> _mapReportRecords({
  required List<Map<String, dynamic>> rawRecords,
  required List<TraccarDevice> devices,
  required String selectedTypeLabel,
  required DateTime from,
  required DateTime to,
}) {
  final devicesById = <int, TraccarDevice>{
    for (final device in devices) device.id: device,
  };

  final groups = <String, _ReportRecordGroup>{};
  final selectedType = _typeFromLabel(selectedTypeLabel);

  for (final raw in rawRecords) {
    final attributes = _asMap(raw['attributes']);
    final createdAt = _resolveDateTime(raw) ?? DateTime.now();
    if (createdAt.isBefore(from) || createdAt.isAfter(to)) {
      continue;
    }
    final deviceId = _resolveInt(raw['deviceId']);
    final eventType = _resolveEventType(raw);
    final type = selectedTypeLabel == 'Todos'
        ? _inferTypeFromRaw(raw)
        : selectedTypeLabel == 'Alertas'
            ? ReportType.alerts
            : selectedType;

    final record = ReportRecord(
      name: _resolveName(raw, type),
      type: type,
      vehicle: _resolveVehicleName(deviceId, devicesById),
      driver: _resolveDriver(raw),
      period: _resolvePeriod(raw, from, to),
      status: _resolveStatus(raw),
      createdAt: createdAt,
      format: ReportFormat.screen,
      totalRecords: _resolveCount(raw),
      deviceId: deviceId,
      latitude: _resolveLatitude(raw, attributes),
      longitude: _resolveLongitude(raw, attributes),
      speedKnots: _resolveSpeedKnots(raw, attributes),
      ignition: _resolveIgnition(raw, attributes),
      battery: _resolveBattery(raw, attributes),
      eventType: eventType,
      address: _resolveAddress(raw, attributes),
      attributes: attributes,
    );

    // Eventos brutos de conexão (online/offline/unknown/moving) repetem
    // várias vezes por dispositivo no período — agrupa em 1 linha por
    // (dispositivo + tipo de evento) em vez de 1 linha por ocorrência.
    //
    // Rotas vêm do Traccar como 1 ponto de GPS por posição registrada
    // (podem ser centenas no período) — mas quando o usuário pede "uma
    // rota" pra um veículo/período, o resultado esperado é 1 linha só (o
    // trajeto inteiro do pedido), não 1 por ponto nem 1 por dia. Agrupa
    // tudo do mesmo device no request inteiro.
    //
    // Viagens e paradas são ocorrências discretas de verdade (cada viagem
    // tem início/fim próprios) — cada uma continua sendo 1 linha, não
    // agrupa.
    final groupKey = switch (type) {
      ReportType.events =>
        '${deviceId ?? 'sem-dispositivo'}|${eventType ?? record.name}',
      ReportType.routes => 'routes|${deviceId ?? 'sem-dispositivo'}',
      _ => 'individual|${groups.length}|${record.name}|${record.createdAt}',
    };

    final existing = groups[groupKey];
    if (existing == null) {
      groups[groupKey] = _ReportRecordGroup(latest: record, occurrences: 1);
    } else if (createdAt.isAfter(existing.latest.createdAt)) {
      groups[groupKey] =
          _ReportRecordGroup(latest: record, occurrences: existing.occurrences + 1);
    } else {
      groups[groupKey] = _ReportRecordGroup(
        latest: existing.latest,
        occurrences: existing.occurrences + 1,
      );
    }
  }

  final routesFullPeriod = _resolvePeriod(const {}, from, to);

  final records = <ReportRecord>[
    for (final group in groups.values)
      group.occurrences == 1
          ? group.latest
          : ReportRecord(
              name: group.latest.name,
              type: group.latest.type,
              vehicle: group.latest.vehicle,
              driver: group.latest.driver,
              // Rota agrupada mostra o período inteiro do pedido (from→to),
              // não só o timestamp do ponto mais recente do trajeto.
              period: group.latest.type == ReportType.routes
                  ? routesFullPeriod
                  : group.latest.period,
              status: group.latest.status,
              createdAt: group.latest.createdAt,
              format: group.latest.format,
              totalRecords: group.occurrences,
              deviceId: group.latest.deviceId,
              latitude: group.latest.latitude,
              longitude: group.latest.longitude,
              speedKnots: group.latest.speedKnots,
              ignition: group.latest.ignition,
              battery: group.latest.battery,
              eventType: group.latest.eventType,
              address: group.latest.address,
              attributes: group.latest.attributes,
            ),
  ];

  records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return records;
}

class _ReportRecordGroup {
  const _ReportRecordGroup({required this.latest, required this.occurrences});

  final ReportRecord latest;
  final int occurrences;
}

DateTime? _resolveDateTime(Map<String, dynamic> raw) {
  final candidates = [
    raw['eventTime'],
    raw['startTime'],
    raw['serverTime'],
    raw['deviceTime'],
    raw['fixTime'],
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
  return null;
}

int? _resolveInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

ReportType _inferTypeFromRaw(Map<String, dynamic> raw) {
  final eventType = '${raw['type'] ?? ''}'.toLowerCase();
  if (eventType.contains('trip')) return ReportType.trips;
  if (eventType.contains('stop')) return ReportType.stops;
  if (eventType.contains('route')) return ReportType.routes;
  return ReportType.events;
}

String _resolveName(Map<String, dynamic> raw, ReportType type) {
  final explicitName = '${raw['name'] ?? ''}'.trim();
  if (explicitName.isNotEmpty) {
    return explicitName;
  }

  final eventType = '${raw['type'] ?? ''}'.trim();
  if (type == ReportType.events && eventType.isNotEmpty) {
    return 'Evento ${eventType.toLowerCase()}';
  }

  switch (type) {
    case ReportType.routes:
      return 'Relatório de rotas';
    case ReportType.trips:
      return 'Relatório de viagens';
    case ReportType.stops:
      return 'Relatório de paradas';
    case ReportType.distance:
      return 'Relatório de resumo operacional';
    case ReportType.alerts:
      return 'Relatório de alertas';
    default:
      return 'Relatório de eventos';
  }
}

String _resolveVehicleName(int? deviceId, Map<int, TraccarDevice> devicesById) {
  if (deviceId == null) return 'Não informado';
  final device = devicesById[deviceId];
  final name = device?.name.trim() ?? '';
  if (name.isNotEmpty) return name;
  return 'Dispositivo $deviceId';
}

String _resolveVehicleFilterLabel(
  String selectedValue,
  List<ReportFilterOption> options,
) {
  for (final option in options) {
    if (option.value == selectedValue) {
      return option.label;
    }
  }
  return 'Todos';
}

List<ReportFilterOption> _buildVehicleOptions(List<TraccarDevice> devices) {
  final duplicateNames = <String, int>{};
  for (final device in devices) {
    final name = device.name.trim().isEmpty
        ? 'Dispositivo ${device.id}'
        : device.name.trim();
    duplicateNames.update(name, (count) => count + 1, ifAbsent: () => 1);
  }

  final seenValues = <String>{'Todos'};
  final options = <ReportFilterOption>[
    const ReportFilterOption(value: 'Todos', label: 'Todos'),
  ];

  for (final device in devices) {
    final value = device.id.toString();
    if (!seenValues.add(value)) {
      continue;
    }
    final baseName = device.name.trim().isEmpty
        ? 'Dispositivo ${device.id}'
        : device.name.trim();
    final label = (duplicateNames[baseName] ?? 0) > 1
        ? '$baseName - ID ${device.id}'
        : baseName;
    options.add(ReportFilterOption(value: value, label: label));
  }

  return options;
}

String _resolveDriver(Map<String, dynamic> raw) {
  final candidates = [
    raw['driverName'],
    raw['driver'],
    raw['driverId'],
  ];

  for (final candidate in candidates) {
    final text = '${candidate ?? ''}'.trim();
    if (text.isNotEmpty && text.toLowerCase() != 'null') {
      return text;
    }
  }
  return 'Não informado';
}

String _resolvePeriod(Map<String, dynamic> raw, DateTime from, DateTime to) {
  final start = _resolveDateTime({'eventTime': raw['startTime']});
  final end = _resolveDateTime({'eventTime': raw['endTime']});

  final begin = start ?? from;
  final finish = end ?? to;

  final fromDay = begin.day.toString().padLeft(2, '0');
  final fromMonth = begin.month.toString().padLeft(2, '0');
  final toDay = finish.day.toString().padLeft(2, '0');
  final toMonth = finish.month.toString().padLeft(2, '0');
  return '$fromDay/$fromMonth - $toDay/$toMonth';
}

ReportStatus _resolveStatus(Map<String, dynamic> raw) {
  final status = '${raw['status'] ?? ''}'.toLowerCase();
  if (status.contains('fail') || status.contains('error')) {
    return ReportStatus.failed;
  }
  if (status.contains('process')) {
    return ReportStatus.processing;
  }
  if (status.contains('schedule')) {
    return ReportStatus.scheduled;
  }
  return ReportStatus.ready;
}

int _resolveCount(Map<String, dynamic> raw) {
  final candidates = [raw['count'], raw['total'], raw['distance']];
  for (final candidate in candidates) {
    if (candidate is int) return candidate;
    if (candidate is num) return candidate.toInt();
    if (candidate is String) {
      final parsed = int.tryParse(candidate);
      if (parsed != null) return parsed;
    }
  }
  return 1;
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

double? _resolveLatitude(
  Map<String, dynamic> raw,
  Map<String, dynamic> attributes,
) {
  return _asDouble(raw['latitude']) ?? _asDouble(attributes['latitude']);
}

double? _resolveLongitude(
  Map<String, dynamic> raw,
  Map<String, dynamic> attributes,
) {
  return _asDouble(raw['longitude']) ?? _asDouble(attributes['longitude']);
}

double? _resolveSpeedKnots(
  Map<String, dynamic> raw,
  Map<String, dynamic> attributes,
) {
  return _asDouble(raw['speed']) ?? _asDouble(attributes['speed']);
}

double? _resolveSensorDouble(
  Map<String, dynamic> raw,
  Map<String, dynamic> attributes,
  List<String> rawKeys,
  List<String> attributeKeys,
) {
  for (final key in rawKeys) {
    final value = _asDouble(raw[key]);
    if (value != null && value.isFinite) {
      return value;
    }
  }
  for (final key in attributeKeys) {
    final value = _asDouble(attributes[key]);
    if (value != null && value.isFinite) {
      return value;
    }
  }
  return null;
}

bool? _resolveIgnition(
  Map<String, dynamic> raw,
  Map<String, dynamic> attributes,
) {
  final rawValue =
      raw['ignition'] ?? attributes['ignition'] ?? attributes['ignitionOn'];
  return _asBool(rawValue);
}

String? _resolveBattery(
  Map<String, dynamic> raw,
  Map<String, dynamic> attributes,
) {
  final value = raw['battery'] ??
      attributes['battery'] ??
      attributes['batteryLevel'] ??
      attributes['power'] ??
      attributes['batteryVoltage'];
  if (value == null) {
    return null;
  }
  if (value is num) {
    final number = value.toDouble();
    if (!number.isFinite) {
      return null;
    }
    if (number > 20) {
      return '${number.toStringAsFixed(0)}%';
    }
    return '${number.toStringAsFixed(2)} V';
  }
  final text = value.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') {
    return null;
  }
  return text;
}

String? _resolveSignal(
  Map<String, dynamic> raw,
  Map<String, dynamic> attributes,
) {
  final value = raw['signal'] ??
      raw['gsm'] ??
      attributes['signal'] ??
      attributes['gsm'] ??
      attributes['gsmSignal'] ??
      attributes['rssi'];
  if (value == null) {
    return null;
  }
  if (value is num) {
    final number = value.toDouble();
    if (!number.isFinite) {
      return null;
    }
    return number.toStringAsFixed(0);
  }
  final text = value.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') {
    return null;
  }
  return text;
}

String? _resolveAddress(
  Map<String, dynamic> raw,
  Map<String, dynamic> attributes,
) {
  final candidates = [
    raw['address'],
    attributes['address'],
    attributes['geocoder'],
    attributes['formattedAddress'],
  ];
  for (final candidate in candidates) {
    final text = '${candidate ?? ''}'.trim();
    if (text.isNotEmpty && text.toLowerCase() != 'null') {
      return text;
    }
  }
  return null;
}

String? _resolveEventType(Map<String, dynamic> raw) {
  final text = '${raw['type'] ?? ''}'.trim();
  if (text.isEmpty) {
    return null;
  }
  return text;
}

bool _isAlertEventType(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }

  return normalized.contains('alarm') ||
      normalized.contains('alert') ||
      normalized.contains('overspeed') ||
      normalized.contains('geofence') ||
      normalized.contains('ignition') ||
      normalized.contains('motion') ||
      normalized.contains('sos') ||
      normalized.contains('panic') ||
      normalized.contains('harsh') ||
      normalized.contains('falha');
}

DateTime _defaultReportsTo() => DateTime.now();

DateTime _defaultReportsFrom() =>
    _defaultReportsTo().subtract(const Duration(days: 30));

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late DateTime _startDateTime;
  late DateTime _endDateTime;
  late DateTime _appliedStartDateTime;
  late DateTime _appliedEndDateTime;
  String _type = 'Resumo operacional';
  String _appliedType = 'Resumo operacional';
  String _vehicle = 'Todos';
  String _appliedVehicle = 'Todos';
  String _driver = 'Todos';
  String _appliedDriver = 'Todos';
  String _eventType = 'Todos';
  String _appliedEventType = 'Todos';
  String _status = 'Todos';
  String _appliedStatus = 'Todos';
  bool _hasSearched = false;
  static const bool _pdfEnabled = false;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _startDateTime = _defaultReportsFrom();
    _endDateTime = _defaultReportsTo();
    _appliedStartDateTime = _startDateTime;
    _appliedEndDateTime = _endDateTime;
    _appliedType = _type;
    _appliedVehicle = _vehicle;
    _appliedDriver = _driver;
    _appliedEventType = _eventType;
    _appliedStatus = _status;
  }

  Future<_ReportsReplayData> _loadReplayData({
    required String vehicleValue,
  }) async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthenticated) {
      return _ReportsReplayData.empty(
        message: 'Sessão inválida para carregar o replay.',
      );
    }

    final devices = await ref.read(reportsRealDevicesProvider.future);
    final deviceId = _resolveSelectedDeviceId(vehicleValue, devices);
    if (deviceId == null) {
      return _ReportsReplayData.empty(
        message: 'Selecione um equipamento para visualizar o replay.',
      );
    }

    final client = ref.read(traccarClientProvider);
    final vehicleLabel = _resolveVehicleFilterLabel(
      vehicleValue,
      _buildVehicleOptions(devices),
    );

    final responses = await Future.wait([
      client.getReport(
        path: '/reports/route',
        cookie: session.cookie,
        authHeader: session.authHeader,
        from: _appliedStartDateTime,
        to: _appliedEndDateTime,
        deviceId: deviceId,
      ),
      client.getReport(
        path: '/reports/events',
        cookie: session.cookie,
        authHeader: session.authHeader,
        from: _appliedStartDateTime,
        to: _appliedEndDateTime,
        deviceId: deviceId,
      ),
      client.getReport(
        path: '/reports/summary',
        cookie: session.cookie,
        authHeader: session.authHeader,
        from: _appliedStartDateTime,
        to: _appliedEndDateTime,
        deviceId: deviceId,
      ),
    ]);

    final pointRows = responses[0];
    final eventRows = responses[1];
    final summaryRows = responses[2];

    final points = <_RouteReplayPoint>[
      for (final row in pointRows)
        if (_RouteReplayPoint.fromMap(row) case final point?) point,
    ]..sort((a, b) {
        final at = a.effectiveTime;
        final bt = b.effectiveTime;
        if (at == null && bt == null) return 0;
        if (at == null) return -1;
        if (bt == null) return 1;
        return at.compareTo(bt);
      });

    final events = <_ReplayEvent>[
      for (final row in eventRows)
        if (_ReplayEvent.fromMap(row) case final event?) event,
    ]..sort((a, b) => a.time.compareTo(b.time));

    final summary = _ReplaySummary.fromRows(
      rows: summaryRows,
      points: points,
      events: events,
      periodStart: _appliedStartDateTime,
      periodEnd: _appliedEndDateTime,
    );

    return _ReportsReplayData(
      vehicleLabel: vehicleLabel,
      deviceId: deviceId,
      periodStart: _appliedStartDateTime,
      periodEnd: _appliedEndDateTime,
      points: points,
      events: events,
      summary: summary,
    );
  }

  Future<_ReportsReplayData> _loadReplayDataForDevice({
    required int deviceId,
    required String vehicleLabel,
  }) async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthenticated) {
      return _ReportsReplayData.empty(
        message: 'Sessão inválida para carregar o replay.',
      );
    }

    final client = ref.read(traccarClientProvider);
    final responses = await Future.wait([
      client.getReport(
        path: '/reports/route',
        cookie: session.cookie,
        authHeader: session.authHeader,
        from: _appliedStartDateTime,
        to: _appliedEndDateTime,
        deviceId: deviceId,
      ),
      client.getReport(
        path: '/reports/events',
        cookie: session.cookie,
        authHeader: session.authHeader,
        from: _appliedStartDateTime,
        to: _appliedEndDateTime,
        deviceId: deviceId,
      ),
      client.getReport(
        path: '/reports/summary',
        cookie: session.cookie,
        authHeader: session.authHeader,
        from: _appliedStartDateTime,
        to: _appliedEndDateTime,
        deviceId: deviceId,
      ),
    ]);

    final points = <_RouteReplayPoint>[
      for (final row in responses[0])
        if (_RouteReplayPoint.fromMap(row) case final point?) point,
    ]..sort((a, b) {
        final at = a.effectiveTime;
        final bt = b.effectiveTime;
        if (at == null && bt == null) return 0;
        if (at == null) return -1;
        if (bt == null) return 1;
        return at.compareTo(bt);
      });

    final events = <_ReplayEvent>[
      for (final row in responses[1])
        if (_ReplayEvent.fromMap(row) case final event?) event,
    ]..sort((a, b) => a.time.compareTo(b.time));

    final summary = _ReplaySummary.fromRows(
      rows: responses[2],
      points: points,
      events: events,
      periodStart: _appliedStartDateTime,
      periodEnd: _appliedEndDateTime,
    );

    if (points.isEmpty) {
      return _ReportsReplayData.empty(
        message: 'Sem posições válidas neste período.',
      );
    }

    return _ReportsReplayData(
      vehicleLabel: vehicleLabel,
      deviceId: deviceId,
      periodStart: _appliedStartDateTime,
      periodEnd: _appliedEndDateTime,
      points: points,
      events: events,
      summary: summary,
    );
  }

  Future<void> _openRecordDetail(ReportRecord record) async {
    final deviceId = record.deviceId;
    if (deviceId == null) {
      _showAction('Este item não possui equipamento vinculado para replay.');
      return;
    }

    final data = await _loadReplayDataForDevice(
      deviceId: deviceId,
      vehicleLabel: record.vehicle,
    );
    if (!mounted) {
      return;
    }
    if (data.points.isEmpty) {
      _showAction(data.message ?? 'Sem posições válidas neste período.');
      return;
    }

    final mapPoints = [
      for (final point in data.points)
        ReportRouteMapPoint(
          latitude: point.latitude,
          longitude: point.longitude,
          effectiveTime: point.effectiveTime,
          course: point.course,
          address: point.address,
          speedKmh: point.speedKmh,
          rpm: point.rpm,
          ignition: point.ignition,
          batteryLabel: point.battery,
          satellites: point.satellites,
          odometerKm: point.odometerKm,
          hourmeterHours: point.hourmeterHours,
          motion: point.motion,
          signalLabel: point.signal,
        ),
    ];
    final requestNonce = DateTime.now().microsecondsSinceEpoch.toString();

    // Abre o replay na hora com os pontos brutos — não espera o OSRM.
    ref.read(reportRouteMapSelectionProvider.notifier).state =
        ReportRouteMapSelection(
      deviceId: deviceId,
      vehicleName: record.vehicle,
      from: _appliedStartDateTime,
      to: _appliedEndDateTime,
      requestNonce: requestNonce,
      points: mapPoints,
    );
    widget.onClose?.call();

    // Em segundo plano, manda pro OSRM e, quando terminar, atualiza a linha
    // do trajeto — só se o usuário ainda estiver vendo esse mesmo replay
    // (não trocou pra outro enquanto isso rodava).
    unawaited(() async {
      final matchedPath = await _matchPointsWithOsrm(data.points);
      if (!mounted) return;
      final current = ref.read(reportRouteMapSelectionProvider);
      if (current?.requestNonce != requestNonce) return;
      ref.read(reportRouteMapSelectionProvider.notifier).state =
          ReportRouteMapSelection(
        deviceId: deviceId,
        vehicleName: record.vehicle,
        from: _appliedStartDateTime,
        to: _appliedEndDateTime,
        requestNonce: requestNonce,
        matchedPath: matchedPath,
        points: mapPoints,
      );
    }());
  }

  /// Distância aproximada (km) entre dois pontos, fórmula de haversine.
  double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLon = (lon2 - lon1) * (math.pi / 180.0);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Quebra o trajeto bruto em pedaços contínuos, cortando exatamente onde
  /// há um buraco de conexão do rastreador (distância grande entre dois
  /// pontos consecutivos). Cada pedaço vira uma linha separada no mapa —
  /// assim um buraco real vira um buraco visual, não uma reta falsa
  /// conectando dois trechos sem relação.
  List<List<_RouteReplayPoint>> _splitRouteIntoContinuousSegments(
    List<_RouteReplayPoint> points,
  ) {
    const maxGapKm = 0.6;
    final segments = <List<_RouteReplayPoint>>[];
    var current = <_RouteReplayPoint>[];
    for (final point in points) {
      if (current.isNotEmpty) {
        final last = current.last;
        final distanceKm = _haversineKm(
          last.latitude,
          last.longitude,
          point.latitude,
          point.longitude,
        );
        if (distanceKm > maxGapKm) {
          if (current.length > 1) segments.add(current);
          current = <_RouteReplayPoint>[];
        }
      }
      current.add(point);
    }
    if (current.length > 1) segments.add(current);
    return segments;
  }

  /// Manda um pedaço contínuo do trajeto pro serviço OSRM (self-hosted,
  /// Sudeste do Brasil), que "gruda" os pontos no asfalto real. Se o serviço
  /// falhar ou não achar match, cai de volta pros pontos originais desse
  /// pedaço (sem quebrar o replay).
  Future<List<MatchedLatLng>> _matchSegmentWithOsrm(
    List<_RouteReplayPoint> segment,
    http.Client client,
  ) async {
    final sampled = _downsampleRouteForMatching(segment, targetCount: 200);
    if (sampled.length < 2) {
      return [
        for (final p in sampled) MatchedLatLng(p.latitude, p.longitude),
      ];
    }

    const batchSize = 90;
    final matched = <MatchedLatLng>[];
    var start = 0;
    while (start < sampled.length - 1) {
      final end = math.min(start + batchSize, sampled.length);
      final batch = sampled.sublist(start, end);
      if (batch.length < 2) break;

      final coords =
          batch.map((p) => '${p.longitude},${p.latitude}').join(';');
      final radiuses = List.filled(batch.length, '30').join(';');
      final uri = Uri.parse(
        'http://204.168.191.10:5333/match/v1/driving/$coords'
        '?geometries=geojson&overview=full&radiuses=$radiuses',
      );

      var matchedThisBatch = false;
      try {
        final response =
            await client.get(uri).timeout(const Duration(seconds: 12));
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final matchings = json['matchings'] as List<dynamic>?;
          if (matchings != null && matchings.isNotEmpty) {
            // Mesmo dentro de um pedaço já contínuo, o OSRM pode ocasionalmente
            // devolver mais de um trecho (baixa confiança de match). Usa só o
            // maior, pra não criar conexão falsa entre pedaços sem relação.
            final largest = matchings.cast<Map<String, dynamic>>().reduce(
              (a, b) {
                final aCoords =
                    (a['geometry'] as Map<String, dynamic>)['coordinates']
                        as List<dynamic>;
                final bCoords =
                    (b['geometry'] as Map<String, dynamic>)['coordinates']
                        as List<dynamic>;
                return aCoords.length >= bCoords.length ? a : b;
              },
            );
            final geometry = largest['geometry'] as Map<String, dynamic>;
            final coordinates = geometry['coordinates'] as List<dynamic>;
            for (final pair in coordinates) {
              final lonLat = pair as List<dynamic>;
              matched.add(MatchedLatLng(
                (lonLat[1] as num).toDouble(),
                (lonLat[0] as num).toDouble(),
              ));
            }
            matchedThisBatch = true;
          }
        }
      } catch (_) {
        // Sem internet/serviço fora do ar: cai pro fallback abaixo.
      }

      if (!matchedThisBatch) {
        for (final p in batch) {
          matched.add(MatchedLatLng(p.latitude, p.longitude));
        }
      }

      if (end >= sampled.length) break;
      start = end - 1; // sobrepõe 1 ponto entre lotes pra continuidade
    }
    return matched;
  }

  /// Ponto de entrada: quebra o trajeto em pedaços contínuos e manda cada um
  /// pro OSRM separadamente. Retorna uma lista de trechos (não uma linha só)
  /// — cada trecho é desenhado como sua própria polyline no mapa.
  Future<List<List<MatchedLatLng>>> _matchPointsWithOsrm(
    List<_RouteReplayPoint> points,
  ) async {
    final segments = _splitRouteIntoContinuousSegments(points);
    if (segments.isEmpty) {
      return [
        [for (final p in points) MatchedLatLng(p.latitude, p.longitude)],
      ];
    }

    final client = http.Client();
    final result = <List<MatchedLatLng>>[];
    try {
      for (final segment in segments) {
        result.add(await _matchSegmentWithOsrm(segment, client));
      }
    } finally {
      client.close();
    }
    return result;
  }

  /// Reduz a quantidade de pontos antes de mandar pro OSRM (rotas de replay
  /// podem ter milhares de pontos; não precisamos de todos pra desenhar uma
  /// linha suave — reduz o número de chamadas HTTP necessárias).
  List<_RouteReplayPoint> _downsampleRouteForMatching(
    List<_RouteReplayPoint> points, {
    required int targetCount,
  }) {
    if (points.length <= targetCount) {
      return points;
    }
    final step = points.length / targetCount;
    final sampled = <_RouteReplayPoint>[];
    for (var i = 0.0; i < points.length; i += step) {
      sampled.add(points[i.floor()]);
    }
    if (sampled.last != points.last) {
      sampled.add(points.last);
    }
    return sampled;
  }

  Future<void> _exportRecords(
    List<ReportRecord> records,
    ReportExportFormat format, {
    ReportRecord? singleRecord,
  }) async {
    if (format == ReportExportFormat.pdf) {
      _showAction(
        'PDF segue bloqueado: exportacao real ainda depende de implementacao dedicada.',
      );
      return;
    }
    if (!_hasSearched) {
      _showAction('Busque um relatório antes de exportar');
      return;
    }
    final target =
        singleRecord == null ? records : <ReportRecord>[singleRecord];
    if (target.isEmpty) {
      _showAction('Busque um relatório antes de exportar');
      return;
    }
    final result = await exportReports(
      records: target,
      format: format,
      scopeLabel: _buildScopeLabel(singleRecord),
    );
    if (!mounted) {
      return;
    }
    _showAction(result.message);
  }

  String _buildScopeLabel(ReportRecord? singleRecord) {
    if (singleRecord != null) {
      return '${singleRecord.type.label}_${singleRecord.vehicle}';
    }
    final vehicleLabel = _resolveVehicleFilterLabel(
      _appliedVehicle,
      _buildVehicleOptions(
        ref.read(reportsRealDevicesProvider).valueOrNull ??
            const <TraccarDevice>[],
      ),
    );
    return '$_appliedType|${_fileDateLabel(_appliedStartDateTime)}-${_fileDateLabel(_appliedEndDateTime)}|'
        '$vehicleLabel|$_appliedDriver|$_appliedEventType|$_appliedStatus';
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _startDateTime : _endDateTime;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) {
      return;
    }

    setState(() {
      final merged = DateTime(
        picked.year,
        picked.month,
        picked.day,
        current.hour,
        current.minute,
      );
      if (isStart) {
        _startDateTime = merged;
      } else {
        _endDateTime = merged;
      }
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart ? _startDateTime : _endDateTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: current.hour,
        minute: current.minute,
      ),
    );
    if (picked == null) {
      return;
    }

    setState(() {
      final merged = DateTime(
        current.year,
        current.month,
        current.day,
        picked.hour,
        picked.minute,
      );
      if (isStart) {
        _startDateTime = merged;
      } else {
        _endDateTime = merged;
      }
    });
  }

  void _applyQueryFilters() {
    if (_startDateTime.isAfter(_endDateTime)) {
      _showAction('A data/hora inicial precisa ser menor que a final.');
      return;
    }

    setState(() {
      _appliedStartDateTime = _startDateTime;
      _appliedEndDateTime = _endDateTime;
      _appliedType = _type;
      _appliedVehicle = _vehicle;
      _appliedDriver = _driver;
      _appliedEventType = _eventType;
      _appliedStatus = _status;
      _hasSearched = true;
      _revision++;
    });
  }

  void _clearFilters() {
    final defaultFrom = _defaultReportsFrom();
    final defaultTo = _defaultReportsTo();
    setState(() {
      _startDateTime = defaultFrom;
      _endDateTime = defaultTo;
      _appliedStartDateTime = defaultFrom;
      _appliedEndDateTime = defaultTo;
      _vehicle = 'Todos';
      _appliedVehicle = 'Todos';
      _driver = 'Todos';
      _appliedDriver = 'Todos';
      _type = 'Resumo operacional';
      _appliedType = 'Resumo operacional';
      _eventType = 'Todos';
      _appliedEventType = 'Todos';
      _status = 'Todos';
      _appliedStatus = 'Todos';
      _hasSearched = false;
      _revision++;
    });
  }

  String _fileDateLabel(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$year$month${day}_$hour$minute';
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(reportsRealDevicesProvider);
    final devices = devicesAsync.valueOrNull ?? const <TraccarDevice>[];
    final executiveAsync = ref.watch(
      executiveSummaryProvider(
        ExecutiveSummaryQuery(
          from: _appliedStartDateTime,
          to: _appliedEndDateTime,
          deviceId: _resolveSelectedDeviceId(_appliedVehicle, devices),
        ),
      ),
    );
    // Só busca quando o usuário clicar em "Buscar" — antes disso, a tela
    // abria já disparando uma consulta pesada (frota inteira, 30 dias) sem
    // pedir nada, e isso segurava a abertura do painel.
    final listAsync = !_hasSearched
        ? const AsyncValue<List<ReportRecord>>.data(<ReportRecord>[])
        : ref.watch(
            reportsListProvider(
              _ReportsQueryParams(
                from: _appliedStartDateTime,
                to: _appliedEndDateTime,
                type: _appliedType,
                vehicle: _appliedVehicle,
                revision: _revision,
              ),
            ),
          );

    return SizedBox.expand(
      child: listAsync.when(
        data: (records) {
          final filtered = _applyFilters(records);
          final typeOptions = const [
            'Todos',
            'Alertas',
            'Rotas',
            'Viagens',
            'Paradas',
            'Eventos',
            'Resumo operacional',
          ];
          final deviceOptions =
              devicesAsync.valueOrNull ?? const <TraccarDevice>[];
          final vehicleOptions = _buildVehicleOptions(deviceOptions);
          final driverOptions = <String>[
            'Todos',
            ...{
              for (final item in records)
                if (item.driver.trim().isNotEmpty &&
                    item.driver.trim().toLowerCase() != 'não informado' &&
                    item.driver.trim().toLowerCase() != 'nao informado')
                  item.driver,
            },
          ];
          final eventTypeOptions = <String>[
            'Todos',
            ...{
              for (final item in records)
                if ((item.eventType ?? '').trim().isNotEmpty) item.eventType!,
            },
          ];
          final statusOptions = <String>[
            'Todos',
            ...{for (final item in records) item.status.label},
          ];

          return LayoutBuilder(
            builder: (context, constraints) {
              final tableHeight = math.max(
                320.0,
                math.min(420.0, constraints.maxHeight * 0.42),
              );

              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  ReportsFiltersBar(
                    startDateTime: _startDateTime,
                    endDateTime: _endDateTime,
                    vehicle: _vehicle,
                    driver: _driver,
                    type: _type,
                    eventType: _eventType,
                    status: _status,
                    vehicleOptions: vehicleOptions,
                    driverOptions: driverOptions,
                    typeOptions: typeOptions,
                    eventTypeOptions: eventTypeOptions,
                    statusOptions: statusOptions,
                    onPickStartDate: () => _pickDate(isStart: true),
                    onPickStartTime: () => _pickTime(isStart: true),
                    onPickEndDate: () => _pickDate(isStart: false),
                    onPickEndTime: () => _pickTime(isStart: false),
                    onVehicleChanged: (value) => setState(() {
                      _vehicle = value;
                      _hasSearched = false;
                    }),
                    onDriverChanged: (value) => setState(() {
                      _driver = value;
                      _hasSearched = false;
                    }),
                    onTypeChanged: (value) => setState(() {
                      _type = value;
                      _hasSearched = false;
                    }),
                    onEventTypeChanged: (value) => setState(() {
                      _eventType = value;
                      _hasSearched = false;
                    }),
                    onStatusChanged: (value) => setState(() {
                      _status = value;
                      _hasSearched = false;
                    }),
                    onApplyFilters: _applyQueryFilters,
                    onExportCsv: () => _exportRecords(
                      filtered,
                      ReportExportFormat.csv,
                    ),
                    onExportHtml: () => _exportRecords(
                      filtered,
                      ReportExportFormat.html,
                    ),
                    onExportPdf: () => _exportRecords(
                      filtered,
                      ReportExportFormat.pdf,
                    ),
                    canExport: _hasSearched && filtered.isNotEmpty,
                    pdfEnabled: _pdfEnabled,
                    onClearFilters: _clearFilters,
                  ),
                  const SizedBox(height: 12),
                  executiveAsync.when(
                    data: (summary) => ExecutiveSummaryPanel(summary: summary),
                    loading: () => const _ExecutiveLoadingPanel(),
                    error: (_, __) => const _ExecutiveUnavailablePanel(),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Histórico de relatórios',
                    style: TextStyle(
                      color: Color(0xFF263650),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: tableHeight,
                    child: ReportsTable(
                      records: filtered,
                      onView: _openRecordDetail,
                      onExportPdf: (record) => _exportRecords(
                        filtered,
                        ReportExportFormat.pdf,
                        singleRecord: record,
                      ),
                      onExportExcel: (record) => _exportRecords(
                        filtered,
                        ReportExportFormat.csv,
                        singleRecord: record,
                      ),
                      canExportRow: filtered.isNotEmpty,
                      pdfEnabled: _pdfEnabled,
                    ),
                  ),
                ],
              );
            },
          );
        },
        loading: () => const _LoadingPanel(),
        error: (error, _) => _ErrorPanel(
          message: 'Falha ao carregar relatórios: $error',
        ),
      ),
    );
  }

  ReportKpiSummary _buildSummary(List<ReportRecord> records) {
    final scheduled =
        records.where((item) => item.status == ReportStatus.scheduled).length;
    final exports =
        records.where((item) => item.format != ReportFormat.screen).length;
    final critical =
        records.where((item) => item.type == ReportType.alerts).length;

    return ReportKpiSummary(
      generated: records.length,
      scheduled: scheduled,
      exports: exports,
      criticalAlerts: critical,
    );
  }

  List<ReportCategory> _buildMainCategories(List<ReportRecord> records) {
    final mainTypes = <ReportType>[
      ReportType.alerts,
      ReportType.routes,
      ReportType.trips,
      ReportType.stops,
      ReportType.events,
      ReportType.distance,
    ];

    return [
      for (final type in mainTypes)
        ReportCategory(
          type: type,
          description: _categoryDescription(type),
          generatedCount: records.where((item) => item.type == type).length,
        ),
    ];
  }

  String _categoryDescription(ReportType type) {
    switch (type) {
      case ReportType.routes:
        return 'Trajeto percorrido pelo veículo';
      case ReportType.trips:
        return 'Viagens realizadas no período';
      case ReportType.stops:
        return 'Paradas registradas no período';
      case ReportType.events:
        return 'Eventos do dispositivo no período';
      case ReportType.distance:
        return 'Resumo consolidado do período';
      case ReportType.alerts:
        return 'Alertas e ocorrências críticas';
      default:
        return 'Categoria operacional.';
    }
  }

  List<ReportRecord> _applyFilters(List<ReportRecord> records) {
    return records.where((record) {
      if (record.createdAt.isBefore(_appliedStartDateTime) ||
          record.createdAt.isAfter(_appliedEndDateTime)) {
        return false;
      }
      if (_appliedType != 'Todos' && record.type.label != _appliedType) {
        return false;
      }
      if (_appliedVehicle != 'Todos' &&
          record.deviceId?.toString() != _appliedVehicle) {
        return false;
      }
      if (_appliedDriver != 'Todos' && record.driver != _appliedDriver) {
        return false;
      }
      if (_appliedStatus != 'Todos' && record.status.label != _appliedStatus) {
        return false;
      }
      if (_appliedEventType != 'Todos' &&
          (record.eventType ?? '').trim() != _appliedEventType) {
        return false;
      }
      if (_appliedType == 'Alertas' && !_isAlertEventType(record.eventType)) {
        return false;
      }
      return true;
    }).toList();
  }

  void _showAction(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

void _noopRecordAction(ReportRecord _) {}

class _ReportsReplaySection extends StatelessWidget {
  const _ReportsReplaySection({
    super.key,
    required this.future,
    required this.vehicleSelected,
    required this.vehicleLabel,
  });

  final Future<_ReportsReplayData>? future;
  final bool vehicleSelected;
  final String vehicleLabel;

  @override
  Widget build(BuildContext context) {
    if (!vehicleSelected) {
      return _ReplayStatePanel(
        title: 'Replay operacional',
        message:
            'Selecione um equipamento para visualizar o trajeto, o replay e a telemetria básica do período.',
      );
    }

    if (future == null) {
      return _ReplayStatePanel(
        title: 'Replay operacional',
        message: 'Busque os dados para carregar o replay de $vehicleLabel.',
      );
    }

    return FutureBuilder<_ReportsReplayData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _ReplayLoadingPanel();
        }
        if (snapshot.hasError) {
          return _ReplayStatePanel(
            title: 'Replay operacional',
            message: 'Falha ao carregar o replay do período: ${snapshot.error}',
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return const _ReplayStatePanel(
            title: 'Replay operacional',
            message: 'Não foi possível montar o replay do período.',
          );
        }

        if (!data.hasUsablePoints) {
          return _ReplayStatePanel(
            title: 'Replay operacional',
            message: data.message ??
                'Sem trajeto disponível para o equipamento no período selecionado.',
          );
        }

        return _ReportsReplayPanel(
          key: ValueKey(
            '${data.deviceId}-${data.periodStart.millisecondsSinceEpoch}-${data.periodEnd.millisecondsSinceEpoch}-${data.points.length}',
          ),
          data: data,
        );
      },
    );
  }
}

class _ReportReplayDialog extends StatelessWidget {
  const _ReportReplayDialog({
    required this.vehicleName,
    required this.periodLabel,
    required this.replayFuture,
  });

  final String vehicleName;
  final String periodLabel;
  final Future<_ReportsReplayData> replayFuture;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1320, maxHeight: 820),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAFF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFD6E0EE)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.18),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: FutureBuilder<_ReportsReplayData>(
          future: replayFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _RouteDetailScaffold(
                title: 'Replay do trajeto',
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Falha ao carregar o replay do perÃ­odo: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }

            final data = snapshot.data;
            if (data == null || !data.hasUsablePoints) {
              return _RouteDetailScaffold(
                title: 'Replay do trajeto',
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      data?.message ?? 'Sem posiÃ§Ãµes vÃ¡lidas neste perÃ­odo.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }

            return _ReportReplayDialogBody(
              vehicleName: vehicleName,
              periodLabel: periodLabel,
              data: data,
            );
          },
        ),
      ),
    );
  }
}

class _ReportReplayDialogBody extends StatefulWidget {
  const _ReportReplayDialogBody({
    required this.vehicleName,
    required this.periodLabel,
    required this.data,
  });

  final String vehicleName;
  final String periodLabel;
  final _ReportsReplayData data;

  @override
  State<_ReportReplayDialogBody> createState() => _ReportReplayDialogBodyState();
}

class _ReportReplayDialogBodyState extends State<_ReportReplayDialogBody> {
  static Future<gmaps.BitmapDescriptor>? _arrowMarkerIconFuture;

  Timer? _timer;
  gmaps.GoogleMapController? _mapController;
  int _currentIndex = 0;
  bool _playing = false;
  bool _showDetails = true;

  List<_RouteReplayPoint> get _points => widget.data.points;

  @override
  void initState() {
    super.initState();
    _playing = _points.length > 1;
    _arrowMarkerIconFuture ??= _buildReplayArrowIcon();
    _syncTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _syncTimer() {
    _timer?.cancel();
    if (!_playing || _points.length <= 1) {
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentIndex = _currentIndex >= _points.length - 1 ? 0 : _currentIndex + 1;
      });
    });
  }

  void _setPlaying(bool value) {
    setState(() => _playing = value);
    _syncTimer();
  }

  void _moveToIndex(int value) {
    setState(() {
      _currentIndex = value.clamp(0, _points.length - 1);
    });
  }

  Future<void> _fitMapToPoints() async {
    final controller = _mapController;
    if (controller == null || _points.isEmpty) {
      return;
    }

    try {
      if (_points.length == 1) {
        await controller.animateCamera(
          gmaps.CameraUpdate.newLatLngZoom(_latLng(_points.first), 16),
        );
        return;
      }

      var minLat = _points.first.latitude;
      var maxLat = _points.first.latitude;
      var minLng = _points.first.longitude;
      var maxLng = _points.first.longitude;

      for (final point in _points) {
        minLat = math.min(minLat, point.latitude);
        maxLat = math.max(maxLat, point.latitude);
        minLng = math.min(minLng, point.longitude);
        maxLng = math.max(maxLng, point.longitude);
      }

      await controller.animateCamera(
        gmaps.CameraUpdate.newLatLngBounds(
          gmaps.LatLngBounds(
            southwest: gmaps.LatLng(minLat, minLng),
            northeast: gmaps.LatLng(maxLat, maxLng),
          ),
          54,
        ),
      );
    } catch (_) {
      // Mantem o replay renderizado mesmo se o ajuste de camera falhar.
    }
  }

  @override
  Widget build(BuildContext context) {
    final point = _points[_currentIndex];
    final bearing = _bearingAt(_currentIndex);
    final event = _nearestEvent(point.effectiveTime);
    final alert = _nearestAlert(point.effectiveTime);
    final directionLabel = _cardinalDirectionLabel(bearing);
    final movementStatus = _movementStatus(point.speedKmh);
    final summary = widget.data.summary;
    final alerts = widget.data.events.where((item) => item.isAlert).take(6).toList();

    return _RouteDetailScaffold(
      title: 'Replay do trajeto',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _RouteInfoChip(label: 'Equipamento', value: widget.vehicleName),
                  _RouteInfoChip(label: 'PerÃ­odo', value: widget.periodLabel),
                  _RouteInfoChip(label: 'Pontos', value: '${summary.totalPoints}'),
                  _RouteInfoChip(label: 'Alertas', value: '${summary.criticalAlerts}'),
                ],
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: FutureBuilder<gmaps.BitmapDescriptor>(
                        future: _arrowMarkerIconFuture,
                        builder: (context, snapshot) {
                          final activeIcon = snapshot.data ??
                              gmaps.BitmapDescriptor.defaultMarkerWithHue(
                                gmaps.BitmapDescriptor.hueAzure,
                              );
                          return gmaps.GoogleMap(
                            initialCameraPosition: gmaps.CameraPosition(
                              target: _latLng(_points.first),
                              zoom: 13,
                            ),
                            mapType: gmaps.MapType.normal,
                            trafficEnabled: false,
                            myLocationButtonEnabled: false,
                            mapToolbarEnabled: false,
                            compassEnabled: true,
                            zoomControlsEnabled: true,
                            onMapCreated: (controller) {
                              _mapController = controller;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _fitMapToPoints();
                              });
                            },
                            markers: _buildReplayMarkers(activeIcon, bearing),
                            polylines: {
                              gmaps.Polyline(
                                polylineId: const gmaps.PolylineId('reports-replay-route'),
                                points: [
                                  for (final replayPoint in _points) _latLng(replayPoint),
                                ],
                                color: const Color(0xFF176EEB),
                                width: 6,
                              ),
                            },
                          );
                        },
                      ),
                    ),
                    Positioned(
                      left: 16,
                      top: 16,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 340),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFD6E0EE)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.10),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.vehicleName,
                              style: const TextStyle(
                                color: Color(0xFF25344A),
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_formatReplayDateTime(point.effectiveTime)} · ${point.speedLabel} · igniÃ§Ã£o ${point.ignitionLabel.toLowerCase()}',
                              style: const TextStyle(
                                color: Color(0xFF60718D),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$movementStatus · sentido $directionLabel',
                              style: const TextStyle(
                                color: Color(0xFF25344A),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            if (event != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Evento: ${event.label}',
                                style: const TextStyle(
                                  color: Color(0xFF176EEB),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (_showDetails)
                      Positioned(
                        left: 16,
                        bottom: 88,
                        width: 320,
                        child: _ReplayPointDetailsCard(
                          vehicleLabel: widget.vehicleName,
                          point: point,
                          directionLabel: directionLabel,
                          movementStatus: movementStatus,
                          relatedEvent: event,
                          relatedAlert: alert,
                          onClose: () => setState(() => _showDetails = false),
                        ),
                      ),
                    Positioned(
                      right: 16,
                      top: 16,
                      width: 320,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFD6E0EE)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.10),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Trajeto',
                              style: TextStyle(
                                color: Color(0xFF25344A),
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _RouteSummaryBlock(
                              label: 'InÃ­cio',
                              value: _formatReplayDateTime(summary.startedAt),
                              subtitle: summary.startLocation,
                            ),
                            const SizedBox(height: 10),
                            _RouteSummaryBlock(
                              label: 'Fim',
                              value: _formatReplayDateTime(summary.endedAt),
                              subtitle: summary.endLocation,
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _RouteInfoChip(
                                  label: 'DistÃ¢ncia',
                                  value: summary.distanceLabel,
                                ),
                                _RouteInfoChip(
                                  label: 'Eventos',
                                  value: '${summary.totalEvents}',
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Alertas do trajeto',
                              style: TextStyle(
                                color: Color(0xFF25344A),
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (alerts.isEmpty)
                              const Text(
                                'Sem alertas relevantes neste perÃ­odo.',
                                style: TextStyle(
                                  color: Color(0xFF60718D),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              )
                            else
                              ...alerts.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    '${_formatReplayDateTime(item.time)} · ${item.label}',
                                    style: const TextStyle(
                                      color: Color(0xFF25344A),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFD6E0EE)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.10),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            _ReplayIconButton(
                              icon: _playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              onTap: () => _setPlaying(!_playing),
                            ),
                            const SizedBox(width: 8),
                            _ReplayIconButton(
                              icon: Icons.skip_previous_rounded,
                              onTap: _currentIndex == 0
                                  ? null
                                  : () {
                                      _setPlaying(false);
                                      _moveToIndex(_currentIndex - 1);
                                    },
                            ),
                            const SizedBox(width: 8),
                            _ReplayIconButton(
                              icon: Icons.skip_next_rounded,
                              onTap: _currentIndex >= _points.length - 1
                                  ? null
                                  : () {
                                      _setPlaying(false);
                                      _moveToIndex(_currentIndex + 1);
                                    },
                            ),
                            const SizedBox(width: 8),
                            _ReplayIconButton(
                              icon: _showDetails
                                  ? Icons.visibility_rounded
                                  : Icons.remove_red_eye_outlined,
                              onTap: () => setState(() => _showDetails = !_showDetails),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: const Color(0xFF176EEB),
                                      inactiveTrackColor: const Color(0xFFD6E0EE),
                                      thumbColor: const Color(0xFF176EEB),
                                    ),
                                    child: Slider(
                                      min: 0,
                                      max: (_points.length - 1).toDouble(),
                                      value: _currentIndex.toDouble(),
                                      onChanged: (value) {
                                        _setPlaying(false);
                                        _moveToIndex(value.round());
                                      },
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        _formatReplayDateTime(_points.first.effectiveTime),
                                        style: const TextStyle(
                                          color: Color(0xFF60718D),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _formatReplayDateTime(point.effectiveTime),
                                        style: const TextStyle(
                                          color: Color(0xFF25344A),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _formatReplayDateTime(_points.last.effectiveTime),
                                        style: const TextStyle(
                                          color: Color(0xFF60718D),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Set<gmaps.Marker> _buildReplayMarkers(
    gmaps.BitmapDescriptor activeIcon,
    double? bearing,
  ) {
    return {
      gmaps.Marker(
        markerId: const gmaps.MarkerId('reports-replay-start'),
        position: _latLng(_points.first),
        icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
          gmaps.BitmapDescriptor.hueGreen,
        ),
        infoWindow: const gmaps.InfoWindow(title: 'InÃ­cio'),
      ),
      gmaps.Marker(
        markerId: const gmaps.MarkerId('reports-replay-end'),
        position: _latLng(_points.last),
        icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
          gmaps.BitmapDescriptor.hueRed,
        ),
        infoWindow: const gmaps.InfoWindow(title: 'Fim'),
      ),
      gmaps.Marker(
        markerId: const gmaps.MarkerId('reports-replay-active'),
        position: _latLng(_points[_currentIndex]),
        icon: activeIcon,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        rotation: bearing ?? 0,
        zIndexInt: 9,
        infoWindow: gmaps.InfoWindow(
          title: widget.vehicleName,
          snippet:
              '${_formatReplayDateTime(_points[_currentIndex].effectiveTime)} · ${_points[_currentIndex].speedLabel}',
        ),
      ),
    };
  }

  gmaps.LatLng _latLng(_RouteReplayPoint point) {
    return gmaps.LatLng(point.latitude, point.longitude);
  }

  double? _bearingAt(int index) {
    if (_points.isEmpty) {
      return null;
    }
    final current = _points[index];
    final directCourse = _normalizeBearing(current.course);
    if (directCourse != null) {
      return directCourse;
    }
    if ((current.speedKmh ?? 0) <= 2) {
      for (var i = index - 1; i >= 0; i--) {
        final previous = _resolveBearingFromPointWindow(i);
        if (previous != null) {
          return previous;
        }
      }
    }
    return _resolveBearingFromPointWindow(index);
  }

  double? _resolveBearingFromPointWindow(int index) {
    final current = _points[index];
    final directCourse = _normalizeBearing(current.course);
    if (directCourse != null) {
      return directCourse;
    }
    if (index < _points.length - 1) {
      final nextBearing = _bearingBetween(_points[index], _points[index + 1]);
      if (nextBearing != null) {
        return nextBearing;
      }
    }
    if (index > 0) {
      return _bearingBetween(_points[index - 1], _points[index]);
    }
    for (var i = index + 1; i < _points.length - 1; i++) {
      final nextBearing = _bearingBetween(_points[i], _points[i + 1]);
      if (nextBearing != null) {
        return nextBearing;
      }
    }
    return null;
  }

  _ReplayEvent? _nearestEvent(DateTime? time) {
    if (time == null || widget.data.events.isEmpty) {
      return null;
    }

    _ReplayEvent? nearest;
    Duration? nearestDelta;
    for (final event in widget.data.events) {
      final delta = event.time.difference(time).abs();
      if (nearestDelta == null || delta < nearestDelta) {
        nearest = event;
        nearestDelta = delta;
      }
    }

    if (nearestDelta == null || nearestDelta > const Duration(minutes: 5)) {
      return null;
    }
    return nearest;
  }

  _ReplayEvent? _nearestAlert(DateTime? time) {
    if (time == null) {
      return null;
    }

    _ReplayEvent? nearest;
    Duration? nearestDelta;
    for (final event in widget.data.events.where((item) => item.isAlert)) {
      final delta = event.time.difference(time).abs();
      if (nearestDelta == null || delta < nearestDelta) {
        nearest = event;
        nearestDelta = delta;
      }
    }

    if (nearestDelta == null || nearestDelta > const Duration(minutes: 5)) {
      return null;
    }
    return nearest;
  }
}

class _ReportsReplayPanel extends StatefulWidget {
  const _ReportsReplayPanel({super.key, required this.data});

  final _ReportsReplayData data;

  @override
  State<_ReportsReplayPanel> createState() => _ReportsReplayPanelState();
}

class _ReportsReplayPanelState extends State<_ReportsReplayPanel> {
  Timer? _timer;
  int _currentIndex = 0;
  bool _playing = false;
  bool _showPointDetails = false;

  List<_RouteReplayPoint> get _points => widget.data.points;

  @override
  void initState() {
    super.initState();
    _playing = _points.length > 1;
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant _ReportsReplayPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _currentIndex = 0;
      _playing = _points.length > 1;
      _syncTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    _timer?.cancel();
    if (!_playing || _points.length <= 1) {
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (_currentIndex >= _points.length - 1) {
          _currentIndex = 0;
          return;
        }
        _currentIndex += 1;
      });
    });
  }

  void _setPlaying(bool value) {
    setState(() {
      _playing = value;
    });
    _syncTimer();
  }

  void _moveToIndex(int value) {
    final next = value.clamp(0, _points.length - 1);
    setState(() {
      _currentIndex = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentPoint = _points[_currentIndex];
    final bearing = _bearingAt(_currentIndex);
    final currentEvent = _nearestEvent(currentPoint.effectiveTime);
    final currentAlert = _nearestAlert(currentPoint.effectiveTime);
    final movementStatus = _movementStatus(currentPoint.speedKmh);
    final currentAddress = currentPoint.shortLocationLabel;
    final directionLabel = _cardinalDirectionLabel(bearing);
    final summary = widget.data.summary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E0EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Replay operacional do período',
                  style: TextStyle(
                    color: Color(0xFF25344A),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              _ReplayIconButton(
                icon: _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                onTap: () => _setPlaying(!_playing),
              ),
              const SizedBox(width: 6),
              _ReplayIconButton(
                icon: Icons.skip_previous_rounded,
                onTap: _currentIndex == 0
                    ? null
                    : () => _moveToIndex(_currentIndex - 1),
              ),
              const SizedBox(width: 6),
              _ReplayIconButton(
                icon: Icons.skip_next_rounded,
                onTap: _currentIndex >= _points.length - 1
                    ? null
                    : () => _moveToIndex(_currentIndex + 1),
              ),
              const SizedBox(width: 6),
              _ReplayIconButton(
                icon: _showPointDetails
                    ? Icons.visibility_rounded
                    : Icons.remove_red_eye_outlined,
                onTap: () => setState(() {
                  _showPointDetails = !_showPointDetails;
                }),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FBFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD6E0EE)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Text(
                  '${widget.data.vehicleLabel} · ${_formatReplayDateTime(currentPoint.effectiveTime)} · ${currentPoint.speedLabel} · ignição ${currentPoint.ignitionLabel.toLowerCase()} · $movementStatus · sentido $directionLabel',
                  style: const TextStyle(
                    color: Color(0xFF25344A),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '· $currentAddress',
                  style: const TextStyle(
                    color: Color(0xFF60718D),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                if (currentEvent != null)
                  Text(
                    '· evento: ${currentEvent.label}',
                    style: const TextStyle(
                      color: Color(0xFF176EEB),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 380,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      Expanded(
                        child: _ReplayMapCard(
                          points: _points,
                          currentIndex: _currentIndex,
                          currentBearing: bearing,
                          detailCard: _showPointDetails
                              ? _ReplayPointDetailsCard(
                                  vehicleLabel: widget.data.vehicleLabel,
                                  point: currentPoint,
                                  directionLabel: directionLabel,
                                  movementStatus: movementStatus,
                                  relatedEvent: currentEvent,
                                  relatedAlert: currentAlert,
                                  onClose: () => setState(() {
                                    _showPointDetails = false;
                                  }),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFF2D8CFF),
                          inactiveTrackColor: const Color(0xFFD6E0EE),
                          thumbColor: const Color(0xFF176EEB),
                          overlayColor:
                              const Color(0xFF176EEB).withValues(alpha: 0.12),
                        ),
                        child: Slider(
                          min: 0,
                          max: (_points.length - 1).toDouble(),
                          value: _currentIndex.toDouble(),
                          onChanged: (value) {
                            _setPlaying(false);
                            _moveToIndex(value.round());
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _RouteSummaryBlock(
                              label: 'Início',
                              value: _formatReplayDateTime(summary.startedAt),
                              subtitle: summary.startLocation,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _RouteSummaryBlock(
                              label: 'Fim',
                              value: _formatReplayDateTime(summary.endedAt),
                              subtitle: summary.endLocation,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _RouteInfoChip(
                            label: 'Distância',
                            value: summary.distanceLabel,
                          ),
                          _RouteInfoChip(
                            label: 'Eventos',
                            value: '${summary.totalEvents}',
                          ),
                          _RouteInfoChip(
                            label: 'Alertas críticos',
                            value: '${summary.criticalAlerts}',
                          ),
                          _RouteInfoChip(
                            label: 'Pontos',
                            value: '${summary.totalPoints}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD6E0EE)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Eventos e alertas do período',
                                style: TextStyle(
                                  color: Color(0xFF25344A),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: summary.highlightEvents.isEmpty
                                    ? const Text(
                                        'Nenhum evento operacional relevante no período.',
                                        style: TextStyle(
                                          color: Color(0xFF60718D),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount:
                                            summary.highlightEvents.length,
                                        separatorBuilder: (_, __) =>
                                            const Divider(height: 12),
                                        itemBuilder: (context, index) {
                                          final event =
                                              summary.highlightEvents[index];
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${_formatReplayDateTime(event.time)} · ${event.label}',
                                                style: const TextStyle(
                                                  color: Color(0xFF25344A),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                event.description,
                                                style: const TextStyle(
                                                  color: Color(0xFF60718D),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (summary.hasSpeedData) ...[
            const SizedBox(height: 12),
            _ReplaySpeedChart(points: _points),
          ],
          if (_points.any((point) => point.hasRpm)) ...[
            const SizedBox(height: 12),
            _ReplayRpmChart(points: _points),
          ],
        ],
      ),
    );
  }

  double? _bearingAt(int index) {
    if (_points.isEmpty) {
      return null;
    }
    final current = _points[index];
    final directCourse = _normalizeBearing(current.course);
    if (directCourse != null) {
      return directCourse;
    }
    if ((current.speedKmh ?? 0) <= 2) {
      for (var i = index - 1; i >= 0; i--) {
        final previous = _resolveBearingFromPointWindow(i);
        if (previous != null) {
          return previous;
        }
      }
    }
    return _resolveBearingFromPointWindow(index);
  }

  double? _resolveBearingFromPointWindow(int index) {
    final current = _points[index];
    final directCourse = _normalizeBearing(current.course);
    if (directCourse != null) {
      return directCourse;
    }
    if (index < _points.length - 1) {
      final nextBearing = _bearingBetween(_points[index], _points[index + 1]);
      if (nextBearing != null) {
        return nextBearing;
      }
    }
    if (index > 0) {
      return _bearingBetween(_points[index - 1], _points[index]);
    }
    for (var i = index + 1; i < _points.length - 1; i++) {
      final nextBearing = _bearingBetween(_points[i], _points[i + 1]);
      if (nextBearing != null) {
        return nextBearing;
      }
    }
    return null;
  }

  _ReplayEvent? _nearestEvent(DateTime? time) {
    if (time == null || widget.data.events.isEmpty) {
      return null;
    }

    _ReplayEvent? nearest;
    Duration? nearestDelta;
    for (final event in widget.data.events) {
      final delta = event.time.difference(time).abs();
      if (nearestDelta == null || delta < nearestDelta) {
        nearest = event;
        nearestDelta = delta;
      }
    }

    if (nearestDelta == null || nearestDelta > const Duration(minutes: 5)) {
      return null;
    }
    return nearest;
  }

  _ReplayEvent? _nearestAlert(DateTime? time) {
    if (time == null) {
      return null;
    }

    _ReplayEvent? nearest;
    Duration? nearestDelta;
    for (final event in widget.data.events.where((item) => item.isAlert)) {
      final delta = event.time.difference(time).abs();
      if (nearestDelta == null || delta < nearestDelta) {
        nearest = event;
        nearestDelta = delta;
      }
    }

    if (nearestDelta == null || nearestDelta > const Duration(minutes: 5)) {
      return null;
    }
    return nearest;
  }
}

class _ReplayMapCard extends StatelessWidget {
  const _ReplayMapCard({
    required this.points,
    required this.currentIndex,
    required this.currentBearing,
    this.detailCard,
  });

  final List<_RouteReplayPoint> points;
  final int currentIndex;
  final double? currentBearing;
  final Widget? detailCard;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E0EE)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final projector = _ReplayTrackProjector.fromPoints(
            points,
            Size(constraints.maxWidth, constraints.maxHeight),
          );
          final currentOffset = projector.project(
              points[currentIndex].latitude, points[currentIndex].longitude);
          final startOffset =
              projector.project(points.first.latitude, points.first.longitude);
          final endOffset =
              projector.project(points.last.latitude, points.last.longitude);

          return Stack(
            children: [
              CustomPaint(
                size: Size.infinite,
                painter: _ReplayTrackPainter(
                  points: points,
                  currentIndex: currentIndex,
                  projector: projector,
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFD6E0EE)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.alt_route_rounded,
                        size: 14,
                        color: Color(0xFF176EEB),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Replay visual do trajeto',
                        style: TextStyle(
                          color: Color(0xFF25344A),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _MapBadge(
                offset: startOffset,
                color: const Color(0xFF10B981),
                label: 'I',
              ),
              _MapBadge(
                offset: endOffset,
                color: const Color(0xFFE74B4B),
                label: 'F',
              ),
              Positioned(
                left: currentOffset.dx - 24,
                top: currentOffset.dy - 24,
                child: Transform.rotate(
                  angle: ((currentBearing ?? 0) * math.pi) / 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF176EEB).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF176EEB),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF176EEB)
                                  .withValues(alpha: 0.28),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.navigation_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: currentOffset.dx + 16,
                top: currentOffset.dy - 34,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFD6E0EE)),
                  ),
                  child: const Text(
                    'Veículo atual',
                    style: TextStyle(
                      color: Color(0xFF25344A),
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
              if (detailCard != null)
                Positioned(
                  top: 14,
                  right: 14,
                  width:
                      math.min(280, math.max(220, constraints.maxWidth * 0.36)),
                  child: detailCard!,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ReplayPointDetailsCard extends StatelessWidget {
  const _ReplayPointDetailsCard({
    required this.vehicleLabel,
    required this.point,
    required this.directionLabel,
    required this.movementStatus,
    required this.relatedEvent,
    required this.relatedAlert,
    required this.onClose,
  });

  final String vehicleLabel;
  final _RouteReplayPoint point;
  final String directionLabel;
  final String movementStatus;
  final _ReplayEvent? relatedEvent;
  final _ReplayEvent? relatedAlert;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final address = point.shortLocationLabel;
    final coordinates =
        '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD6E0EE)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Detalhes do ponto',
                    style: TextStyle(
                      color: Color(0xFF25344A),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onClose,
                  borderRadius: BorderRadius.circular(999),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFF60718D),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _ReplayDetailLine(label: 'Equipamento', value: vehicleLabel),
            _ReplayDetailLine(
              label: 'Data/hora',
              value: _formatReplayDateTime(point.effectiveTime),
            ),
            _ReplayDetailLine(label: 'Velocidade', value: point.speedLabel),
            _ReplayDetailLine(label: 'Ignição', value: point.ignitionLabel),
            _ReplayDetailLine(label: 'Sentido', value: directionLabel),
            _ReplayDetailLine(label: 'Status', value: movementStatus),
            _ReplayDetailLine(label: 'Localização', value: address),
            _ReplayDetailLine(label: 'Lat/Lng', value: coordinates),
            if (point.hasBattery)
              _ReplayDetailLine(label: 'Bateria', value: point.battery!.trim()),
            if (point.hasSignal)
              _ReplayDetailLine(label: 'Sinal', value: point.signal!.trim()),
            if (point.hasRpm)
              _ReplayDetailLine(
                label: 'RPM',
                value: '${point.rpm!.toStringAsFixed(0)} rpm',
              ),
            if (point.hasOdometer)
              _ReplayDetailLine(
                label: 'Odômetro',
                value: '${point.odometerKm!.toStringAsFixed(1)} km',
              ),
            _ReplayDetailLine(
              label: 'Evento',
              value: relatedEvent?.label ?? 'Não informado',
            ),
            _ReplayDetailLine(
              label: 'Alerta',
              value: relatedAlert?.label ?? 'Sem alerta relacionado',
              accent: relatedAlert == null
                  ? const Color(0xFF60718D)
                  : const Color(0xFFB42318),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplayDetailLine extends StatelessWidget {
  const _ReplayDetailLine({
    required this.label,
    required this.value,
    this.accent = const Color(0xFF25344A),
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF60718D),
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplayTrackPainter extends CustomPainter {
  const _ReplayTrackPainter({
    required this.points,
    required this.currentIndex,
    required this.projector,
  });

  final List<_RouteReplayPoint> points;
  final int currentIndex;
  final _ReplayTrackProjector projector;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF9FCFF), Color(0xFFF1F7FF)],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      backgroundPaint,
    );

    final gridPaint = Paint()
      ..color = const Color(0xFFDCE7F5)
      ..strokeWidth = 1;
    for (var i = 1; i < 6; i++) {
      final dx = size.width * i / 6;
      final dy = size.height * i / 6;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), gridPaint);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    final routePath = Path();
    for (var i = 0; i < points.length; i++) {
      final point = projector.project(points[i].latitude, points[i].longitude);
      if (i == 0) {
        routePath.moveTo(point.dx, point.dy);
      } else {
        routePath.lineTo(point.dx, point.dy);
      }
    }

    final routeShadowPaint = Paint()
      ..color = const Color(0xFF2D8CFF).withValues(alpha: 0.14)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final routePaint = Paint()
      ..color = const Color(0xFF2D8CFF)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(routePath, routeShadowPaint);
    canvas.drawPath(routePath, routePaint);

    if (currentIndex > 0) {
      final progressPath = Path();
      for (var i = 0; i <= currentIndex; i++) {
        final point =
            projector.project(points[i].latitude, points[i].longitude);
        if (i == 0) {
          progressPath.moveTo(point.dx, point.dy);
        } else {
          progressPath.lineTo(point.dx, point.dy);
        }
      }
      final progressPaint = Paint()
        ..color = const Color(0xFF10B981)
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(progressPath, progressPaint);
    }

    final dotPaint = Paint()..color = const Color(0xFF94A3B8);
    final currentPaint = Paint()..color = const Color(0xFF176EEB);
    for (var i = 0; i < points.length; i++) {
      final point = projector.project(points[i].latitude, points[i].longitude);
      canvas.drawCircle(
        point,
        i == currentIndex ? 5 : 2.6,
        i == currentIndex ? currentPaint : dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ReplayTrackPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.currentIndex != currentIndex;
  }
}

class _ReplayTrackProjector {
  const _ReplayTrackProjector({
    required this.minLatitude,
    required this.maxLatitude,
    required this.minLongitude,
    required this.maxLongitude,
    required this.size,
  });

  final double minLatitude;
  final double maxLatitude;
  final double minLongitude;
  final double maxLongitude;
  final Size size;

  factory _ReplayTrackProjector.fromPoints(
    List<_RouteReplayPoint> points,
    Size size,
  ) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    const padding = 0.0008;
    return _ReplayTrackProjector(
      minLatitude: minLat - padding,
      maxLatitude: maxLat + padding,
      minLongitude: minLng - padding,
      maxLongitude: maxLng + padding,
      size: size,
    );
  }

  Offset project(double latitude, double longitude) {
    const inset = 22.0;
    final usableWidth = math.max(1.0, size.width - inset * 2);
    final usableHeight = math.max(1.0, size.height - inset * 2);
    final lngSpan = math.max(0.000001, maxLongitude - minLongitude);
    final latSpan = math.max(0.000001, maxLatitude - minLatitude);
    final x = ((longitude - minLongitude) / lngSpan) * usableWidth + inset;
    final y = usableHeight -
        ((latitude - minLatitude) / latSpan) * usableHeight +
        inset;
    return Offset(x, y);
  }
}

class _MapBadge extends StatelessWidget {
  const _MapBadge({
    required this.offset,
    required this.color,
    required this.label,
  });

  final Offset offset;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: offset.dx - 12,
      top: offset.dy - 12,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _ReplaySpeedChart extends StatelessWidget {
  const _ReplaySpeedChart({required this.points});

  final List<_RouteReplayPoint> points;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E0EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Velocidade no período',
            style: TextStyle(
              color: Color(0xFF25344A),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _ReplaySpeedChartPainter(points),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplaySpeedChartPainter extends CustomPainter {
  const _ReplaySpeedChartPainter(this.points);

  final List<_RouteReplayPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final chartPaint = Paint()
      ..color = const Color(0xFFDCE7F5)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), chartPaint);
    }

    final speedPoints = points
        .asMap()
        .entries
        .where((entry) => entry.value.speedKmh != null)
        .toList(growable: false);
    if (speedPoints.length < 2) {
      return;
    }

    var maxSpeed = 1.0;
    for (final entry in speedPoints) {
      maxSpeed = math.max(maxSpeed, entry.value.speedKmh!);
    }

    final path = Path();
    for (var i = 0; i < speedPoints.length; i++) {
      final item = speedPoints[i];
      final x = (i / (speedPoints.length - 1)) * size.width;
      final y = size.height - (item.value.speedKmh! / maxSpeed) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = const Color(0xFF2D8CFF)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _ReplaySpeedChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _ReplayRpmChart extends StatelessWidget {
  const _ReplayRpmChart({required this.points});

  final List<_RouteReplayPoint> points;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E0EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RPM no período',
            style: TextStyle(
              color: Color(0xFF25344A),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _ReplayRpmChartPainter(points),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplayRpmChartPainter extends CustomPainter {
  const _ReplayRpmChartPainter(this.points);

  final List<_RouteReplayPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFDCE7F5)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final rpmPoints = points
        .asMap()
        .entries
        .where((entry) => entry.value.hasRpm)
        .toList(growable: false);
    if (rpmPoints.length < 2) {
      return;
    }

    var maxRpm = 1.0;
    for (final entry in rpmPoints) {
      maxRpm = math.max(maxRpm, entry.value.rpm!);
    }

    final path = Path();
    for (var i = 0; i < rpmPoints.length; i++) {
      final item = rpmPoints[i];
      final x = (i / (rpmPoints.length - 1)) * size.width;
      final y = size.height - (item.value.rpm! / maxRpm) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = const Color(0xFFE85D3F)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _ReplayRpmChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _ReplayIconButton extends StatelessWidget {
  const _ReplayIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color:
              onTap == null ? const Color(0xFFEFF3F9) : const Color(0xFFF1F7FF),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFFD6E0EE)),
        ),
        child: Icon(
          icon,
          size: 18,
          color:
              onTap == null ? const Color(0xFF94A3B8) : const Color(0xFF176EEB),
        ),
      ),
    );
  }
}

class _ReplayStatePanel extends StatelessWidget {
  const _ReplayStatePanel({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E0EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF25344A),
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF60718D),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplayLoadingPanel extends StatelessWidget {
  const _ReplayLoadingPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E0EE)),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _RouteDetailDialog extends StatefulWidget {
  const _RouteDetailDialog({
    required this.vehicleName,
    required this.periodLabel,
    required this.pointsFuture,
  });

  final String vehicleName;
  final String periodLabel;
  final Future<List<_RouteDetailPoint>> pointsFuture;

  @override
  State<_RouteDetailDialog> createState() => _RouteDetailDialogState();
}

class _RouteDetailDialogState extends State<_RouteDetailDialog> {
  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'Nao informado';
    }
    final local = value.isUtc ? value.toLocal() : value;
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute:$second';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: SizedBox(
        width: 1040,
        height: 720,
        child: FutureBuilder<List<_RouteDetailPoint>>(
          future: widget.pointsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _RouteDetailScaffold(
                title: 'Detalhe da rota',
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Falha ao carregar a rota real: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }

            final points = snapshot.data ?? const <_RouteDetailPoint>[];
            final validPoints =
                points.where((point) => point.hasValidCoordinates).toList();
            final firstPoint = points.isEmpty ? null : points.first;
            final lastPoint = points.isEmpty ? null : points.last;

            return _RouteDetailScaffold(
              title: 'Detalhe da rota',
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _RouteInfoChip(
                          label: 'Equipamento',
                          value: widget.vehicleName,
                        ),
                        _RouteInfoChip(
                          label: 'Período',
                          value: widget.periodLabel,
                        ),
                        _RouteInfoChip(
                          label: 'Pontos',
                          value: '${points.length}',
                        ),
                        _RouteInfoChip(
                          label: 'Coordenadas validas',
                          value: '${validPoints.length}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _RouteSummaryBlock(
                            label: 'Inicio',
                            value: _formatDateTime(firstPoint?.effectiveTime),
                            subtitle:
                                firstPoint?.coordinatesLabel ?? 'Nao informado',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _RouteSummaryBlock(
                            label: 'Fim',
                            value: _formatDateTime(lastPoint?.effectiveTime),
                            subtitle:
                                lastPoint?.coordinatesLabel ?? 'Nao informado',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFD6E0EE),
                                ),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Resumo da rota',
                                    style: TextStyle(
                                      color: Color(0xFF25344A),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    validPoints.isEmpty
                                        ? 'Nenhum ponto no periodo com coordenada valida.'
                                        : 'A rota possui ${validPoints.length} coordenadas validas para a proxima etapa visual.',
                                    style: const TextStyle(
                                      color: Color(0xFF60718D),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _RouteSummaryBlock(
                                    label: 'Primeira coordenada valida',
                                    value: validPoints.isEmpty
                                        ? 'Nao informado'
                                        : validPoints.first.coordinatesLabel,
                                    subtitle: validPoints.isEmpty
                                        ? 'Sem trilha valida para desenhar agora'
                                        : _formatDateTime(
                                            validPoints.first.effectiveTime,
                                          ),
                                  ),
                                  const SizedBox(height: 10),
                                  _RouteSummaryBlock(
                                    label: 'Ultima coordenada valida',
                                    value: validPoints.isEmpty
                                        ? 'Nao informado'
                                        : validPoints.last.coordinatesLabel,
                                    subtitle: validPoints.isEmpty
                                        ? 'Mapa visual da rota fica para a proxima etapa'
                                        : _formatDateTime(
                                            validPoints.last.effectiveTime,
                                          ),
                                  ),
                                  const SizedBox(height: 10),
                                  const _RouteSummaryBlock(
                                    label: 'Visualizacao desta etapa',
                                    value: 'Detalhe real da rota',
                                    subtitle:
                                        'Mapa/trilha interativa fica para a proxima correcao minima.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFD6E0EE),
                                ),
                              ),
                              child: points.isEmpty
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(24),
                                        child: Text(
                                          'Nenhum ponto no periodo.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Color(0xFF60718D),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.all(12),
                                      itemCount: points.length > 12
                                          ? 12
                                          : points.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 16),
                                      itemBuilder: (context, index) {
                                        final point = points[index];
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Ponto ${index + 1}',
                                              style: const TextStyle(
                                                color: Color(0xFF25344A),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatDateTime(
                                                  point.effectiveTime),
                                              style: const TextStyle(
                                                color: Color(0xFF60718D),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              point.coordinatesLabel,
                                              style: const TextStyle(
                                                color: Color(0xFF334155),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Vel ${point.speedLabel} | Ign ${point.ignitionLabel} | Bat ${point.batteryLabel}',
                                              style: const TextStyle(
                                                color: Color(0xFF60718D),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RouteDetailScaffold extends StatelessWidget {
  const _RouteDetailScaffold({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF25344A),
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: child),
      ],
    );
  }
}

class _RouteInfoChip extends StatelessWidget {
  const _RouteInfoChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E0EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF60718D),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF25344A),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteSummaryBlock extends StatelessWidget {
  const _RouteSummaryBlock({
    required this.label,
    required this.value,
    required this.subtitle,
  });

  final String label;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E0EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF60718D),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF25344A),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF60718D),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportsReplayData {
  _ReportsReplayData({
    required this.vehicleLabel,
    required this.deviceId,
    required this.periodStart,
    required this.periodEnd,
    required this.points,
    required this.events,
    required this.summary,
    this.message,
  });

  factory _ReportsReplayData.empty({required String message}) {
    return _ReportsReplayData(
      vehicleLabel: '',
      deviceId: 0,
      periodStart: DateTime.now(),
      periodEnd: DateTime.now(),
      points: const <_RouteReplayPoint>[],
      events: const <_ReplayEvent>[],
      summary: _ReplaySummary.empty(),
      message: message,
    );
  }

  final String vehicleLabel;
  final int deviceId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<_RouteReplayPoint> points;
  final List<_ReplayEvent> events;
  final _ReplaySummary summary;
  final String? message;

  bool get hasUsablePoints => points.length >= 2;
}

class _ReplaySummary {
  const _ReplaySummary({
    required this.startedAt,
    required this.endedAt,
    required this.startLocation,
    required this.endLocation,
    required this.distanceKm,
    required this.totalEvents,
    required this.criticalAlerts,
    required this.totalPoints,
    required this.highlightEvents,
    required this.hasSpeedData,
  });

  factory _ReplaySummary.empty() {
    return const _ReplaySummary(
      startedAt: null,
      endedAt: null,
      startLocation: 'Não informado',
      endLocation: 'Não informado',
      distanceKm: null,
      totalEvents: 0,
      criticalAlerts: 0,
      totalPoints: 0,
      highlightEvents: <_ReplayEvent>[],
      hasSpeedData: false,
    );
  }

  factory _ReplaySummary.fromRows({
    required List<Map<String, dynamic>> rows,
    required List<_RouteReplayPoint> points,
    required List<_ReplayEvent> events,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    final startedAt = points.isEmpty ? null : points.first.effectiveTime;
    final endedAt = points.isEmpty ? null : points.last.effectiveTime;
    final highlightEvents = {
      ...events.where((event) => event.isAlert).take(6),
      ...events.where((event) => !event.isAlert).take(3),
    }.take(6).toList(growable: false);

    var distanceKm = _distanceFromSummaryRows(rows);
    distanceKm ??= _distanceFromPoints(points);

    return _ReplaySummary(
      startedAt: startedAt,
      endedAt: endedAt,
      startLocation:
          points.isEmpty ? 'Não informado' : points.first.shortLocationLabel,
      endLocation:
          points.isEmpty ? 'Não informado' : points.last.shortLocationLabel,
      distanceKm: distanceKm,
      totalEvents: events.length,
      criticalAlerts: events.where((event) => event.isCritical).length,
      totalPoints: points.length,
      highlightEvents: highlightEvents,
      hasSpeedData: points.any((point) => point.speedKmh != null),
    );
  }

  final DateTime? startedAt;
  final DateTime? endedAt;
  final String startLocation;
  final String endLocation;
  final double? distanceKm;
  final int totalEvents;
  final int criticalAlerts;
  final int totalPoints;
  final List<_ReplayEvent> highlightEvents;
  final bool hasSpeedData;

  String get distanceLabel {
    if (distanceKm == null) {
      return 'Não informado';
    }
    return '${distanceKm!.toStringAsFixed(1)} km';
  }
}

class _ReplayEvent {
  const _ReplayEvent({
    required this.time,
    required this.label,
    required this.description,
    required this.isAlert,
    required this.isCritical,
  });

  static _ReplayEvent? fromMap(Map<String, dynamic> raw) {
    final time = _resolveDateTime(raw);
    if (time == null) {
      return null;
    }
    final attributes = _asMap(raw['attributes']);
    final type = '${raw['type'] ?? ''}'.trim();
    final alarm = '${attributes['alarm'] ?? ''}'.trim();
    final label = _humanizeReplayEventLabel(type, alarm);
    final description = _describeReplayEvent(raw, attributes, label);
    final isAlert = _isReplayAlertType(type, alarm);
    final isCritical = _isCriticalReplayAlertType(type, alarm);
    return _ReplayEvent(
      time: time,
      label: label,
      description: description,
      isAlert: isAlert,
      isCritical: isCritical,
    );
  }

  final DateTime time;
  final String label;
  final String description;
  final bool isAlert;
  final bool isCritical;

  @override
  bool operator ==(Object other) {
    return other is _ReplayEvent &&
        other.time == time &&
        other.label == label &&
        other.description == description;
  }

  @override
  int get hashCode => Object.hash(time, label, description);
}

class _RouteReplayPoint {
  const _RouteReplayPoint({
    required this.latitude,
    required this.longitude,
    required this.effectiveTime,
    required this.course,
    required this.speedKnots,
    required this.ignition,
    required this.battery,
    required this.signal,
    required this.rpm,
    required this.odometerKm,
    required this.address,
    required this.satellites,
    required this.hours,
    required this.motion,
  });

  static _RouteReplayPoint? fromMap(Map<String, dynamic> raw) {
    final base = _RouteDetailPoint.fromMap(raw);
    if (base == null) {
      return null;
    }
    return _RouteReplayPoint(
      latitude: base.latitude,
      longitude: base.longitude,
      effectiveTime: base.effectiveTime,
      course: base.course,
      speedKnots: base.speedKnots,
      ignition: base.ignition,
      battery: base.battery,
      signal: base.signal,
      rpm: base.rpm,
      odometerKm: base.odometerKm,
      address: base.address,
      satellites: base.satellites,
      hours: base.hours,
      motion: base.motion,
    );
  }

  final double latitude;
  final double longitude;
  final DateTime? effectiveTime;
  final double? course;
  final double? speedKnots;
  final bool? ignition;
  final String? battery;
  final String? signal;
  final double? rpm;
  final double? odometerKm;
  final String? address;
  final double? satellites;
  final double? hours;
  final bool? motion;

  double? get hourmeterHours =>
      hours == null ? null : hours! / 3600000.0;

  double? get speedKmh => speedKnots == null ? null : speedKnots! * 1.852;

  String get speedLabel {
    if (speedKmh == null) {
      return 'Sem velocidade';
    }
    return '${speedKmh!.toStringAsFixed(0)} km/h';
  }

  String get ignitionLabel {
    if (ignition == null) {
      return 'Não informada';
    }
    return ignition! ? 'Ligada' : 'Desligada';
  }

  String get shortLocationLabel {
    final trimmed = address?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      return trimmed.length > 72 ? '${trimmed.substring(0, 72)}...' : trimmed;
    }
    return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
  }

  bool get hasBattery => (battery?.trim().isNotEmpty ?? false);
  bool get hasSignal => (signal?.trim().isNotEmpty ?? false);
  bool get hasRpm => rpm != null && rpm!.isFinite;
  bool get hasOdometer => odometerKm != null && odometerKm!.isFinite;
}

String _formatReplayDateTime(DateTime? value) {
  if (value == null) {
    return 'Não informado';
  }
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month $hour:$minute';
}

String _movementStatus(double? speedKmh) {
  if (speedKmh == null) {
    return 'status indisponível';
  }
  if (speedKmh <= 2) {
    return 'parado';
  }
  return 'em movimento';
}

String _cardinalDirectionLabel(double? bearing) {
  if (bearing == null) {
    return 'não informado';
  }
  const directions = [
    'Norte',
    'Nordeste',
    'Leste',
    'Sudeste',
    'Sul',
    'Sudoeste',
    'Oeste',
    'Noroeste',
  ];
  final normalized = ((bearing % 360) + 360) % 360;
  final index = ((normalized + 22.5) / 45).floor() % 8;
  return directions[index];
}

double? _normalizeBearing(double? value) {
  if (value == null || !value.isFinite) {
    return null;
  }
  return ((value % 360) + 360) % 360;
}

double? _bearingBetween(_RouteReplayPoint from, _RouteReplayPoint to) {
  final startLat = from.latitude * math.pi / 180.0;
  final startLng = from.longitude * math.pi / 180.0;
  final endLat = to.latitude * math.pi / 180.0;
  final endLng = to.longitude * math.pi / 180.0;
  final deltaLng = endLng - startLng;
  final y = math.sin(deltaLng) * math.cos(endLat);
  final x = math.cos(startLat) * math.sin(endLat) -
      math.sin(startLat) * math.cos(endLat) * math.cos(deltaLng);
  final bearingRad = math.atan2(y, x);
  return _normalizeBearing((bearingRad * 180.0 / math.pi + 360.0) % 360.0);
}

Future<gmaps.BitmapDescriptor> _buildReplayArrowIcon() async {
  const size = 92.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final center = const Offset(size / 2, size / 2);

  final glowPaint = Paint()
    ..color = const Color(0x33176EEB)
    ..style = PaintingStyle.fill;
  canvas.drawCircle(center, 34, glowPaint);

  final circlePaint = Paint()
    ..color = const Color(0xFF176EEB)
    ..style = PaintingStyle.fill;
  canvas.drawCircle(center, 24, circlePaint);

  final borderPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4;
  canvas.drawCircle(center, 24, borderPaint);

  final path = Path()
    ..moveTo(center.dx, center.dy - 18)
    ..lineTo(center.dx + 12, center.dy + 10)
    ..lineTo(center.dx + 2, center.dy + 7)
    ..lineTo(center.dx - 3, center.dy + 18)
    ..lineTo(center.dx - 8, center.dy + 5)
    ..lineTo(center.dx - 16, center.dy + 8)
    ..close();

  final arrowPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;
  canvas.drawPath(path, arrowPaint);

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return gmaps.BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
}

double? _distanceFromSummaryRows(List<Map<String, dynamic>> rows) {
  for (final row in rows) {
    final candidates = [
      row['distance'],
      row['totalDistance'],
      row['totaldistance'],
    ];
    for (final candidate in candidates) {
      final value = _asDouble(candidate);
      if (value != null && value.isFinite) {
        return value;
      }
    }
  }
  return null;
}

double? _distanceFromPoints(List<_RouteReplayPoint> points) {
  if (points.length < 2) {
    return null;
  }
  var totalKm = 0.0;
  for (var i = 1; i < points.length; i++) {
    totalKm += _distanceBetweenPoints(points[i - 1], points[i]);
  }
  return totalKm > 0 ? totalKm : null;
}

double _distanceBetweenPoints(_RouteReplayPoint a, _RouteReplayPoint b) {
  const earthRadiusKm = 6371.0;
  final dLat = (b.latitude - a.latitude) * math.pi / 180.0;
  final dLng = (b.longitude - a.longitude) * math.pi / 180.0;
  final lat1 = a.latitude * math.pi / 180.0;
  final lat2 = b.latitude * math.pi / 180.0;
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  return earthRadiusKm * c;
}

String _humanizeReplayEventLabel(String type, String alarm) {
  final normalized = type.trim().toLowerCase();
  final normalizedAlarm = alarm.trim().toLowerCase();
  if (normalized.contains('overspeed') ||
      normalizedAlarm.contains('overspeed')) {
    return 'Excesso de velocidade';
  }
  if (normalized.contains('geofenceenter')) {
    return 'Entrada em cerca';
  }
  if (normalized.contains('geofenceexit')) {
    return 'Saída de cerca';
  }
  if (normalized.contains('ignitionon')) {
    return 'Ignição ligada';
  }
  if (normalized.contains('ignitionoff')) {
    return 'Ignição desligada';
  }
  if (normalized.contains('deviceoffline')) {
    return 'Sem comunicação';
  }
  if (normalized.contains('deviceonline')) {
    return 'Dispositivo online';
  }
  if (normalized.contains('stopped')) {
    return 'Parada';
  }
  if (normalized.contains('moving')) {
    return 'Em movimento';
  }
  if (normalized.contains('alarm') || normalizedAlarm.isNotEmpty) {
    return 'Alerta ${normalizedAlarm.isEmpty ? 'operacional' : normalizedAlarm}';
  }
  final value = type.trim();
  if (value.isEmpty) {
    return 'Evento';
  }
  final spaced = value
      .replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      )
      .replaceAll('_', ' ');
  return spaced[0].toUpperCase() + spaced.substring(1);
}

String _describeReplayEvent(
  Map<String, dynamic> raw,
  Map<String, dynamic> attributes,
  String label,
) {
  final candidates = [
    '${raw['message'] ?? ''}'.trim(),
    '${raw['description'] ?? ''}'.trim(),
    '${attributes['message'] ?? ''}'.trim(),
    '${attributes['description'] ?? ''}'.trim(),
  ];
  for (final candidate in candidates) {
    if (candidate.isNotEmpty && candidate.toLowerCase() != 'null') {
      return candidate;
    }
  }
  final geofence =
      '${attributes['geofenceName'] ?? attributes['geofence'] ?? ''}'.trim();
  if (geofence.isNotEmpty) {
    return '$label em $geofence';
  }
  return label;
}

bool _isReplayAlertType(String type, String alarm) {
  final normalized = '${type.trim()} ${alarm.trim()}'.toLowerCase();
  return normalized.contains('overspeed') ||
      normalized.contains('alarm') ||
      normalized.contains('panic') ||
      normalized.contains('sos') ||
      normalized.contains('geofence') ||
      normalized.contains('offline') ||
      normalized.contains('jammer') ||
      normalized.contains('power');
}

bool _isCriticalReplayAlertType(String type, String alarm) {
  final normalized = '${type.trim()} ${alarm.trim()}'.toLowerCase();
  return normalized.contains('panic') ||
      normalized.contains('sos') ||
      normalized.contains('jammer') ||
      normalized.contains('powercut');
}

class _RouteDetailPoint {
  const _RouteDetailPoint({
    required this.latitude,
    required this.longitude,
    required this.effectiveTime,
    required this.course,
    required this.speedKnots,
    required this.ignition,
    required this.battery,
    required this.signal,
    required this.rpm,
    required this.odometerKm,
    required this.address,
    required this.satellites,
    required this.hours,
    required this.motion,
  });

  final double? satellites;
  final double? hours;
  final bool? motion;

  final double latitude;
  final double longitude;
  final DateTime? effectiveTime;
  final double? course;
  final double? speedKnots;
  final bool? ignition;
  final String? battery;
  final String? signal;
  final double? rpm;
  final double? odometerKm;
  final String? address;

  static _RouteDetailPoint? fromMap(Map<String, dynamic> raw) {
    final attributes = _asMap(raw['attributes']);
    final latitude =
        _asDouble(raw['latitude']) ?? _asDouble(attributes['latitude']);
    final longitude =
        _asDouble(raw['longitude']) ?? _asDouble(attributes['longitude']);
    if (latitude == null || longitude == null) {
      return null;
    }
    if (latitude == 0 && longitude == 0) {
      return null;
    }

    return _RouteDetailPoint(
      latitude: latitude,
      longitude: longitude,
      effectiveTime: _resolveDateTime(raw),
      course: _asDouble(
        raw['course'] ??
            raw['heading'] ??
            raw['bearing'] ??
            attributes['course'] ??
            attributes['heading'] ??
            attributes['bearing'],
      ),
      speedKnots: _asDouble(raw['speed']) ?? _asDouble(attributes['speed']),
      ignition: _asBool(
        raw['ignition'] ?? attributes['ignition'] ?? attributes['ignitionOn'],
      ),
      motion: _asBool(raw['motion'] ?? attributes['motion']),
      battery: _resolveBattery(raw, attributes),
      signal: _resolveSignal(raw, attributes),
      rpm: _resolveSensorDouble(
        raw,
        attributes,
        const ['rpm'],
        const ['rpm', 'engineRpm', 'obd.rpm'],
      ),
      odometerKm: _resolveSensorDouble(
        raw,
        attributes,
        const ['odometer'],
        const ['odometer', 'totalDistance', 'mileage'],
      ),
      address: _resolveAddress(raw, attributes),
      satellites: _resolveSensorDouble(
        raw,
        attributes,
        const ['satellites'],
        const ['sat', 'satellites'],
      ),
      hours: _resolveSensorDouble(
        raw,
        attributes,
        const ['hours'],
        const ['hours'],
      ),
    );
  }

  bool get hasValidCoordinates => latitude != 0 || longitude != 0;

  String get coordinatesLabel =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  String get speedLabel {
    if (speedKnots == null) {
      return 'Nao informado';
    }
    final kmh = speedKnots! * 1.852;
    return '${kmh.toStringAsFixed(1)} km/h';
  }

  String get ignitionLabel {
    if (ignition == null) {
      return 'Nao informado';
    }
    return ignition! ? 'Ligada' : 'Desligada';
  }

  String get batteryLabel {
    final text = battery?.trim() ?? '';
    return text.isEmpty ? 'Nao informado' : text;
  }

  String get signalLabel {
    final text = signal?.trim() ?? '';
    return text.isEmpty ? 'Nao informado' : text;
  }

  String get rpmLabel {
    if (rpm == null || !rpm!.isFinite) {
      return 'Nao informado';
    }
    return '${rpm!.toStringAsFixed(0)} rpm';
  }

  String get odometerLabel {
    if (odometerKm == null || !odometerKm!.isFinite) {
      return 'Nao informado';
    }
    return '${odometerKm!.toStringAsFixed(1)} km';
  }

  String get addressLabel {
    final text = address?.trim() ?? '';
    return text.isEmpty ? 'Nao informado' : text;
  }
}

class _ExecutiveLoadingPanel extends StatelessWidget {
  const _ExecutiveLoadingPanel();

  @override
  Widget build(BuildContext context) => Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD6E0EE)),
        ),
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 12),
            Text(
              'Carregando resumo executivo...',
              style: TextStyle(color: Color(0xFF60718D), fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
}

class _ExecutiveUnavailablePanel extends StatelessWidget {
  const _ExecutiveUnavailablePanel();

  @override
  Widget build(BuildContext context) => Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD6E0EE)),
        ),
        alignment: Alignment.center,
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nao foi possivel carregar os dados do resumo executivo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF60718D), fontWeight: FontWeight.w700),
          ),
        ),
      );
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD6E0EE)),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 116,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD6E0EE)),
          ),
        ),
        const SizedBox(height: 12),
        const ReportsKpiRow(
          summary: ReportKpiSummary(
            generated: 0,
            scheduled: 0,
            exports: 0,
            criticalAlerts: 0,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ReportsTable(
            records: const [],
            onView: _noopRecordAction,
            onExportPdf: _noopRecordAction,
            onExportExcel: _noopRecordAction,
            canExportRow: false,
            pdfEnabled: false,
          ),
        ),
      ],
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD6E0EE)),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
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
          ),
        ),
      ],
    );
  }
}
