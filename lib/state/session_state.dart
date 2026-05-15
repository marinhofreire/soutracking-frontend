import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_constants.dart';
import '../core/tenant_config.dart';
import '../core/white_label.dart';
import '../data/mock_traccar_client.dart';
import '../data/models.dart';
import '../data/traccar_client.dart';

class SessionState {
  const SessionState({
    required this.status,
    this.email,
    this.error,
    this.cookie,
    this.authHeader,
    this.tenantConfig = TenantConfig.fallback,
    this.profileCode = 'OM',
    this.isAdministrator = false,
  });

  final SessionStatus status;
  final String? email;
  final String? error;
  final String? cookie;
  final String? authHeader;
  final TenantConfig tenantConfig;
  final String profileCode;
  final bool isAdministrator;

  bool get isAuthenticated =>
      status == SessionStatus.authenticated &&
      (cookie?.isNotEmpty == true || authHeader?.isNotEmpty == true);

  SessionState copyWith({
    SessionStatus? status,
    String? email,
    String? error,
    String? cookie,
    String? authHeader,
    TenantConfig? tenantConfig,
    String? profileCode,
    bool? isAdministrator,
  }) {
    return SessionState(
      status: status ?? this.status,
      email: email ?? this.email,
      error: error,
      cookie: cookie ?? this.cookie,
      authHeader: authHeader ?? this.authHeader,
      tenantConfig: tenantConfig ?? this.tenantConfig,
      profileCode: profileCode ?? this.profileCode,
      isAdministrator: isAdministrator ?? this.isAdministrator,
    );
  }
}

enum SessionStatus { idle, loading, authenticated, error }

final traccarClientProvider = Provider<TraccarClient>((ref) {
  if (presentationMode || kUseMockApi) {
    return MockTraccarClient();
  }
  return TraccarClient(
    baseUrl: kTraccarBaseUrl,
    souAssistBaseUrl: kSouAssistApiBaseUrl,
  );
});

class SessionController extends StateNotifier<SessionState> {
  SessionController(this._client, this._ref)
      : super(const SessionState(status: SessionStatus.idle)) {
    logTraccarBaseUrl();
  }

  final TraccarClient _client;
  final Ref _ref;

  bool? _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value > 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return null;
  }

  Map<String, bool> _parseModuleFlags(dynamic raw) {
    final modules = <String, bool>{};

    void setModule(String key, dynamic value) {
      final parsed = _asBool(value);
      if (parsed != null && key.trim().isNotEmpty) {
        modules[key.trim().toLowerCase()] = parsed;
      }
    }

    if (raw is Map) {
      raw.forEach((key, value) => setModule(key.toString(), value));
      return modules;
    }

    if (raw is List) {
      for (final item in raw) {
        if (item is String) {
          modules[item.trim().toLowerCase()] = true;
        } else if (item is Map) {
          final key = item['key'] ?? item['name'] ?? item['module'] ?? '';
          final value = item['enabled'] ?? item['active'] ?? item['value'];
          setModule(key.toString(), value ?? true);
        }
      }
      return modules;
    }

    if (raw is String) {
      final tokens = raw
          .split(RegExp(r'[,;\\s]+'))
          .map((it) => it.trim().toLowerCase())
          .where((it) => it.isNotEmpty);
      for (final token in tokens) {
        modules[token] = true;
      }
      return modules;
    }

    return modules;
  }

  Map<String, bool> _extractUserModules(Map<String, dynamic> user) {
    final parsed = <String, bool>{};

    void mergeFrom(dynamic raw) {
      final found = _parseModuleFlags(raw);
      if (found.isNotEmpty) {
        parsed.addAll(found);
      }
    }

    mergeFrom(user['modules']);
    mergeFrom(user['features']);
    mergeFrom(user['permissions']);

    final attrs = user['attributes'];
    if (attrs is Map) {
      final casted = attrs.cast<String, dynamic>();
      mergeFrom(casted['modules']);
      mergeFrom(casted['features']);
      mergeFrom(casted['permissions']);

      const knownKeys = [
        'tracking',
        'assist',
        'demand',
        'communication',
        'zpro',
        'ai',
        'ai_ops',
        'assistant',
        'finance',
        'inventory',
        'mdvr',
        'cameras',
        'data_log',
        'datalog',
        'logs',
        'reports',
        'reports_plus',
        'automations',
        'automation',
        'rules',
        'admin',
      ];

      for (final key in knownKeys) {
        final parsedValue = _asBool(casted[key]);
        if (parsedValue != null) {
          parsed[key] = parsedValue;
        }
      }
    }

    return parsed;
  }

  TenantConfig _mergeTenantConfigWithUser(
    TenantConfig tenantConfig,
    Map<String, dynamic> user,
  ) {
    final isAdministrator = user['administrator'] == true;
    final userModules = _extractUserModules(user);

    if (!isAdministrator && userModules.isEmpty) {
      return tenantConfig;
    }

    return TenantConfig(
      tenantId: tenantConfig.tenantId,
      companyName: tenantConfig.companyName,
      slug: tenantConfig.slug,
      modules: {
        ...tenantConfig.modules,
        ...userModules,
      },
      isMasterAdmin: tenantConfig.isMasterAdmin || isAdministrator,
      isCompanyAdmin: tenantConfig.isCompanyAdmin || isAdministrator,
      branding: tenantConfig.branding,
    );
  }

  String _normalizeProfileCode(String? raw) {
    final value = (raw ?? '').trim().toUpperCase();
    switch (value) {
      case 'MASTER_ADMIN':
      case 'MASTER':
      case 'MA':
        return 'MA';
      case 'ADMIN_EMPRESA':
      case 'ADMIN':
      case 'AE':
        return 'AE';
      case 'SUPERVISOR':
      case 'SO':
        return 'SO';
      case 'OPERADOR':
      case 'OM':
        return 'OM';
      case 'ATENDIMENTO':
      case 'SAC':
        return 'SAC';
      case 'TECNICO':
      case 'TEC':
        return 'TEC';
      case 'COMERCIAL':
      case 'COM':
        return 'COM';
      case 'FINANCEIRO':
      case 'FIN':
        return 'FIN';
      case 'ESTOQUE':
      case 'EST':
        return 'EST';
      case 'GESTOR_CLIENTE':
      case 'GC':
        return 'GC';
      case 'CLIENTE_FINAL':
      case 'CF':
        return 'CF';
      default:
        return value.isEmpty ? 'OM' : value;
    }
  }

  String _inferProfileCode(
    Map<String, dynamic> user, {
    required TenantConfig tenantConfig,
  }) {
    final directRole = user['role']?.toString();
    if (directRole != null && directRole.trim().isNotEmpty) {
      return _normalizeProfileCode(directRole);
    }

    final directProfile = user['profile']?.toString();
    if (directProfile != null && directProfile.trim().isNotEmpty) {
      return _normalizeProfileCode(directProfile);
    }

    final directProfileCode = user['profileCode']?.toString();
    if (directProfileCode != null && directProfileCode.trim().isNotEmpty) {
      return _normalizeProfileCode(directProfileCode);
    }

    if (tenantConfig.isMasterAdmin) {
      return 'MA';
    }
    if (tenantConfig.isCompanyAdmin || user['administrator'] == true) {
      return 'AE';
    }
    if (user['readonly'] == true) {
      return 'CF';
    }

    return 'OM';
  }

  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(
      status: SessionStatus.loading,
      error: null,
      email: email,
    );
    if (presentationMode) {
      // ForÃ§a modo demo estÃ¡vel
      const tenantConfig = TenantConfig(
        tenantId: 'demo',
        companyName: 'SouTracking Demo',
        slug: 'soutracking-demo',
        modules: {
          'tracking': true,
          'assist': true,
          'demand': true,
          'admin': true,
          'mdvr': false,
          'zpro': false,
          'finance': false,
          'inventory': false,
          'reports_plus': false,
        },
        isMasterAdmin: true,
        isCompanyAdmin: true,
        branding: {
          'appName': 'SouTracking',
          'tagline': 'Central operacional em modo demo',
          'primaryColor': '#2D7DFF',
          'secondaryColor': '#22D3EE',
        },
      );
      await _ref
          .read(whiteLabelProvider.notifier)
          .applyBranding(tenantConfig.branding);
      state = state.copyWith(
        status: SessionStatus.authenticated,
        cookie: 'demo',
        authHeader: '',
        error: null,
        tenantConfig: tenantConfig,
        profileCode: 'MA',
        isAdministrator: true,
      );
      return;
    }
    try {
      final session = await _client.login(email: email, password: password);
      // Hotfix: removida validaÃ§Ã£o manual de /api/server e /api/devices para permitir build.
      // Segue fluxo normal apÃ³s login.
      TenantConfig tenantConfig = TenantConfig.fallback;
      try {
        final tenantRaw = await _client.getTenantConfig(
          cookie: session.cookie,
          authHeader: session.authHeader,
        );
        tenantConfig = TenantConfig.fromJson(tenantRaw);
      } catch (_) {
        tenantConfig = TenantConfig(
          tenantId: 'default',
          companyName: (session.user['name'] ?? 'Soutracking').toString(),
          slug: (session.user['email'] ?? 'soutracking')
              .toString()
              .split('@')
              .first,
          modules: const {
            'tracking': true,
            'assist': false,
            'demand': false,
            'mdvr': false,
            'admin': false,
            'zpro': false,
            'finance': false,
            'inventory': false,
            'ai': false,
            'data_log': false,
            'automations': false,
          },
          isMasterAdmin: session.user['administrator'] == true,
          isCompanyAdmin: session.user['administrator'] == true,
          branding: const {
            'appName': 'Soutracking',
            'tagline': 'GestÃ£o inteligente de frotas e ativos',
            'primaryColor': '#7C5CFF',
            'secondaryColor': '#7C5CFF',
          },
        );
      }
      final mergedTenantConfig = _mergeTenantConfigWithUser(
        tenantConfig,
        session.user,
      );
      await _ref
          .read(whiteLabelProvider.notifier)
          .applyBranding(mergedTenantConfig.branding);
      final profileCode = _inferProfileCode(
        session.user,
        tenantConfig: mergedTenantConfig,
      );
      state = state.copyWith(
        status: SessionStatus.authenticated,
        cookie: session.cookie,
        authHeader: session.authHeader,
        error: null,
        tenantConfig: mergedTenantConfig,
        profileCode: profileCode,
        isAdministrator: session.user['administrator'] == true,
      );
    } catch (e) {
      state = state.copyWith(
        status: SessionStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> logout() async {
    final current = state;
    try {
      if (current.cookie?.isNotEmpty == true ||
          current.authHeader?.isNotEmpty == true) {
        await _client.deleteEntity(
          path: '/session',
          cookie: current.cookie,
          authHeader: current.authHeader,
        );
      }
    } catch (_) {
      // Mantem logout local mesmo com falha de rede.
    }

    state = const SessionState(status: SessionStatus.idle);
    _ref.read(whiteLabelProvider.notifier).reset();
  }
}

final sessionProvider = StateNotifierProvider<SessionController, SessionState>((
  ref,
) {
  final client = ref.watch(traccarClientProvider);
  return SessionController(client, ref);
});

final tenantConfigProvider = Provider<TenantConfig>((ref) {
  return ref.watch(sessionProvider).tenantConfig;
});

final devicesProvider = FutureProvider<List<TraccarDevice>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (!session.isAuthenticated) {
    return [];
  }
  final client = ref.watch(traccarClientProvider);
  try {
    return await client.getDevices(
      cookie: session.cookie,
      authHeader: session.authHeader,
    );
  } catch (_) {
    return [];
  }
});

final positionsProvider = FutureProvider<List<TraccarPosition>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (!session.isAuthenticated) {
    return [];
  }
  final client = ref.watch(traccarClientProvider);
  try {
    return await client.getPositions(
      cookie: session.cookie,
      authHeader: session.authHeader,
    );
  } catch (_) {
    // Nunca propaga erro para UI
    return [];
  }
});

final usersProvider = FutureProvider<List<TraccarUser>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (!session.isAuthenticated) {
    return [];
  }
  final client = ref.watch(traccarClientProvider);
  return client.getUsers(
    cookie: session.cookie,
    authHeader: session.authHeader,
  );
});

FutureProvider<List<Map<String, dynamic>>> _genericListProvider(String path) {
  return FutureProvider<List<Map<String, dynamic>>>((ref) async {
    final session = ref.watch(sessionProvider);
    if (presentationMode || !session.isAuthenticated) {
      // DEMO: nunca lanÃ§a exception, sempre retorna vazio
      return [];
    }
    final client = ref.watch(traccarClientProvider);
    try {
      return await client.getList(
        path: path,
        cookie: session.cookie,
        authHeader: session.authHeader,
        query: {'all': 'true'},
      );
    } catch (_) {
      try {
        return await client.getList(
          path: path,
          cookie: session.cookie,
          authHeader: session.authHeader,
        );
      } catch (_) {
        // Nunca propaga erro para UI
        return [];
      }
    }
  });
}

DateTime _defaultReportFrom() =>
    DateTime.now().subtract(const Duration(days: 7));

DateTime _defaultReportTo() => DateTime.now();

String _inferAttributeType(dynamic value) {
  if (value is bool) return 'boolean';
  if (value is num) return 'number';
  return 'string';
}

void _collectEmbeddedAttributes({
  required Iterable<Map<String, dynamic>> items,
  required String source,
  required Map<String, Map<String, dynamic>> catalog,
}) {
  for (final item in items) {
    final attrs = item['attributes'];
    if (attrs is! Map) {
      continue;
    }

    for (final entry in attrs.entries) {
      final key = '${entry.key}'.trim();
      if (key.isEmpty) {
        continue;
      }

      final existing = catalog[key];
      final inferredType = _inferAttributeType(entry.value);

      if (existing == null) {
        catalog[key] = {
          'description': key,
          'attribute': key,
          'type': inferredType,
          'expression': '',
          'source': source,
        };
        continue;
      }

      if ((existing['type'] == null || '${existing['type']}'.isEmpty) &&
          inferredType.isNotEmpty) {
        existing['type'] = inferredType;
      }
      existing['source'] = existing['source'] ?? source;
    }
  }
}

final groupsProvider = _genericListProvider('/groups');
final driversProvider = _genericListProvider('/drivers');
final geofencesProvider = _genericListProvider('/geofences');
final maintenanceProvider = _genericListProvider('/maintenance');
final notificationsProvider = _genericListProvider('/notifications');
final commandsProvider = _genericListProvider('/commands');
final attributesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (presentationMode || !session.isAuthenticated) {
    return [];
  }

  final client = ref.watch(traccarClientProvider);
  final catalog = <String, Map<String, dynamic>>{};

  try {
    final computed = await client.getComputedAttributes(
      cookie: session.cookie,
      authHeader: session.authHeader,
    );

    for (final item in computed) {
      final key = '${item['attribute'] ?? ''}'.trim();
      if (key.isEmpty) {
        continue;
      }
      catalog[key] = {
        ...item,
        'description': '${item['description'] ?? ''}'.trim().isEmpty
            ? key
            : item['description'],
        'attribute': key,
        'source': 'computed',
      };
    }
  } catch (_) {
    // ignora falha de /attributes para nÃ£o bloquear catÃ¡logo
  }

  try {
    final devices = await client.getList(
      path: '/devices',
      cookie: session.cookie,
      authHeader: session.authHeader,
    );
    _collectEmbeddedAttributes(
      items: devices,
      source: 'device',
      catalog: catalog,
    );
  } catch (_) {
    // ignora falha parcial
  }

  try {
    final positions = await client.getList(
      path: '/positions',
      cookie: session.cookie,
      authHeader: session.authHeader,
    );
    _collectEmbeddedAttributes(
      items: positions,
      source: 'position',
      catalog: catalog,
    );
  } catch (_) {
    // ignora falha parcial
  }

  final merged = catalog.values.toList();
  merged.sort((a, b) {
    final ak = '${a['attribute'] ?? ''}'.toLowerCase();
    final bk = '${b['attribute'] ?? ''}'.toLowerCase();
    return ak.compareTo(bk);
  });
  return merged;
});
final calendarsProvider = _genericListProvider('/calendars');
final ordersProvider = _genericListProvider('/orders');
final permissionsProvider = _genericListProvider('/permissions');
final statisticsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (presentationMode || !session.isAuthenticated) {
    return [];
  }
  final client = ref.watch(traccarClientProvider);
  try {
    return await client.getStatistics(
      cookie: session.cookie,
      authHeader: session.authHeader,
      from: _defaultReportFrom(),
      to: _defaultReportTo(),
    );
  } catch (_) {
    return [];
  }
});

final serverProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final session = ref.watch(sessionProvider);
  if (presentationMode || !session.isAuthenticated) {
    return null;
  }
  final client = ref.watch(traccarClientProvider);
  try {
    return await client.getServer(
      cookie: session.cookie,
      authHeader: session.authHeader,
    );
  } catch (_) {
    return null;
  }
});

final timezonesProvider = FutureProvider<List<String>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (presentationMode || !session.isAuthenticated) {
    return [];
  }
  final client = ref.watch(traccarClientProvider);
  try {
    return await client.getTimezones(
      cookie: session.cookie,
      authHeader: session.authHeader,
    );
  } catch (_) {
    return [];
  }
});

final commandTypesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int?>(
        (ref, deviceId) async {
  final session = ref.watch(sessionProvider);
  if (presentationMode || !session.isAuthenticated) {
    return [];
  }
  final client = ref.watch(traccarClientProvider);
  try {
    return await client.getCommandTypes(
      cookie: session.cookie,
      authHeader: session.authHeader,
      deviceId: deviceId,
    );
  } catch (_) {
    return [];
  }
});

final notificationTypesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (presentationMode || !session.isAuthenticated) {
    return [];
  }
  final client = ref.watch(traccarClientProvider);
  try {
    return await client.getNotificationTypes(
      cookie: session.cookie,
      authHeader: session.authHeader,
    );
  } catch (_) {
    return [];
  }
});

final latestEventsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (presentationMode || !session.isAuthenticated) {
    return [];
  }
  final devices = await ref.watch(devicesProvider.future);
  final deviceId = devices.length == 1 ? devices.first.id : null;
  final client = ref.watch(traccarClientProvider);
  try {
    return await client.getReport(
      path: '/reports/events',
      cookie: session.cookie,
      authHeader: session.authHeader,
      from: _defaultReportFrom(),
      to: _defaultReportTo(),
      deviceId: deviceId,
    );
  } catch (_) {
    return [];
  }
});

final deviceEventsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>(
        (ref, deviceId) async {
  final session = ref.watch(sessionProvider);
  if (presentationMode || !session.isAuthenticated) {
    return [];
  }
  final client = ref.watch(traccarClientProvider);
  try {
    return await client.getReport(
      path: '/reports/events',
      cookie: session.cookie,
      authHeader: session.authHeader,
      from: _defaultReportFrom(),
      to: _defaultReportTo(),
      deviceId: deviceId,
    );
  } catch (_) {
    return [];
  }
});

final reverseGeocodeProvider =
    FutureProvider.family<String?, String>((ref, key) async {
  final session = ref.watch(sessionProvider);
  if (presentationMode || !session.isAuthenticated) {
    return null;
  }
  final parts = key.split(',');
  if (parts.length != 2) return null;
  final latitude = double.tryParse(parts[0]);
  final longitude = double.tryParse(parts[1]);
  if (latitude == null || longitude == null) return null;
  final client = ref.watch(traccarClientProvider);
  try {
    return await client.reverseGeocode(
      cookie: session.cookie,
      authHeader: session.authHeader,
      latitude: latitude,
      longitude: longitude,
    );
  } catch (_) {
    return null;
  }
});
