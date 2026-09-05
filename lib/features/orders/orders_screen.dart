import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_constants.dart';
import '../admin/admin_reference_ui.dart';
import 'models/service_order_models.dart';
import 'repositories/mock_service_orders_repository.dart';
import 'repositories/service_orders_repository.dart';
import 'services/service_orders_api_service.dart';
import 'widgets/service_orders_filters_bar.dart';
import 'widgets/service_orders_kpi_row.dart';
import 'widgets/service_orders_table.dart';

final serviceOrdersApiServiceProvider =
    Provider<ServiceOrdersApiService>((ref) {
  return ServiceOrdersApiService(baseUrl: kSouAssistApiBaseUrl);
});

final serviceOrdersRepositoryProvider =
    Provider<ServiceOrdersRepository>((ref) {
  // Mantemos mock nesta etapa; swap para API real fica centralizado aqui.
  ref.watch(serviceOrdersApiServiceProvider);
  return const MockServiceOrdersRepository();
});

final serviceOrdersKpiProvider =
    FutureProvider<ServiceOrderKpiSummary>((ref) async {
  final repository = ref.watch(serviceOrdersRepositoryProvider);
  return repository.getKpiSummary();
});

final serviceOrdersListProvider =
    FutureProvider<List<ServiceOrderRecord>>((ref) async {
  final repository = ref.watch(serviceOrdersRepositoryProvider);
  return repository.getOrders();
});

class ServiceOrdersScreen extends ConsumerStatefulWidget {
  const ServiceOrdersScreen({super.key});

  @override
  ConsumerState<ServiceOrdersScreen> createState() =>
      _ServiceOrdersScreenState();
}

class _ServiceOrdersScreenState extends ConsumerState<ServiceOrdersScreen> {
  final _searchController = TextEditingController();

  String _search = '';
  String _status = 'Todos';
  String _priority = 'Todas';
  String _technician = 'Todos';
  String _client = 'Todos';
  String _vehicle = 'Todos';
  String _period = '30 dias';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kpiAsync = ref.watch(serviceOrdersKpiProvider);
    final listAsync = ref.watch(serviceOrdersListProvider);

    return AdminReferenceScaffold(
      title: 'Ordens de Servico',
      breadcrumbs: const ['Operação', 'Ordens de Servico'],
      selectedMenu: 'orders',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kpiAsync.when(
            data: (summary) => ServiceOrdersKpiRow(summary: summary),
            loading: () => const _LoadingPanel(),
            error: (error, _) => _ErrorPanel(
              message: 'Falha ao carregar indicadores: $error',
            ),
          ),
          const SizedBox(height: 12),
          listAsync.when(
            data: (records) {
              final statusOptions = <String>[
                'Todos',
                ...{for (final item in records) item.status.label},
              ];
              final priorityOptions = <String>[
                'Todas',
                ...{for (final item in records) item.priority.label},
              ];
              final technicianOptions = <String>[
                'Todos',
                ...{for (final item in records) item.technician},
              ];
              final clientOptions = <String>[
                'Todos',
                ...{for (final item in records) item.client},
              ];
              final vehicleOptions = <String>[
                'Todos',
                ...{for (final item in records) item.vehicle},
              ];
              const periodOptions = ['Hoje', '7 dias', '30 dias', '90 dias'];

              final filtered = _applyFilters(records);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ServiceOrdersFiltersBar(
                    searchController: _searchController,
                    status: _status,
                    priority: _priority,
                    technician: _technician,
                    client: _client,
                    vehicle: _vehicle,
                    period: _period,
                    statusOptions: statusOptions,
                    priorityOptions: priorityOptions,
                    technicianOptions: technicianOptions,
                    clientOptions: clientOptions,
                    vehicleOptions: vehicleOptions,
                    periodOptions: periodOptions,
                    onSearchChanged: (value) => setState(() => _search = value),
                    onStatusChanged: (value) => setState(() => _status = value),
                    onPriorityChanged: (value) =>
                        setState(() => _priority = value),
                    onTechnicianChanged: (value) =>
                        setState(() => _technician = value),
                    onClientChanged: (value) => setState(() => _client = value),
                    onVehicleChanged: (value) =>
                        setState(() => _vehicle = value),
                    onPeriodChanged: (value) => setState(() => _period = value),
                    // Status/Prioridade/Técnico/Cliente/Veículo/Período já
                    // cobrem os campos filtráveis do mock. Padronizado com o
                    // resto da tela (_showMockAction) -- ver mesma decisão em
                    // inventory_screen.dart, mesmo estado de mock declarado.
                    onMoreFilters: () {
                      _showMockAction(
                        'Ordens de serviço ainda usa dado simulado -- '
                        'filtros adicionais entram quando o módulo tiver '
                        'integração real.',
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  ServiceOrdersTable(
                    records: filtered,
                    onView: (record) {
                      _showMockAction('Visualizando OS ${record.id}.');
                    },
                  ),
                ],
              );
            },
            loading: () => const _LoadingPanel(),
            error: (error, _) => _ErrorPanel(
              message: 'Falha ao carregar ordens de servico: $error',
            ),
          ),
        ],
      ),
    );
  }

  List<ServiceOrderRecord> _applyFilters(List<ServiceOrderRecord> records) {
    final now = DateTime.now();
    final query = _search.trim().toLowerCase();

    final periodStart = switch (_period) {
      'Hoje' => DateTime(now.year, now.month, now.day),
      '7 dias' => now.subtract(const Duration(days: 7)),
      '30 dias' => now.subtract(const Duration(days: 30)),
      '90 dias' => now.subtract(const Duration(days: 90)),
      _ => DateTime(2000),
    };

    return records.where((record) {
      if (record.createdAt.isBefore(periodStart)) return false;

      if (query.isNotEmpty) {
        final matchesQuery = record.id.toLowerCase().contains(query) ||
            record.client.toLowerCase().contains(query) ||
            record.vehicle.toLowerCase().contains(query) ||
            record.serviceType.label.toLowerCase().contains(query);
        if (!matchesQuery) return false;
      }

      if (_status != 'Todos' && record.status.label != _status) return false;
      if (_priority != 'Todas' && record.priority.label != _priority) {
        return false;
      }
      if (_technician != 'Todos' && record.technician != _technician) {
        return false;
      }
      if (_client != 'Todos' && record.client != _client) return false;
      if (_vehicle != 'Todos' && record.vehicle != _vehicle) return false;

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

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ServiceOrdersScreen();
  }
}
