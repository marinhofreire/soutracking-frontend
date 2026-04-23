import 'dart:math';

import 'models.dart';
import 'traccar_client.dart';

class MockTraccarClient extends TraccarClient {
  MockTraccarClient() : super(baseUrl: 'http://localhost/mock');

  final _rng = Random(42);
  final List<TraccarDevice> _devices = [
    TraccarDevice(
      id: 1,
      name: 'Carro ABC1D23',
      status: 'online',
      lastUpdate: DateTime.now().toUtc().toIso8601String(),
      uniqueId: 'ABC1D23',
      positionId: 101,
    ),
    TraccarDevice(
      id: 2,
      name: 'Van XYZ9Z99',
      status: 'offline',
      lastUpdate: DateTime.now().toUtc().toIso8601String(),
      uniqueId: 'XYZ9Z99',
      positionId: 102,
    ),
  ];

  final List<Map<String, dynamic>> _drivers = [
    {'id': 10, 'name': 'João Silva', 'uniqueId': 'DRV001'},
    {'id': 11, 'name': 'Maria Souza', 'uniqueId': 'DRV002'},
  ];

  final List<Map<String, dynamic>> _geofences = [
    {'id': 20, 'name': 'Base', 'area': 'CIRCLE (-23.56 -46.64, 200)'},
  ];

  final List<Map<String, dynamic>> _notifications = [];
  final List<Map<String, dynamic>> _groups = [
    {'id': 30, 'name': 'Operação'},
  ];
  final List<Map<String, dynamic>> _commands = [];
  final List<Map<String, dynamic>> _permissions = [
    {'id': 501, 'userId': 1, 'deviceId': 1},
    {'id': 502, 'userId': 1, 'deviceId': 2},
    {'id': 503, 'userId': 2, 'deviceId': 1},
    {'id': 504, 'userId': 3, 'deviceId': 2},
  ];

  @override
  Future<TraccarSession> login({
    required String email,
    required String password,
  }) async {
    return TraccarSession(
        cookie: 'mock', authHeader: '', user: {'email': email});
  }

  @override
  Future<List<TraccarDevice>> getDevices({
    String? cookie,
    String? authHeader,
  }) async {
    return _devices;
  }

  @override
  Future<List<TraccarPosition>> getPositions({
    String? cookie,
    String? authHeader,
    int? deviceId,
  }) async {
    final baseLat = -23.56 + _rng.nextDouble() * 0.01;
    final baseLon = -46.64 + _rng.nextDouble() * 0.01;
    final positions = _devices
        .where((d) => deviceId == null || d.id == deviceId)
        .map(
          (d) => TraccarPosition(
            id: d.positionId ?? d.id + 100,
            deviceId: d.id,
            latitude: baseLat + _rng.nextDouble() * 0.01,
            longitude: baseLon + _rng.nextDouble() * 0.01,
            fixTime: DateTime.now().toUtc().toIso8601String(),
            speed: _rng.nextDouble() * 30,
          ),
        )
        .toList();
    return positions;
  }

  @override
  Future<List<TraccarUser>> getUsers({
    String? cookie,
    String? authHeader,
  }) async {
    return [
      TraccarUser(
        id: 1,
        name: 'Administrador',
        email: 'admin@demo.com',
        administrator: true,
        readonly: false,
        disabled: false,
      ),
      TraccarUser(
        id: 2,
        name: 'Julia Martins',
        email: 'julia@demo.com',
        administrator: false,
        readonly: true,
        disabled: false,
      ),
      TraccarUser(
        id: 3,
        name: 'Carlos Lima',
        email: 'carlos@demo.com',
        administrator: false,
        readonly: false,
        disabled: false,
      ),
      TraccarUser(
        id: 4,
        name: 'Cliente Final',
        email: 'cliente@demo.com',
        administrator: false,
        readonly: false,
        disabled: true,
      ),
      TraccarUser(
        id: 5,
        name: 'Samuel Rodrigues',
        email: 'samuel@demo.com',
        administrator: false,
        readonly: false,
        disabled: false,
      ),
    ];
  }

  @override
  Future<TraccarDevice> createDevice({
    String? cookie,
    String? authHeader,
    required Map<String, dynamic> body,
  }) async {
    final id = _devices.length + 1;
    final device = TraccarDevice(
      id: id,
      name: (body['name'] ?? 'Novo dispositivo') as String,
      status: 'offline',
      lastUpdate: DateTime.now().toUtc().toIso8601String(),
      uniqueId: body['uniqueId'] as String?,
      positionId: id + 100,
    );
    _devices.add(device);
    return device;
  }

  @override
  Future<List<Map<String, dynamic>>> getList({
    required String path,
    String? cookie,
    String? authHeader,
    Map<String, dynamic>? query,
  }) async {
    switch (path) {
      case '/drivers':
        return _drivers;
      case '/geofences':
        return _geofences;
      case '/notifications':
        return _notifications;
      case '/groups':
        return _groups;
      case '/commands':
        return _commands;
      case '/permissions':
        return _permissions;
      default:
        return [];
    }
  }

  @override
  Future<Map<String, dynamic>> createEntity({
    required String path,
    String? cookie,
    String? authHeader,
    required Map<String, dynamic> body,
  }) async {
    final data = Map<String, dynamic>.from(body);
    data['id'] = _rng.nextInt(10000) + 100;
    if (path == '/geofences') {
      _geofences.add(data);
    } else if (path == '/notifications') {
      _notifications.add(data);
    } else if (path == '/commands') {
      _commands.add(data);
    } else if (path == '/permissions') {
      _permissions.add(data);
    }
    return data;
  }

  @override
  Future<Map<String, dynamic>> updateEntity({
    required String path,
    String? cookie,
    String? authHeader,
    required Map<String, dynamic> body,
  }) async {
    return body;
  }

  @override
  Future<Map<String, dynamic>> getTenantConfig({
    String? cookie,
    String? authHeader,
  }) async {
    // Simula config mock: tracking sempre true, assist/mdvr/admin true, branding demo
    return {
      'tenantId': 'tenant-demo',
      'companyName': 'SouInnova Demo',
      'slug': 'souinnova-demo',
      'role': 'master_admin',
      'modules': {
        'tracking': true,
        'assist': true,
        'demand': true,
        'mdvr': true,
        'admin': true,
        'zpro': true,
      },
      'branding': {
        'appName': 'SouAssist',
        'tagline': 'Operação assistida com tracking integrado',
        'primaryColor': '#7C5CFF',
        'secondaryColor': '#4F46E5',
      },
    };
  }
}
