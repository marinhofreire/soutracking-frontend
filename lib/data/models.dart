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
    return TraccarDevice(
      id: json['id'] as int,
      name: (json['name'] ?? 'Sem nome') as String,
      status: (json['status'] ?? 'unknown') as String,
      lastUpdate: json['lastUpdate'] as String?,
      uniqueId: json['uniqueId'] as String?,
      positionId: json['positionId'] as int?,
      category: json['category'] as String?,
      image: (json['image'] ?? json['photo']) as String?,
      attributes: json['attributes'] is Map
          ? (json['attributes'] as Map).cast<String, dynamic>()
          : null,
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
    this.attributes,
  });

  final int id;
  final String name;
  final String email;
  final bool administrator;
  final bool readonly;
  final bool disabled;
  final Map<String, dynamic>? attributes;

  String get soutrackingRole =>
      (attributes?['soutracking_role'] ?? '').toString().trim().toLowerCase();

  factory TraccarUser.fromJson(Map<String, dynamic> json) {
    return TraccarUser(
      id: json['id'] as int,
      name: (json['name'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      administrator: json['administrator'] == true,
      readonly: json['readonly'] == true,
      disabled: json['disabled'] == true,
      attributes: json['attributes'] is Map
          ? (json['attributes'] as Map).cast<String, dynamic>()
          : null,
    );
  }
}
