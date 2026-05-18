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
        return 'Crítica';
      case AlertSeverity.high:
        return 'Alta';
      case AlertSeverity.medium:
        return 'Média';
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
        return 'Em análise';
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
    required this.description,
    required this.dateTime,
    this.status,
    this.latitude,
    this.longitude,
    this.speedKnots,
    this.ignition,
    this.battery,
    this.address,
    this.attributes = const <String, dynamic>{},
  });

  final String id;
  final AlertSeverity severity;
  final String type;
  final String vehicle;
  final String description;
  final DateTime dateTime;
  final AlertStatus? status;
  final double? latitude;
  final double? longitude;
  final double? speedKnots;
  final bool? ignition;
  final String? battery;
  final String? address;
  final Map<String, dynamic> attributes;

  static const List<String> _preferredAttributeKeys = <String>[
    'alarm',
    'motion',
    'result',
    'odometer',
    'totalDistance',
    'sat',
    'rssi',
    'geofenceName',
    'geofence',
    'fuel',
    'temperature',
  ];

  String get latitudeLabel {
    if (latitude == null) {
      return 'Nao informado';
    }
    return latitude!.toStringAsFixed(6);
  }

  String get longitudeLabel {
    if (longitude == null) {
      return 'Nao informado';
    }
    return longitude!.toStringAsFixed(6);
  }

  String get latLngLabel {
    if (latitude == null || longitude == null) {
      return 'Nao informado';
    }
    return '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}';
  }

  String get speedKmhLabel {
    final raw = speedKnots ?? _asDouble(attributes['speed']);
    if (raw == null) {
      return 'Nao informado';
    }
    final kmh = raw * 1.852;
    return '${kmh.toStringAsFixed(1)} km/h';
  }

  String get ignitionLabel {
    final value = ignition ?? _asBool(attributes['ignition'] ?? attributes['ignitionOn']);
    if (value == null) {
      return 'Nao informado';
    }
    return value ? 'Ligada' : 'Desligada';
  }

  String get batteryLabel {
    final direct = _sanitizeText(battery);
    if (direct != null) {
      return direct;
    }

    final raw = attributes['battery'] ??
        attributes['batteryLevel'] ??
        attributes['power'] ??
        attributes['batteryVoltage'];
    if (raw == null) {
      return 'Nao informado';
    }

    if (raw is num) {
      final value = raw.toDouble();
      if (!value.isFinite) {
        return 'Nao informado';
      }
      if (value > 20) {
        return '${value.toStringAsFixed(0)}%';
      }
      return '${value.toStringAsFixed(2)} V';
    }

    final text = _sanitizeText(raw.toString());
    return text ?? 'Nao informado';
  }

  String get addressLabel {
    final direct = _sanitizeText(address);
    if (direct != null) {
      return direct;
    }
    final fromAttributes = _sanitizeText(
      (attributes['address'] ?? attributes['geocoder'] ?? '').toString(),
    );
    return fromAttributes ?? 'Nao informado';
  }

  String get attributesSummaryLabel {
    if (attributes.isEmpty) {
      return 'Nao informado';
    }

    final summary = <String>[];
    final usedKeys = <String>{};

    void appendAttribute(String key) {
      if (usedKeys.contains(key)) {
        return;
      }
      if (!attributes.containsKey(key)) {
        return;
      }
      final value = _formatAttributeValue(attributes[key]);
      if (value == null) {
        return;
      }
      summary.add('$key: $value');
      usedKeys.add(key);
    }

    for (final key in _preferredAttributeKeys) {
      appendAttribute(key);
      if (summary.length >= 5) {
        break;
      }
    }

    if (summary.length < 5) {
      for (final entry in attributes.entries) {
        appendAttribute(entry.key.toString());
        if (summary.length >= 5) {
          break;
        }
      }
    }

    if (summary.isEmpty) {
      return 'Nao informado';
    }
    return summary.join(' | ');
  }

  static String? _sanitizeText(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }

  static String? _formatAttributeValue(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value ? 'Sim' : 'Nao';
    }
    if (value is num) {
      final number = value.toDouble();
      if (!number.isFinite) {
        return null;
      }
      return number == number.roundToDouble()
          ? number.toStringAsFixed(0)
          : number.toStringAsFixed(2);
    }

    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }

  static double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value == null) {
      return null;
    }
    return double.tryParse('$value');
  }

  static bool? _asBool(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value > 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' ||
          normalized == '1' ||
          normalized == 'on' ||
          normalized == 'ligada' ||
          normalized == 'sim') {
        return true;
      }
      if (normalized == 'false' ||
          normalized == '0' ||
          normalized == 'off' ||
          normalized == 'desligada' ||
          normalized == 'nao' ||
          normalized == 'nÃ£o') {
        return false;
      }
    }
    return null;
  }
}
