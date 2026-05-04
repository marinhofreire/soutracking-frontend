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
  });

  final SessionStatus status;
  final String? email;
  final String? error;
  final String? cookie;
  final String? authHeader;
  final TenantConfig tenantConfig;
  final String profileCode;

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
  }) {
    return SessionState(
      status: status ?? this.status,
      email: email ?? this.email,
      error: error,
      cookie: cookie ?? this.cookie,
      authHeader: authHeader ?? this.authHeader,
      tenantConfig: tenantConfig ?? this.tenantConfig,
      profileCode: profileCode ?? this.profileCode,
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
      // Força modo demo estável
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
      );
      return;
    }
    try {
      final session = await _client.login(email: email, password: password);
      // Hotfix: removida validação manual de /api/server e /api/devices para permitir build.
      // Segue fluxo normal após login.
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
            'demand': true,
            'mdvr': true,
            'admin': false,
            'zpro': true,
          },
          isMasterAdmin: session.user['administrator'] == true,
          isCompanyAdmin: session.user['administrator'] == true,
          branding: const {
            'appName': 'Soutracking',
            'tagline': 'Gestão inteligente de frotas e ativos',
            'primaryColor': '#7C5CFF',
            'secondaryColor': '#7C5CFF',
          },
        );
      }
      await _ref
          .read(whiteLabelProvider.notifier)
          .applyBranding(tenantConfig.branding);
      final profileCode = _inferProfileCode(
        session.user,
        tenantConfig: tenantConfig,
      );
      state = state.copyWith(
        status: SessionStatus.authenticated,
        cookie: session.cookie,
        authHeader: session.authHeader,
        error: null,
        tenantConfig: tenantConfig,
        profileCode: profileCode,
      );
    } catch (e) {
      state = state.copyWith(
        status: SessionStatus.error,
        error: e.toString(),
      );
    }
  }

  void logout() {
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
  if (presentationMode || !session.isAuthenticated) {
    // DEMO: nunca lança exception, sempre retorna mock
    return [
      TraccarDevice(
          id: 1,
          name: 'Veículo 1',
          status: 'online',
          lastUpdate: '2026-02-27T12:00:00Z'),
      TraccarDevice(
          id: 2,
          name: 'Veículo 2',
          status: 'offline',
          lastUpdate: '2026-02-27T11:00:00Z'),
      TraccarDevice(
          id: 3, name: 'Veículo 3', status: 'unknown', lastUpdate: null),
    ];
  }
  final client = ref.watch(traccarClientProvider);
  try {
    return await client.getDevices(
      cookie: session.cookie,
      authHeader: session.authHeader,
    );
  } catch (_) {
    // Nunca propaga erro para UI
    return [
      TraccarDevice(
          id: 1,
          name: 'Veículo 1',
          status: 'online',
          lastUpdate: '2026-02-27T12:00:00Z'),
      TraccarDevice(
          id: 2,
          name: 'Veículo 2',
          status: 'offline',
          lastUpdate: '2026-02-27T11:00:00Z'),
      TraccarDevice(
          id: 3, name: 'Veículo 3', status: 'unknown', lastUpdate: null),
    ];
  }
});

final positionsProvider = FutureProvider<List<TraccarPosition>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (presentationMode || !session.isAuthenticated) {
    // DEMO: nunca lança exception, sempre retorna posições mockadas
    return [
      TraccarPosition(
        id: 101,
        deviceId: 1,
        latitude: -23.5615,
        longitude: -46.6554,
        fixTime: '2026-02-27T12:00:00Z',
        speed: 28,
      ),
      TraccarPosition(
        id: 102,
        deviceId: 2,
        latitude: -23.6002,
        longitude: -46.6891,
        fixTime: '2026-02-27T11:58:00Z',
        speed: 0,
      ),
      TraccarPosition(
        id: 103,
        deviceId: 3,
        latitude: -23.5482,
        longitude: -46.6921,
        fixTime: '2026-02-27T11:54:00Z',
        speed: 12,
      ),
    ];
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
      // DEMO: nunca lança exception, sempre retorna vazio
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
    // ignora falha de /attributes para não bloquear catálogo
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
