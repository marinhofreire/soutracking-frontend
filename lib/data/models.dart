class TraccarDevice {
  TraccarDevice({
    required this.id,
    required this.name,
    required this.status,
    required this.lastUpdate,
    this.uniqueId,
    this.positionId,
    this.category,
    this.image,
    this.attributes,
  });

  final int id;
  final String name;
  final String status;
  final String? lastUpdate;
  final String? uniqueId;
  final int? positionId;
  final String? category;
  final String? image;
  final Map<String, dynamic>? attributes;

  factory TraccarDevice.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'] is Map
        ? (json['attributes'] as Map).cast<String, dynamic>()
        : null;
    // Traccar não tem campo nativo de foto de veículo -- foto de upload
    // (2026-09-05) fica em attributes.souVehiclePhoto (data URL base64,
    // mesmo padrão do logo/imagem de login). json['image']/['photo'] como
    // fallback, caso um dia venha de outra fonte.
    final uploadedPhoto = attrs?['souVehiclePhoto'] as String?;
    return TraccarDevice(
      id: json['id'] as int,
      name: (json['name'] ?? 'Sem nome') as String,
      status: (json['status'] ?? 'unknown') as String,
      lastUpdate: json['lastUpdate'] as String?,
      uniqueId: json['uniqueId'] as String?,
      positionId: json['positionId'] as int?,
      category: json['category'] as String?,
      image: (uploadedPhoto?.isNotEmpty ?? false)
          ? uploadedPhoto
          : (json['image'] ?? json['photo']) as String?,
      attributes: attrs,
    );
  }
}

class TraccarPosition {
  TraccarPosition({
    required this.id,
    required this.deviceId,
    required this.latitude,
    required this.longitude,
    required this.fixTime,
    this.speed,
    this.course,
    this.address,
    this.attributes,
  });

  final int id;
  final int deviceId;
  final double latitude;
  final double longitude;
  final String fixTime;
  final double? speed;
  final double? course;
  final String? address;
  final Map<String, dynamic>? attributes;

  factory TraccarPosition.fromJson(Map<String, dynamic> json) {
    return TraccarPosition(
      id: json['id'] as int,
      deviceId: json['deviceId'] as int,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      fixTime: (json['fixTime'] ?? '') as String,
      speed: json['speed'] == null ? null : (json['speed'] as num).toDouble(),
      course: _readOptionalDouble(
        json['course'] ?? json['heading'] ?? json['bearing'],
      ),
      address: json['address'] as String?,
      attributes: json['attributes'] is Map
          ? (json['attributes'] as Map).cast<String, dynamic>()
          : null,
    );
  }
}

double? _readOptionalDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) {
    final normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }
  return null;
}

class TraccarSession {
  TraccarSession({
    required this.cookie,
    required this.authHeader,
    required this.user,
  });

  final String cookie;
  final String authHeader;
  final Map<String, dynamic> user;
}

class TraccarUser {
  TraccarUser({
    required this.id,
    required this.name,
    required this.email,
    required this.administrator,
    required this.readonly,
    required this.disabled,
    this.userLimit = 0,
    this.deviceLimit = 0,
    this.attributes,
  });

  final int id;
  final String name;
  final String email;
  final bool administrator;
  final bool readonly;
  final bool disabled;
  // 0 = sem limite (padrão do Traccar). >0 = teto de sub-usuários/devices
  // que esse usuário (como Manager) pode criar por baixo dele.
  final int userLimit;
  final int deviceLimit;
  final Map<String, dynamic>? attributes;

  String get soutrackingRole =>
      (attributes?['soutracking_role'] ?? '').toString().trim().toLowerCase();

  // Foto de perfil, mesmo padrao do souVehiclePhoto (upload, data URL
  // base64 salva em attributes) -- sem campo nativo de avatar no Traccar.
  String get photoUrl =>
      (attributes?['souUserPhoto'] ?? '').toString().trim();

  // Manager = "empresa" no modelo de multi-tenant do Painel Master: um
  // usuário comum (não administrator) mas com limite configurado, que cria
  // e isola os próprios sub-usuários/dispositivos por baixo dele -- suporte
  // nativo do Traccar, não é conceito novo nosso.
  bool get isManager =>
      !administrator && (userLimit > 0 || deviceLimit > 0);

  // Módulos internos (SouTracking/SouCall/SouFind) habilitados pro Manager
  // dessa empresa -- guardado em attributes.sou_modules, formato
  // "soutracking,soucall" (lista separada por vírgula, texto simples pra
  // não depender de parser JSON aninhado nos attributes do Traccar).
  Set<String> get enabledModules => (attributes?['sou_modules'] ?? '')
      .toString()
      .split(',')
      .map((m) => m.trim().toLowerCase())
      .where((m) => m.isNotEmpty)
      .toSet();

  // Chaves/credenciais isoladas por empresa (cada Manager tem as próprias,
  // nunca compartilha com outra empresa) -- mesmo motivo já registrado em
  // memória: canal WhatsApp compartilhado entre clientes já causou ban de
  // número antes. Guardadas em attributes com prefixo "sou_key_" pra não
  // colidir com outros atributos custom do Traccar.
  String get iaApiKey => (attributes?['sou_key_ia'] ?? '').toString();
  String get souCallToken => (attributes?['sou_key_soucall'] ?? '').toString();
  String get bridgeSouFindKey =>
      (attributes?['sou_key_bridge_soufind'] ?? '').toString();

  factory TraccarUser.fromJson(Map<String, dynamic> json) {
    return TraccarUser(
      id: json['id'] as int,
      name: (json['name'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      administrator: json['administrator'] == true,
      readonly: json['readonly'] == true,
      disabled: json['disabled'] == true,
      userLimit: (json['userLimit'] as num?)?.toInt() ?? 0,
      deviceLimit: (json['deviceLimit'] as num?)?.toInt() ?? 0,
      attributes: json['attributes'] is Map
          ? (json['attributes'] as Map).cast<String, dynamic>()
          : null,
    );
  }
}

class TraccarDriver {
  TraccarDriver({
    required this.id,
    required this.name,
    required this.uniqueId,
    this.attributes,
  });

  final int id;
  final String name;
  final String uniqueId;
  final Map<String, dynamic>? attributes;

  factory TraccarDriver.fromJson(Map<String, dynamic> json) {
    return TraccarDriver(
      id: json['id'] as int,
      name: (json['name'] ?? '') as String,
      uniqueId: (json['uniqueId'] ?? '') as String,
      attributes: json['attributes'] is Map
          ? (json['attributes'] as Map).cast<String, dynamic>()
          : null,
    );
  }
}
