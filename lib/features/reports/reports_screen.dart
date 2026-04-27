import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_constants.dart';
import '../admin/admin_reference_ui.dart';
import 'models/report_models.dart';
import 'repositories/mock_reports_repository.dart';
import 'repositories/reports_repository.dart';
import 'services/reports_api_service.dart';
import 'widgets/report_category_cards.dart';
import 'widgets/reports_filters_bar.dart';
import 'widgets/reports_kpi_row.dart';
import 'widgets/reports_table.dart';

final reportsApiServiceProvider = Provider<ReportsApiService>((ref) {
  return ReportsApiService(baseUrl: kSouAssistApiBaseUrl);
});

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  // Mantemos mock nesta etapa; swap para API real fica centralizado aqui.
  ref.watch(reportsApiServiceProvider);
  return const MockReportsRepository();
});

final reportsKpiProvider = FutureProvider<ReportKpiSummary>((ref) async {
  final repository = ref.watch(reportsRepositoryProvider);
  return repository.getKpiSummary();
});

final reportCategoriesProvider =
    FutureProvider<List<ReportCategory>>((ref) async {
  final repository = ref.watch(reportsRepositoryProvider);
  return repository.getCategories();
});

final reportsListProvider = FutureProvider<List<ReportRecord>>((ref) async {
  final repository = ref.watch(reportsRepositoryProvider);
  return repository.getReports();
});

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _period = '30 dias';
  String _vehicle = 'Todos';
  String _driver = 'Todos';
  String _type = 'Todos';
  String _status = 'Todos';

  @override
  Widget build(BuildContext context) {
    final kpiAsync = ref.watch(reportsKpiProvider);
    final categoriesAsync = ref.watch(reportCategoriesProvider);
    final listAsync = ref.watch(reportsListProvider);

    return AdminReferenceScaffold(
      title: 'Relatorios',
      breadcrumbs: const ['Operacao', 'Relatorios'],
      selectedMenu: 'reports',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kpiAsync.when(
            data: (summary) => ReportsKpiRow(summary: summary),
            loading: () => const _LoadingPanel(),
            error: (error, _) => _ErrorPanel(
              message: 'Falha ao carregar indicadores: $error',
            ),
          ),
          const SizedBox(height: 12),
          categoriesAsync.when(
            data: (categories) => ReportCategoryCards(
              categories: categories,
              onGenerate: (type) {
                setState(() => _type = type.label);
                _showMockAction(
                  'Geracao iniciada para o relatorio de ${type.label}.',
                );
              },
            ),
            loading: () => const _LoadingPanel(),
            error: (error, _) => _ErrorPanel(
              message: 'Falha ao carregar categorias: $error',
            ),
          ),
          const SizedBox(height: 12),
          listAsync.when(
            data: (records) {
              final periodOptions = const [
                'Hoje',
                '7 dias',
                '30 dias',
                '90 dias'
              ];
              final vehicleOptions = <String>[
                'Todos',
                ...{for (final item in records) item.vehicle},
              ];
              final driverOptions = <String>[
                'Todos',
                ...{for (final item in records) item.driver},
              ];
              final typeOptions = <String>[
                'Todos',
                ...{for (final item in records) item.type.label},
              ];
              final statusOptions = <String>[
                'Todos',
                ...{for (final item in records) item.status.label},
              ];

              final filtered = _applyFilters(records);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    onVehicleChanged: (value) =>
                        setState(() => _vehicle = value),
                    onDriverChanged: (value) => setState(() => _driver = value),
                    onTypeChanged: (value) => setState(() => _type = value),
                    onStatusChanged: (value) => setState(() => _status = value),
                    onGenerate: () =>
                        _showMockAction('Relatorio gerado com dados mock.'),
                    onExportPdf: () =>
                        _showMockAction('Exportacao PDF simulada.'),
                    onExportExcel: () =>
                        _showMockAction('Exportacao Excel simulada.'),
                    onSchedule: () =>
                        _showMockAction('Agendamento simulado com sucesso.'),
                  ),
                  const SizedBox(height: 12),
                  ReportsTable(
                    records: filtered,
                    onView: (record) {
                      _showMockAction('Visualizando ${record.name}.');
                    },
                  ),
                ],
              );
            },
            loading: () => const _LoadingPanel(),
            error: (error, _) => _ErrorPanel(
              message: 'Falha ao carregar relatorios: $error',
            ),
          ),
        ],
      ),
    );
  }

  List<ReportRecord> _applyFilters(List<ReportRecord> records) {
    final now = DateTime.now();
    final periodStart = switch (_period) {
      'Hoje' => DateTime(now.year, now.month, now.day),
      '7 dias' => now.subtract(const Duration(days: 7)),
      '30 dias' => now.subtract(const Duration(days: 30)),
      '90 dias' => now.subtract(const Duration(days: 90)),
      _ => DateTime(2000),
    };

    return records.where((record) {
      if (record.createdAt.isBefore(periodStart)) return false;
      if (_vehicle != 'Todos' && record.vehicle != _vehicle) return false;
      if (_driver != 'Todos' && record.driver != _driver) return false;
      if (_type != 'Todos' && record.type.label != _type) return false;
      if (_status != 'Todos' && record.status.label != _status) return false;
      return true;
    }).toList();
  }

  void _showMockAction(String message) {
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
