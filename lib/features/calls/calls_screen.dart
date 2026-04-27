import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_constants.dart';
import '../admin/admin_reference_ui.dart';
import 'models/call_models.dart';
import 'repositories/calls_repository.dart';
import 'repositories/mock_calls_repository.dart';
import 'services/calls_api_service.dart';
import 'widgets/calls_filters_bar.dart';
import 'widgets/calls_kpi_row.dart';
import 'widgets/calls_table.dart';

final callsApiServiceProvider = Provider<CallsApiService>((ref) {
  return CallsApiService(baseUrl: kSouAssistApiBaseUrl);
});

final callsRepositoryProvider = Provider<CallsRepository>((ref) {
  // Mantemos mock nesta etapa; swap para API real fica centralizado aqui.
  ref.watch(callsApiServiceProvider);
  return const MockCallsRepository();
});

final callsKpiProvider = FutureProvider<CallKpiSummary>((ref) async {
  final repository = ref.watch(callsRepositoryProvider);
  return repository.getKpiSummary();
});

final callsListProvider = FutureProvider<List<CallTicket>>((ref) async {
  final repository = ref.watch(callsRepositoryProvider);
  return repository.getTickets();
});

class CallsScreen extends ConsumerStatefulWidget {
  const CallsScreen({super.key});

  @override
  ConsumerState<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends ConsumerState<CallsScreen> {
  final _searchController = TextEditingController();

  String _search = '';
  String _status = 'Todos';
  String _priority = 'Todas';
  String _category = 'Todas';
  String _attendant = 'Todos';
  String _client = 'Todos';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kpiAsync = ref.watch(callsKpiProvider);
    final listAsync = ref.watch(callsListProvider);

    return AdminReferenceScaffold(
      title: 'Chamados',
      breadcrumbs: const ['Operacao', 'Chamados'],
      selectedMenu: 'calls',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kpiAsync.when(
            data: (summary) => CallsKpiRow(summary: summary),
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
              final categoryOptions = <String>[
                'Todas',
                ...{for (final item in records) item.category.label},
              ];
              final attendantOptions = <String>[
                'Todos',
                ...{for (final item in records) item.attendant},
              ];
              final clientOptions = <String>[
                'Todos',
                ...{for (final item in records) item.client},
              ];

              final filtered = _applyFilters(records);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CallsFiltersBar(
                    searchController: _searchController,
                    status: _status,
                    priority: _priority,
                    category: _category,
                    attendant: _attendant,
                    client: _client,
                    statusOptions: statusOptions,
                    priorityOptions: priorityOptions,
                    categoryOptions: categoryOptions,
                    attendantOptions: attendantOptions,
                    clientOptions: clientOptions,
                    onSearchChanged: (value) => setState(() => _search = value),
                    onStatusChanged: (value) => setState(() => _status = value),
                    onPriorityChanged: (value) =>
                        setState(() => _priority = value),
                    onCategoryChanged: (value) =>
                        setState(() => _category = value),
                    onAttendantChanged: (value) =>
                        setState(() => _attendant = value),
                    onClientChanged: (value) => setState(() => _client = value),
                    onMoreFilters: () {
                      _showMockAction(
                        'Mais filtros sera habilitado na proxima etapa.',
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  CallsTable(
                    records: filtered,
                    onView: (record) {
                      _showMockAction('Visualizando chamado ${record.id}.');
                    },
                  ),
                ],
              );
            },
            loading: () => const _LoadingPanel(),
            error: (error, _) => _ErrorPanel(
              message: 'Falha ao carregar chamados: $error',
            ),
          ),
        ],
      ),
    );
  }

  List<CallTicket> _applyFilters(List<CallTicket> records) {
    final query = _search.trim().toLowerCase();

    return records.where((record) {
      if (query.isNotEmpty) {
        final matchesQuery = record.id.toLowerCase().contains(query) ||
            record.client.toLowerCase().contains(query) ||
            record.vehicle.toLowerCase().contains(query) ||
            record.subject.toLowerCase().contains(query);
        if (!matchesQuery) return false;
      }

      if (_status != 'Todos' && record.status.label != _status) return false;
      if (_priority != 'Todas' && record.priority.label != _priority) {
        return false;
      }
      if (_category != 'Todas' && record.category.label != _category) {
        return false;
      }
      if (_attendant != 'Todos' && record.attendant != _attendant) {
        return false;
      }
      if (_client != 'Todos' && record.client != _client) return false;

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
