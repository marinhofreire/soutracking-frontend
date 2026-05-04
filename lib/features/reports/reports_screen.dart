import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/session_state.dart';
import '../admin/admin_reference_ui.dart';
import 'models/report_models.dart';
import 'widgets/report_category_cards.dart';
import 'widgets/reports_filters_bar.dart';
import 'widgets/reports_kpi_row.dart';
import 'widgets/reports_table.dart';

class _ReportsQueryParams {
  const _ReportsQueryParams({
    required this.period,
    required this.type,
    required this.revision,
  });

  final String period;
  final String type;
  final int revision;

  @override
  bool operator ==(Object other) {
    return other is _ReportsQueryParams &&
        other.period == period &&
        other.type == type &&
        other.revision == revision;
  }

  @override
  int get hashCode => Object.hash(period, type, revision);
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

  try {
    final raw = await client.getReport(
      path: _resolveReportEndpoint(query.type),
      cookie: session.cookie,
      authHeader: session.authHeader,
      from: from,
      to: now,
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
  int _revision = 0;

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(
      reportsListProvider(
        _ReportsQueryParams(
          period: _period,
          type: _type,
          revision: _revision,
        ),
      ),
    );

    return AdminReferenceScaffold(
      title: 'Relatórios',
      breadcrumbs: const ['Operação', 'Relatórios'],
      selectedMenu: 'reports',
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
              ReportsKpiRow(summary: summary),
              const SizedBox(height: 12),
              ReportCategoryCards(
                categories: categories,
                onGenerate: (type) {
                  setState(() {
                    _type = type.label;
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
                onPeriodChanged: (value) => setState(() => _period = value),
                onVehicleChanged: (value) => setState(() => _vehicle = value),
                onDriverChanged: (value) => setState(() => _driver = value),
                onTypeChanged: (value) => setState(() => _type = value),
                onStatusChanged: (value) => setState(() => _status = value),
                onSearch: () {
                  setState(() {
                    _revision++;
                  });
                },
                onExport: () {
                  final message = filtered.isEmpty
                      ? 'Nenhum dado disponível para exportação.'
                      : 'Exportação preparada para os registros filtrados.';
                  _showAction(message);
                },
                onClearFilters: () {
                  setState(() {
                    _period = '30 dias';
                    _vehicle = 'Todos';
                    _driver = 'Todos';
                    _type = 'Eventos';
                    _status = 'Todos';
                    _revision++;
                  });
                },
              ),
              const SizedBox(height: 12),
              ReportsTable(
                records: filtered,
                onView: (record) => _showAction('Visualizando ${record.name}.'),
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
        return 'Percursos e variações por período.';
      case ReportType.trips:
        return 'Viagens concluídas e tempos de trajeto.';
      case ReportType.stops:
        return 'Paradas e permanência por local.';
      case ReportType.events:
        return 'Eventos operacionais registrados.';
      case ReportType.distance:
        return 'Resumo consolidado do período selecionado.';
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
