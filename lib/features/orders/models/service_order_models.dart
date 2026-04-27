enum ServiceOrderStatus {
  open,
  scheduled,
  inProgress,
  waitingPart,
  waitingCustomer,
  completed,
  canceled,
  overdue,
}

enum ServiceOrderPriority {
  critical,
  high,
  medium,
  low,
}

enum ServiceType {
  trackerInstall,
  trackerRemoval,
  preventiveMaintenance,
  chipReplacement,
  electricalDiagnostics,
  powerReview,
  inspection,
  fieldSupport,
}

class ServiceOrderKpiSummary {
  const ServiceOrderKpiSummary({
    required this.open,
    required this.inProgress,
    required this.completed,
    required this.overdue,
  });

  final int open;
  final int inProgress;
  final int completed;
  final int overdue;
}

class ServiceOrderRecord {
  const ServiceOrderRecord({
    required this.id,
    required this.client,
    required this.vehicle,
    required this.serviceType,
    required this.technician,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.scheduledAt,
  });

  final String id;
  final String client;
  final String vehicle;
  final ServiceType serviceType;
  final String technician;
  final ServiceOrderStatus status;
  final ServiceOrderPriority priority;
  final DateTime createdAt;
  final DateTime scheduledAt;
}

extension ServiceOrderStatusView on ServiceOrderStatus {
  String get label {
    switch (this) {
      case ServiceOrderStatus.open:
        return 'Aberta';
      case ServiceOrderStatus.scheduled:
        return 'Agendada';
      case ServiceOrderStatus.inProgress:
        return 'Em andamento';
      case ServiceOrderStatus.waitingPart:
        return 'Aguardando peca';
      case ServiceOrderStatus.waitingCustomer:
        return 'Aguardando cliente';
      case ServiceOrderStatus.completed:
        return 'Concluida';
      case ServiceOrderStatus.canceled:
        return 'Cancelada';
      case ServiceOrderStatus.overdue:
        return 'Atrasada';
    }
  }
}

extension ServiceOrderPriorityView on ServiceOrderPriority {
  String get label {
    switch (this) {
      case ServiceOrderPriority.critical:
        return 'Critica';
      case ServiceOrderPriority.high:
        return 'Alta';
      case ServiceOrderPriority.medium:
        return 'Media';
      case ServiceOrderPriority.low:
        return 'Baixa';
    }
  }
}

extension ServiceTypeView on ServiceType {
  String get label {
    switch (this) {
      case ServiceType.trackerInstall:
        return 'Instalacao de rastreador';
      case ServiceType.trackerRemoval:
        return 'Retirada de rastreador';
      case ServiceType.preventiveMaintenance:
        return 'Manutencao preventiva';
      case ServiceType.chipReplacement:
        return 'Troca de chip';
      case ServiceType.electricalDiagnostics:
        return 'Diagnostico eletrico';
      case ServiceType.powerReview:
        return 'Revisao de alimentacao';
      case ServiceType.inspection:
        return 'Vistoria';
      case ServiceType.fieldSupport:
        return 'Suporte em campo';
    }
  }
}
