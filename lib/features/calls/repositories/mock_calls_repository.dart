import '../models/call_models.dart';
import 'calls_repository.dart';

class MockCallsRepository implements CallsRepository {
  const MockCallsRepository();

  @override
  Future<CallKpiSummary> getKpiSummary() async {
    return const CallKpiSummary(
      open: 26,
      inProgress: 11,
      slaCritical: 4,
      closed: 39,
    );
  }

  @override
  Future<List<CallTicket>> getTickets() async {
    final now = DateTime.now();
    return [
      CallTicket(
        id: 'CH-1042',
        client: 'Transportes Alfa',
        vehicle: 'ABC1D23',
        category: CallCategory.connectivity,
        priority: CallPriority.high,
        attendant: 'Marina Costa',
        sla: '00:32',
        status: CallStatus.inProgress,
        openedAt: now.subtract(const Duration(minutes: 28)),
        subject: 'Equipamento sem telemetria',
      ),
      CallTicket(
        id: 'CH-1041',
        client: 'Varejo Sul',
        vehicle: 'QWE4R56',
        category: CallCategory.maintenance,
        priority: CallPriority.medium,
        attendant: 'Paulo Mendes',
        sla: '01:45',
        status: CallStatus.waitingPart,
        openedAt: now.subtract(const Duration(hours: 2, minutes: 14)),
        subject: 'Troca de chicote',
      ),
      CallTicket(
        id: 'CH-1040',
        client: 'Construtora Gama',
        vehicle: 'KLM2N34',
        category: CallCategory.installation,
        priority: CallPriority.critical,
        attendant: 'Ana Oliveira',
        sla: '00:09',
        status: CallStatus.slaCritical,
        openedAt: now.subtract(const Duration(hours: 3, minutes: 4)),
        subject: 'Instalacao pendente no patio',
      ),
      CallTicket(
        id: 'CH-1039',
        client: 'Grupo Omega',
        vehicle: 'TYU8I90',
        category: CallCategory.support,
        priority: CallPriority.low,
        attendant: 'Lucas Ribeiro',
        sla: '03:20',
        status: CallStatus.open,
        openedAt: now.subtract(const Duration(hours: 5, minutes: 33)),
        subject: 'Duvida de uso do painel',
      ),
      CallTicket(
        id: 'CH-1038',
        client: 'Transportes Alfa',
        vehicle: 'ZXC7V89',
        category: CallCategory.diagnostics,
        priority: CallPriority.high,
        attendant: 'Marina Costa',
        sla: '00:55',
        status: CallStatus.inProgress,
        openedAt: now.subtract(const Duration(hours: 1, minutes: 46)),
        subject: 'Falha intermitente de ignicao',
      ),
      CallTicket(
        id: 'CH-1037',
        client: 'Varejo Sul',
        vehicle: '-',
        category: CallCategory.report,
        priority: CallPriority.medium,
        attendant: 'Fernanda Lima',
        sla: 'Concluido',
        status: CallStatus.closed,
        openedAt: now.subtract(const Duration(days: 1, hours: 1)),
        subject: 'Relatorio semanal de suporte',
      ),
      CallTicket(
        id: 'CH-1036',
        client: 'Construtora Gama',
        vehicle: 'HJK5L67',
        category: CallCategory.connectivity,
        priority: CallPriority.high,
        attendant: 'Ana Oliveira',
        sla: '00:21',
        status: CallStatus.waitingCustomer,
        openedAt: now.subtract(const Duration(hours: 6, minutes: 12)),
        subject: 'Sem sinal em area de sombra',
      ),
    ];
  }
}
