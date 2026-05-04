import 'dart:convert';

import 'package:http/http.dart' as http;

class OpenF1Client {
  OpenF1Client({
    http.Client? httpClient,
    String? baseUrl,
  })  : _http = httpClient ?? http.Client(),
        _baseUrl = _normalizeBaseUrl(baseUrl ?? 'https://api.openf1.org/v1');

  final http.Client _http;
  final String _baseUrl;

  static String _normalizeBaseUrl(String value) {
    var base = value.trim();
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    return Uri.parse('$_baseUrl$path').replace(
      queryParameters: query?.map(
        (key, value) => MapEntry(key, value?.toString()),
      ),
    );
  }

  Future<List<dynamic>> _getList(
    String path, [
    Map<String, dynamic>? query,
  ]) async {
    final response = await _http.get(
      _uri(path, query),
      headers: const {'Accept': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('OpenF1 HTTP ${response.statusCode} em $path');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is List<dynamic>) {
      return decoded;
    }

    throw Exception('OpenF1 retornou formato invalido em $path');
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '--:--:--';
    final local = value.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final ss = local.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  Future<OpenF1SessionSnapshot?> buscarSessaoAtualOuUltima() async {
    try {
      final latest = await _getList('/sessions', {'session_key': 'latest'});
      if (latest.isNotEmpty && latest.first is Map<String, dynamic>) {
        return OpenF1SessionSnapshot.fromJson(
          latest.first as Map<String, dynamic>,
        );
      }
    } catch (_) {}

    final currentYear = DateTime.now().year;
    final sessions = await _getList('/sessions', {'year': currentYear});

    final parsed = sessions
        .whereType<Map<String, dynamic>>()
        .map(OpenF1SessionSnapshot.fromJson)
        .toList(growable: false)
      ..sort((a, b) => b.dateStart.compareTo(a.dateStart));

    if (parsed.isEmpty) {
      return null;
    }

    return parsed.first;
  }

  Future<List<OpenF1DriverSnapshot>> buscarPilotosDaSessao({
    required int sessionKey,
  }) async {
    final drivers = await _getList('/drivers', {'session_key': sessionKey});

    return drivers
        .whereType<Map<String, dynamic>>()
        .map(OpenF1DriverSnapshot.fromJson)
        .where((driver) => driver.driverNumber > 0)
        .toList(growable: false);
  }

  Future<OpenF1CarSnapshot?> buscarCarData({
    required int sessionKey,
    required int driverNumber,
  }) async {
    final rows = await _getList(
      '/car_data',
      {
        'session_key': sessionKey,
        'driver_number': driverNumber,
      },
    );

    final parsed =
        rows.whereType<Map<String, dynamic>>().toList(growable: false)
          ..sort((a, b) {
            final dateA = _toDate(a['date']);
            final dateB = _toDate(b['date']);
            if (dateA == null && dateB == null) return 0;
            if (dateA == null) return -1;
            if (dateB == null) return 1;
            return dateA.compareTo(dateB);
          });

    if (parsed.isEmpty) {
      return null;
    }

    final latest = parsed.last;
    return OpenF1CarSnapshot(
      speedKmh: _toInt(latest['speed']),
      rpm: _toInt(latest['rpm']),
      gear: _toInt(latest['n_gear']),
      throttle: _toInt(latest['throttle']),
      brake: _toInt(latest['brake']),
      sampleTime: _formatTime(_toDate(latest['date'])),
    );
  }

  Future<List<OpenF1RaceControlEvent>> _buscarEventosReais({
    required int sessionKey,
  }) async {
    final rows = await _getList('/race_control', {'session_key': sessionKey});

    final parsed =
        rows.whereType<Map<String, dynamic>>().toList(growable: false)
          ..sort((a, b) {
            final dateA = _toDate(a['date']);
            final dateB = _toDate(b['date']);
            if (dateA == null && dateB == null) return 0;
            if (dateA == null) return 1;
            if (dateB == null) return -1;
            return dateB.compareTo(dateA);
          });

    return parsed.take(10).map((json) {
      final message = (json['message'] ?? '').toString().trim();
      final category = (json['category'] ?? '').toString().trim();
      final flag = (json['flag'] ?? '').toString().trim();
      final title = message.isNotEmpty
          ? message
          : (category.isNotEmpty ? category : 'Evento de corrida');
      final lap = _toInt(json['lap_number']);
      final driver = _toInt(json['driver_number']);

      final details = <String>[
        if (driver != null) 'Piloto #$driver',
        if (lap != null) 'Volta $lap',
        if (flag.isNotEmpty) flag,
      ];

      final severityRaw = (flag.isNotEmpty ? flag : category).toLowerCase();
      var severity = 'Medio';
      if (severityRaw.contains('red') || severityRaw.contains('danger')) {
        severity = 'Alto';
      } else if (severityRaw.contains('green') ||
          severityRaw.contains('clear')) {
        severity = 'Baixo';
      }

      return OpenF1RaceControlEvent(
        timeLabel: _formatTime(_toDate(json['date'])),
        sectionLabel: category.isNotEmpty ? category : 'Race control',
        title: title,
        detail: details.isEmpty ? 'Sem detalhe adicional' : details.join(' • '),
        severity: severity,
        isSnapshot: false,
      );
    }).toList(growable: false);
  }

  Future<List<OpenF1RaceControlEvent>> buscarEventosOuMontarEventosDemo({
    required int sessionKey,
    required List<OpenF1RaceControlEvent> fallbackSnapshot,
  }) async {
    try {
      final real = await _buscarEventosReais(sessionKey: sessionKey);
      if (real.isNotEmpty) {
        return real;
      }
    } catch (_) {}

    return fallbackSnapshot
        .map(
          (event) => event.copyWith(
            isSnapshot: true,
          ),
        )
        .toList(growable: false);
  }
}

class OpenF1SessionSnapshot {
  const OpenF1SessionSnapshot({
    required this.sessionKey,
    required this.sessionName,
    required this.meetingName,
    required this.dateStart,
  });

  final int sessionKey;
  final String sessionName;
  final String meetingName;
  final DateTime dateStart;

  String get label {
    if (meetingName.isEmpty && sessionName.isEmpty) {
      return 'Sessao OpenF1';
    }
    if (meetingName.isEmpty) {
      return sessionName;
    }
    if (sessionName.isEmpty) {
      return meetingName;
    }
    return '$meetingName - $sessionName';
  }

  factory OpenF1SessionSnapshot.fromJson(Map<String, dynamic> json) {
    final sessionKey = json['session_key'];
    final rawDate = json['date_start'];
    return OpenF1SessionSnapshot(
      sessionKey: sessionKey is int
          ? sessionKey
          : int.tryParse(sessionKey?.toString() ?? '') ?? 0,
      sessionName: (json['session_name'] ?? '').toString(),
      meetingName: (json['meeting_name'] ?? '').toString(),
      dateStart: DateTime.tryParse(rawDate?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class OpenF1DriverSnapshot {
  const OpenF1DriverSnapshot({
    required this.driverNumber,
    required this.displayName,
  });

  final int driverNumber;
  final String displayName;

  factory OpenF1DriverSnapshot.fromJson(Map<String, dynamic> json) {
    final number = json['driver_number'];
    final fullName = (json['full_name'] ?? '').toString().trim();
    final broadcastName = (json['broadcast_name'] ?? '').toString().trim();
    final acronym = (json['name_acronym'] ?? '').toString().trim();

    final display = broadcastName.isNotEmpty
        ? broadcastName
        : (fullName.isNotEmpty ? fullName : acronym);

    return OpenF1DriverSnapshot(
      driverNumber:
          number is int ? number : int.tryParse(number?.toString() ?? '') ?? 0,
      displayName: display,
    );
  }
}

class OpenF1CarSnapshot {
  const OpenF1CarSnapshot({
    required this.speedKmh,
    required this.rpm,
    required this.gear,
    required this.throttle,
    required this.brake,
    required this.sampleTime,
  });

  final int? speedKmh;
  final int? rpm;
  final int? gear;
  final int? throttle;
  final int? brake;
  final String sampleTime;
}

class OpenF1RaceControlEvent {
  const OpenF1RaceControlEvent({
    required this.timeLabel,
    required this.sectionLabel,
    required this.title,
    required this.detail,
    required this.severity,
    required this.isSnapshot,
  });

  final String timeLabel;
  final String sectionLabel;
  final String title;
  final String detail;
  final String severity;
  final bool isSnapshot;

  OpenF1RaceControlEvent copyWith({
    String? timeLabel,
    String? sectionLabel,
    String? title,
    String? detail,
    String? severity,
    bool? isSnapshot,
  }) {
    return OpenF1RaceControlEvent(
      timeLabel: timeLabel ?? this.timeLabel,
      sectionLabel: sectionLabel ?? this.sectionLabel,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      severity: severity ?? this.severity,
      isSnapshot: isSnapshot ?? this.isSnapshot,
    );
  }
}
