import '../models/finance_models.dart';
import 'finance_repository.dart';

class MockFinanceRepository implements FinanceRepository {
  const MockFinanceRepository();

  @override
  Future<FinanceKpiSummary> getKpiSummary() async {
    return const FinanceKpiSummary(
      monthRevenue: 182450.35,
      received: 143220.90,
      openAmount: 27610.45,
      delinquency: 11619.00,
    );
  }

  @override
  Future<List<FinanceSummaryCard>> getSummaryCards() async {
    return const [
      FinanceSummaryCard(
        title: 'A vencer hoje',
        value: 'R\$ 9.430,00',
        subtitle: '12 cobrancas no dia',
      ),
      FinanceSummaryCard(
        title: 'Links ativos',
        value: '34',
        subtitle: '6 convertendo agora',
      ),
      FinanceSummaryCard(
        title: 'Recorrencias',
        value: '89',
        subtitle: '8 com tentativa pendente',
      ),
      FinanceSummaryCard(
        title: 'Ticket medio',
        value: 'R\$ 487,20',
        subtitle: 'Mes atual',
      ),
    ];
  }

  @override
  Future<List<FinanceChargeRecord>> getCharges() async {
    final now = DateTime.now();
    return [
      FinanceChargeRecord(
        id: 'COB-8901',
        client: 'Transportes Alfa',
        description: 'Mensalidade rastreamento - Abril',
        amount: 18450.35,
        dueDate: now.add(const Duration(days: 1)),
        paymentMethod: PaymentMethod.boleto,
        status: FinanceStatus.open,
        createdAt: now.subtract(const Duration(days: 4, hours: 2)),
      ),
      FinanceChargeRecord(
        id: 'COB-8900',
        client: 'Varejo Sul',
        description: 'Pacote monitoramento premium',
        amount: 9320.00,
        dueDate: now.subtract(const Duration(days: 2)),
        paymentMethod: PaymentMethod.pix,
        status: FinanceStatus.overdue,
        createdAt: now.subtract(const Duration(days: 8, hours: 6)),
      ),
      FinanceChargeRecord(
        id: 'COB-8899',
        client: 'Construtora Gama',
        description: 'Mensalidade rastreamento - Abril',
        amount: 25110.90,
        dueDate: now.subtract(const Duration(days: 1)),
        paymentMethod: PaymentMethod.recurrence,
        status: FinanceStatus.paid,
        createdAt: now.subtract(const Duration(days: 10)),
      ),
      FinanceChargeRecord(
        id: 'COB-8898',
        client: 'Grupo Omega',
        description: 'Link de pagamento servico emergencial',
        amount: 3200.00,
        dueDate: now.add(const Duration(days: 3)),
        paymentMethod: PaymentMethod.paymentLink,
        status: FinanceStatus.waitingPayment,
        createdAt: now.subtract(const Duration(hours: 11)),
      ),
      FinanceChargeRecord(
        id: 'COB-8897',
        client: 'Transportes Alfa',
        description: 'Ajuste de franquia de dados',
        amount: 980.00,
        dueDate: now.subtract(const Duration(days: 6)),
        paymentMethod: PaymentMethod.creditCard,
        status: FinanceStatus.refunded,
        createdAt: now.subtract(const Duration(days: 16, hours: 5)),
      ),
      FinanceChargeRecord(
        id: 'COB-8896',
        client: 'Varejo Sul',
        description: 'Multa por quebra de fidelidade',
        amount: 1450.00,
        dueDate: now.subtract(const Duration(days: 4)),
        paymentMethod: PaymentMethod.boleto,
        status: FinanceStatus.canceled,
        createdAt: now.subtract(const Duration(days: 18, hours: 8)),
      ),
      FinanceChargeRecord(
        id: 'COB-8895',
        client: 'Construtora Gama',
        description: 'Renovacao de licencas',
        amount: 6750.20,
        dueDate: now.add(const Duration(days: 7)),
        paymentMethod: PaymentMethod.pix,
        status: FinanceStatus.open,
        createdAt: now.subtract(const Duration(days: 1, hours: 4)),
      ),
    ];
  }
}
