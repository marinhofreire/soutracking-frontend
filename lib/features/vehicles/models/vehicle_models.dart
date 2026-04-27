class VehicleKpiSummary {
  const VehicleKpiSummary({
    required this.total,
    required this.online,
    required this.maintenance,
    required this.noSignal,
  });

  final int total;
  final int online;
  final int maintenance;
  final int noSignal;
}

enum VehicleStatus {
  online,
  maintenance,
  noSignal,
  offline,
}

extension VehicleStatusLabel on VehicleStatus {
  String get label {
    switch (this) {
      case VehicleStatus.online:
        return 'Online';
      case VehicleStatus.maintenance:
        return 'Em manutenção';
      case VehicleStatus.noSignal:
        return 'Sem sinal';
      case VehicleStatus.offline:
        return 'Offline';
    }
  }
}

enum IgnitionStatus {
  on,
  off,
}

extension IgnitionStatusLabel on IgnitionStatus {
  String get label => this == IgnitionStatus.on ? 'Ligada' : 'Desligada';
}

class VehicleRecord {
  const VehicleRecord({
    required this.id,
    required this.plate,
    required this.model,
    required this.driver,
    required this.status,
    required this.ignition,
    required this.speedKmh,
    required this.lastUpdate,
  });

  final String id;
  final String plate;
  final String model;
  final String driver;
  final VehicleStatus status;
  final IgnitionStatus ignition;
  final double speedKmh;
  final DateTime lastUpdate;
}
