import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_constants.dart';
import 'models.dart';

class TraccarClient {
  TraccarClient({
    http.Client? httpClient,
    String? baseUrl,
    String? souAssistBaseUrl,
  })  : _http = httpClient ?? http.Client(),
        _baseUrl = _normalizeBaseUrl(baseUrl ?? kTraccarBaseUrl),
        _souAssistBaseUrl =
            _normalizeBaseUrl(souAssistBaseUrl ?? kSouAssistApiBaseUrl);

  final http.Client _http;
  final String _baseUrl;
  final String _souAssistBaseUrl;

  static String _normalizeBaseUrl(String value) {
    var base = value.trim();
    // Remove /api do final se existir
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    if (base.endsWith('/api')) base = base.substring(0, base.length - 4);
    return base;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final uri = _uriOnBase(_baseUrl, path, query, ensureApiPrefix: true);
    logTraccarBaseUrl(endpoint: uri.toString());
    return uri;
  }

  Uri _souAssistUri(String path, [Map<String, dynamic>? query]) {
    final uri = _uriOnBase(
      _souAssistBaseUrl,
      path,
      query,
      ensureApiPrefix: true,
    );
    logSouAssistBaseUrl(endpoint: uri.toString());
    return uri;
  }

  Uri _uriOnBase(
    String base,
    String path,
    Map<String, dynamic>? query, {
    required bool ensureApiPrefix,
  }) {
    // Garante que path sempre começa com /api
    final fixedPath =
        ensureApiPrefix ? (path.startsWith('/api') ? path : '/api$path') : path;
    return Uri.parse('$base$fixedPath').replace(queryParameters: query);
  }

  Map<String, String> _headers({
    String? cookie,
    String? authHeader,
    bool json = false,
  }) {
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
      if (authHeader != null && authHeader.isNotEmpty)
        'Authorization': authHeader,
    };
  }

  Future<TraccarSession> login({
    required String email,
    required String password,
  }) async {
    final basicAuth = 'Basic ${base64Encode(utf8.encode('$email:$password'))}';

    final response = await _http.post(
      _uri('/session'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
      },
      body:
          'email=${Uri.encodeComponent(email)}&password=${Uri.encodeComponent(password)}',
    );

    if (response.statusCode == 200) {
      final cookie = response.headers['set-cookie']?.split(';').first ?? '';
      final user = jsonDecode(response.body) as Map<String, dynamic>;
      return TraccarSession(
        cookie: cookie,
        authHeader: basicAuth,
        user: user,
      );
    } else if (response.statusCode == 302 || response.statusCode == 401) {
      throw Exception('Usuário ou senha inválidos. (${response.statusCode})');
    } else if (response.statusCode == 404) {
      throw Exception(
          'Endpoint não encontrado (404). Verifique a URL do servidor Traccar.');
    }
    throw Exception('Login falhou: ${response.statusCode}');
  }

  Future<List<TraccarDevice>> getDevices({
    String? cookie,
    String? authHeader,
  }) async {
    final response = await _http.get(
      _uri('/devices'),
      headers: _headers(cookie: cookie, authHeader: authHeader),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao carregar dispositivos: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => TraccarDevice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TraccarPosition>> getPositions({
    String? cookie,
    String? authHeader,
    int? deviceId,
  }) async {
    final response = await _http.get(
      _uri('/positions', deviceId == null ? null : {'deviceId': '$deviceId'}),
      headers: _headers(cookie: cookie, authHeader: authHeader),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao carregar posições: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => TraccarPosition.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TraccarUser>> getUsers({
    String? cookie,
    String? authHeader,
  }) async {
    final response = await _http.get(
      _uri('/users'),
      headers: _headers(cookie: cookie, authHeader: authHeader),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao carregar usuários: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => TraccarUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getServer({
    String? cookie,
    String? authHeader,
  }) async {
    final response = await _http.get(
      _uri('/server'),
      headers: _headers(cookie: cookie, authHeader: authHeader),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao carregar servidor: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data;
  }

  Future<List<String>> getTimezones({
    String? cookie,
    String? authHeader,
  }) async {
    final response = await _http.get(
      _uri('/server/timezones'),
      headers: _headers(cookie: cookie, authHeader: authHeader),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao carregar fusos: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => e.toString()).toList(growable: false);
  }

  Future<String?> reverseGeocode({
    String? cookie,
    String? authHeader,
    required double latitude,
    required double longitude,
  }) async {
    final response = await _http.get(
      _uri('/server/geocode', {
        'latitude': '$latitude',
        'longitude': '$longitude',
      }),
      headers: _headers(cookie: cookie, authHeader: authHeader),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao geocodificar: ${response.statusCode}');
    }

    final text = response.body.trim();
    return text.isEmpty ? null : text;
  }

  Future<List<Map<String, dynamic>>> getComputedAttributes({
    String? cookie,
    String? authHeader,
    bool all = true,
  }) {
    return getList(
      path: '/attributes/computed',
      cookie: cookie,
      authHeader: authHeader,
      query: all ? {'all': 'true'} : null,
    );
  }

  Future<List<Map<String, dynamic>>> getCommandTypes({
    String? cookie,
    String? authHeader,
    int? deviceId,
  }) {
    return getList(
      path: '/commands/types',
      cookie: cookie,
      authHeader: authHeader,
      query: deviceId == null ? null : {'deviceId': '$deviceId'},
    );
  }

  Future<List<Map<String, dynamic>>> getNotificationTypes({
    String? cookie,
    String? authHeader,
  }) {
    return getList(
      path: '/notifications/types',
      cookie: cookie,
      authHeader: authHeader,
    );
  }

  Future<List<Map<String, dynamic>>> getStatistics({
    String? cookie,
    String? authHeader,
    required DateTime from,
    required DateTime to,
  }) {
    return getList(
      path: '/statistics',
      cookie: cookie,
      authHeader: authHeader,
      query: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> getReport({
    required String path,
    String? cookie,
    String? authHeader,
    required DateTime from,
    required DateTime to,
    int? deviceId,
    Map<String, dynamic>? extraQuery,
  }) {
    return getList(
      path: path,
      cookie: cookie,
      authHeader: authHeader,
      query: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        if (deviceId != null) 'deviceId': '$deviceId',
        ...?extraQuery,
      },
    );
  }

  Future<TraccarUser> createUser({
    String? cookie,
    String? authHeader,
    required Map<String, dynamic> body,
  }) async {
    final response = await _http.post(
      _uri('/users'),
      headers: _headers(cookie: cookie, authHeader: authHeader, json: true),
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao criar usuário: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return TraccarUser.fromJson(data);
  }

  Future<TraccarDevice> createDevice({
    String? cookie,
    String? authHeader,
    required Map<String, dynamic> body,
  }) async {
    final response = await _http.post(
      _uri('/devices'),
      headers: _headers(cookie: cookie, authHeader: authHeader, json: true),
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao criar dispositivo: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return TraccarDevice.fromJson(data);
  }

  Future<List<Map<String, dynamic>>> getList({
    required String path,
    String? cookie,
    String? authHeader,
    Map<String, dynamic>? query,
  }) async {
    final response = await _http.get(
      _uri(path, query),
      headers: _headers(cookie: cookie, authHeader: authHeader),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Falha ao carregar $path: ${response.statusCode}');
    }

    if (response.statusCode == 204 || response.body.trim().isEmpty) {
      return [];
    }

    final data = jsonDecode(response.body);
    if (data is List) {
      return data.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    if (data is Map) {
      return [data.cast<String, dynamic>()];
    }
    return [];
  }

  Future<Map<String, dynamic>> createEntity({
    required String path,
    String? cookie,
    String? authHeader,
    required Map<String, dynamic> body,
  }) async {
    final response = await _http.post(
      _uri(path),
      headers: _headers(cookie: cookie, authHeader: authHeader, json: true),
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao criar $path: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data;
  }

  Future<Map<String, dynamic>> updateEntity({
    required String path,
    String? cookie,
    String? authHeader,
    required Map<String, dynamic> body,
  }) async {
    final response = await _http.put(
      _uri(path),
      headers: _headers(cookie: cookie, authHeader: authHeader, json: true),
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao atualizar $path: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data;
  }

  Future<Map<String, dynamic>> updateEntityById({
    required String path,
    required int id,
    String? cookie,
    String? authHeader,
    required Map<String, dynamic> body,
  }) {
    return updateEntity(
      path: '$path/$id',
      cookie: cookie,
      authHeader: authHeader,
      body: body,
    );
  }

  Future<void> deleteEntity({
    required String path,
    String? cookie,
    String? authHeader,
  }) async {
    final response = await _http.delete(
      _uri(path),
      headers: _headers(cookie: cookie, authHeader: authHeader),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Falha ao excluir $path: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> getTenantConfig({
    String? cookie,
    String? authHeader,
  }) async {
    final candidates = <String>[
      '/api/souassist/tenant/config',
      '/tenant/config',
      '/tenant/me',
      '/souassist/tenant/config',
    ];

    for (final path in candidates) {
      final response = await _http.get(
        _souAssistUri(path),
        headers: _headers(cookie: cookie, authHeader: authHeader),
      );

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        if (data is Map) {
          return data.cast<String, dynamic>();
        }
      }
    }

    throw Exception('Falha ao carregar tenant config');
  }
}
