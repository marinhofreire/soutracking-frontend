enum ReportType {
  trips,
  routes,
  events,
  stops,
  distance,
  speed,
  alerts,
  drivers,
  vehicles,
}

enum ReportStatus {
  ready,
  processing,
  scheduled,
  failed,
}

enum ReportFormat {
  pdf,
  excel,
  screen,
}

class ReportKpiSummary {
  const ReportKpiSummary({
    required this.generated,
    required this.scheduled,
    required this.exports,
    required this.criticalAlerts,
  });

  final int generated;
  final int scheduled;
  final int exports;
  final int criticalAlerts;
}

class ReportCategory {
  const ReportCategory({
    required this.type,
    required this.description,
    required this.generatedCount,
  });

  final ReportType type;
  final String description;
  final int generatedCount;
}

class ReportRecord {
  const ReportRecord({
    required this.name,
    required this.type,
    required this.vehicle,
    required this.driver,
    required this.period,
    required this.status,
    required this.createdAt,
    required this.format,
    required this.totalRecords,
  });

  final String name;
  final ReportType type;
  final String vehicle;
  final String driver;
  final String period;
  final ReportStatus status;
  final DateTime createdAt;
  final ReportFormat format;
  final int totalRecords;
}

extension ReportTypeView on ReportType {
  String get label {
    switch (this) {
      case ReportType.trips:
        return 'Viagens';
      case ReportType.routes:
        return 'Rotas';
      case ReportType.events:
        return 'Eventos';
      case ReportType.stops:
        return 'Paradas';
      case ReportType.distance:
        return 'Resumo';
      case ReportType.speed:
        return 'Velocidade';
      case ReportType.alerts:
        return 'Alertas';
      case ReportType.drivers:
        return 'Motoristas';
      case ReportType.vehicles:
        return 'Veículos';
    }
  }

  String get traccarEndpoint {
    switch (this) {
      case ReportType.trips:
        return '/reports/trips';
      case ReportType.routes:
        return '/reports/route';
      case ReportType.events:
        return '/reports/events';
      case ReportType.stops:
        return '/reports/stops';
      case ReportType.distance:
        return '/reports/summary';
      case ReportType.speed:
        return '/reports/summary';
      case ReportType.alerts:
        return '/reports/events';
      case ReportType.drivers:
        return '/reports/summary';
      case ReportType.vehicles:
        return '/reports/summary';
    }
  }
}

extension ReportStatusView on ReportStatus {
  String get label {
    switch (this) {
      case ReportStatus.ready:
        return 'Pronto';
      case ReportStatus.processing:
        return 'Processando';
      case ReportStatus.scheduled:
        return 'Agendado';
      case ReportStatus.failed:
        return 'Falhou';
    }
  }
}

extension ReportFormatView on ReportFormat {
  String get label {
    switch (this) {
      case ReportFormat.pdf:
        return 'PDF';
      case ReportFormat.excel:
        return 'Excel';
      case ReportFormat.screen:
        return 'Tela';
    }
  }
}
