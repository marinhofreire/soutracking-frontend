import '../models/finance_models.dart';
import '../services/finance_api_service.dart';
import 'finance_repository.dart';

class AsaasFinanceRepository implements FinanceRepository {
  const AsaasFinanceRepository({required this.api});

  final FinanceApiService api;

  @override
  Future<FinanceKpiSummary> getKpiSummary() => api.fetchKpiSummary();

  @override
  Future<List<FinanceSummaryCard>> getSummaryCards() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final results = await Future.wait([
      api.fetchAsaasCharges(
        from: today,
        to: today,
      ),
      api.fetchSubscriptions(limit: 100),
      api.fetchBalance(),
    ]);

    final todayCharges = results[0] as List<Map<String, dynamic>>;
    final subscriptions = results[1] as List<Map<String, dynamic>>;
    final balance = results[2] as Map<String, dynamic>;

    final todayTotal = todayCharges.fold<double>(
      0,
      (sum, c) => sum + ((c['value'] as num?)?.toDouble() ?? 0),
    );
    final activeSubscriptions = subscriptions
        .where((s) => (s['status'] as String?) == 'ACTIVE')
        .length;
    final balanceValue = (balance['balance'] as num?)?.toDouble() ?? 0;

    // Ticket médio: média das cobranças de hoje
    final avgTicket = todayCharges.isEmpty
        ? 0.0
        : todayTotal / todayCharges.length;

    return [
      FinanceSummaryCard(
        title: 'A vencer hoje',
        value: _brl(todayTotal),
        subtitle: '${todayCharges.length} cobranças no dia',
      ),
      FinanceSummaryCard(
        title: 'Assinaturas ativas',
        value: '$activeSubscriptions',
        subtitle: '${subscriptions.length} assinaturas no total',
      ),
      FinanceSummaryCard(
        title: 'Saldo disponível',
        value: _brl(balanceValue),
        subtitle: 'Conta Asaas',
      ),
      FinanceSummaryCard(
        title: 'Ticket médio',
        value: _brl(avgTicket),
        subtitle: 'Cobranças de hoje',
      ),
    ];
  }

  @override
  Future<List<FinanceChargeRecord>> getCharges() async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final raw = await api.fetchAsaasCharges(from: from, to: now, limit: 100);
    return raw.map(_mapCharge).toList();
  }

  static FinanceChargeRecord _mapCharge(Map<String, dynamic> c) {
    final statusStr = (c['status'] as String? ?? '').toUpperCase();
    final billingStr = (c['billingType'] as String? ?? '').toUpperCase();

    final status = switch (statusStr) {
      'RECEIVED' || 'CONFIRMED' || 'RECEIVED_IN_CASH' => FinanceStatus.paid,
      'PENDING'                                        => FinanceStatus.open,
      'OVERDUE'                                        => FinanceStatus.overdue,
      'REFUNDED' || 'CHARGEBACK_REQUESTED' ||
      'CHARGEBACK_DISPUTE' || 'AWAITING_CHARGEBACK_REVERSAL' => FinanceStatus.refunded,
      'CANCELED' || 'CANCELLED'                        => FinanceStatus.canceled,
      _                                                => FinanceStatus.waitingPayment,
    };

    final method = switch (billingStr) {
      'PIX'         => PaymentMethod.pix,
      'BOLETO'      => PaymentMethod.boleto,
      'CREDIT_CARD' => PaymentMethod.creditCard,
      _             => PaymentMethod.boleto,
    };

    final dueDateStr  = c['dueDate']?.toString()  ?? '';
    final createdStr  = c['dateCreated']?.toString() ?? '';

    return FinanceChargeRecord(
      id:            c['id']?.toString() ?? '',
      client:        c['customerName']?.toString() ?? c['customer']?.toString() ?? '—',
      description:   c['description']?.toString() ?? 'Cobrança Asaas',
      amount:        (c['value'] as num?)?.toDouble() ?? 0,
      dueDate:       DateTime.tryParse(dueDateStr)  ?? DateTime.now(),
      paymentMethod: method,
      status:        status,
      createdAt:     DateTime.tryParse(createdStr)  ?? DateTime.now(),
    );
  }

  static String _brl(double value) {
    final abs = value.abs();
    final formatted = abs
        .toStringAsFixed(2)
        .replaceAll('.', ',')
        .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return value < 0 ? '- R\$ $formatted' : 'R\$ $formatted';
  }
}
