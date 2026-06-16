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

class ReportFilterOption {
  const ReportFilterOption({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;
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
    this.deviceId,
    this.latitude,
    this.longitude,
    this.speedKnots,
    this.ignition,
    this.battery,
    this.eventType,
    this.address,
    this.attributes = const <String, dynamic>{},
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
  final int? deviceId;
  final double? latitude;
  final double? longitude;
  final double? speedKnots;
  final bool? ignition;
  final String? battery;
  final String? eventType;
  final String? address;
  final Map<String, dynamic> attributes;

  String get latitudeLabel {
    if (latitude == null) {
      return 'Não informado';
    }
    return latitude!.toStringAsFixed(6);
  }

  String get longitudeLabel {
    if (longitude == null) {
      return 'Não informado';
    }
    return longitude!.toStringAsFixed(6);
  }

  String get speedKmhLabel {
    if (speedKnots == null) {
      return 'Não informado';
    }
    final kmh = speedKnots! * 1.852;
    return '${kmh.toStringAsFixed(1)} km/h';
  }

  String get ignitionLabel {
    if (ignition == null) {
      return 'Não informado';
    }
    return ignition! ? 'Ligada' : 'Desligada';
  }

  String get batteryLabel {
    final text = battery?.trim() ?? '';
    return text.isEmpty ? 'Não informado' : text;
  }

  String get addressLabel {
    final text = address?.trim() ?? '';
    return text.isEmpty ? 'Não informado' : text;
  }

  String get attributesSummaryLabel {
    if (attributes.isEmpty) {
      return 'Não informado';
    }
    final summary = <String>[];
    for (final entry in attributes.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) continue;
      final value = '${entry.value ?? ''}'.trim();
      if (value.isEmpty || value.toLowerCase() == 'null') continue;
      summary.add('$key=$value');
      if (summary.length >= 6) break;
    }
    if (summary.isEmpty) {
      return 'Não informado';
    }
    return summary.join(' | ');
  }
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
        return 'Resumo operacional';
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
        return 'Em processamento';
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
