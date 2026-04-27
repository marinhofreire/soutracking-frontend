import '../models/inventory_models.dart';

abstract class InventoryRepository {
  Future<InventoryKpiSummary> getKpiSummary();

  Future<List<InventorySummaryCard>> getSummaryCards();

  Future<List<InventoryItemRecord>> getItems();
}
