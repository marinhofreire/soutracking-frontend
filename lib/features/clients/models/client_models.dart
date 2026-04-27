class ClientKpiSummary {
  const ClientKpiSummary({
    required this.total,
    required this.active,
    required this.overdue,
    required this.vip,
  });

  final int total;
  final int active;
  final int overdue;
  final int vip;
}

class ClientRecord {
  const ClientRecord({
    required this.id,
    required this.name,
    required this.contact,
    required this.vehicleCount,
    required this.lastService,
    required this.balance,
    required this.status,
    required this.segment,
  });

  final String id;
  final String name;
  final String contact;
  final int vehicleCount;
  final DateTime lastService;
  final double balance;
  final ClientStatus status;
  final String segment;
}

enum ClientStatus {
  active,
  late,
  inactive,
}

extension ClientStatusLabel on ClientStatus {
  String get label {
    switch (this) {
      case ClientStatus.active:
        return 'Ativo';
      case ClientStatus.late:
        return 'Atrasado';
      case ClientStatus.inactive:
        return 'Inativo';
    }
  }
}
