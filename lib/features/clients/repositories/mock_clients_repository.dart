import '../models/client_models.dart';
import 'clients_repository.dart';

class MockClientsRepository implements ClientsRepository {
  const MockClientsRepository();

  @override
  Future<ClientKpiSummary> getKpiSummary() async {
    return const ClientKpiSummary(
      total: 4,
      active: 2,
      overdue: 1,
      inactive: 1,
    );
  }

  @override
  Future<List<ClientRecord>> getClients() async {
    return const <ClientRecord>[
      ClientRecord(
        traccarUserId: 0,
        name: 'Transportes Alfa',
        email: 'contato@alfa.com',
        phone: '(11) 98888-0001',
        document: '12.345.678/0001-90',
        clientType: ClientType.pj,
        address: 'Av. das Nações, 100',
        city: 'São Paulo',
        state: 'SP',
        zip: '01000-000',
        plan: ClientPlan.pro,
        asaasCustomerId: '',
        status: ClientStatus.active,
        deviceCount: 18,
        operatorCount: 3,
        disabled: false,
      ),
      ClientRecord(
        traccarUserId: 0,
        name: 'Varejo Sul',
        email: 'financeiro@varejosul.com',
        phone: '(51) 99999-0002',
        document: '98.765.432/0001-10',
        clientType: ClientType.pj,
        address: 'Rua do Comércio, 55',
        city: 'Porto Alegre',
        state: 'RS',
        zip: '90000-000',
        plan: ClientPlan.basic,
        asaasCustomerId: '',
        status: ClientStatus.overdue,
        deviceCount: 6,
        operatorCount: 1,
        disabled: false,
      ),
      ClientRecord(
        traccarUserId: 0,
        name: 'Construtora Gama',
        email: 'operacao@gama.com',
        phone: '(21) 97777-0003',
        document: '11.222.333/0001-44',
        clientType: ClientType.pj,
        address: 'Est. do Contorno, 200',
        city: 'Rio de Janeiro',
        state: 'RJ',
        zip: '20000-000',
        plan: ClientPlan.enterprise,
        asaasCustomerId: 'cus_demo_001',
        status: ClientStatus.active,
        deviceCount: 12,
        operatorCount: 2,
        disabled: false,
      ),
      ClientRecord(
        traccarUserId: 0,
        name: 'Grupo Omega',
        email: 'suporte@omega.com',
        phone: '',
        document: '55.444.333/0001-22',
        clientType: ClientType.pj,
        address: '',
        city: '',
        state: '',
        zip: '',
        plan: ClientPlan.basic,
        asaasCustomerId: '',
        status: ClientStatus.inactive,
        deviceCount: 4,
        operatorCount: 0,
        disabled: true,
      ),
    ];
  }
}
