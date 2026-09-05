class DriverKpiSummary {
  const DriverKpiSummary({
    required this.active,
    required this.onRoute,
    required this.withoutVehicle,
    required this.cnhExpiring,
  });

  final int active;
  final int onRoute;
  final int withoutVehicle;
  final int cnhExpiring;
}

enum DriverStatus {
  onRoute,
  available,
  withoutVehicle,
  inactive,
}

extension DriverStatusLabel on DriverStatus {
  String get label {
    switch (this) {
      case DriverStatus.onRoute:
        return 'Em rota';
      case DriverStatus.available:
        return 'Disponivel';
      case DriverStatus.withoutVehicle:
        return 'Sem veiculo';
      case DriverStatus.inactive:
        return 'Inativo';
    }
  }
}

enum CnhState {
  valid,
  expiring,
  expired,
  unknown,
}

extension CnhStateLabel on CnhState {
  String get label {
    switch (this) {
      case CnhState.valid:
        return 'Valida';
      case CnhState.expiring:
        return 'A vencer';
      case CnhState.expired:
        return 'Vencida';
      case CnhState.unknown:
        return 'Nao informada';
    }
  }
}

class DriverRecord {
  const DriverRecord({
    required this.id,
    required this.name,
    required this.phone,
    required this.cnh,
    required this.cnhCategory,
    required this.ear,
    required this.toxicologicoDate,
    required this.vehicle,
    required this.status,
    required this.lastActivity,
    required this.cnhExpiry,
    required this.cnhState,
    required this.score,
    required this.base,
  });

  final String id;
  final String name;
  final String phone;
  final String cnh;
  final String cnhCategory;
  final bool ear;
  final DateTime? toxicologicoDate;
  final String vehicle;
  final DriverStatus status;
  final DateTime lastActivity;
  // Nulo quando o motorista nao tem validade de CNH cadastrada -- nunca
  // inventamos uma data so pra preencher a UI.
  final DateTime? cnhExpiry;
  final CnhState cnhState;
  final int score;
  final String base;
}
