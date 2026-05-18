import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/session_state.dart';

class TelemetrySensorsScreen extends ConsumerStatefulWidget {
  const TelemetrySensorsScreen({super.key});

  @override
  ConsumerState<TelemetrySensorsScreen> createState() =>
      _TelemetrySensorsScreenState();
}

class _TelemetrySensorsScreenState extends ConsumerState<TelemetrySensorsScreen> {
  int? _deviceId;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesProvider);
    final positionsAsync = ref.watch(positionsProvider);

    if (devicesAsync.isLoading || positionsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (devicesAsync.hasError) {
      return Center(child: Text('Falha ao carregar dispositivos: ${devicesAsync.error}'));
    }
    if (positionsAsync.hasError) {
      return Center(child: Text('Falha ao carregar posicoes: ${positionsAsync.error}'));
    }

    final devices = devicesAsync.valueOrNull ?? const <TraccarDevice>[];
    final positions = positionsAsync.valueOrNull ?? const <TraccarPosition>[];
    final latestByDevice = _latestPositionByDevice(positions);

    if (_deviceId == null && devices.isNotEmpty) {
      _deviceId = devices.first.id;
    }

    TraccarDevice? selectedDevice;
    if (_deviceId != null) {
      for (final device in devices) {
        if (device.id == _deviceId) {
          selectedDevice = device;
          break;
        }
      }
    }

    final selectedPosition =
        _deviceId == null ? null : latestByDevice[_deviceId!];
    final sensorRows = _buildSensorRows(
      selectedDevice: selectedDevice,
      selectedPosition: selectedPosition,
      search: _search,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDDE5F0)),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 320,
                child: DropdownButtonFormField<int>(
                  initialValue: _deviceId,
                  items: [
                    for (final d in devices)
                      DropdownMenuItem(value: d.id, child: Text(d.name)),
                  ],
                  onChanged: (value) => setState(() => _deviceId = value),
                  decoration: const InputDecoration(
                    labelText: 'Dispositivo',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(
                width: 280,
                child: TextField(
                  onChanged: (value) => setState(() => _search = value),
                  decoration: const InputDecoration(
                    hintText: 'Buscar sensor (ex: ignition, battery)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ref.invalidate(devicesProvider);
                  ref.invalidate(positionsProvider);
                },
                icon: const Icon(Icons.refresh_outlined),
                label: const Text('Atualizar'),
              ),
              Text(
                'Sensores recebidos: ${sensorRows.length}',
                style: const TextStyle(
                  color: Color(0xFF526684),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDDE5F0)),
            ),
            child: sensorRows.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhum sensor disponivel para o dispositivo selecionado.',
                      style: TextStyle(
                        color: Color(0xFF526684),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: sensorRows.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (context, index) {
                      final row = sensorRows[index];
                      return Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              row.key,
                              style: const TextStyle(
                                color: Color(0xFF1F2A44),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(
                              row.value,
                              style: const TextStyle(
                                color: Color(0xFF334155),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              row.source,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

Map<int, TraccarPosition> _latestPositionByDevice(List<TraccarPosition> rows) {
  final latest = <int, TraccarPosition>{};
  for (final row in rows) {
    final current = latest[row.deviceId];
    if (current == null) {
      latest[row.deviceId] = row;
      continue;
    }
    final currentTime = _parseDate(current.fixTime);
    final nextTime = _parseDate(row.fixTime);
    if (nextTime != null && (currentTime == null || nextTime.isAfter(currentTime))) {
      latest[row.deviceId] = row;
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

List<_SensorRow> _buildSensorRows({
  required TraccarDevice? selectedDevice,
  required TraccarPosition? selectedPosition,
  required String search,
}) {
  final normalizedSearch = search.trim().toLowerCase();
  final map = <String, _SensorRow>{};

  void addAll(Map<String, dynamic>? attrs, String source) {
    if (attrs == null || attrs.isEmpty) return;
    attrs.forEach((key, value) {
      final normalizedKey = key.trim();
      final normalizedValue = '${value ?? ''}'.trim();
      if (normalizedKey.isEmpty || normalizedValue.isEmpty) return;
      final id = normalizedKey.toLowerCase();
      map[id] = _SensorRow(
        key: normalizedKey,
        value: normalizedValue,
        source: source,
      );
    });
  }

  addAll(selectedDevice?.attributes, 'device');
  addAll(selectedPosition?.attributes, 'position');

  final rows = map.values.toList()
    ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

  if (normalizedSearch.isEmpty) return rows;
  return rows.where((row) {
    final bag = '${row.key} ${row.value} ${row.source}'.toLowerCase();
    return bag.contains(normalizedSearch);
  }).toList(growable: false);
}

class _SensorRow {
  const _SensorRow({
    required this.key,
    required this.value,
    required this.source,
  });

  final String key;
  final String value;
  final String source;
}
