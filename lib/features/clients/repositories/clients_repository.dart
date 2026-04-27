import '../models/client_models.dart';

abstract class ClientsRepository {
  Future<ClientKpiSummary> getKpiSummary();

  Future<List<ClientRecord>> getClients();
}
