import 'package:flutter/material.dart';
import '../../ui/module_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/asaas_config.dart';
import 'models/finance_models.dart';
import 'repositories/asaas_finance_repository.dart';
import 'repositories/finance_repository.dart';
import 'repositories/mock_finance_repository.dart';
import 'services/finance_api_service.dart';

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
  final _searchController = TextEditingController();

  String? _selectedId;
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
    final configured = ref.watch(financeApiServiceProvider) != null;
    // Presentation gate: the production view never renders fallback fixtures.
    final list = configured
        ? ref.watch(financeChargesProvider)
        : const AsyncData<List<FinanceChargeRecord>>([]);
    final records = list.valueOrNull ?? <FinanceChargeRecord>[],
        filtered = _applyFilters(records);
    final selected = filtered.where((r) => r.id == _selectedId).firstOrNull;
    Widget filter(String label, String value, List<String> options,
            ValueChanged<String> change) =>
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
                key: ValueKey('$label-$value'),
                isExpanded: true,
                initialValue: options.contains(value) ? value : options.first,
                decoration: InputDecoration(labelText: label),
                items: options
                    .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(v, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => change(v));
                }));
    return ModuleScaffold(
        title: 'Cobranças',
        subtitle: 'Acompanhe os recebimentos e vencimentos.',
        navigation:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const ModuleSectionLabel('Filtros'),
          filter(
              'Status',
              _status,
              {'Todos', ...records.map((r) => r.status.label)}.toList(),
              (v) => _status = v),
          filter('Período', _period, ['Hoje', '7 dias', '30 dias', '90 dias'],
              (v) => _period = v),
          filter(
              'Forma de pagamento',
              _paymentMethod,
              {'Todos', ...records.map((r) => r.paymentMethod.label)}.toList(),
              (v) => _paymentMethod = v),
          filter(
              'Cliente',
              _client,
              {'Todos', ...records.map((r) => r.client)}.toList(),
              (v) => _client = v)
        ]),
        content:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                  hintText: 'Buscar cobrança ou cliente',
                  prefixIcon: Icon(Icons.search))),
          const SizedBox(height: 14),
          list.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  const ModuleEmpty('Não foi possível carregar as cobranças',
                      'Tente novamente em instantes.'),
              data: (_) => filtered.isEmpty
                  ? ModuleEmpty(
                      configured
                          ? 'Nenhuma cobrança encontrada'
                          : 'Cobranças indisponíveis',
                      configured
                          ? 'Revise os filtros ou aguarde novos registros.'
                          : 'As cobranças aparecerão quando o serviço estiver disponível.',
                      icon: Icons.receipt_long_outlined)
                  : Column(children: [
                      for (final r in filtered)
                        ModuleListItem(
                            title: r.client,
                            subtitle:
                                '${r.description} · ${r.dueDate.day}/${r.dueDate.month}/${r.dueDate.year}',
                            icon: Icons.receipt_long_outlined,
                            selected: r.id == _selectedId,
                            onTap: () => setState(() => _selectedId = r.id),
                            trailing: ModuleStatusChip(r.status.label,
                                tone: r.status == FinanceStatus.paid
                                    ? ModuleTone.success
                                    : r.status == FinanceStatus.overdue
                                        ? ModuleTone.critical
                                        : ModuleTone.neutral))
                    ]))
        ]),
        detail: selected == null
            ? const ModuleEmpty('Selecione uma cobrança',
                'O valor, o vencimento e o status aparecem aqui.')
            : ModuleCard(
                title: 'Resumo da cobrança',
                child: Column(children: [
                  ModuleDetailRow('Cliente', selected.client),
                  ModuleDetailRow('Descrição', selected.description),
                  ModuleDetailRow('Valor',
                      'R\$ ${selected.amount.toStringAsFixed(2).replaceAll(".", ",")}'),
                  ModuleDetailRow('Vencimento',
                      '${selected.dueDate.day}/${selected.dueDate.month}/${selected.dueDate.year}'),
                  ModuleDetailRow('Pagamento', selected.paymentMethod.label),
                  ModuleDetailRow('Status', selected.status.label)
                ])),
        actions: const [
          OutlinedButton(onPressed: null, child: Text('Exportar')),
          OutlinedButton(onPressed: null, child: Text('Link de pagamento')),
          OutlinedButton(onPressed: null, child: Text('Recorrência')),
          FilledButton(onPressed: null, child: Text('Nova cobrança'))
        ]);
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
}
