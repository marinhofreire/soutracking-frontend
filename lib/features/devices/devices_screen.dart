import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/session_state.dart';

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

enum _DevicesQuickFilter { all, pending, ready, offline }

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  static const List<MapEntry<String, String>> _sensorOptions = [
    MapEntry('speed', 'Velocidade'),
    MapEntry('distance', 'Distancia'),
    MapEntry('ignition', 'Ignicao'),
    MapEntry('odometer', 'Odometro'),
    MapEntry('battery', 'Battery level'),
    MapEntry('rssi', 'GSM level'),
    MapEntry('power', 'Power'),
    MapEntry('fuel', 'Combustivel'),
    MapEntry('hours', 'Engine hour'),
    MapEntry('sat', 'GPS signal'),
  ];

  static const Set<String> _defaultSensorKeys = {
    'speed',
    'distance',
    'ignition',
    'odometer',
    'battery',
    'rssi',
  };

  final _nameController = TextEditingController();
  final _identifierController = TextEditingController();
  final _categoryController = TextEditingController();
  final _phoneController = TextEditingController();
  final Set<String> _selectedSensorKeys = <String>{};

  bool _saving = false;
  _DevicesQuickFilter _activeFilter = _DevicesQuickFilter.all;

  @override
  void dispose() {
    _nameController.dispose();
    _identifierController.dispose();
    _categoryController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _openCreateDeviceDialog() async {
    _nameController.clear();
    _identifierController.clear();
    _categoryController.clear();
    _phoneController.clear();
    _selectedSensorKeys
      ..clear()
      ..addAll(_defaultSensorKeys);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Adicionar dispositivo',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        IconButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        hintText: 'Ex: Teste Frontend',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _identifierController,
                      decoration: const InputDecoration(
                        labelText: 'Identificador / IMEI / Unique ID',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Categoria ou modelo (opcional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Telefone/chip (opcional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Sensores exibidos no painel',
                      style: TextStyle(
                        color: Color(0xFF1F2A44),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StatefulBuilder(
                      builder: (context, setModalState) {
                        return Wrap(
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
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Dica: esses sensores vao aparecer no card "Sensores" do veiculo.',
                      style: TextStyle(
                        color: Color(0xFF60718D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _saving
                            ? null
                            : () async {
                                final navigator = Navigator.of(dialogContext);
                                final created = await _createDevice();
                                if (!mounted ||
                                    !dialogContext.mounted ||
                                    !created) {
                                  return;
                                }
                                navigator.pop();
                              },
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_circle_outline),
                        label: Text(_saving ? 'Salvando...' : 'Salvar'),
                      ),
                    ),
                  ],
                ),
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
          _selectedSensorKeys.add(key);
        }
      }
    }
    if (_selectedSensorKeys.isEmpty) {
      _selectedSensorKeys.addAll(_defaultSensorKeys);
    }
  }

  Future<void> _openEditDeviceDialog(TraccarDevice device) async {
    _nameController.text = device.name;
    _identifierController.text = (device.uniqueId ?? '').trim();
    _categoryController.text = (device.category ?? '').trim();
    _phoneController.text = (device.attributes?['phone'] ?? '').toString();
    _setSelectedSensorsFromDevice(device);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Editar dispositivo',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        IconButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _identifierController,
                      decoration: const InputDecoration(
                        labelText: 'Identificador / IMEI / Unique ID',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Categoria ou modelo (opcional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Telefone/chip (opcional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Sensores exibidos no painel',
                      style: TextStyle(
                        color: Color(0xFF1F2A44),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StatefulBuilder(
                      builder: (context, setModalState) {
                        return Wrap(
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
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _saving
                            ? null
                            : () async {
                                final navigator = Navigator.of(dialogContext);
                                final updated = await _updateDevice(device);
                                if (!mounted ||
                                    !dialogContext.mounted ||
                                    !updated) {
                                  return;
                                }
                                navigator.pop();
                              },
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Salvando...' : 'Salvar edicao'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _createDevice() async {
    final name = _nameController.text.trim();
    final identifier = _identifierController.text.trim();
    final category = _categoryController.text.trim();
    final phone = _phoneController.text.trim();
    if (_selectedSensorKeys.isEmpty) {
      _selectedSensorKeys.addAll(_defaultSensorKeys);
    }
    final selectedSensors = _selectedSensorKeys.toList()..sort();
    final attributes = <String, dynamic>{
      if (phone.isNotEmpty) 'phone': phone,
      if (selectedSensors.isNotEmpty) 'souSensors': selectedSensors,
    };

    if (name.isEmpty || identifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe nome e identificador do dispositivo.'),
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
          if (attributes.isNotEmpty) 'attributes': attributes,
        },
      );

      ref.invalidate(devicesManagementProvider);
      ref.invalidate(devicesProvider);
      ref.invalidate(positionsProvider);

      if (!mounted) {
        return true;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispositivo cadastrado com sucesso.')),
      );
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<bool> _updateDevice(TraccarDevice device) async {
    final name = _nameController.text.trim();
    final identifier = _identifierController.text.trim();
    final category = _categoryController.text.trim();
    final phone = _phoneController.text.trim();
    if (_selectedSensorKeys.isEmpty) {
      _selectedSensorKeys.addAll(_defaultSensorKeys);
    }

    if (name.isEmpty || identifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe nome e identificador do dispositivo.'),
        ),
      );
      return false;
    }

    final selectedSensors = _selectedSensorKeys.toList()..sort();
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

      if (!mounted) {
        return true;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispositivo atualizado com sucesso.')),
      );
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _friendlyError(Object error) {
    final code = _extractHttpStatusCode(error);
    if (code == 401) {
      return 'Sessao expirada. Faca login novamente.';
    }
    if (code == 403) {
      return 'Seu usuario nao tem permissao para cadastrar dispositivos.';
    }
    if (code != null && code >= 500) {
      return 'Servico temporariamente indisponivel. Tente novamente em instantes.';
    }
    if (code != null) {
      return 'Nao foi possivel concluir a operacao (codigo $code).';
    }
    return 'Nao foi possivel concluir a operacao agora. Tente novamente.';
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

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'Nao informado';
    final dd = value.day.toString().padLeft(2, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final yyyy = value.year.toString().padLeft(4, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$min';
  }

  String _formatRelative(DateTime? value) {
    if (value == null) return 'Nao informado';
    final diff = DateTime.now().difference(value);
    if (diff.isNegative) return 'agora';
    if (diff.inSeconds < 60) return 'agora';
    if (diff.inMinutes < 60) return 'ha ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'ha ${diff.inHours}h';
    return 'ha ${diff.inDays}d';
  }

  String _latLngLabel(TraccarPosition? position) {
    if (position == null) return 'Nao informado';
    return '${position.latitude.toStringAsFixed(6)}, '
        '${position.longitude.toStringAsFixed(6)}';
  }

  String _speedLabel(TraccarPosition? position) {
    final speed = position?.speed;
    if (speed == null) return 'Nao informado';
    return '${speed.toStringAsFixed(0)} km/h';
  }

  bool _isHomologReady(TraccarDevice device, TraccarPosition? position) {
    final communication = _parseDate(device.lastUpdate ?? position?.fixTime);
    return device.id > 0 && communication != null && position != null;
  }

  DateTime? _deviceCommunicationAt(
    TraccarDevice device,
    TraccarPosition? position,
  ) {
    return _parseDate(device.lastUpdate ?? position?.fixTime);
  }

  bool _isOfflineDevice(TraccarDevice device, TraccarPosition? position) {
    final status = device.status.trim().toLowerCase();
    if (status == 'offline' || status == 'unknown') {
      return true;
    }
    final communication = _deviceCommunicationAt(device, position);
    if (communication == null) {
      return true;
    }
    return DateTime.now().difference(communication).inHours >= 24;
  }

  List<TraccarDevice> _applyQuickFilter(
    List<TraccarDevice> devices,
    Map<int, TraccarPosition> latestByDevice,
  ) {
    switch (_activeFilter) {
      case _DevicesQuickFilter.all:
        return devices;
      case _DevicesQuickFilter.pending:
        return devices
            .where(
                (device) => !_isHomologReady(device, latestByDevice[device.id]))
            .toList(growable: false);
      case _DevicesQuickFilter.ready:
        return devices
            .where(
                (device) => _isHomologReady(device, latestByDevice[device.id]))
            .toList(growable: false);
      case _DevicesQuickFilter.offline:
        return devices
            .where(
                (device) => _isOfflineDevice(device, latestByDevice[device.id]))
            .toList(growable: false);
    }
  }

  String _quickFilterLabel(_DevicesQuickFilter filter) {
    switch (filter) {
      case _DevicesQuickFilter.all:
        return 'Todos';
      case _DevicesQuickFilter.pending:
        return 'Pendentes';
      case _DevicesQuickFilter.ready:
        return 'Prontos';
      case _DevicesQuickFilter.offline:
        return 'Offline';
    }
  }

  Widget _buildQuickMenu({
    required int total,
    required int pending,
    required int ready,
    required int offline,
  }) {
    int countFor(_DevicesQuickFilter filter) {
      switch (filter) {
        case _DevicesQuickFilter.all:
          return total;
        case _DevicesQuickFilter.pending:
          return pending;
        case _DevicesQuickFilter.ready:
          return ready;
        case _DevicesQuickFilter.offline:
          return offline;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Menu rapido do modulo',
            style: TextStyle(
              color: Color(0xFF1F2A44),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final filter in _DevicesQuickFilter.values)
                ChoiceChip(
                  label: Text(
                    '${_quickFilterLabel(filter)} (${countFor(filter)})',
                  ),
                  selected: _activeFilter == filter,
                  onSelected: (_) {
                    setState(() => _activeFilter = filter);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesManagementProvider);
    final positionsAsync = ref.watch(positionsProvider);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Dispositivos',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF1F2A44),
                    ),
              ),
            ),
            FilledButton.icon(
              onPressed: _saving ? null : _openCreateDeviceDialog,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar dispositivo'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: devicesAsync.when(
            data: (devices) {
              final positions =
                  positionsAsync.valueOrNull ?? const <TraccarPosition>[];
              final latestByDevice = _latestPositionsByDevice(positions);

              if (devices.isEmpty) {
                return const _EmptyDevicesState();
              }
              final pendingCount = devices
                  .where((device) =>
                      !_isHomologReady(device, latestByDevice[device.id]))
                  .length;
              final readyCount = devices.length - pendingCount;
              final offlineCount = devices
                  .where((device) =>
                      _isOfflineDevice(device, latestByDevice[device.id]))
                  .length;
              final filteredDevices =
                  _applyQuickFilter(devices, latestByDevice);

              return Column(
                children: [
                  _buildQuickMenu(
                    total: devices.length,
                    pending: pendingCount,
                    ready: readyCount,
                    offline: offlineCount,
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filteredDevices.isEmpty
                        ? const _EmptyFilteredDevicesState()
                        : ListView.separated(
                            itemCount: filteredDevices.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = filteredDevices[index];
                              final position = latestByDevice[item.id];
                              final communicationAt =
                                  _deviceCommunicationAt(item, position);
                              final homologReady =
                                  _isHomologReady(item, position);

                              final details = [
                                if ((item.uniqueId ?? '').trim().isNotEmpty)
                                  'ID: ${item.uniqueId}',
                                if ((item.category ?? '').trim().isNotEmpty)
                                  'Categoria: ${item.category}',
                                if ((item.attributes?['phone'] ?? '')
                                    .toString()
                                    .trim()
                                    .isNotEmpty)
                                  'Chip: ${item.attributes?['phone']}',
                                'Status: ${item.status}',
                                'Ultima comunicacao: ${_formatDateTime(communicationAt)}',
                                'Tempo: ${_formatRelative(communicationAt)}',
                                'Posicao: ${_latLngLabel(position)}',
                                'Velocidade: ${_speedLabel(position)}',
                                'Homologacao: ${homologReady ? 'Pronto' : 'Pendente'}',
                              ].join(' | ');

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.84),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFDDE5F0)),
                                ),
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(
                                    Icons.memory_outlined,
                                    color: Color(0xFF176EEB),
                                  ),
                                  title: Text(
                                    item.name,
                                    style: const TextStyle(
                                      color: Color(0xFF1F2A44),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    details,
                                    style: const TextStyle(
                                      color: Color(0xFF60718D),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    tooltip: 'Editar dispositivo',
                                    onPressed: _saving
                                        ? null
                                        : () => _openEditDeviceDialog(item),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      color: Color(0xFF176EEB),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _FriendlyErrorState(
              message: _friendlyError(error),
              onRetry: () => ref.invalidate(devicesManagementProvider),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyDevicesState extends StatelessWidget {
  const _EmptyDevicesState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDDE5F0)),
        ),
        child: const Text(
          'Nenhum dispositivo cadastrado',
          style: TextStyle(
            color: Color(0xFF25344A),
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _EmptyFilteredDevicesState extends StatelessWidget {
  const _EmptyFilteredDevicesState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDDE5F0)),
        ),
        child: const Text(
          'Nenhum dispositivo encontrado para esse filtro',
          style: TextStyle(
            color: Color(0xFF25344A),
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _FriendlyErrorState extends StatelessWidget {
  const _FriendlyErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDDE5F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF176EEB)),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                color: Color(0xFF25344A),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
