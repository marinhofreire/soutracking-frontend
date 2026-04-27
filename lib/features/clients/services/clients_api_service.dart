import '../models/client_models.dart';

class ClientsApiService {
  const ClientsApiService({required this.baseUrl});

  final String baseUrl;

  Future<ClientKpiSummary> fetchKpiSummary() async {
    throw UnimplementedError('Integração API de clientes ainda não habilitada.');
  }

  Future<List<ClientRecord>> fetchClients() async {
    throw UnimplementedError('Integração API de clientes ainda não habilitada.');
  }
}
