import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models.dart';
import '../../state/session_state.dart';
import 'models/report_models.dart';
import 'services/report_export_service.dart';
import 'widgets/report_category_cards.dart';
import 'widgets/reports_filters_bar.dart';
import 'widgets/reports_kpi_row.dart';
import 'widgets/reports_table.dart';

class _ReportsQueryParams {
  const _ReportsQueryParams({
    required this.period,
    required this.type,
    required this.vehicle,
    required this.revision,
  });

  final String period;
  final String type;
  final String vehicle;
  final int revision;

  @override
  bool operator ==(Object other) {
    return other is _ReportsQueryParams &&
        other.period == period &&
        other.type == type &&
        other.vehicle == vehicle &&
        other.revision == revision;
  }

  @override
  int get hashCode => Object.hash(period, type, vehicle, revision);
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
  final now = DateTime.now();
  final from = _periodStart(query.period, now);
  final selectedDeviceId = _resolveSelectedDeviceId(query.vehicle, devices);

  try {
    final raw = await client.getReport(
      path: _resolveReportEndpoint(query.type),
      cookie: session.cookie,
      authHeader: session.authHeader,
      from: from,
      to: now,
      deviceId: selectedDeviceId,
    );
    return _mapReportRecords(
      rawRecords: raw,
      devices: devices,
      selectedTypeLabel: query.type,
      from: from,
      to: now,
    );
  } catch (_) {
    return [];
  }
});

int? _resolveSelectedDeviceId(
    String vehicleLabel, List<TraccarDevice> devices) {
  if (vehicleLabel == 'Todos') {
    return null;
  }

  for (final device in devices) {
    if (device.name == vehicleLabel) {
      return device.id;
    }
  }

  return null;
}

DateTime _periodStart(String period, DateTime now) {
  switch (period) {
    case 'Hoje':
      return DateTime(now.year, now.month, now.day);
    case '7 dias':
      return now.subtract(const Duration(days: 7));
    case '30 dias':
      return now.subtract(const Duration(days: 30));
    case '90 dias':
      return now.subtract(const Duration(days: 90));
    default:
      return now.subtract(const Duration(days: 30));
  }
}

String _resolvePeriodLabel(DateTime from, DateTime to) {
  final startDay = from.day.toString().padLeft(2, '0');
  final startMonth = from.month.toString().padLeft(2, '0');
  final endDay = to.day.toString().padLeft(2, '0');
  final endMonth = to.month.toString().padLeft(2, '0');
  return '$startDay/$startMonth - $endDay/$endMonth';
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
      return '/reports/summary';
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
      return ReportType.distance;
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

  final records = <ReportRecord>[];
  final selectedType = _typeFromLabel(selectedTypeLabel);

  for (final raw in rawRecords) {
    final attributes = _asMap(raw['attributes']);
    final createdAt = _resolveDateTime(raw) ?? DateTime.now();
    final deviceId = _resolveInt(raw['deviceId']);
    final type =
        selectedTypeLabel == 'Todos' ? _inferTypeFromRaw(raw) : selectedType;

    records.add(
      ReportRecord(
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
        eventType: _resolveEventType(raw),
        address: _resolveAddress(raw, attributes),
        attributes: attributes,
      ),
    );
  }

  records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return records;
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
      return 'Relatório de resumo';
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

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _period = '30 dias';
  String _type = 'Eventos';
  String _vehicle = 'Todos';
  String _driver = 'Todos';
  String _status = 'Todos';
  bool _hasSearched = false;
  static const bool _pdfEnabled = false;
  int _revision = 0;

  Future<List<ReportRouteMapPoint>> _loadRouteMapPoints(
    ReportRecord record,
  ) async {
    final deviceId = record.deviceId;
    if (deviceId == null) {
      return const <ReportRouteMapPoint>[];
    }

    final session = ref.read(sessionProvider);
    if (!session.isAuthenticated) {
      return const <ReportRouteMapPoint>[];
    }

    final client = ref.read(traccarClientProvider);
    final now = DateTime.now();
    final from = _periodStart(_period, now);

    final rows = await client.getReport(
      path: '/reports/route',
      cookie: session.cookie,
      authHeader: session.authHeader,
      from: from,
      to: now,
      deviceId: deviceId,
    );

    final points = <ReportRouteMapPoint>[];
    for (final row in rows) {
      final point = _RouteDetailPoint.fromMap(row);
      if (point != null) {
        points.add(
          ReportRouteMapPoint(
            latitude: point.latitude,
            longitude: point.longitude,
            effectiveTime: point.effectiveTime,
            course: point.course,
            address: point.address,
          ),
        );
      }
    }

    points.sort((a, b) {
      final at = a.effectiveTime;
      final bt = b.effectiveTime;
      if (at == null && bt == null) return 0;
      if (at == null) return -1;
      if (bt == null) return 1;
      return at.compareTo(bt);
    });
    return points;
  }

  Future<void> _openRecordDetail(ReportRecord record) async {
    if (record.type != ReportType.routes) {
      _showAction('Visualizando ${record.name}.');
      return;
    }

    final now = DateTime.now();
    final from = _periodStart(_period, now);
    final deviceId = record.deviceId;
    if (deviceId == null) {
      return;
    }

    final points = await _loadRouteMapPoints(record);
    if (!mounted) {
      return;
    }

    ref.read(reportRouteMapSelectionProvider.notifier).state =
        ReportRouteMapSelection(
      deviceId: deviceId,
      vehicleName: record.vehicle,
      from: from,
      to: now,
      points: points,
      requestNonce: DateTime.now().microsecondsSinceEpoch.toString(),
    );
  }

  Future<void> _exportRecords(
    List<ReportRecord> records,
    ReportExportFormat format, {
    ReportRecord? singleRecord,
  }) async {
    if (format == ReportExportFormat.pdf) {
      _showAction('PDF em desenvolvimento');
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
    return '$_type|$_period|$_vehicle|$_status';
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(
      reportsListProvider(
        _ReportsQueryParams(
          period: _period,
          type: _type,
          vehicle: _vehicle,
          revision: _revision,
        ),
      ),
    );

    return SizedBox.expand(
      child: listAsync.when(
        data: (records) {
          final summary = _buildSummary(records);
          final categories = _buildMainCategories(records);
          final filtered = _applyFilters(records);

          final periodOptions = const [
            'Hoje',
            '7 dias',
            '30 dias',
            '90 dias',
          ];
          final typeOptions = const [
            'Todos',
            'Rotas',
            'Viagens',
            'Paradas',
            'Eventos',
            'Resumo',
          ];
          final vehicleOptions = <String>[
            'Todos',
            ...{for (final item in records) item.vehicle},
          ];
          final driverOptions = <String>[
            'Todos',
            ...{for (final item in records) item.driver},
          ];
          final statusOptions = <String>[
            'Todos',
            ...{for (final item in records) item.status.label},
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ReportsPageHeader(),
              const SizedBox(height: 12),
              ReportCategoryCards(
                categories: categories,
                selectedTypeLabel: _type,
                onGenerate: (type) {
                  setState(() {
                    _type = type.label;
                    _hasSearched = false;
                    _revision++;
                  });
                },
              ),
              const SizedBox(height: 12),
              ReportsFiltersBar(
                period: _period,
                vehicle: _vehicle,
                driver: _driver,
                type: _type,
                status: _status,
                periodOptions: periodOptions,
                vehicleOptions: vehicleOptions,
                driverOptions: driverOptions,
                typeOptions: typeOptions,
                statusOptions: statusOptions,
                onPeriodChanged: (value) => setState(() {
                  _period = value;
                  _hasSearched = false;
                }),
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
                onStatusChanged: (value) => setState(() {
                  _status = value;
                  _hasSearched = false;
                }),
                onSearch: () {
                  setState(() {
                    _hasSearched = true;
                    _revision++;
                  });
                },
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
                canExport: true,
                pdfEnabled: _pdfEnabled,
                onClearFilters: () {
                  setState(() {
                    _period = '30 dias';
                    _vehicle = 'Todos';
                    _driver = 'Todos';
                    _type = 'Eventos';
                    _status = 'Todos';
                    _hasSearched = false;
                    _revision++;
                  });
                },
              ),
              const SizedBox(height: 12),
              ReportsKpiRow(summary: summary),
              const SizedBox(height: 12),
              Expanded(
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
        return 'Endpoint /reports/route';
      case ReportType.trips:
        return 'Endpoint /reports/trips';
      case ReportType.stops:
        return 'Endpoint /reports/stops';
      case ReportType.events:
        return 'Endpoint /reports/events';
      case ReportType.distance:
        return 'Endpoint /reports/summary';
      default:
        return 'Categoria operacional.';
    }
  }

  List<ReportRecord> _applyFilters(List<ReportRecord> records) {
    return records.where((record) {
      if (_type != 'Todos' && record.type.label != _type) return false;
      if (_vehicle != 'Todos' && record.vehicle != _vehicle) return false;
      if (_driver != 'Todos' && record.driver != _driver) return false;
      if (_status != 'Todos' && record.status.label != _status) return false;
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
                          label: 'Periodo',
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

class _RouteDetailPoint {
  const _RouteDetailPoint({
    required this.latitude,
    required this.longitude,
    required this.effectiveTime,
    required this.course,
    required this.speedKnots,
    required this.ignition,
    required this.battery,
    required this.address,
  });

  final double latitude;
  final double longitude;
  final DateTime? effectiveTime;
  final double? course;
  final double? speedKnots;
  final bool? ignition;
  final String? battery;
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
      battery: _resolveBattery(raw, attributes),
      address: _resolveAddress(raw, attributes),
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

  String get addressLabel {
    final text = address?.trim() ?? '';
    return text.isEmpty ? 'Nao informado' : text;
  }
}

class _ReportsPageHeader extends StatelessWidget {
  const _ReportsPageHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E0EE)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFE9F2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.article_outlined,
              color: Color(0xFF2D8CFF),
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Painel executivo',
                  style: TextStyle(
                    color: Color(0xFF25344A),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Relatórios operacionais e executivos',
                  style: TextStyle(
                    color: Color(0xFF60718D),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: const Text('Exportar'),
          ),
        ],
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ReportsPageHeader(),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD6E0EE)),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 116,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.84),
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
        const _ReportsPageHeader(),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.84),
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
