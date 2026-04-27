import '../models/service_order_models.dart';

abstract class ServiceOrdersRepository {
  Future<ServiceOrderKpiSummary> getKpiSummary();

  Future<List<ServiceOrderRecord>> getOrders();
}
