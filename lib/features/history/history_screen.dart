import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/session_state.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  static const int _maxPositionRows = 300;
  static const int _maxEventRows = 300;
  static const List<String> _protocolCoreKeys = [
    'event',
    'ignition',
    'motion',
    'rssi',
    'power',
  ];

  static const List<String> _easyTrackE3PresetKeys = [
    'event',
    'ignition',
    'motion',
    'rssi',
    'sat',
    'power',
    'fuel',
    'blocked',
    'temp1',
    'adc1',
    'driveruniqueid',
    'odometer',
    'distance',
    'totaldistance',
    'hours',
    'command',
    'status',
    'alarm',
  ];

  static const List<String> _priorityProtocolKeys = [
    'protocol',
    'event',
    'alarm',
    'status',
    'ignition',
    'motion',
    'rssi',
    'sat',
    'power',
    'fuel',
    'speed',
    'odometer',
    'distance',
    'totaldistance',
    'hours',
    'command',
  ];

  int? _deviceId;
  DateTime _from = DateTime.now().subtract(const Duration(hours: 24));
  DateTime _to = DateTime.now();
  bool _loading = false;
  String _sourceFilter = 'Todos';
  String _severityFilter = 'Todos';
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _activeProtocolKeys = {..._protocolCoreKeys};
  String? _detectedProtocol;
  List<_HistoryLogRow> _rows = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _presetKeysForProtocol(String? protocolId) {
    final normalized = protocolId?.trim().toLowerCase() ?? '';
    if (normalized.contains('easytrack') || normalized.contains('e3')) {
      return _easyTrackE3PresetKeys;
    }
    return _protocolCoreKeys;
  }

  String? _detectProtocolFromPayload({
    required List<Map<String, dynamic>> positions,
    required List<Map<String, dynamic>> events,
  }) {
    final counts = <String, int>{};

    void collectFromRows(List<Map<String, dynamic>> rows) {
      for (final row in rows) {
        final attrs = _asMap(row['attributes']);
        final rawValue = row['protocol'] ?? attrs['protocol'];
        final value = '${rawValue ?? ''}'.trim().toLowerCase();
        if (value.isEmpty) continue;
        counts[value] = (counts[value] ?? 0) + 1;
      }
    }

    collectFromRows(positions);
    collectFromRows(events);

    if (counts.isEmpty) {
      return null;
    }

    final sorted = counts.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  void _applyPresetForProtocol(String? protocolId) {
    _activeProtocolKeys
      ..clear()
      ..addAll(_presetKeysForProtocol(protocolId));
  }

  void _onDeviceChanged(int? value, List<TraccarDevice> devices) {
    final selected = devices.where((device) => device.id == value).toList();
    final selectedDevice = selected.isEmpty ? null : selected.first;
    final attrs = selectedDevice?.attributes ?? const <String, dynamic>{};
    final inferredProtocol =
        '${attrs['protocol'] ?? attrs['deviceProtocol'] ?? attrs['model'] ?? ''}'
            .trim()
            .toLowerCase();

    setState(() {
      _deviceId = value;
      _rows = const [];
      _detectedProtocol = inferredProtocol.isEmpty ? null : inferredProtocol;
      _applyPresetForProtocol(_detectedProtocol);
    });
  }

  Future<void> _pickDateTime({required bool isFrom}) async {
    final current = isFrom ? _from : _to;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isFrom) {
        _from = selected;
      } else {
        _to = selected;
      }
    });
  }

  Future<void> _loadHistory() async {
    if (_deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um dispositivo.')),
      );
      return;
    }

    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    final query = <String, dynamic>{
      'deviceId': '$_deviceId',
      'from': _from.toUtc().toIso8601String(),
      'to': _to.toUtc().toIso8601String(),
    };

    setState(() => _loading = true);
    try {
      final responses = await Future.wait([
        client.getList(
          path: '/positions',
          cookie: session.cookie,
          authHeader: session.authHeader,
          query: query,
        ),
        client.getList(
          path: '/reports/events',
          cookie: session.cookie,
          authHeader: session.authHeader,
          query: query,
        ),
      ]);
      final positions = _trimRecentRows(
        responses[0],
        _maxPositionRows,
        _positionDateOf,
      );
      final events = _trimRecentRows(
        responses[1],
        _maxEventRows,
        _eventDateOf,
      );

      final mapped = <_HistoryLogRow>[
        ...positions.map(_mapPositionRow),
        ...events.map(_mapEventRow),
      ]..sort((a, b) {
          if (a.timestamp == null && b.timestamp == null) return 0;
          if (a.timestamp == null) return 1;
          if (b.timestamp == null) return -1;
          return b.timestamp!.compareTo(a.timestamp!);
        });

      final detectedProtocol = _detectProtocolFromPayload(
        positions: positions,
        events: events,
      );

      if (!mounted) return;
      setState(() {
        _rows = mapped;
        _detectedProtocol = detectedProtocol;
        _applyPresetForProtocol(_detectedProtocol);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao carregar histórico: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _trimRecentRows(
    List<Map<String, dynamic>> rows,
    int limit,
    DateTime? Function(Map<String, dynamic>) resolveDate,
  ) {
    if (rows.length <= limit) {
      return rows;
    }
    final sorted = [...rows]..sort((a, b) {
        final aDate = resolveDate(a);
        final bDate = resolveDate(b);
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
    return sorted.take(limit).toList(growable: false);
  }

  DateTime? _positionDateOf(Map<String, dynamic> raw) {
    return _parseDate(raw['fixTime'] ?? raw['deviceTime'] ?? raw['serverTime']);
  }

  DateTime? _eventDateOf(Map<String, dynamic> raw) {
    return _parseDate(raw['eventTime'] ?? raw['serverTime']);
  }

  _HistoryLogRow _mapPositionRow(Map<String, dynamic> raw) {
    final attributes = _asMap(raw['attributes']);
    final timestamp = _parseDate(
      raw['fixTime'] ?? raw['deviceTime'] ?? raw['serverTime'],
    );
    final lat = _asDouble(raw['latitude']) ?? _asDouble(attributes['latitude']);
    final lng =
        _asDouble(raw['longitude']) ?? _asDouble(attributes['longitude']);
    final speed = _asDouble(raw['speed']) ?? _asDouble(attributes['speed']);
    final ignition = _normalizeBooleanLabel(
      raw['ignition'] ?? attributes['ignition'] ?? attributes['ignitionOn'],
    );
    final battery = _resolveBattery(raw, attributes);

    return _HistoryLogRow(
      source: 'Posicao',
      timestamp: timestamp,
      type: 'Posicao',
      description: 'Comunicação de posicionamento',
      speedKmh: speed,
      ignition: ignition,
      battery: battery,
      lat: lat,
      lng: lng,
      origin: 'GPS',
      attributesSummary: _attributesSummary(attributes),
      protocolValues: _extractProtocolValues(raw: raw, attributes: attributes),
    );
  }

  _HistoryLogRow _mapEventRow(Map<String, dynamic> raw) {
    final attributes = _asMap(raw['attributes']);
    final timestamp = _parseDate(raw['eventTime'] ?? raw['serverTime']);
    final lat = _asDouble(raw['latitude']) ?? _asDouble(attributes['latitude']);
    final lng =
        _asDouble(raw['longitude']) ?? _asDouble(attributes['longitude']);
    final speed = _asDouble(raw['speed']) ?? _asDouble(attributes['speed']);
    final ignition = _normalizeBooleanLabel(
      raw['ignition'] ?? attributes['ignition'] ?? attributes['ignitionOn'],
    );
    final battery = _resolveBattery(raw, attributes);
    final eventType = '${raw['type'] ?? ''}'.trim();
    final alarm = '${attributes['alarm'] ?? ''}'.trim();
    final description = [
      if (eventType.isNotEmpty) _humanize(eventType),
      if (alarm.isNotEmpty) 'alarm=$alarm',
    ].join(' | ');

    return _HistoryLogRow(
      source: 'Evento',
      timestamp: timestamp,
      type: 'Evento',
      description: description.isEmpty ? 'Evento sem descricao' : description,
      speedKmh: speed,
      ignition: ignition,
      battery: battery,
      lat: lat,
      lng: lng,
      origin: 'Evento',
      attributesSummary: _attributesSummary(attributes),
      protocolValues: _extractProtocolValues(raw: raw, attributes: attributes),
    );
  }

  List<_HistoryLogRow> get _filteredRows {
    final search = _searchController.text.trim().toLowerCase();
    return _rows.where((row) {
      if (_sourceFilter != 'Todos' && row.source != _sourceFilter) {
        return false;
      }
      if (search.isEmpty) {
        return true;
      }
      final bag = [
        row.type,
        row.description,
        row.origin,
        row.attributesSummary,
        row.dateTimeLabel,
        row.protocolSearchBag,
      ].join(' ').toLowerCase();
      return bag.contains(search);
    }).toList(growable: false);
  }

  String _fmt(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  String _severityFromText(String value) {
    final lower = value.trim().toLowerCase();
    if (lower.isEmpty || lower == '-') {
      return 'Info';
    }
    if (lower.contains('alarm') ||
        lower.contains('overspeed') ||
        lower.contains('panic') ||
        lower.contains('excesso')) {
      return 'Alerta';
    }
    if (lower.contains('off') ||
        lower.contains('unknown') ||
        lower.contains('sem comunicacao') ||
        lower.contains('desligad')) {
      return 'Aviso';
    }
    return 'Info';
  }

  String _severityFromField({
    required String field,
    required String value,
    required _HistoryLogRow row,
  }) {
    final lowerValue = value.trim().toLowerCase();
    if (field == 'velocidade') {
      final parsed = double.tryParse(value.replaceAll(',', '.'));
      if (parsed != null && parsed >= 80) {
        return 'Alerta';
      }
      return 'Info';
    }

    if (field == 'blocked' &&
        (lowerValue == 'sim' ||
            lowerValue == 'true' ||
            lowerValue == '1' ||
            lowerValue.contains('ativ'))) {
      return 'Alerta';
    }

    if (field == 'alarm' && lowerValue != '-' && lowerValue != 'nao') {
      return 'Alerta';
    }

    if (row.source == 'Evento') {
      return _severityFromText('${row.description} $value');
    }

    return 'Info';
  }

  int _severityRank(String severity) {
    switch (severity) {
      case 'Alerta':
        return 2;
      case 'Aviso':
        return 1;
      default:
        return 0;
    }
  }

  List<_DataLogEntry> _toDataLogEntries({
    required List<_HistoryLogRow> rows,
    required String equipmentName,
  }) {
    final entries = <_DataLogEntry>[];

    for (final row in rows) {
      final protocolKeys = row.protocolValues.keys.toSet();
      final remainingKeys = protocolKeys
          .where((key) => !_priorityProtocolKeys.contains(key))
          .toList(growable: false)
        ..sort();

      final orderedKeys = <String>[
        ..._priorityProtocolKeys.where(protocolKeys.contains),
        ...remainingKeys,
      ];

      final values = <String, String>{};
      var rowSeverity =
          row.source == 'Evento' ? _severityFromText(row.description) : 'Info';

      for (final key in orderedKeys) {
        final value = row.protocolValue(key);
        final normalized = value.trim();
        if (normalized.isEmpty ||
            normalized == '-' ||
            normalized.toLowerCase() == 'nao informado') {
          continue;
        }

        values[key] = normalized;
        final fieldSeverity = _severityFromField(
          field: key,
          value: normalized,
          row: row,
        );
        if (_severityRank(fieldSeverity) > _severityRank(rowSeverity)) {
          rowSeverity = fieldSeverity;
        }
      }

      if (values.isEmpty) {
        continue;
      }

      entries.add(
        _DataLogEntry(
          timestamp: row.dateTimeLabel,
          equipment: equipmentName,
          logType: row.protocolValue('protocol') == '-'
              ? row.type
              : row.protocolValue('protocol'),
          severity: rowSeverity,
          protocolValues: values,
        ),
      );
    }

    return entries;
  }

  Widget _severityBadge(String severity) {
    Color background;
    Color foreground;
    switch (severity) {
      case 'Alerta':
        background = const Color(0x33FF6B6B);
        foreground = const Color(0xFFFF9A9A);
        break;
      case 'Aviso':
        background = const Color(0x33FFB84D);
        foreground = const Color(0xFFFFD37A);
        break;
      default:
        background = const Color(0x332D8CFF);
        foreground = const Color(0xFF8BC2FF);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.55)),
      ),
      child: Text(
        severity,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesProvider);
    final visibleRows = _filteredRows;
    final devices = devicesAsync.valueOrNull ?? const <TraccarDevice>[];

    var equipmentName = 'Não informado';
    for (final device in devices) {
      if (device.id == _deviceId) {
        equipmentName = device.name;
        break;
      }
    }

    final baseEntries = _toDataLogEntries(
      rows: visibleRows,
      equipmentName: equipmentName,
    );
    final search = _searchController.text.trim().toLowerCase();
    final filteredEntries = baseEntries.where((entry) {
      if (_severityFilter != 'Todos' && entry.severity != _severityFilter) {
        return false;
      }

      if (search.isEmpty) {
        return true;
      }

      final bag = [
        entry.timestamp,
        entry.equipment,
        entry.logType,
        entry.severity,
        entry.protocolSearchBag,
      ].join(' ').toLowerCase();

      return bag.contains(search);
    }).toList(growable: false);

    final protocolColumnsSet = <String>{};
    for (final entry in filteredEntries) {
      protocolColumnsSet.addAll(entry.protocolValues.keys);
    }
    final protocolColumns = <String>[
      ..._priorityProtocolKeys.where(protocolColumnsSet.contains),
      ...protocolColumnsSet
          .where((key) => !_priorityProtocolKeys.contains(key))
          .toList(growable: false)
        ..sort(),
    ];

    const panelBackground = Color(0xEFFFFFFF);
    const panelBorder = Color(0xFFD6E0EE);
    const titleColor = Color(0xFF25344A);
    const subtitleColor = Color(0xFF5F738F);
    const fieldColor = Color(0xFFF7F9FD);
    const lineColor = Color(0xFFD6E0EE);

    InputDecoration darkInput({String? hintText, String? labelText}) {
      return InputDecoration(
        hintText: hintText,
        labelText: labelText,
        isDense: true,
        filled: true,
        fillColor: fieldColor,
        hintStyle: const TextStyle(color: subtitleColor),
        labelStyle: const TextStyle(color: subtitleColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lineColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lineColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF4A84FF), width: 1.2),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: panelBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: panelBorder),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickDateTime(isFrom: true),
                icon: const Icon(Icons.schedule_outlined, size: 16),
                label: Text(_fmt(_from)),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickDateTime(isFrom: false),
                icon: const Icon(Icons.schedule_outlined, size: 16),
                label: Text(_fmt(_to)),
              ),
              SizedBox(
                width: 240,
                child: devicesAsync.when(
                  data: (loadedDevices) => DropdownButtonFormField<int>(
                    initialValue: _deviceId,
                    style: const TextStyle(color: titleColor),
                    decoration: darkInput(labelText: 'Equipamento'),
                    items: [
                      for (final d in loadedDevices)
                        DropdownMenuItem(value: d.id, child: Text(d.name)),
                    ],
                    onChanged: (v) => _onDeviceChanged(v, loadedDevices),
                  ),
                  loading: () => const SizedBox(
                    width: 240,
                    child: LinearProgressIndicator(),
                  ),
                  error: (e, _) => SizedBox(
                    width: 240,
                    child: Text(
                      'Erro: $e',
                      style: const TextStyle(color: Color(0xFFFF8A8A)),
                    ),
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _loading ? null : _loadHistory,
                icon: const Icon(Icons.search_outlined, size: 16),
                label: Text(_loading ? 'Buscando...' : 'Buscar'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: panelBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: panelBorder),
            ),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filteredEntries.isEmpty
                    ? const Center(
                        child: Text(
                          'Sem logs no periodo/criterios selecionados.',
                          style: TextStyle(
                            color: subtitleColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mostrando 1 a ${filteredEntries.length} registros',
                            style: const TextStyle(
                              color: subtitleColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Scrollbar(
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  child: DataTable(
                                    dividerThickness: 0.45,
                                    headingRowColor: WidgetStatePropertyAll(
                                      const Color(0xCCF8FBFF),
                                    ),
                                    headingTextStyle: const TextStyle(
                                      color: titleColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                    dataTextStyle: const TextStyle(
                                      color: titleColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                    columns: [
                                      const DataColumn(
                                          label: Text('Data/Hora')),
                                      const DataColumn(
                                          label: Text('Equipamento')),
                                      const DataColumn(
                                          label: Text('Tipo de Log')),
                                      const DataColumn(
                                          label: Text('Severidade')),
                                      for (final key in protocolColumns)
                                        DataColumn(label: Text(key)),
                                    ],
                                    rows: [
                                      for (final entry in filteredEntries)
                                        DataRow(
                                          cells: [
                                            DataCell(Text(entry.timestamp)),
                                            DataCell(Text(entry.equipment)),
                                            DataCell(Text(entry.logType)),
                                            DataCell(
                                                _severityBadge(entry.severity)),
                                            for (final key in protocolColumns)
                                              DataCell(
                                                SizedBox(
                                                  width: 160,
                                                  child: Text(
                                                    entry.protocolValue(key),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
        ),
      ],
    );
  }
}

class _DataLogEntry {
  const _DataLogEntry({
    required this.timestamp,
    required this.equipment,
    required this.logType,
    required this.severity,
    required this.protocolValues,
  });

  final String timestamp;
  final String equipment;
  final String logType;
  final String severity;
  final Map<String, String> protocolValues;

  String protocolValue(String key) {
    final value = protocolValues[key];
    if (value == null || value.trim().isEmpty) {
      return '-';
    }
    return value;
  }

  String get protocolSearchBag => protocolValues.entries
      .map((entry) => '${entry.key}=${entry.value}')
      .join(' ');
}

class _HistoryLogRow {
  const _HistoryLogRow({
    required this.source,
    required this.timestamp,
    required this.type,
    required this.description,
    required this.speedKmh,
    required this.ignition,
    required this.battery,
    required this.lat,
    required this.lng,
    required this.origin,
    required this.attributesSummary,
    required this.protocolValues,
  });

  final String source;
  final DateTime? timestamp;
  final String type;
  final String description;
  final double? speedKmh;
  final String ignition;
  final String battery;
  final double? lat;
  final double? lng;
  final String origin;
  final String attributesSummary;
  final Map<String, String> protocolValues;

  String get dateTimeLabel => _formatDateTime(timestamp);

  String get protocolSearchBag => protocolValues.entries
      .map((entry) => '${entry.key}=${entry.value}')
      .join(' ');

  String protocolValue(String key) {
    final value = protocolValues[key.toLowerCase()];
    if (value == null || value.trim().isEmpty) {
      return '-';
    }
    return value;
  }

  String get speedLabel {
    if (speedKmh == null) return 'Não informado';
    return '${speedKmh!.toStringAsFixed(0)} km/h';
  }

  String get latLabel =>
      lat == null ? 'Não informado' : lat!.toStringAsFixed(6);
  String get lngLabel =>
      lng == null ? 'Não informado' : lng!.toStringAsFixed(6);
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, v) => MapEntry('$key', v));
  }
  return const <String, dynamic>{};
}

DateTime? _parseDate(dynamic raw) {
  final text = '${raw ?? ''}'.trim();
  if (text.isEmpty) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return null;
  return parsed.isUtc ? parsed.toLocal() : parsed;
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String _normalizeBooleanLabel(dynamic value) {
  if (value == null) return 'Não informado';
  if (value is bool) return value ? 'Ligada' : 'Desligada';
  if (value is num) return value > 0 ? 'Ligada' : 'Desligada';
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'on') {
      return 'Ligada';
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'off') {
      return 'Desligada';
    }
  }
  return 'Não informado';
}

String _resolveBattery(Map<String, dynamic> raw, Map<String, dynamic> attrs) {
  final value = raw['battery'] ??
      attrs['battery'] ??
      attrs['batteryLevel'] ??
      attrs['power'] ??
      attrs['batteryVoltage'];
  if (value == null) return 'Não informado';
  if (value is num) {
    if (value > 20) return '${value.toStringAsFixed(0)}%';
    return '${value.toStringAsFixed(2)} V';
  }
  final text = value.toString().trim();
  return text.isEmpty ? 'Não informado' : text;
}

String _attributesSummary(Map<String, dynamic> attrs) {
  if (attrs.isEmpty) return 'Não informado';
  final pairs = <String>[];
  for (final entry in attrs.entries) {
    final key = entry.key.trim();
    final val = '${entry.value ?? ''}'.trim();
    if (key.isEmpty || val.isEmpty || val.toLowerCase() == 'null') {
      continue;
    }
    pairs.add('$key=$val');
    if (pairs.length >= 3) break;
  }
  if (pairs.isEmpty) return 'Não informado';
  return pairs.join(' | ');
}

bool _ignoreProtocolKey(String key) {
  const ignored = <String>{
    'id',
    'deviceid',
    'servertime',
    'devicetime',
    'fixtime',
    'valid',
    'outdated',
    'approximate',
    'latitude',
    'longitude',
    'altitude',
    'course',
    'speed',
    'address',
    'accuracy',
    'network',
    'geofenceids',
    'type',
  };
  return ignored.contains(key);
}

Map<String, String> _extractProtocolValues({
  required Map<String, dynamic> raw,
  required Map<String, dynamic> attributes,
}) {
  final normalizedRaw = <String, dynamic>{
    for (final entry in raw.entries) entry.key.toLowerCase(): entry.value,
  };
  final normalizedAttributes = <String, dynamic>{
    for (final entry in attributes.entries)
      entry.key.toLowerCase(): entry.value,
  };

  final result = <String, String>{};

  String resolve(String key) {
    final lower = key.toLowerCase();
    dynamic value = normalizedAttributes[lower] ?? normalizedRaw[lower];

    if (lower == 'event' && (value == null || '$value'.trim().isEmpty)) {
      value = normalizedRaw['type'];
    }
    if (lower == 'ignition' && value == null) {
      value = normalizedAttributes['ignitionon'];
    }
    if (lower == 'power' && value == null) {
      value = normalizedAttributes['power'] ??
          normalizedAttributes['battery'] ??
          normalizedAttributes['batterylevel'] ??
          normalizedAttributes['batteryvoltage'];
    }

    return _formatProtocolValue(lower, value);
  }

  for (final key in _HistoryScreenState._protocolCoreKeys) {
    result[key] = resolve(key);
  }

  for (final entry in normalizedAttributes.entries) {
    final key = entry.key;
    if (result.containsKey(key) || _ignoreProtocolKey(key)) {
      continue;
    }
    result[key] = _formatProtocolValue(key, entry.value);
  }

  for (final entry in normalizedRaw.entries) {
    final key = entry.key;
    if (result.containsKey(key) || _ignoreProtocolKey(key)) {
      continue;
    }
    if (key == 'protocol' || key.startsWith('io') || key.startsWith('di')) {
      result[key] = _formatProtocolValue(key, entry.value);
    }
  }

  return result;
}

String _formatProtocolValue(String _, dynamic value) {
  if (value == null) return '-';

  if (value is bool) {
    return value ? 'true' : 'false';
  }

  if (value is num) {
    return value.toString();
  }

  final text = '$value'.trim();
  if (text.isEmpty || text.toLowerCase() == 'null') {
    return '-';
  }

  return text;
}

String _humanize(String value) {
  if (value.trim().isEmpty) return value;
  final withSpace = value
      .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'), (m) => '${m.group(1)} ${m.group(2)}')
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .trim();
  if (withSpace.isEmpty) return value;
  return '${withSpace[0].toUpperCase()}${withSpace.substring(1)}';
}

String _formatDateTime(DateTime? value) {
  if (value == null) return 'Não informado';
  final dd = value.day.toString().padLeft(2, '0');
  final mm = value.month.toString().padLeft(2, '0');
  final yyyy = value.year.toString().padLeft(4, '0');
  final hh = value.hour.toString().padLeft(2, '0');
  final min = value.minute.toString().padLeft(2, '0');
  final ss = value.second.toString().padLeft(2, '0');
  return '$dd/$mm/$yyyy $hh:$min:$ss';
}
