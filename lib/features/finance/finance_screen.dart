import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/asaas_config.dart';
import '../admin/admin_reference_ui.dart';
import 'models/finance_models.dart';
import 'repositories/asaas_finance_repository.dart';
import 'repositories/finance_repository.dart';
import 'repositories/mock_finance_repository.dart';
import 'services/finance_api_service.dart';
import 'widgets/finance_filters_bar.dart';
import 'widgets/finance_kpi_row.dart';
import 'widgets/finance_summary_cards.dart';
import 'widgets/finance_table.dart';

final financeApiServiceProvider = Provider<FinanceApiService?>((ref) {
  final config = ref.watch(asaasConfigProvider);
  if (!config.isConfigured) return null;
  return FinanceApiService(baseUrl: config.baseUrl, apiKey: config.apiKey);
});

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  final api = ref.watch(financeApiServiceProvider);
  if (api != null) return AsaasFinanceRepository(api: api);
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
  static const String _financeImplementationMessage =
      'Modulo em implantacao: indicadores, cobrancas e exportacoes seguem em demonstracao com repositorio mock e nao representam financeiro produtivo.';
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
          const _ImplementationBanner(
            message: _financeImplementationMessage,
          ),
          const SizedBox(height: 12),
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
                        'Mais filtros ainda nao consultam backend financeiro real.'),
                    onNewCharge: () => _showMockAction(
                        'Criacao de cobranca permanece bloqueada em modo demonstrativo.'),
                    onPaymentLink: () => _showMockAction(
                        'Link de pagamento permanece bloqueado em modo demonstrativo.'),
                    onRecurrence: () => _showMockAction(
                        'Recorrencia permanece bloqueada em modo demonstrativo.'),
                    onExport: () => _showMockAction(
                        'Exportacao financeira permanece bloqueada sem backend dedicado.'),
                  ),
                  const SizedBox(height: 12),
                  _mockDataNotice(
                    filteredCount: filtered.length,
                    totalCount: records.length,
                  ),
                  const SizedBox(height: 12),
                  FinanceTable(
                    records: filtered,
                    onView: (record) {
                      _showMockAction(
                          'Visualizacao detalhada da cobranca ${record.id} permanece bloqueada em modo demonstrativo.');
                    },
                    onMarkPaid: (record) {
                      _showMockAction(
                          'Baixa financeira da cobranca ${record.id} nao executa operacao real.');
                    },
                    onCancel: (record) {
                      _showMockAction(
                          'Cancelamento da cobranca ${record.id} nao executa operacao real.');
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
      SnackBar(
        content: Text(
          'Financeiro depende de backend dedicado. Operacao nao executada: $message',
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
              'VALORES MOCK',
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
              'Resumo demonstrativo: $filteredCount de $totalCount cobrancas visiveis com dados ficticios, sem baixa, emissao ou exportacao real.',
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
