import '../../../data/models.dart';
import '../../../data/traccar_client.dart';
import '../../../state/session_state.dart';
import '../models/client_models.dart';
import 'clients_repository.dart';

class TraccarClientsRepository implements ClientsRepository {
  const TraccarClientsRepository({
    required this.client,
    required this.session,
  });

  final TraccarClient client;
  final SessionState session;

  @override
  Future<List<ClientRecord>> getClients() async {
    final raw = await client.getList(
      path: '/users',
      cookie: session.cookie,
      authHeader: session.authHeader,
    );
    final users = raw
        .map((u) => TraccarUser.fromJson(u))
        .where(_isClient)
        .toList();
    return users.map((u) => ClientRecord.fromTraccarUser(u)).toList();
  }

  @override
  Future<ClientKpiSummary> getKpiSummary() async {
    final clients = await getClients();
    return ClientKpiSummary(
      total:    clients.length,
      active:   clients.where((c) => c.status == ClientStatus.active).length,
      overdue:  clients.where((c) => c.status == ClientStatus.overdue).length,
      inactive: clients.where((c) => c.status == ClientStatus.inactive).length,
    );
  }

  static bool _isClient(TraccarUser user) {
    final role = user.soutrackingRole;
    return role == 'client' || role == 'master';
  }
}
