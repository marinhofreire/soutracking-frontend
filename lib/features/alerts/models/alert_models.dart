class AlertKpiSummary {
  const AlertKpiSummary({
    required this.today,
    required this.critical,
    required this.inAnalysis,
    required this.resolved,
  });

  final int today;
  final int critical;
  final int inAnalysis;
  final int resolved;
}

enum AlertSeverity {
  critical,
  high,
  medium,
  low,
}

extension AlertSeverityLabel on AlertSeverity {
  String get label {
    switch (this) {
      case AlertSeverity.critical:
        return 'Critica';
      case AlertSeverity.high:
        return 'Alta';
      case AlertSeverity.medium:
        return 'Media';
      case AlertSeverity.low:
        return 'Baixa';
    }
  }
}

enum AlertStatus {
  newAlert,
  inAnalysis,
  resolved,
}

extension AlertStatusLabel on AlertStatus {
  String get label {
    switch (this) {
      case AlertStatus.newAlert:
        return 'Novo';
      case AlertStatus.inAnalysis:
        return 'Em analise';
      case AlertStatus.resolved:
        return 'Resolvido';
    }
  }
}

class AlertRecord {
  const AlertRecord({
    required this.id,
    required this.severity,
    required this.type,
    required this.vehicle,
    required this.driver,
    required this.location,
    required this.dateTime,
    required this.status,
  });

  final String id;
  final AlertSeverity severity;
  final String type;
  final String vehicle;
  final String driver;
  final String location;
  final DateTime dateTime;
  final AlertStatus status;
}
