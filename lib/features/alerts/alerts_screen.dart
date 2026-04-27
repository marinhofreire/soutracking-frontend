import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_constants.dart';
import '../admin/admin_reference_ui.dart';
import 'models/alert_models.dart';
import 'repositories/alerts_repository.dart';
import 'repositories/mock_alerts_repository.dart';
import 'services/alerts_api_service.dart';
import 'widgets/alerts_filters_bar.dart';
import 'widgets/alerts_kpi_row.dart';
import 'widgets/alerts_table.dart';

final alertsApiServiceProvider = Provider<AlertsApiService>((ref) {
  return AlertsApiService(baseUrl: kSouAssistApiBaseUrl);
});

final alertsRepositoryProvider = Provider<AlertsRepository>((ref) {
  // Mantemos mock nesta etapa; swap para API real fica centralizado aqui.
  ref.watch(alertsApiServiceProvider);
  return const MockAlertsRepository();
});

final alertsKpiProvider = FutureProvider<AlertKpiSummary>((ref) async {
  final repository = ref.watch(alertsRepositoryProvider);
  return repository.getKpiSummary();
});

final alertsListProvider = FutureProvider<List<AlertRecord>>((ref) async {
  final repository = ref.watch(alertsRepositoryProvider);
  return repository.getAlerts();
});

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
    final kpiAsync = ref.watch(alertsKpiProvider);
    final listAsync = ref.watch(alertsListProvider);

    return AdminReferenceScaffold(
      title: 'Alertas',
      breadcrumbs: const ['Operacao', 'Alertas'],
      selectedMenu: 'alerts',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kpiAsync.when(
            data: (summary) => AlertsKpiRow(summary: summary),
            loading: () => const _LoadingPanel(),
            error: (error, _) => _ErrorPanel(
              message: 'Falha ao carregar indicadores: $error',
            ),
          ),
          const SizedBox(height: 12),
          listAsync.when(
            data: (records) {
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
                ...{for (final item in records) item.status.label},
              ];
              final vehicleOptions = <String>[
                'Todos',
                ...{for (final item in records) item.vehicle},
              ];

              final filtered = _applyFilters(records);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AlertsFiltersBar(
                    period: _period,
                    type: _type,
                    severity: _severity,
                    status: _status,
                    vehicle: _vehicle,
                    periodOptions: periodOptions,
                    typeOptions: typeOptions,
                    severityOptions: severityOptions,
                    statusOptions: statusOptions,
                    vehicleOptions: vehicleOptions,
                    onPeriodChanged: (value) => setState(() => _period = value),
                    onTypeChanged: (value) => setState(() => _type = value),
                    onSeverityChanged: (value) =>
                        setState(() => _severity = value),
                    onStatusChanged: (value) => setState(() => _status = value),
                    onVehicleChanged: (value) =>
                        setState(() => _vehicle = value),
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
        ],
      ),
    );
  }

  List<AlertRecord> _applyFilters(List<AlertRecord> records) {
    final now = DateTime.now();
    final periodStart = switch (_period) {
      'Hoje' => DateTime(now.year, now.month, now.day),
      '7 dias' => now.subtract(const Duration(days: 7)),
      '30 dias' => now.subtract(const Duration(days: 30)),
      _ => DateTime(2000),
    };

    return records.where((record) {
      if (record.dateTime.isBefore(periodStart)) return false;
      if (_type != 'Todos' && record.type != _type) return false;
      if (_severity != 'Todas' && record.severity.label != _severity) {
        return false;
      }
      if (_status != 'Todos' && record.status.label != _status) return false;
      if (_vehicle != 'Todos' && record.vehicle != _vehicle) return false;
      return true;
    }).toList();
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
