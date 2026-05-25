import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/session_state.dart';
import '../telemetry/sensor_presentation.dart';

final devicesManagementProvider =
    FutureProvider.autoDispose<List<TraccarDevice>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (!session.isAuthenticated) {
    return [];
  }

  final client = ref.watch(traccarClientProvider);
  return client.getDevices(
    cookie: session.cookie,
    authHeader: session.authHeader,
  );
});

enum _DevicesQuickFilter {
  all,
  online,
  moving,
  alerts,
  offline,
  noCommunication,
}

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  static final List<MapEntry<String, String>> _sensorOptions =
      sensorSelectionOptions();

  static const Set<String> _defaultSensorKeys = {
    'ignition',
    'motion',
    'door',
    'blocked',
    'gpsTracking',
    'power',
    'batteryLevel',
    'battery',
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
  };

  final _nameController = TextEditingController();
  final _identifierController = TextEditingController();
  final _categoryController = TextEditingController();
  final _phoneController = TextEditingController();
  final _searchController = TextEditingController();
  final Set<String> _selectedSensorKeys = <String>{};

  bool _saving = false;
  _DevicesQuickFilter _activeFilter = _DevicesQuickFilter.all;
  bool _showFilterChips = false;

  @override
  void dispose() {
    _nameController.dispose();
    _identifierController.dispose();
    _categoryController.dispose();
    _phoneController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openDeviceDialog({TraccarDevice? editing}) async {
    if (editing == null) {
      _nameController.clear();
      _identifierController.clear();
      _categoryController.clear();
      _phoneController.clear();
      _selectedSensorKeys
        ..clear()
        ..addAll(_defaultSensorKeys);
    } else {
      _nameController.text = editing.name;
      _identifierController.text = (editing.uniqueId ?? '').trim();
      _categoryController.text = (editing.category ?? '').trim();
      _phoneController.text = (editing.attributes?['phone'] ?? '').toString();
      _setSelectedSensorsFromDevice(editing);
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                editing == null
                                    ? 'Novo equipamento'
                                    : 'Editar equipamento',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      color: const Color(0xFF1F2A44),
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            IconButton(
                              onPressed: _saving
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nome',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _identifierController,
                          decoration: const InputDecoration(
                            labelText: 'Identificador / IMEI / Unique ID',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _categoryController,
                          decoration: const InputDecoration(
                            labelText: 'Categoria/Modelo (opcional)',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Telefone/chip (opcional)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Sensores do card',
                          style: TextStyle(
                            color: Color(0xFF1F2A44),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final option in _sensorOptions)
                              FilterChip(
                                label: Text(option.value),
                                selected:
                                    _selectedSensorKeys.contains(option.key),
                                onSelected: _saving
                                    ? null
                                    : (selected) {
                                        setModalState(() {
                                          if (selected) {
                                            _selectedSensorKeys.add(option.key);
                                          } else {
                                            _selectedSensorKeys
                                                .remove(option.key);
                                          }
                                        });
                                      },
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _saving
                                ? null
                                : () async {
                                    final ok = editing == null
                                        ? await _createDevice()
                                        : await _updateDevice(editing);
                                    if (!mounted || !dialogContext.mounted) {
                                      return;
                                    }
                                    if (ok) {
                                      Navigator.of(dialogContext).pop();
                                    }
                                  },
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    editing == null
                                        ? Icons.add_rounded
                                        : Icons.save_outlined,
                                  ),
                            label: Text(
                              _saving
                                  ? 'Salvando...'
                                  : (editing == null
                                      ? 'Salvar equipamento'
                                      : 'Salvar alteracoes'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _setSelectedSensorsFromDevice(TraccarDevice device) {
    _selectedSensorKeys.clear();
    final rawSensors = device.attributes?['souSensors'];
    if (rawSensors is List) {
      for (final raw in rawSensors) {
        final key = raw.toString().trim();
        if (key.isNotEmpty) {
          _selectedSensorKeys.add(_normalizeSensorKey(key));
        }
      }
    }
    if (_selectedSensorKeys.isEmpty) {
      _selectedSensorKeys.addAll(_defaultSensorKeys);
    }
  }

  String _normalizeSensorKey(String key) {
    final normalized = key.trim().toLowerCase();
    switch (normalized) {
      case 'sat':
        return 'satellites';
      case 'hours':
        return 'totalHours';
      case 'distance':
        return 'odometer';
      default:
        return key;
    }
  }

  Future<bool> _createDevice() async {
    final name = _nameController.text.trim();
    final identifier = _identifierController.text.trim();
    final category = _categoryController.text.trim();
    final phone = _phoneController.text.trim();
    final selectedSensors = (_selectedSensorKeys.isEmpty
            ? _defaultSensorKeys
            : _selectedSensorKeys)
        .toList()
      ..sort();

    if (name.isEmpty || identifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe nome e identificador do equipamento.'),
        ),
      );
      return false;
    }

    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    setState(() => _saving = true);

    try {
      await client.createDevice(
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'name': name,
          'uniqueId': identifier,
          if (category.isNotEmpty) 'category': category,
          if (phone.isNotEmpty) 'phone': phone,
          'attributes': {
            if (phone.isNotEmpty) 'phone': phone,
            'souSensors': selectedSensors,
          },
        },
      );

      ref.invalidate(devicesManagementProvider);
      ref.invalidate(devicesProvider);
      ref.invalidate(positionsProvider);
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Equipamento cadastrado com sucesso.')),
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _updateDevice(TraccarDevice device) async {
    final name = _nameController.text.trim();
    final identifier = _identifierController.text.trim();
    final category = _categoryController.text.trim();
    final phone = _phoneController.text.trim();
    final selectedSensors = (_selectedSensorKeys.isEmpty
            ? _defaultSensorKeys
            : _selectedSensorKeys)
        .toList()
      ..sort();

    if (name.isEmpty || identifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe nome e identificador do equipamento.'),
        ),
      );
      return false;
    }

    final attributes = <String, dynamic>{
      ...?device.attributes,
      'souSensors': selectedSensors,
    };
    if (phone.isNotEmpty) {
      attributes['phone'] = phone;
    } else {
      attributes.remove('phone');
    }

    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    setState(() => _saving = true);

    try {
      await client.updateEntityById(
        path: '/devices',
        id: device.id,
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'id': device.id,
          'name': name,
          'uniqueId': identifier,
          if (category.isNotEmpty) 'category': category,
          if (phone.isNotEmpty) 'phone': phone,
          'attributes': attributes,
        },
      );

      ref.invalidate(devicesManagementProvider);
      ref.invalidate(devicesProvider);
      ref.invalidate(positionsProvider);
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Equipamento atualizado com sucesso.')),
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _friendlyError(Object error) {
    final code = _extractHttpStatusCode(error);
    if (code == 401) {
      return 'Sessao expirada. Faca login novamente.';
    }
    if (code == 403) {
      return 'Usuario sem permissao para editar equipamentos.';
    }
    if (code != null) {
      return 'Falha na operacao (codigo $code).';
    }
    return 'Falha ao concluir a operacao.';
  }

  int? _extractHttpStatusCode(Object error) {
    final raw = error.toString();
    final match =
        RegExp(r'(?:^|[^0-9])([1-5][0-9]{2})(?:[^0-9]|$)').firstMatch(raw);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  Map<int, TraccarPosition> _latestPositionsByDevice(
    List<TraccarPosition> positions,
  ) {
    final latest = <int, TraccarPosition>{};
    for (final position in positions) {
      final current = latest[position.deviceId];
      if (current == null) {
        latest[position.deviceId] = position;
        continue;
      }
      final currentTime = _parseDate(current.fixTime);
      final nextTime = _parseDate(position.fixTime);
      if (nextTime != null &&
          (currentTime == null || nextTime.isAfter(currentTime))) {
        latest[position.deviceId] = position;
      }
    }
    return latest;
  }

  DateTime? _parseDate(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  DateTime? _deviceCommunicationAt(
    TraccarDevice device,
    TraccarPosition? position,
  ) {
    return _parseDate(device.lastUpdate ?? position?.fixTime);
  }

  String _formatRelative(DateTime? value) {
    if (value == null) return 'Não informado';
    final diff = DateTime.now().difference(value);
    if (diff.isNegative || diff.inSeconds < 60) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours} h';
    if (diff.inDays == 1) return 'há 1 dia';
    return 'há ${diff.inDays} dias';
  }

  String _formatDateTimeShort(DateTime? value) {
    if (value == null) return '--';
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$d/$m $hh:$mm';
  }

  double _speedKmh(TraccarPosition? position) => position?.speed ?? 0;

  bool _isMoving(TraccarPosition? position) => _speedKmh(position) >= 3;

  bool _isOffline(TraccarDevice device, TraccarPosition? position) {
    final status = device.status.trim().toLowerCase();
    if (status == 'offline' || status == 'unknown') return true;
    final at = _deviceCommunicationAt(device, position);
    if (at == null) return true;
    return DateTime.now().difference(at).inHours >= 24;
  }

  bool _isNoCommunication(TraccarDevice device, TraccarPosition? position) {
    final at = _deviceCommunicationAt(device, position);
    if (at == null || position == null) return true;
    return DateTime.now().difference(at).inHours >= 12;
  }

  Map<String, dynamic> _attrs(TraccarDevice device, TraccarPosition? position) {
    return <String, dynamic>{...?device.attributes, ...?position?.attributes};
  }

  dynamic _firstAttr(Map<String, dynamic> attrs, List<String> keys) {
    for (final key in keys) {
      final value = attrs[key];
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      return value;
    }
    return null;
  }

  bool? _asBool(dynamic raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw > 0;
    if (raw is String) {
      final n = raw.trim().toLowerCase();
      if (n == 'true' || n == '1' || n == 'on' || n == 'sim') return true;
      if (n == 'false' || n == '0' || n == 'off' || n == 'nao') return false;
    }
    return null;
  }

  double? _asDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw.replaceAll(',', '.'));
    return null;
  }

  bool _hasAlert(TraccarDevice device, TraccarPosition? position) {
    final attrs = _attrs(device, position);
    if (_firstAttr(attrs, const ['alarm', 'event']) != null) return true;
    if (_asBool(_firstAttr(attrs, const ['blocked'])) == true) return true;
    return device.status.trim().toLowerCase() == 'unknown';
  }

  String _statusLabel(TraccarDevice device, TraccarPosition? position) {
    if (_isNoCommunication(device, position)) return 'Sem comunicação';
    if (_hasAlert(device, position)) return 'Alerta';
    if (_isOffline(device, position)) return 'Offline';
    return 'Online';
  }

  Color _statusColor(String label) {
    switch (label) {
      case 'Online':
        return const Color(0xFF18A558);
      case 'Alerta':
        return const Color(0xFFE74B4B);
      case 'Offline':
        return const Color(0xFF5E6B82);
      case 'Sem comunicação':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF5E6B82);
    }
  }

  String _ignitionLabel(Map<String, dynamic> attrs) {
    final value = _asBool(_firstAttr(attrs, const ['ignition', 'engineOn']));
    if (value == null) return 'Não informado';
    return value ? 'Ligada' : 'Desligada';
  }

  Color _ignitionColor(Map<String, dynamic> attrs) {
    final value = _asBool(_firstAttr(attrs, const ['ignition', 'engineOn']));
    if (value == null) return const Color(0xFF7A879D);
    return value ? const Color(0xFF18A558) : const Color(0xFFE74B4B);
  }

  String _batteryLabel(Map<String, dynamic> attrs) {
    final percent = _asDouble(_firstAttr(attrs, const ['batteryLevel']));
    if (percent != null) return '${percent.round()}%';
    final voltage = _asDouble(_firstAttr(attrs, const ['battery', 'power']));
    if (voltage != null) return '${voltage.toStringAsFixed(1)} V';
    return 'Não informado';
  }

  Color _batteryColor(Map<String, dynamic> attrs) {
    final percent = _asDouble(_firstAttr(attrs, const ['batteryLevel']));
    if (percent != null) {
      if (percent <= 20) return const Color(0xFFE74B4B);
      if (percent <= 50) return const Color(0xFFF59E0B);
      return const Color(0xFF18A558);
    }
    return const Color(0xFF18A558);
  }

  String _gsmLabel(Map<String, dynamic> attrs) {
    final signal =
        _asDouble(_firstAttr(attrs, const ['gsm', 'rssi', 'signal']));
    if (signal == null) return '--';
    if (signal < 0) return '${signal.toStringAsFixed(0)} dBm';
    return signal.toStringAsFixed(0);
  }

  Color _gsmColor(Map<String, dynamic> attrs) {
    final signal =
        _asDouble(_firstAttr(attrs, const ['gsm', 'rssi', 'signal']));
    if (signal == null) return const Color(0xFF7A879D);
    if (signal < 0) {
      if (signal <= -95) return const Color(0xFFE74B4B);
      if (signal <= -80) return const Color(0xFFF59E0B);
      return const Color(0xFF18A558);
    }
    if (signal <= 20) return const Color(0xFFE74B4B);
    if (signal <= 40) return const Color(0xFFF59E0B);
    return const Color(0xFF18A558);
  }

  String _vehicleLabel(TraccarDevice device) {
    final value = _firstAttr(
      device.attributes ?? const <String, dynamic>{},
      const ['vehicle', 'plate', 'asset', 'model'],
    );
    final text = (value ?? '').toString().trim();
    if (text.isNotEmpty) return text;
    return device.category?.trim().isNotEmpty == true
        ? device.category!.trim()
        : device.name;
  }

  String _groupLabel(TraccarDevice device) {
    final value = _firstAttr(
      device.attributes ?? const <String, dynamic>{},
      const ['group', 'groupName', 'department', 'fleet'],
    );
    final text = (value ?? '').toString().trim();
    if (text.isNotEmpty) return text;
    return 'Sem grupo';
  }

  List<TraccarDevice> _filterByStatus(
    List<TraccarDevice> devices,
    Map<int, TraccarPosition> latestByDevice,
  ) {
    switch (_activeFilter) {
      case _DevicesQuickFilter.all:
        return devices;
      case _DevicesQuickFilter.online:
        return devices
            .where((it) => !_isOffline(it, latestByDevice[it.id]))
            .toList(growable: false);
      case _DevicesQuickFilter.moving:
        return devices
            .where((it) => _isMoving(latestByDevice[it.id]))
            .toList(growable: false);
      case _DevicesQuickFilter.alerts:
        return devices
            .where((it) => _hasAlert(it, latestByDevice[it.id]))
            .toList(growable: false);
      case _DevicesQuickFilter.offline:
        return devices
            .where((it) => _isOffline(it, latestByDevice[it.id]))
            .toList(growable: false);
      case _DevicesQuickFilter.noCommunication:
        return devices
            .where((it) => _isNoCommunication(it, latestByDevice[it.id]))
            .toList(growable: false);
    }
  }

  List<TraccarDevice> _filterBySearch(List<TraccarDevice> devices) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return devices;
    return devices.where((device) {
      return device.name.toLowerCase().contains(q) ||
          (device.uniqueId ?? '').toLowerCase().contains(q) ||
          (device.category ?? '').toLowerCase().contains(q);
    }).toList(growable: false);
  }

  int _count(
    _DevicesQuickFilter filter,
    List<TraccarDevice> devices,
    Map<int, TraccarPosition> latestByDevice,
  ) {
    switch (filter) {
      case _DevicesQuickFilter.all:
        return devices.length;
      case _DevicesQuickFilter.online:
        return devices
            .where((it) => !_isOffline(it, latestByDevice[it.id]))
            .length;
      case _DevicesQuickFilter.moving:
        return devices.where((it) => _isMoving(latestByDevice[it.id])).length;
      case _DevicesQuickFilter.alerts:
        return devices
            .where((it) => _hasAlert(it, latestByDevice[it.id]))
            .length;
      case _DevicesQuickFilter.offline:
        return devices
            .where((it) => _isOffline(it, latestByDevice[it.id]))
            .length;
      case _DevicesQuickFilter.noCommunication:
        return devices
            .where((it) => _isNoCommunication(it, latestByDevice[it.id]))
            .length;
    }
  }

  String _filterLabel(_DevicesQuickFilter filter) {
    switch (filter) {
      case _DevicesQuickFilter.all:
        return 'Todos os status';
      case _DevicesQuickFilter.online:
        return 'Online';
      case _DevicesQuickFilter.moving:
        return 'Em movimento';
      case _DevicesQuickFilter.alerts:
        return 'Alertas';
      case _DevicesQuickFilter.offline:
        return 'Offline';
      case _DevicesQuickFilter.noCommunication:
        return 'Sem comunicação';
    }
  }

  Future<void> _exportVisible(
    List<TraccarDevice> devices,
    Map<int, TraccarPosition> latestByDevice,
  ) async {
    final lines = <String>[
      'Status;Equipamento;IMEI_ID;Veículo_Ativo;Grupo;Última_Conexão;Velocidade;Ignição;Bateria;Sinal_GSM',
      for (final device in devices)
        [
          _statusLabel(device, latestByDevice[device.id]),
          device.name,
          (device.uniqueId ?? '').trim().isEmpty
              ? 'Não informado'
              : (device.uniqueId ?? '').trim(),
          _vehicleLabel(device),
          _groupLabel(device),
          _formatRelative(
              _deviceCommunicationAt(device, latestByDevice[device.id])),
          '${_speedKmh(latestByDevice[device.id]).toStringAsFixed(0)} km/h',
          _ignitionLabel(_attrs(device, latestByDevice[device.id])),
          _batteryLabel(_attrs(device, latestByDevice[device.id])),
          _gsmLabel(_attrs(device, latestByDevice[device.id])),
        ].map(_escapeCsv).join(';'),
    ];

    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tabela copiada para a área de transferência.'),
      ),
    );
  }

  String _escapeCsv(String value) {
    if (value.contains(';') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesManagementProvider);
    final positionsAsync = ref.watch(positionsProvider);

    return SizedBox.expand(
      child: devicesAsync.when(
        data: (devices) {
          final positions =
              positionsAsync.valueOrNull ?? const <TraccarPosition>[];
          final latestByDevice = _latestPositionsByDevice(positions);

          if (devices.isEmpty) {
            return const _PanelMessageState(
              icon: Icons.devices_other_rounded,
              message: 'Nenhum equipamento cadastrado.',
            );
          }

          final total =
              _count(_DevicesQuickFilter.all, devices, latestByDevice);
          final online =
              _count(_DevicesQuickFilter.online, devices, latestByDevice);
          final moving =
              _count(_DevicesQuickFilter.moving, devices, latestByDevice);
          final alerts =
              _count(_DevicesQuickFilter.alerts, devices, latestByDevice);
          final offline =
              _count(_DevicesQuickFilter.offline, devices, latestByDevice);
          final noCommunication = _count(
              _DevicesQuickFilter.noCommunication, devices, latestByDevice);

          final visible = _filterBySearch(
            _filterByStatus(devices, latestByDevice),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 8.0;
                  final width = constraints.maxWidth;
                  final columns = width >= 1080
                      ? 6
                      : width >= 860
                          ? 4
                          : width >= 640
                              ? 3
                              : width >= 420
                                  ? 2
                                  : 1;
                  final cardWidth =
                      ((width - (columns - 1) * spacing) / columns)
                          .clamp(150.0, 220.0);

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      _MetricCard(
                        width: cardWidth,
                        icon: Icons.memory_rounded,
                        title: 'Total de Equipamentos',
                        value: total,
                        hint: '100% do total',
                        color: const Color(0xFF176EEB),
                      ),
                      _MetricCard(
                        width: cardWidth,
                        icon: Icons.wifi_tethering_rounded,
                        title: 'Online',
                        value: online,
                        hint: total == 0
                            ? '0%'
                            : '${((online / total) * 100).round()}% do total',
                        color: const Color(0xFF18A558),
                      ),
                      _MetricCard(
                        width: cardWidth,
                        icon: Icons.near_me_rounded,
                        title: 'Em movimento',
                        value: moving,
                        hint: total == 0
                            ? '0%'
                            : '${((moving / total) * 100).round()}% do total',
                        color: const Color(0xFF176EEB),
                      ),
                      _MetricCard(
                        width: cardWidth,
                        icon: Icons.warning_amber_rounded,
                        title: 'Alertas Ativos',
                        value: alerts,
                        hint: total == 0
                            ? '0%'
                            : '${((alerts / total) * 100).round()}% do total',
                        color: const Color(0xFFE74B4B),
                      ),
                      _MetricCard(
                        width: cardWidth,
                        icon: Icons.wifi_off_rounded,
                        title: 'Offline',
                        value: offline,
                        hint: total == 0
                            ? '0%'
                            : '${((offline / total) * 100).round()}% do total',
                        color: const Color(0xFF5E6B82),
                      ),
                      _MetricCard(
                        width: cardWidth,
                        icon: Icons.portable_wifi_off_rounded,
                        title: 'Sem comunicação',
                        value: noCommunication,
                        hint: total == 0
                            ? '0%'
                            : '${((noCommunication / total) * 100).round()}% do total',
                        color: const Color(0xFFF59E0B),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 980;
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xCCFFFFFF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD1DCEB)),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Buscar equipamento, IMEI ou placa...',
                              hintStyle: TextStyle(
                                color: Color(0xFF74839B),
                                fontWeight: FontWeight.w600,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: Color(0xFF60718D),
                              ),
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _TopActionButton(
                              label: 'Filtros',
                              icon: Icons.filter_alt_outlined,
                              onTap: () => setState(
                                  () => _showFilterChips = !_showFilterChips),
                            ),
                            _TopActionButton(
                              label: 'Exportar',
                              icon: Icons.download_outlined,
                              onTap: () =>
                                  _exportVisible(visible, latestByDevice),
                            ),
                            _TopActionButton(
                              label: 'Novo Equipamento',
                              icon: Icons.add_rounded,
                              primary: true,
                              onTap:
                                  _saving ? () {} : () => _openDeviceDialog(),
                            ),
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xCCFFFFFF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD1DCEB)),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Buscar equipamento, IMEI ou placa...',
                              hintStyle: TextStyle(
                                color: Color(0xFF74839B),
                                fontWeight: FontWeight.w600,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: Color(0xFF60718D),
                              ),
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _TopActionButton(
                        label: 'Filtros',
                        icon: Icons.filter_alt_outlined,
                        onTap: () => setState(
                            () => _showFilterChips = !_showFilterChips),
                      ),
                      const SizedBox(width: 10),
                      _TopActionButton(
                        label: 'Exportar',
                        icon: Icons.download_outlined,
                        onTap: () => _exportVisible(visible, latestByDevice),
                      ),
                      const SizedBox(width: 10),
                      _TopActionButton(
                        label: 'Novo Equipamento',
                        icon: Icons.add_rounded,
                        primary: true,
                        onTap: _saving ? () {} : () => _openDeviceDialog(),
                      ),
                    ],
                  );
                },
              ),
              if (_showFilterChips) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final filter in _DevicesQuickFilter.values)
                      ChoiceChip(
                        selectedColor: const Color(0xFFE8F1FF),
                        labelStyle: TextStyle(
                          color: _activeFilter == filter
                              ? const Color(0xFF176EEB)
                              : const Color(0xFF5A6B84),
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide(
                          color: _activeFilter == filter
                              ? const Color(0xFFAAC9FF)
                              : const Color(0xFFD1DCEB),
                        ),
                        label: Text(
                          '${_filterLabel(filter)} (${_count(filter, devices, latestByDevice)})',
                        ),
                        selected: _activeFilter == filter,
                        onSelected: (_) =>
                            setState(() => _activeFilter = filter),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Expanded(
                child: visible.isEmpty
                    ? const _PanelMessageState(
                        icon: Icons.search_off_rounded,
                        message:
                            'Nenhum equipamento encontrado com os filtros atuais.',
                      )
                    : _DevicesTable(
                        devices: visible,
                        latestByDevice: latestByDevice,
                        onEdit: (device) => _openDeviceDialog(editing: device),
                        statusLabel: _statusLabel,
                        statusColor: _statusColor,
                        attrs: _attrs,
                        vehicleLabel: _vehicleLabel,
                        groupLabel: _groupLabel,
                        formatDateTimeShort: _formatDateTimeShort,
                        formatRelative: _formatRelative,
                        speedKmh: _speedKmh,
                        isMoving: _isMoving,
                        ignitionLabel: _ignitionLabel,
                        ignitionColor: _ignitionColor,
                        batteryLabel: _batteryLabel,
                        batteryColor: _batteryColor,
                        gsmLabel: _gsmLabel,
                        gsmColor: _gsmColor,
                        communicationAt: _deviceCommunicationAt,
                      ),
              ),
            ],
          );
        },
        loading: () => const _DevicesLoadingState(),
        error: (error, _) => _PanelMessageState(
          icon: Icons.info_outline_rounded,
          message: _friendlyError(error),
        ),
      ),
    );
  }
}

class _DevicesLoadingState extends StatelessWidget {
  const _DevicesLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 94,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 6,
            itemBuilder: (context, _) => Container(
              width: 188,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD1DCEB)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xCCFFFFFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD1DCEB)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            for (var i = 0; i < 3; i++) ...[
              Container(
                width: i == 2 ? 156 : 116,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD1DCEB)),
                ),
              ),
              if (i != 2) const SizedBox(width: 10),
            ],
          ],
        ),
        const SizedBox(height: 10),
        const Expanded(
          child: _PanelMessageState(
            icon: Icons.hourglass_top_rounded,
            message: 'Carregando equipamentos...',
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.value,
    required this.hint,
    required this.color,
  });

  final double width;
  final IconData icon;
  final String title;
  final int value;
  final String hint;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1DCEB)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF5A6B84),
                    fontWeight: FontWeight.w700,
                    fontSize: 10.2,
                  ),
                ),
                Text(
                  '$value',
                  style: const TextStyle(
                    color: Color(0xFF1F2A44),
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                    height: 0.98,
                  ),
                ),
                Text(
                  hint,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 9.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final bg = primary ? const Color(0xFF2D8CFF) : const Color(0x99FFFFFF);
    final fg = primary ? Colors.white : const Color(0xFF1F2A44);
    final border = primary ? const Color(0xFF2D8CFF) : const Color(0xFFD1DCEB);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelMessageState extends StatelessWidget {
  const _PanelMessageState({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD1DCEB)),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF2D8CFF), size: 24),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF394B66),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _DeviceStatusLabel = String Function(
  TraccarDevice device,
  TraccarPosition? position,
);
typedef _StatusColor = Color Function(String label);
typedef _DeviceAttrs = Map<String, dynamic> Function(
  TraccarDevice device,
  TraccarPosition? position,
);
typedef _DeviceText = String Function(TraccarDevice device);
typedef _FormatDate = String Function(DateTime? value);
typedef _Speed = double Function(TraccarPosition? position);
typedef _IsMoving = bool Function(TraccarPosition? position);
typedef _ValueLabel = String Function(Map<String, dynamic> attrs);
typedef _ValueColor = Color Function(Map<String, dynamic> attrs);
typedef _CommunicationAt = DateTime? Function(
  TraccarDevice device,
  TraccarPosition? position,
);

class _DevicesTable extends StatelessWidget {
  const _DevicesTable({
    required this.devices,
    required this.latestByDevice,
    required this.onEdit,
    required this.statusLabel,
    required this.statusColor,
    required this.attrs,
    required this.vehicleLabel,
    required this.groupLabel,
    required this.formatDateTimeShort,
    required this.formatRelative,
    required this.speedKmh,
    required this.isMoving,
    required this.ignitionLabel,
    required this.ignitionColor,
    required this.batteryLabel,
    required this.batteryColor,
    required this.gsmLabel,
    required this.gsmColor,
    required this.communicationAt,
  });

  final List<TraccarDevice> devices;
  final Map<int, TraccarPosition> latestByDevice;
  final ValueChanged<TraccarDevice> onEdit;
  final _DeviceStatusLabel statusLabel;
  final _StatusColor statusColor;
  final _DeviceAttrs attrs;
  final _DeviceText vehicleLabel;
  final _DeviceText groupLabel;
  final _FormatDate formatDateTimeShort;
  final _FormatDate formatRelative;
  final _Speed speedKmh;
  final _IsMoving isMoving;
  final _ValueLabel ignitionLabel;
  final _ValueColor ignitionColor;
  final _ValueLabel batteryLabel;
  final _ValueColor batteryColor;
  final _ValueLabel gsmLabel;
  final _ValueColor gsmColor;
  final _CommunicationAt communicationAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD1DCEB)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const statusWidth = 154.0;
          const equipmentWidth = 206.0;
          const imeiWidth = 176.0;
          const vehicleWidth = 170.0;
          const groupWidth = 126.0;
          const connectionWidth = 184.0;
          const speedWidth = 116.0;
          const ignitionWidth = 130.0;
          const batteryWidth = 126.0;
          const signalWidth = 126.0;
          const actionsWidth = 148.0;
          const contentPadding = 28.0;
          const tableWidth = statusWidth +
              equipmentWidth +
              imeiWidth +
              vehicleWidth +
              groupWidth +
              connectionWidth +
              speedWidth +
              ignitionWidth +
              batteryWidth +
              signalWidth +
              actionsWidth +
              contentPadding;
          final effectiveWidth = constraints.maxWidth > tableWidth
              ? constraints.maxWidth
              : tableWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: effectiveWidth,
              child: Column(
                children: [
                  const SizedBox(
                    height: 52,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          _H(statusWidth, 'Status'),
                          _H(equipmentWidth, 'Equipamento'),
                          _H(imeiWidth, 'IMEI / ID'),
                          _H(vehicleWidth, 'Veículo / Ativo'),
                          _H(groupWidth, 'Grupo'),
                          _H(connectionWidth, 'Última conexão'),
                          _H(speedWidth, 'Velocidade'),
                          _H(ignitionWidth, 'Ignição'),
                          _H(batteryWidth, 'Bateria'),
                          _H(signalWidth, 'Sinal GSM'),
                          _H(actionsWidth, 'Ações'),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFD8E3F1)),
                  Expanded(
                    child: ListView.separated(
                      itemCount: devices.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xFFDCE6F3)),
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        final position = latestByDevice[device.id];
                        final details = attrs(device, position);
                        final label = statusLabel(device, position);
                        final labelColor = statusColor(label);
                        final comm = communicationAt(device, position);
                        final ignitionCol = ignitionColor(details);
                        final batteryCol = batteryColor(details);
                        final gsmCol = gsmColor(details);

                        return SizedBox(
                          height: 58,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: statusWidth,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: labelColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: labelColor.withValues(
                                                alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: labelColor,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _R(equipmentWidth, device.name,
                                    weight: FontWeight.w800),
                                _R(
                                  imeiWidth,
                                  (device.uniqueId ?? '').trim().isEmpty
                                      ? 'Não informado'
                                      : (device.uniqueId ?? '').trim(),
                                  color: const Color(0xFF4F6483),
                                ),
                                _R(vehicleWidth, vehicleLabel(device),
                                    color: const Color(0xFF4F6483)),
                                _R(groupWidth, groupLabel(device),
                                    color: const Color(0xFF4F6483)),
                                SizedBox(
                                  width: connectionWidth,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        formatDateTimeShort(comm),
                                        style: const TextStyle(
                                          color: Color(0xFF1F2A44),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12.2,
                                        ),
                                      ),
                                      Text(
                                        formatRelative(comm),
                                        style: const TextStyle(
                                          color: Color(0xFF176EEB),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _R(
                                  speedWidth,
                                  '${speedKmh(position).toStringAsFixed(0)} km/h',
                                  color: isMoving(position)
                                      ? const Color(0xFF176EEB)
                                      : const Color(0xFF1F2A44),
                                  weight: isMoving(position)
                                      ? FontWeight.w800
                                      : FontWeight.w700,
                                ),
                                SizedBox(
                                  width: ignitionWidth,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.power_settings_new_rounded,
                                        size: 16,
                                        color: ignitionCol,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          ignitionLabel(details),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: ignitionCol,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: batteryWidth,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.battery_5_bar_rounded,
                                        size: 16,
                                        color: batteryCol,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          batteryLabel(details),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: batteryCol,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: signalWidth,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.network_cell_rounded,
                                        size: 16,
                                        color: gsmCol,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          gsmLabel(details),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: gsmCol,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: actionsWidth,
                                  child: Row(
                                    children: [
                                      _IconAction(
                                        icon: Icons.remove_red_eye_outlined,
                                        tooltip: 'Ver detalhes',
                                        onTap: () => onEdit(device),
                                      ),
                                      const SizedBox(width: 6),
                                      _IconAction(
                                        icon: Icons.edit_outlined,
                                        tooltip: 'Editar',
                                        onTap: () => onEdit(device),
                                      ),
                                      const SizedBox(width: 6),
                                      _IconAction(
                                        icon: Icons.more_horiz_rounded,
                                        tooltip: 'Mais',
                                        onTap: () => onEdit(device),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _H extends StatelessWidget {
  const _H(this.width, this.text);
  final double width;
  final String text;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF52627C),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _R extends StatelessWidget {
  const _R(
    this.width,
    this.text, {
    this.color = const Color(0xFF1F2A44),
    this.weight = FontWeight.w700,
  });
  final double width;
  final String text;
  final Color color;
  final FontWeight weight;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontWeight: weight,
          fontSize: 12.5,
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFFF2F7FF),
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(icon, size: 17, color: const Color(0xFF2C5FA8)),
          ),
        ),
      ),
    );
  }
}
