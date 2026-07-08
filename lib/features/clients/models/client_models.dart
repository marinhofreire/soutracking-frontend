import '../../../data/models.dart';

enum ClientStatus { active, overdue, inactive }

enum ClientPlan { basic, pro, enterprise }

enum ClientType { pj, pf }

extension ClientStatusLabel on ClientStatus {
  String get label => switch (this) {
        ClientStatus.active   => 'Ativo',
        ClientStatus.overdue  => 'Inadimplente',
        ClientStatus.inactive => 'Inativo',
      };
}

extension ClientPlanLabel on ClientPlan {
  String get label => switch (this) {
        ClientPlan.basic      => 'Basic',
        ClientPlan.pro        => 'Pro',
        ClientPlan.enterprise => 'Enterprise',
      };

  String get priceLabel => switch (this) {
        ClientPlan.basic      => 'R\$ 29,90/veículo',
        ClientPlan.pro        => 'R\$ 49,90/veículo',
        ClientPlan.enterprise => 'Negociado',
      };
}

class ClientRecord {
  const ClientRecord({
    required this.traccarUserId,
    required this.name,
    required this.email,
    required this.phone,
    required this.document,
    required this.clientType,
    required this.address,
    required this.city,
    required this.state,
    required this.zip,
    required this.plan,
    required this.asaasCustomerId,
    required this.status,
    required this.deviceCount,
    required this.operatorCount,
    required this.disabled,
  });

  final int traccarUserId;
  final String name;
  final String email;
  final String phone;
  final String document;
  final ClientType clientType;
  final String address;
  final String city;
  final String state;
  final String zip;
  final ClientPlan plan;
  final String asaasCustomerId;
  final ClientStatus status;
  final int deviceCount;
  final int operatorCount;
  final bool disabled;

  bool get hasAsaas => asaasCustomerId.isNotEmpty;

  factory ClientRecord.fromTraccarUser(TraccarUser user, {
    int deviceCount = 0,
    int operatorCount = 0,
  }) {
    final attrs = user.attributes ?? const <String, dynamic>{};
    final typeStr = attrs['client_type']?.toString() ?? 'pj';
    final planStr = attrs['plan']?.toString() ?? 'basic';

    return ClientRecord(
      traccarUserId:   user.id,
      name:            user.name,
      email:           user.email,
      phone:           attrs['phone']?.toString()             ?? '',
      document:        attrs['document']?.toString()          ?? '',
      clientType:      typeStr == 'pf' ? ClientType.pf : ClientType.pj,
      address:         attrs['address']?.toString()           ?? '',
      city:            attrs['city']?.toString()              ?? '',
      state:           attrs['state']?.toString()             ?? '',
      zip:             attrs['zip']?.toString()               ?? '',
      plan:            ClientPlan.values.firstWhere(
                         (p) => p.name == planStr,
                         orElse: () => ClientPlan.basic,
                       ),
      asaasCustomerId: attrs['asaas_customer_id']?.toString() ?? '',
      status:          user.disabled
                         ? ClientStatus.inactive
                         : ClientStatus.active,
      deviceCount:     deviceCount,
      operatorCount:   operatorCount,
      disabled:        user.disabled,
    );
  }

  Map<String, dynamic> toTraccarAttributes() => {
        'soutracking_role':  'client',
        'client_type':       clientType.name,
        'phone':             phone,
        'document':          document,
        'address':           address,
        'city':              city,
        'state':             state,
        'zip':               zip,
        'plan':              plan.name,
        if (asaasCustomerId.isNotEmpty) 'asaas_customer_id': asaasCustomerId,
      };
}

class ClientKpiSummary {
  const ClientKpiSummary({
    required this.total,
    required this.active,
    required this.overdue,
    required this.inactive,
  });
  final int total;
  final int active;
  final int overdue;
  final int inactive;
}
