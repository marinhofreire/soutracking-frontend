import '../models/client_models.dart';
import 'clients_repository.dart';

class MockClientsRepository implements ClientsRepository {
  const MockClientsRepository();

  @override
  Future<ClientKpiSummary> getKpiSummary() async {
    return const ClientKpiSummary(
      total: 24,
      active: 19,
      overdue: 3,
      vip: 5,
    );
  }

  @override
  Future<List<ClientRecord>> getClients() async {
    final now = DateTime.now();
    return <ClientRecord>[
      ClientRecord(
        id: 'CLI-001',
        name: 'Transportes Alfa',
        contact: 'contato@alfa.com',
        vehicleCount: 18,
        lastService: now.subtract(const Duration(days: 2)),
        balance: 18450.35,
        status: ClientStatus.active,
        segment: 'Logistica',
      ),
      ClientRecord(
        id: 'CLI-002',
        name: 'Varejo Sul',
        contact: 'financeiro@varejosul.com',
        vehicleCount: 6,
        lastService: now.subtract(const Duration(days: 7)),
        balance: 9320.00,
        status: ClientStatus.late,
        segment: 'Varejo',
      ),
      ClientRecord(
        id: 'CLI-003',
        name: 'Construtora Gama',
        contact: 'operacao@gama.com',
        vehicleCount: 12,
        lastService: now.subtract(const Duration(days: 1)),
        balance: 25110.90,
        status: ClientStatus.active,
        segment: 'Construcao',
      ),
      ClientRecord(
        id: 'CLI-004',
        name: 'Grupo Omega',
        contact: 'suporte@omega.com',
        vehicleCount: 4,
        lastService: now.subtract(const Duration(days: 19)),
        balance: 0,
        status: ClientStatus.inactive,
        segment: 'Servicos',
      ),
    ];
  }
}
