class TenantConfig {
  const TenantConfig({
    required this.tenantId,
    required this.companyName,
    required this.slug,
    required this.modules,
    this.isMasterAdmin = false,
    this.isCompanyAdmin = false,
    this.branding = const <String, dynamic>{},
  });

  final String tenantId;
  final String companyName;
  final String slug;
  final Map<String, bool> modules;
  final bool isMasterAdmin;
  final bool isCompanyAdmin;
  final Map<String, dynamic> branding;

  static const TenantConfig fallback = TenantConfig(
    tenantId: 'default',
    companyName: 'Soutracking',
    slug: 'soutracking',
    modules: {
      'tracking': true,
      'assist': false,
      'demand': true,
      'mdvr': true,
      'admin': false,
      'zpro': true,
    },
    branding: {
      'appName': 'Soutracking',
      'tagline': 'Gestão inteligente de frotas e ativos',
      'primaryColor': '#7C5CFF',
      'secondaryColor': '#7C5CFF',
      // logoAsset pode ser adicionado aqui se desejar
    },
  );

  bool isFeatureEnabled(String module) => modules[module] == true;

  factory TenantConfig.fromJson(Map<String, dynamic> json) {
    final modules = _parseModules(json['modules']);
    return TenantConfig(
      tenantId:
          (json['tenantId'] ?? json['id'] ?? fallback.tenantId).toString(),
      companyName: (json['companyName'] ?? json['name'] ?? fallback.companyName)
          .toString(),
      slug: (json['slug'] ?? fallback.slug).toString(),
      modules: {
        ...fallback.modules,
        ...modules,
      },
      isMasterAdmin:
          json['isMasterAdmin'] == true || json['role'] == 'master_admin',
      isCompanyAdmin:
          json['isCompanyAdmin'] == true || json['role'] == 'company_admin',
      branding: _parseBranding(json['branding']),
    );
  }

  static Map<String, dynamic> _parseBranding(dynamic value) {
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    return const <String, dynamic>{};
  }

  static Map<String, bool> _parseModules(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, moduleValue) => MapEntry(
          key.toString(),
          moduleValue == true || moduleValue == 1 || moduleValue == 'true',
        ),
      );
    }

    if (value is List) {
      final parsed = <String, bool>{};
      for (final item in value) {
        if (item != null) {
          parsed[item.toString()] = true;
        }
      }
      return parsed;
    }

    return const <String, bool>{};
  }
}
