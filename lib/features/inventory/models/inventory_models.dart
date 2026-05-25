enum InventoryCategory {
  tracker,
  chip,
  sensor,
  relay,
  cable,
  accessory,
  installationKit,
}

enum InventoryStatus {
  available,
  lowStock,
  inUse,
  reserved,
  defective,
  discarded,
}

class InventoryKpiSummary {
  const InventoryKpiSummary({
    required this.itemsInStock,
    required this.lowStock,
    required this.inUse,
    required this.monthMovements,
  });

  final int itemsInStock;
  final int lowStock;
  final int inUse;
  final int monthMovements;
}

class InventorySummaryCard {
  const InventorySummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;
}

class InventoryItemRecord {
  const InventoryItemRecord({
    required this.id,
    required this.item,
    required this.category,
    required this.quantity,
    required this.status,
    required this.location,
    required this.supplier,
    required this.lastMovementAt,
    this.linkedOrderId,
    this.linkedVehicle,
    this.linkedTechnician,
    this.chipCode,
  });

  final String id;
  final String item;
  final InventoryCategory category;
  final int quantity;
  final InventoryStatus status;
  final String location;
  final String supplier;
  final DateTime lastMovementAt;

  // Campos opcionais para vinculos futuros com OS, veiculo, técnico e chip.
  final String? linkedOrderId;
  final String? linkedVehicle;
  final String? linkedTechnician;
  final String? chipCode;
}

extension InventoryCategoryView on InventoryCategory {
  String get label {
    switch (this) {
      case InventoryCategory.tracker:
        return 'Rastreador';
      case InventoryCategory.chip:
        return 'Chip';
      case InventoryCategory.sensor:
        return 'Sensor';
      case InventoryCategory.relay:
        return 'Rele';
      case InventoryCategory.cable:
        return 'Cabo';
      case InventoryCategory.accessory:
        return 'Acessorio';
      case InventoryCategory.installationKit:
        return 'Kit instalacao';
    }
  }
}

extension InventoryStatusView on InventoryStatus {
  String get label {
    switch (this) {
      case InventoryStatus.available:
        return 'Disponivel';
      case InventoryStatus.lowStock:
        return 'Baixo estoque';
      case InventoryStatus.inUse:
        return 'Em uso';
      case InventoryStatus.reserved:
        return 'Reservado';
      case InventoryStatus.defective:
        return 'Defeituoso';
      case InventoryStatus.discarded:
        return 'Descartado';
    }
  }
}
