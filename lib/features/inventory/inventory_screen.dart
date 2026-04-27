import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_constants.dart';
import '../admin/admin_reference_ui.dart';
import 'models/inventory_models.dart';
import 'repositories/inventory_repository.dart';
import 'repositories/mock_inventory_repository.dart';
import 'services/inventory_api_service.dart';
import 'widgets/inventory_filters_bar.dart';
import 'widgets/inventory_kpi_row.dart';
import 'widgets/inventory_summary_cards.dart';
import 'widgets/inventory_table.dart';

final inventoryApiServiceProvider = Provider<InventoryApiService>((ref) {
  return InventoryApiService(baseUrl: kSouAssistApiBaseUrl);
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  // Mantemos mock nesta etapa; swap para API real fica centralizado aqui.
  ref.watch(inventoryApiServiceProvider);
  return const MockInventoryRepository();
});

final inventoryKpiProvider = FutureProvider<InventoryKpiSummary>((ref) async {
  final repository = ref.watch(inventoryRepositoryProvider);
  return repository.getKpiSummary();
});

final inventorySummaryCardsProvider =
    FutureProvider<List<InventorySummaryCard>>((ref) async {
  final repository = ref.watch(inventoryRepositoryProvider);
  return repository.getSummaryCards();
});

final inventoryItemsProvider =
    FutureProvider<List<InventoryItemRecord>>((ref) async {
  final repository = ref.watch(inventoryRepositoryProvider);
  return repository.getItems();
});

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchController = TextEditingController();

  String _search = '';
  String _category = 'Todos';
  String _status = 'Todos';
  String _location = 'Todos';
  String _supplier = 'Todos';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kpiAsync = ref.watch(inventoryKpiProvider);
    final summaryAsync = ref.watch(inventorySummaryCardsProvider);
    final itemsAsync = ref.watch(inventoryItemsProvider);

    return AdminReferenceScaffold(
      title: 'Estoque',
      breadcrumbs: const ['Operacao', 'Estoque'],
      selectedMenu: 'inventory',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kpiAsync.when(
            data: (summary) => InventoryKpiRow(summary: summary),
            loading: () => const _LoadingPanel(),
            error: (error, _) => _ErrorPanel(
              message: 'Falha ao carregar indicadores: $error',
            ),
          ),
          const SizedBox(height: 12),
          summaryAsync.when(
            data: (cards) => InventorySummaryCards(cards: cards),
            loading: () => const _LoadingPanel(),
            error: (error, _) => _ErrorPanel(
              message: 'Falha ao carregar resumo de estoque: $error',
            ),
          ),
          const SizedBox(height: 12),
          itemsAsync.when(
            data: (records) {
              final categoryOptions = <String>[
                'Todos',
                ...{for (final item in records) item.category.label},
              ];
              final statusOptions = <String>[
                'Todos',
                ...{for (final item in records) item.status.label},
              ];
              final locationOptions = <String>[
                'Todos',
                ...{for (final item in records) item.location},
              ];
              final supplierOptions = <String>[
                'Todos',
                ...{for (final item in records) item.supplier},
              ];

              final filtered = _applyFilters(records);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InventoryFiltersBar(
                    searchController: _searchController,
                    category: _category,
                    status: _status,
                    location: _location,
                    supplier: _supplier,
                    categoryOptions: categoryOptions,
                    statusOptions: statusOptions,
                    locationOptions: locationOptions,
                    supplierOptions: supplierOptions,
                    onSearchChanged: (value) => setState(() => _search = value),
                    onCategoryChanged: (value) =>
                        setState(() => _category = value),
                    onStatusChanged: (value) => setState(() => _status = value),
                    onLocationChanged: (value) =>
                        setState(() => _location = value),
                    onSupplierChanged: (value) =>
                        setState(() => _supplier = value),
                    onMoreFilters: () => _showMockAction(
                      'Mais filtros sera habilitado na proxima etapa.',
                    ),
                    onEntry: () => _showMockAction(
                        'Entrada de itens simulada com sucesso.'),
                    onExit: () =>
                        _showMockAction('Saida de itens simulada com sucesso.'),
                    onTransfer: () =>
                        _showMockAction('Transferencia simulada com sucesso.'),
                    onReserve: () =>
                        _showMockAction('Reserva simulada com sucesso.'),
                  ),
                  const SizedBox(height: 12),
                  InventoryTable(
                    records: filtered,
                    onView: (record) {
                      _showMockAction('Visualizando item ${record.id}.');
                    },
                    onEdit: (record) {
                      _showMockAction('Editando item (mock): ${record.id}.');
                    },
                  ),
                ],
              );
            },
            loading: () => const _LoadingPanel(),
            error: (error, _) => _ErrorPanel(
              message: 'Falha ao carregar estoque: $error',
            ),
          ),
        ],
      ),
    );
  }

  List<InventoryItemRecord> _applyFilters(List<InventoryItemRecord> records) {
    final query = _search.trim().toLowerCase();

    return records.where((record) {
      if (query.isNotEmpty) {
        final matchesQuery = record.id.toLowerCase().contains(query) ||
            record.item.toLowerCase().contains(query) ||
            record.supplier.toLowerCase().contains(query);
        if (!matchesQuery) return false;
      }

      if (_category != 'Todos' && record.category.label != _category) {
        return false;
      }
      if (_status != 'Todos' && record.status.label != _status) return false;
      if (_location != 'Todos' && record.location != _location) return false;
      if (_supplier != 'Todos' && record.supplier != _supplier) return false;

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
