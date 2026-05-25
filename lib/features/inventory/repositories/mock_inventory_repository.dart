import '../models/inventory_models.dart';
import 'inventory_repository.dart';

class MockInventoryRepository implements InventoryRepository {
  const MockInventoryRepository();

  @override
  Future<InventoryKpiSummary> getKpiSummary() async {
    return const InventoryKpiSummary(
      itemsInStock: 1248,
      lowStock: 38,
      inUse: 412,
      monthMovements: 267,
    );
  }

  @override
  Future<List<InventorySummaryCard>> getSummaryCards() async {
    return const [
      InventorySummaryCard(
        title: 'Entradas da semana',
        value: '96',
        subtitle: '12 rastreadores e 41 chips hoje',
      ),
      InventorySummaryCard(
        title: 'Saidas para instalacao',
        value: '74',
        subtitle: '28 vinculadas a ordens de servico',
      ),
      InventorySummaryCard(
        title: 'Transferencias internas',
        value: '23',
        subtitle: 'Centro -> Base Norte e Base Sul',
      ),
      InventorySummaryCard(
        title: 'Itens reservados',
        value: '51',
        subtitle: '16 aguardando técnico responsavel',
      ),
    ];
  }

  @override
  Future<List<InventoryItemRecord>> getItems() async {
    final now = DateTime.now();

    return [
      InventoryItemRecord(
        id: 'EST-1201',
        item: 'Rastreador ST-4G Pro',
        category: InventoryCategory.tracker,
        quantity: 186,
        status: InventoryStatus.available,
        location: 'CD Sao Paulo',
        supplier: 'Telco Devices',
        lastMovementAt: now.subtract(const Duration(days: 1, hours: 2)),
        linkedOrderId: 'OS-2026-1041',
      ),
      InventoryItemRecord(
        id: 'EST-1200',
        item: 'Chip M2M 10GB',
        category: InventoryCategory.chip,
        quantity: 24,
        status: InventoryStatus.lowStock,
        location: 'CD Sao Paulo',
        supplier: 'Operadora BR',
        lastMovementAt: now.subtract(const Duration(hours: 6)),
        linkedVehicle: 'ABC1D23',
        chipCode: 'M2M-000341',
      ),
      InventoryItemRecord(
        id: 'EST-1199',
        item: 'Sensor de temperatura CAN',
        category: InventoryCategory.sensor,
        quantity: 47,
        status: InventoryStatus.inUse,
        location: 'Base Campinas',
        supplier: 'Sense Track',
        lastMovementAt: now.subtract(const Duration(days: 3, hours: 5)),
        linkedVehicle: 'QWE4R56',
      ),
      InventoryItemRecord(
        id: 'EST-1198',
        item: 'Rele bloqueio ignicao 12V',
        category: InventoryCategory.relay,
        quantity: 19,
        status: InventoryStatus.reserved,
        location: 'Base Guarulhos',
        supplier: 'Auto Relay BR',
        lastMovementAt: now.subtract(const Duration(days: 2, hours: 4)),
        linkedTechnician: 'Marcio Lima',
      ),
      InventoryItemRecord(
        id: 'EST-1197',
        item: 'Cabo alimentacao 2m',
        category: InventoryCategory.cable,
        quantity: 0,
        status: InventoryStatus.defective,
        location: 'Quarentena',
        supplier: 'Cabos Sul',
        lastMovementAt: now.subtract(const Duration(days: 12)),
      ),
      InventoryItemRecord(
        id: 'EST-1196',
        item: 'Suporte fixacao universal',
        category: InventoryCategory.accessory,
        quantity: 7,
        status: InventoryStatus.lowStock,
        location: 'Base Osasco',
        supplier: 'FixParts',
        lastMovementAt: now.subtract(const Duration(days: 9, hours: 3)),
      ),
      InventoryItemRecord(
        id: 'EST-1195',
        item: 'Kit instalacao premium',
        category: InventoryCategory.installationKit,
        quantity: 0,
        status: InventoryStatus.discarded,
        location: 'Descarte técnico',
        supplier: 'Kit Master',
        lastMovementAt: now.subtract(const Duration(days: 20)),
      ),
      InventoryItemRecord(
        id: 'EST-1194',
        item: 'Rastreador ST-Lite 2G',
        category: InventoryCategory.tracker,
        quantity: 129,
        status: InventoryStatus.available,
        location: 'Base Jundiai',
        supplier: 'Telco Devices',
        lastMovementAt: now.subtract(const Duration(days: 4, hours: 7)),
        linkedTechnician: 'Ana Oliveira',
      ),
    ];
  }
}
