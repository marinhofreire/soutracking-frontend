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
  static const String _callsImplementationMessage =
      'Modulo em implantacao: chamados seguem em demonstracao com repositorio mock. Nenhum dado ou acao desta tela representa atendimento produtivo.';
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
      breadcrumbs: const ['Operação', 'Chamados'],
      selectedMenu: 'calls',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ImplementationBanner(
            message: _callsImplementationMessage,
          ),
          const SizedBox(height: 12),
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
                        'Mais filtros ainda nao consultam backend real.',
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _mockDataNotice(
                    filteredCount: filtered.length,
                    totalCount: records.length,
                  ),
                  const SizedBox(height: 12),
                  CallsTable(
                    records: filtered,
                    onView: (record) {
                      _showMockAction(
                        'Abertura detalhada do chamado ${record.id} permanece bloqueada em modo demonstracao.',
                      );
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
      SnackBar(
        content: Text(
          'Chamados dependem de API propria. Operacao nao executada: $message',
        ),
      ),
    );
  }

  Widget _mockDataNotice({
    required int filteredCount,
    required int totalCount,
  }) {
    return AdminGlassPanel(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Text(
              'DADOS MOCK',
              style: TextStyle(
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Listagem demonstrativa: $filteredCount de $totalCount chamados visiveis, sem criacao, edicao ou despacho real.',
              style: const TextStyle(
                color: Color(0xFF5D728E),
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImplementationBanner extends StatelessWidget {
  const _ImplementationBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AdminGlassPanel(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Text(
          message,
          style: const TextStyle(
            color: Color(0xFF92400E),
            fontWeight: FontWeight.w700,
            fontSize: 12.2,
          ),
        ),
      ),
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
