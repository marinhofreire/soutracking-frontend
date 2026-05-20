import 'package:flutter/material.dart';

enum SensorDisplayGroup {
  status,
  energy,
  communication,
  operational,
  technical,
}

String sensorDisplayGroupTitle(SensorDisplayGroup group) {
  switch (group) {
    case SensorDisplayGroup.status:
      return 'Status do ve\u00EDculo';
    case SensorDisplayGroup.energy:
      return 'Energia';
    case SensorDisplayGroup.communication:
      return 'Comunica\u00E7\u00E3o';
    case SensorDisplayGroup.operational:
      return 'Operacional';
    case SensorDisplayGroup.technical:
      return 'T\u00E9cnico';
  }
}

class SensorDisplayItem {
  const SensorDisplayItem({
    required this.key,
    required this.label,
    required this.value,
    required this.group,
    required this.icon,
    required this.technical,
  });

  final String key;
  final String label;
  final String value;
  final SensorDisplayGroup group;
  final IconData icon;
  final bool technical;
}

class SensorDisplaySection {
  const SensorDisplaySection({
    required this.group,
    required this.title,
    required this.items,
  });

  final SensorDisplayGroup group;
  final String title;
  final List<SensorDisplayItem> items;
}

class _SensorDefinition {
  const _SensorDefinition({
    required this.canonicalKey,
    required this.label,
    required this.group,
    required this.icon,
    required this.aliases,
    this.technical = false,
  });

  final String canonicalKey;
  final String label;
  final SensorDisplayGroup group;
  final IconData icon;
  final Set<String> aliases;
  final bool technical;
}

const List<_SensorDefinition> _definitions = [
  _SensorDefinition(
    canonicalKey: 'ignition',
    label: 'Igni\u00E7\u00E3o',
    group: SensorDisplayGroup.status,
    icon: Icons.power_settings_new_outlined,
    aliases: {'ignition', 'ignitionon'},
  ),
  _SensorDefinition(
    canonicalKey: 'motion',
    label: 'Movimento',
    group: SensorDisplayGroup.status,
    icon: Icons.directions_walk_outlined,
    aliases: {'motion', 'moving'},
  ),
  _SensorDefinition(
    canonicalKey: 'door',
    label: 'Porta/Entrada',
    group: SensorDisplayGroup.status,
    icon: Icons.door_front_door_outlined,
    aliases: {'door', 'input', 'input1', 'entrada'},
  ),
  _SensorDefinition(
    canonicalKey: 'blocked',
    label: 'Bloqueio/Corte',
    group: SensorDisplayGroup.status,
    icon: Icons.block_outlined,
    aliases: {'blocked', 'block', 'engineblocked', 'relay', 'immobilizer'},
  ),
  _SensorDefinition(
    canonicalKey: 'gpsTracking',
    label: 'GPS ativo',
    group: SensorDisplayGroup.status,
    icon: Icons.gps_fixed_outlined,
    aliases: {'gpstracking', 'gpsactive', 'gpsenabled'},
  ),
  _SensorDefinition(
    canonicalKey: 'power',
    label: 'Tens\u00E3o do ve\u00EDculo',
    group: SensorDisplayGroup.energy,
    icon: Icons.bolt_outlined,
    aliases: {'power', 'voltage', 'mainvoltage'},
  ),
  _SensorDefinition(
    canonicalKey: 'battery',
    label: 'Bateria interna',
    group: SensorDisplayGroup.energy,
    icon: Icons.battery_charging_full_outlined,
    aliases: {'battery', 'batteryvoltage', 'devicebattery', 'backupbattery'},
  ),
  _SensorDefinition(
    canonicalKey: 'batteryLevel',
    label: 'N\u00EDvel da bateria',
    group: SensorDisplayGroup.energy,
    icon: Icons.battery_5_bar_outlined,
    aliases: {'batterylevel', 'batterypercent', 'devicebatterylevel'},
  ),
  _SensorDefinition(
    canonicalKey: 'charge',
    label: 'Carga/Alimenta\u00E7\u00E3o',
    group: SensorDisplayGroup.energy,
    icon: Icons.electrical_services_outlined,
    aliases: {'charge', 'charging', 'externalpower'},
  ),
  _SensorDefinition(
    canonicalKey: 'gsm',
    label: 'Sinal GSM',
    group: SensorDisplayGroup.communication,
    icon: Icons.network_cell_outlined,
    aliases: {'gsm', 'signal', 'gsmsignal'},
  ),
  _SensorDefinition(
    canonicalKey: 'rssi',
    label: 'RSSI',
    group: SensorDisplayGroup.communication,
    icon: Icons.signal_cellular_alt_outlined,
    aliases: {'rssi'},
  ),
  _SensorDefinition(
    canonicalKey: 'mcc',
    label: 'MCC',
    group: SensorDisplayGroup.communication,
    icon: Icons.pin_outlined,
    aliases: {'mcc'},
  ),
  _SensorDefinition(
    canonicalKey: 'mnc',
    label: 'MNC',
    group: SensorDisplayGroup.communication,
    icon: Icons.pin_outlined,
    aliases: {'mnc'},
  ),
  _SensorDefinition(
    canonicalKey: 'lac',
    label: 'LAC',
    group: SensorDisplayGroup.communication,
    icon: Icons.pin_outlined,
    aliases: {'lac'},
  ),
  _SensorDefinition(
    canonicalKey: 'cid',
    label: 'CID',
    group: SensorDisplayGroup.communication,
    icon: Icons.pin_outlined,
    aliases: {'cid'},
  ),
  _SensorDefinition(
    canonicalKey: 'satellites',
    label: 'Sat\u00E9lites',
    group: SensorDisplayGroup.communication,
    icon: Icons.satellite_alt_outlined,
    aliases: {'sat', 'satellites'},
  ),
  _SensorDefinition(
    canonicalKey: 'odometer',
    label: 'Od\u00F4metro',
    group: SensorDisplayGroup.operational,
    icon: Icons.av_timer_outlined,
    aliases: {'odometer', 'distance', 'totaldistance'},
  ),
  _SensorDefinition(
    canonicalKey: 'totalHours',
    label: 'Hor\u00EDmetro',
    group: SensorDisplayGroup.operational,
    icon: Icons.schedule_outlined,
    aliases: {'totalhours', 'hours', 'enginehours'},
  ),
  _SensorDefinition(
    canonicalKey: 'activated',
    label: 'Equipamento ativado',
    group: SensorDisplayGroup.technical,
    icon: Icons.verified_user_outlined,
    aliases: {'activated'},
    technical: true,
  ),
  _SensorDefinition(
    canonicalKey: 'nt20.frame',
    label: 'Frame NT20',
    group: SensorDisplayGroup.technical,
    icon: Icons.memory_outlined,
    aliases: {'nt20frame'},
    technical: true,
  ),
  _SensorDefinition(
    canonicalKey: 'nt20.rawProtocol',
    label: 'Protocolo bruto',
    group: SensorDisplayGroup.technical,
    icon: Icons.code_outlined,
    aliases: {'nt20rawprotocol'},
    technical: true,
  ),
  _SensorDefinition(
    canonicalKey: 'terminalInfo',
    label: 'Terminal info',
    group: SensorDisplayGroup.technical,
    icon: Icons.terminal_outlined,
    aliases: {'terminalinfo', 'terminal', 'deviceinfo', 'nt20terminalinfo'},
    technical: true,
  ),
  _SensorDefinition(
    canonicalKey: 'locationSource',
    label: 'Origem da localiza\u00E7\u00E3o',
    group: SensorDisplayGroup.technical,
    icon: Icons.my_location_outlined,
    aliases: {
      'positionsource',
      'locationsource',
      'typeoflocationsource',
      'tipodeorigemdelocalizacao',
    },
    technical: true,
  ),
  _SensorDefinition(
    canonicalKey: 'nt20.totalHoursSum',
    label: 'Hor\u00EDmetro bruto',
    group: SensorDisplayGroup.technical,
    icon: Icons.timelapse_outlined,
    aliases: {'nt20totalhourssum'},
    technical: true,
  ),
  _SensorDefinition(
    canonicalKey: 'internalDateTime',
    label: 'Data/hora interna',
    group: SensorDisplayGroup.technical,
    icon: Icons.access_time_outlined,
    aliases: {'internaldatetime'},
    technical: true,
  ),
  _SensorDefinition(
    canonicalKey: 'gpsDateTime',
    label: 'Data/hora GPS',
    group: SensorDisplayGroup.technical,
    icon: Icons.schedule_outlined,
    aliases: {'gpsdatetime'},
    technical: true,
  ),
];

final Map<String, _SensorDefinition> _canonicalToDefinition = {
  for (final def in _definitions) def.canonicalKey: def,
};

final Map<String, String> _aliasToCanonical = () {
  final map = <String, String>{};
  for (final def in _definitions) {
    for (final alias in def.aliases) {
      map[_normalizeKey(alias)] = def.canonicalKey;
    }
    map[_normalizeKey(def.canonicalKey)] = def.canonicalKey;
  }
  return map;
}();

const List<String> _orderedCanonicalKeys = [
  'ignition',
  'motion',
  'door',
  'blocked',
  'gpsTracking',
  'power',
  'battery',
  'batteryLevel',
  'charge',
  'gsm',
  'rssi',
  'mcc',
  'mnc',
  'lac',
  'cid',
  'satellites',
  'odometer',
  'totalHours',
  'activated',
  'nt20.frame',
  'nt20.rawProtocol',
  'terminalInfo',
  'locationSource',
  'nt20.totalHoursSum',
  'internalDateTime',
  'gpsDateTime',
];

List<MapEntry<String, String>> sensorSelectionOptions() {
  const ordered = [
    'ignition',
    'motion',
    'door',
    'blocked',
    'gpsTracking',
    'power',
    'battery',
    'batteryLevel',
    'charge',
    'gsm',
    'rssi',
    'satellites',
    'mcc',
    'mnc',
    'lac',
    'cid',
    'odometer',
    'totalHours',
  ];
  return [
    for (final key in ordered)
      if (_canonicalToDefinition[key] case final def?)
        MapEntry(def.canonicalKey, def.label),
  ];
}

bool hasValidGpsPosition({
  required double? latitude,
  required double? longitude,
  Map<String, dynamic>? attributes,
}) {
  final lat = latitude;
  final lng = longitude;
  if (lat == null || lng == null) return false;
  if (lat == 0 && lng == 0) return false;

  final attrs = attributes ?? const <String, dynamic>{};
  final valid = _toBool(attrs['valid'] ?? attrs['gpsValid']);
  if (valid == false) return false;

  return true;
}

String formatGpsCoordinateLabel({
  required double? latitude,
  required double? longitude,
  Map<String, dynamic>? attributes,
}) {
  if (!hasValidGpsPosition(
    latitude: latitude,
    longitude: longitude,
    attributes: attributes,
  )) {
    return 'Sem GPS v\u00E1lido';
  }

  return '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}';
}

List<SensorDisplaySection> buildSensorDisplaySections({
  Map<String, dynamic>? deviceAttributes,
  Map<String, dynamic>? positionAttributes,
  bool includeTechnical = false,
  Iterable<String>? preferredKeys,
}) {
  final merged = <String, dynamic>{
    ...?deviceAttributes,
    ...?positionAttributes,
  };
  if (merged.isEmpty) return const [];

  final canonicalValues = <String, dynamic>{};
  final rawUnknown = <String, dynamic>{};

  for (final entry in merged.entries) {
    final key = entry.key.trim();
    if (key.isEmpty) continue;
    final canonical = _canonicalFromKey(key);
    if (canonical == null) {
      rawUnknown[key] = entry.value;
      continue;
    }
    canonicalValues[canonical] = entry.value;
  }

  final ordered = <String>[];
  final seen = <String>{};

  void push(String key) {
    if (seen.add(key)) {
      ordered.add(key);
    }
  }

  if (preferredKeys != null) {
    for (final key in preferredKeys) {
      final canonical = _canonicalFromKey(key);
      if (canonical != null) {
        push(canonical);
      }
    }
  }

  for (final key in _orderedCanonicalKeys) {
    push(key);
  }

  final rows = <SensorDisplayItem>[];

  for (final canonical in ordered) {
    final def = _canonicalToDefinition[canonical];
    if (def == null) continue;
    if (def.technical && !includeTechnical) continue;

    final raw = canonicalValues[canonical];
    if (!_hasContent(raw)) continue;

    final value = _formatByCanonicalKey(canonical, raw);
    if (!_hasContent(value)) continue;

    rows.add(
      SensorDisplayItem(
        key: canonical,
        label: def.label,
        value: value!,
        group: def.group,
        icon: def.icon,
        technical: def.technical,
      ),
    );
  }

  if (includeTechnical) {
    final unknownKeys = rawUnknown.keys.toList()..sort();
    for (final key in unknownKeys) {
      final raw = rawUnknown[key];
      if (!_hasContent(raw)) continue;
      final value = _formatGenericValue(raw);
      if (!_hasContent(value)) continue;

      rows.add(
        SensorDisplayItem(
          key: key,
          label: _humanizeUnknownKey(key),
          value: value!,
          group: SensorDisplayGroup.technical,
          icon: Icons.developer_mode_outlined,
          technical: true,
        ),
      );
    }
  }

  if (rows.isEmpty) return const [];

  final sections = <SensorDisplaySection>[];
  for (final group in SensorDisplayGroup.values) {
    final items = rows.where((row) => row.group == group).toList(growable: false);
    if (items.isEmpty) continue;
    sections.add(
      SensorDisplaySection(
        group: group,
        title: sensorDisplayGroupTitle(group),
        items: items,
      ),
    );
  }
  return sections;
}

String? _canonicalFromKey(String rawKey) {
  final normalized = _normalizeKey(rawKey);
  if (normalized.isEmpty) return null;
  return _aliasToCanonical[normalized];
}

String _normalizeKey(String key) {
  final lowered = _removeDiacritics(key.toLowerCase().trim());
  return lowered.replaceAll(RegExp(r'[^a-z0-9]'), '');
}

String _removeDiacritics(String value) {
  const from = '\u00E1\u00E0\u00E3\u00E2\u00E4\u00E9\u00E8\u00EA\u00EB\u00ED\u00EC\u00EE\u00EF\u00F3\u00F2\u00F5\u00F4\u00F6\u00FA\u00F9\u00FB\u00FC\u00E7\u00F1';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    if (index >= 0) {
      buffer.write(to[index]);
    } else {
      buffer.write(char);
    }
  }
  return buffer.toString();
}

bool _hasContent(dynamic value) {
  if (value == null) return false;
  if (value is String) return value.trim().isNotEmpty;
  return true;
}

String? _formatByCanonicalKey(String key, dynamic raw) {
  switch (key) {
    case 'power':
      return _formatVoltage(raw);
    case 'battery':
      return _formatVoltage(raw);
    case 'batteryLevel':
      return _formatPercent(raw);
    case 'charge':
      final boolValue = _toBool(raw);
      if (boolValue != null) return boolValue ? 'Sim' : 'N\u00E3o';
      final number = _toDouble(raw);
      if (number != null) return '${_formatDecimal(number, 2)} V';
      return _formatGenericValue(raw);
    case 'rssi':
      final number = _toDouble(raw);
      if (number == null) return _formatGenericValue(raw);
      return '${number.toStringAsFixed(0)} dBm';
    case 'satellites':
      final number = _toDouble(raw);
      if (number == null) return _formatGenericValue(raw);
      return number.toStringAsFixed(0);
    case 'odometer':
      return _formatDistanceKm(raw);
    case 'totalHours':
      return _formatHours(raw);
    case 'nt20.totalHoursSum':
      return _formatHours(raw);
    case 'gpsDateTime':
    case 'internalDateTime':
      return _formatDateTime(raw);
    case 'locationSource':
      return _formatLocationSource(raw);
    case 'ignition':
    case 'motion':
    case 'door':
    case 'blocked':
    case 'gpsTracking':
    case 'activated':
      final boolValue = _toBool(raw);
      if (boolValue == null) return _formatGenericValue(raw);
      return boolValue ? 'Sim' : 'N\u00E3o';
    default:
      return _formatGenericValue(raw);
  }
}

String? _formatVoltage(dynamic raw) {
  final number = _toDouble(raw);
  if (number == null) return _formatGenericValue(raw);
  return '${_formatDecimal(number, 2)} V';
}

String? _formatPercent(dynamic raw) {
  final number = _toDouble(raw);
  if (number == null) return _formatGenericValue(raw);
  final percent = number <= 1 ? number * 100 : number;
  return '${_formatDecimal(percent, 0)}%';
}

String? _formatDistanceKm(dynamic raw) {
  final number = _toDouble(raw);
  if (number == null) return _formatGenericValue(raw);
  final km = number / 1000;
  return '${_formatDecimal(km, 2)} km';
}

String? _formatHours(dynamic raw) {
  final number = _toDouble(raw);
  if (number == null) return _formatGenericValue(raw);

  double hours = number;
  if (number > 100000) {
    hours = number / 3600;
  }

  final totalMinutes = (hours * 60).round();
  final hh = totalMinutes ~/ 60;
  final mm = totalMinutes % 60;
  return '${hh}h ${mm.toString().padLeft(2, '0')}min';
}

String? _formatDateTime(dynamic raw) {
  final text = raw?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return text;
  final local = parsed.isUtc ? parsed.toLocal() : parsed;
  final dd = local.day.toString().padLeft(2, '0');
  final mm = local.month.toString().padLeft(2, '0');
  final yyyy = local.year.toString().padLeft(4, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  final ss = local.second.toString().padLeft(2, '0');
  return '$dd/$mm/$yyyy $hh:$min:$ss';
}

String? _formatLocationSource(dynamic raw) {
  final text = raw?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  final normalized = _normalizeKey(text);
  switch (normalized) {
    case 'gps':
      return 'GPS';
    case 'network':
      return 'Rede';
    case 'cell':
      return 'Celular';
    case 'wifi':
      return 'Wi-Fi';
    default:
      return text;
  }
}

String? _formatGenericValue(dynamic raw) {
  if (raw == null) return null;
  if (raw is bool) return raw ? 'Sim' : 'N\u00E3o';
  if (raw is num) {
    if (raw % 1 == 0) return raw.toInt().toString();
    return _formatDecimal(raw.toDouble(), 2);
  }
  final text = raw.toString().trim();
  return text.isEmpty ? null : text;
}

double? _toDouble(dynamic raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text.replaceAll(',', '.'));
  }
  return null;
}

bool? _toBool(dynamic raw) {
  if (raw is bool) return raw;
  if (raw is num) return raw > 0;
  if (raw is String) {
    final normalized = _normalizeKey(raw);
    if (normalized.isEmpty) return null;
    if (normalized == 'true' ||
        normalized == '1' ||
        normalized == 'sim' ||
        normalized == 'on' ||
        normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' ||
        normalized == '0' ||
        normalized == 'nao' ||
        normalized == 'no' ||
        normalized == 'off') {
      return false;
    }
  }
  return null;
}

String _formatDecimal(double value, int fractionDigits) {
  return value.toStringAsFixed(fractionDigits).replaceAll('.', ',');
}

String _humanizeUnknownKey(String rawKey) {
  final cleaned = rawKey
      .replaceAll('.', ' ')
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .trim();
  if (cleaned.isEmpty) return 'Atributo t\u00E9cnico';
  final first = cleaned.substring(0, 1).toUpperCase();
  final rest = cleaned.length > 1 ? cleaned.substring(1) : '';
  return '$first$rest';
}
