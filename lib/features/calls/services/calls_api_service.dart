import '../models/call_models.dart';

class CallsApiService {
  const CallsApiService({required this.baseUrl});

  final String baseUrl;

  Future<List<Map<String, dynamic>>> fetchTickets({
    String? queue,
    String? attendant,
    String? status,
  }) async {
    // Estrutura pronta para integrar SouCall/ZPRO futuramente.
    return <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> fetchTicketMessages({
    required String ticketId,
  }) async {
    // Estrutura preparada para histórico de mensagens do atendimento.
    return <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> fetchQueues() async {
    // Estrutura preparada para filas/responsaveis de atendimento.
    return <Map<String, dynamic>>[];
  }

  Future<CallKpiSummary> fetchKpiSummary() async {
    throw UnimplementedError(
        'Integracao API de chamados ainda nao habilitada.');
  }
}
