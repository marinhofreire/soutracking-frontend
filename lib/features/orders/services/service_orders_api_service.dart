import '../models/service_order_models.dart';

class ServiceOrdersApiService {
  const ServiceOrdersApiService({required this.baseUrl});

  final String baseUrl;

  Future<List<Map<String, dynamic>>> fetchFieldOrders({
    String? technicianId,
    String? status,
    DateTime? from,
    DateTime? to,
  }) async {
    // Estrutura pronta para integrar Traccar/SouFind/SouCall futuramente.
    return <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> fetchOrderHistory({
    required String orderId,
  }) async {
    // Estrutura preparada para histórico de atendimento e execucao.
    return <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> fetchTechnicians() async {
    // Estrutura preparada para tecnicos/prestadores e filas operacionais.
    return <Map<String, dynamic>>[];
  }

  Future<ServiceOrderKpiSummary> fetchKpiSummary() async {
    throw UnimplementedError(
        'Integracao API de ordens de servico ainda nao habilitada.');
  }
}
