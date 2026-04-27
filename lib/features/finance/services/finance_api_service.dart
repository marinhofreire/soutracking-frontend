import '../models/finance_models.dart';

class FinanceApiService {
  const FinanceApiService({required this.baseUrl});

  final String baseUrl;

  Future<List<Map<String, dynamic>>> fetchAsaasCustomers() async {
    // Estrutura pronta para integrar clientes Asaas futuramente.
    return <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> fetchAsaasCharges({
    String? status,
    DateTime? from,
    DateTime? to,
  }) async {
    // Estrutura pronta para integrar cobrancas Asaas futuramente.
    return <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> fetchPaymentLinks() async {
    // Estrutura pronta para links de pagamento.
    return <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> fetchRecurrences() async {
    // Estrutura pronta para recorrencias e assinaturas.
    return <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> fetchPaymentWebhooks() async {
    // Estrutura pronta para webhooks de pagamento (processamento futuro).
    return <Map<String, dynamic>>[];
  }

  Future<FinanceKpiSummary> fetchKpiSummary() async {
    throw UnimplementedError('Integracao Asaas ainda nao habilitada.');
  }
}
