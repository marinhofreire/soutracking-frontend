enum CallPriority {
  critical,
  high,
  medium,
  low,
}

enum CallCategory {
  installation,
  connectivity,
  diagnostics,
  maintenance,
  support,
  report,
}

enum CallStatus {
  open,
  inProgress,
  waitingPart,
  waitingCustomer,
  slaCritical,
  closed,
}

class CallKpiSummary {
  const CallKpiSummary({
    required this.open,
    required this.inProgress,
    required this.slaCritical,
    required this.closed,
  });

  final int open;
  final int inProgress;
  final int slaCritical;
  final int closed;
}

class CallTicket {
  const CallTicket({
    required this.id,
    required this.client,
    required this.vehicle,
    required this.category,
    required this.priority,
    required this.attendant,
    required this.sla,
    required this.status,
    required this.openedAt,
    required this.subject,
  });

  final String id;
  final String client;
  final String vehicle;
  final CallCategory category;
  final CallPriority priority;
  final String attendant;
  final String sla;
  final CallStatus status;
  final DateTime openedAt;
  final String subject;
}

extension CallPriorityView on CallPriority {
  String get label {
    switch (this) {
      case CallPriority.critical:
        return 'Critica';
      case CallPriority.high:
        return 'Alta';
      case CallPriority.medium:
        return 'Media';
      case CallPriority.low:
        return 'Baixa';
    }
  }
}

extension CallCategoryView on CallCategory {
  String get label {
    switch (this) {
      case CallCategory.installation:
        return 'Instalacao';
      case CallCategory.connectivity:
        return 'Conectividade';
      case CallCategory.diagnostics:
        return 'Diagnostico';
      case CallCategory.maintenance:
        return 'Manutencao';
      case CallCategory.support:
        return 'Suporte';
      case CallCategory.report:
        return 'Relatorio';
    }
  }
}

extension CallStatusView on CallStatus {
  String get label {
    switch (this) {
      case CallStatus.open:
        return 'Em aberto';
      case CallStatus.inProgress:
        return 'Em atendimento';
      case CallStatus.waitingPart:
        return 'Aguardando peca';
      case CallStatus.waitingCustomer:
        return 'Aguardando cliente';
      case CallStatus.slaCritical:
        return 'SLA critico';
      case CallStatus.closed:
        return 'Concluido';
    }
  }
}
