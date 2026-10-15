import 'package:flutter/material.dart';
import '../../ui/module_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_constants.dart';
import 'models/inventory_models.dart';
import 'repositories/inventory_repository.dart';
import 'repositories/mock_inventory_repository.dart';
import 'services/inventory_api_service.dart';

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

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The repository is a fixture-only adapter. Keep it out of the client UI
    // until the data team supplies a production source; never present demo stock.
    return const ModuleScaffold(
        title: 'Estoque',
        subtitle: 'Equipamentos, chips e materiais da operação.',
        navigation:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ModuleSectionLabel('Categorias'),
          ModuleListItem(
              title: 'Todos os itens',
              icon: Icons.inventory_2_outlined,
              selected: true)
        ]),
        content: ModuleEmpty('Estoque indisponível',
            'Os itens aparecerão quando o serviço estiver disponível.',
            icon: Icons.inventory_2_outlined),
        detail: ModuleCard(
            title: 'Resumo do estoque',
            child: ModuleEmpty('Sem dados disponíveis',
                'Nenhuma movimentação será exibida sem registros reais.')),
        actions: [
          OutlinedButton(onPressed: null, child: Text('Saída')),
          OutlinedButton(onPressed: null, child: Text('Transferência')),
          OutlinedButton(onPressed: null, child: Text('Reserva')),
          FilledButton(onPressed: null, child: Text('Entrada'))
        ]);
  }
}
