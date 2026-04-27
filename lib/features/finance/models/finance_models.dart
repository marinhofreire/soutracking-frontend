enum FinanceStatus {
  paid,
  open,
  overdue,
  canceled,
  waitingPayment,
  refunded,
}

enum PaymentMethod {
  pix,
  boleto,
  creditCard,
  paymentLink,
  recurrence,
}

class FinanceKpiSummary {
  const FinanceKpiSummary({
    required this.monthRevenue,
    required this.received,
    required this.openAmount,
    required this.delinquency,
  });

  final double monthRevenue;
  final double received;
  final double openAmount;
  final double delinquency;
}

class FinanceSummaryCard {
  const FinanceSummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;
}

class FinanceChargeRecord {
  const FinanceChargeRecord({
    required this.id,
    required this.client,
    required this.description,
    required this.amount,
    required this.dueDate,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String client;
  final String description;
  final double amount;
  final DateTime dueDate;
  final PaymentMethod paymentMethod;
  final FinanceStatus status;
  final DateTime createdAt;
}

extension FinanceStatusView on FinanceStatus {
  String get label {
    switch (this) {
      case FinanceStatus.paid:
        return 'Pago';
      case FinanceStatus.open:
        return 'Em aberto';
      case FinanceStatus.overdue:
        return 'Vencido';
      case FinanceStatus.canceled:
        return 'Cancelado';
      case FinanceStatus.waitingPayment:
        return 'Aguardando pagamento';
      case FinanceStatus.refunded:
        return 'Reembolsado';
    }
  }
}

extension PaymentMethodView on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.pix:
        return 'Pix';
      case PaymentMethod.boleto:
        return 'Boleto';
      case PaymentMethod.creditCard:
        return 'Cartao de credito';
      case PaymentMethod.paymentLink:
        return 'Link de pagamento';
      case PaymentMethod.recurrence:
        return 'Recorrencia';
    }
  }
}
