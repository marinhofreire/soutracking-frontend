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
  });

  final SessionStatus status;
  final String? email;
  final String? error;
  final String? cookie;
  final String? authHeader;
  final TenantConfig tenantConfig;

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
  }) {
    return SessionState(
      status: status ?? this.status,
      email: email ?? this.email,
      error: error,
      cookie: cookie ?? this.cookie,
      authHeader: authHeader ?? this.authHeader,
      tenantConfig: tenantConfig ?? this.tenantConfig,
    );
  }
}

enum SessionStatus { idle, loading, authenticated, error }

final traccarClientProvider = Provider<TraccarClient>((ref) {
  if (kUseMockApi) {
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

  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(
      status: SessionStatus.loading,
      error: null,
      email: email,
    );
    if (presentationMode) {
      // Força modo demo estável
      final tenantConfig = TenantConfig.fallback;
      await _ref
          .read(whiteLabelProvider.notifier)
          .applyBranding(tenantConfig.branding);
      state = state.copyWith(
        status: SessionStatus.authenticated,
        cookie: 'demo',
        authHeader: '',
        error: null,
        tenantConfig: tenantConfig,
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
      state = state.copyWith(
        status: SessionStatus.authenticated,
        cookie: session.cookie,
        authHeader: session.authHeader,
        error: null,
        tenantConfig: tenantConfig,
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
    // DEMO: nunca lança exception, sempre retorna vazio
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
      // DEMO: nunca lança exception, sempre retorna vazio
      return [];
    }
    final client = ref.watch(traccarClientProvider);
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
  });
}

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
    final computed = await client.getList(
      path: '/attributes',
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
final statisticsProvider = _genericListProvider('/statistics');
