import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_constants.dart';
import '../admin/admin_reference_ui.dart';
import 'models/finance_models.dart';
import 'repositories/finance_repository.dart';
import 'repositories/mock_finance_repository.dart';
import 'services/finance_api_service.dart';
import 'widgets/finance_filters_bar.dart';
import 'widgets/finance_kpi_row.dart';
import 'widgets/finance_summary_cards.dart';
import 'widgets/finance_table.dart';

final financeApiServiceProvider = Provider<FinanceApiService>((ref) {
  return FinanceApiService(baseUrl: kSouAssistApiBaseUrl);
});

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  // Mantemos mock nesta etapa; swap para API real fica centralizado aqui.
  ref.watch(financeApiServiceProvider);
  return const MockFinanceRepository();
});

final financeKpiProvider = FutureProvider<FinanceKpiSummary>((ref) async {
  final repository = ref.watch(financeRepositoryProvider);
  return repository.getKpiSummary();
});

final financeSummaryCardsProvider =
    FutureProvider<List<FinanceSummaryCard>>((ref) async {
  final repository = ref.watch(financeRepositoryProvider);
  return repository.getSummaryCards();
});

final financeChargesProvider =
    FutureProvider<List<FinanceChargeRecord>>((ref) async {
  final repository = ref.watch(financeRepositoryProvider);
  return repository.getCharges();
});

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  final _searchController = TextEditingController();

  String _search = '';
  String _status = 'Todos';
  String _period = '30 dias';
  String _paymentMethod = 'Todos';
  String _client = 'Todos';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kpiAsync = ref.watch(financeKpiProvider);
    final summaryAsync = ref.watch(financeSummaryCardsProvider);
    final chargesAsync = ref.watch(financeChargesProvider);

    return AdminReferenceScaffold(
      title: 'Financeiro',
      breadcrumbs: const ['Operação', 'Financeiro'],
      selectedMenu: 'finance',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kpiAsync.when(
            data: (summary) => FinanceKpiRow(summary: summary),
            loading: () => const _LoadingPanel(),
            error: (error, _) => _ErrorPanel(
              message: 'Falha ao carregar indicadores: $error',
            ),
          ),
          const SizedBox(height: 12),
          summaryAsync.when(
            data: (cards) => FinanceSummaryCards(cards: cards),
            loading: () => const _LoadingPanel(),
            error: (error, _) => _ErrorPanel(
              message: 'Falha ao carregar resumo financeiro: $error',
            ),
          ),
          const SizedBox(height: 12),
          chargesAsync.when(
            data: (records) {
              final statusOptions = <String>[
                'Todos',
                ...{for (final item in records) item.status.label},
              ];
              const periodOptions = ['Hoje', '7 dias', '30 dias', '90 dias'];
              final methodOptions = <String>[
                'Todos',
                ...{for (final item in records) item.paymentMethod.label},
              ];
              final clientOptions = <String>[
                'Todos',
                ...{for (final item in records) item.client},
              ];

              final filtered = _applyFilters(records);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FinanceFiltersBar(
                    searchController: _searchController,
                    status: _status,
                    period: _period,
                    paymentMethod: _paymentMethod,
                    client: _client,
                    statusOptions: statusOptions,
                    periodOptions: periodOptions,
                    paymentMethodOptions: methodOptions,
                    clientOptions: clientOptions,
                    onSearchChanged: (value) => setState(() => _search = value),
                    onStatusChanged: (value) => setState(() => _status = value),
                    onPeriodChanged: (value) => setState(() => _period = value),
                    onPaymentMethodChanged: (value) =>
                        setState(() => _paymentMethod = value),
                    onClientChanged: (value) => setState(() => _client = value),
                    onMoreFilters: () => _showMockAction(
                        'Mais filtros sera habilitado na proxima etapa.'),
                    onNewCharge: () =>
                        _showMockAction('Nova cobranca simulada com sucesso.'),
                    onPaymentLink: () => _showMockAction(
                        'Criacao de link de pagamento simulada.'),
                    onRecurrence: () =>
                        _showMockAction('Criacao de recorrencia simulada.'),
                    onExport: () => _showMockAction('Exportacao simulada.'),
                  ),
                  const SizedBox(height: 12),
                  FinanceTable(
                    records: filtered,
                    onView: (record) {
                      _showMockAction('Visualizando cobranca ${record.id}.');
                    },
                    onMarkPaid: (record) {
                      _showMockAction(
                          'Marcado como pago (mock): ${record.id}.');
                    },
                    onCancel: (record) {
                      _showMockAction('Cancelamento mock: ${record.id}.');
                    },
                  ),
                ],
              );
            },
            loading: () => const _LoadingPanel(),
            error: (error, _) => _ErrorPanel(
              message: 'Falha ao carregar cobrancas: $error',
            ),
          ),
        ],
      ),
    );
  }

  List<FinanceChargeRecord> _applyFilters(List<FinanceChargeRecord> records) {
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
            record.description.toLowerCase().contains(query);
        if (!matchesQuery) return false;
      }

      if (_status != 'Todos' && record.status.label != _status) return false;
      if (_paymentMethod != 'Todos' &&
          record.paymentMethod.label != _paymentMethod) {
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
