import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/display_text_formatter.dart';
import '../../data/models.dart';
import '../../state/session_state.dart';
import '../../widgets/dial_gauge.dart';

/// Painel dedicado ao TPMS (sensores de pressão/temperatura dos pneus).
/// Fica separado da tela de Telemetria normal — nada ali é removido, esse
/// é só mais um item de menu que lê os mesmos atributos tireXXBattery/
/// Temp/Pressure gravados pelo decoder "totem" (mensagem E6).
class TpmsScreen extends ConsumerStatefulWidget {
  const TpmsScreen({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  ConsumerState<TpmsScreen> createState() => _TpmsScreenState();
}

class _TireReading {
  const _TireReading({
    required this.index,
    required this.rawId,
    required this.batteryVolts,
    required this.temperatureC,
    required this.pressureRaw,
  });

  final int index;
  final String rawId;
  final double? batteryVolts;
  final int? temperatureC;
  final int? pressureRaw;

  bool get isLowBattery => batteryVolts != null && batteryVolts! < 2.8;
}

class _TpmsScreenState extends ConsumerState<TpmsScreen> {
  int? _deviceId;
  String _search = '';

  // Pacotes E6 (TPMS) chegam bem mais raro que os pacotes de posição normais
  // do device, então uma posição comum não carrega mais os atributos de
  // pneu. Sem esse cache local por dispositivo, o painel piscaria/zeraria
  // toda vez que uma posição sem TPMS chegasse depois.
  final Map<int, Map<String, dynamic>> _tireCache = {};

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesProvider);
    final positionsAsync = ref.watch(positionsProvider);

    if (devicesAsync.isLoading || positionsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (devicesAsync.hasError) {
      return Center(
        child: Text('Falha ao carregar dispositivos: ${devicesAsync.error}'),
      );
    }
    if (positionsAsync.hasError) {
      return Center(
        child: Text('Falha ao carregar posições: ${positionsAsync.error}'),
      );
    }

    final devices = devicesAsync.valueOrNull ?? const <TraccarDevice>[];
    final positions = positionsAsync.valueOrNull ?? const <TraccarPosition>[];
    final latestByDevice = _latestPositionByDevice(positions);

    for (final entry in latestByDevice.entries) {
      final attrs = entry.value.attributes;
      if (attrs == null) continue;
      final tireEntries = <String, dynamic>{
        for (final attrEntry in attrs.entries)
          if (attrEntry.key.startsWith('tire')) attrEntry.key: attrEntry.value,
      };
      if (tireEntries.isEmpty) continue;
      _tireCache.putIfAbsent(entry.key, () => {}).addAll(tireEntries);
    }

    if (devices.isEmpty) {
      _deviceId = null;
    } else if (_deviceId == null ||
        !devices.any((device) => device.id == _deviceId)) {
      // Prioriza mostrar primeiro um equipamento que já tenha algum dado de
      // pneu recebido, em vez do primeiro da lista.
      final withTires =
          devices.where((d) => (_tireCache[d.id] ?? const {}).isNotEmpty);
      _deviceId = withTires.isNotEmpty ? withTires.first.id : devices.first.id;
    }

    TraccarDevice? selectedDevice;
    for (final device in devices) {
      if (device.id == _deviceId) {
        selectedDevice = device;
        break;
      }
    }
    final selectedPosition =
        selectedDevice == null ? null : latestByDevice[selectedDevice.id];
    final tireAttrs = selectedDevice == null
        ? const <String, dynamic>{}
        : (_tireCache[selectedDevice.id] ?? const <String, dynamic>{});
    final readings = _readingsFromAttributes(tireAttrs);
    final mergedAttrs = <String, dynamic>{
      ...?selectedDevice?.attributes,
      ...?selectedPosition?.attributes,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF176EEB).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.tire_repair_rounded,
                color: Color(0xFF176EEB),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TPMS',
                    style: TextStyle(
                      color: Color(0xFF1F2A44),
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'Sensores e dados operacionais dos pneus',
                    style: TextStyle(
                      color: Color(0xFF60718D),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                ref.invalidate(devicesProvider);
                ref.invalidate(positionsProvider);
              },
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Atualizar',
              style:
                  IconButton.styleFrom(foregroundColor: const Color(0xFF60718D)),
            ),
            IconButton(
              onPressed: widget.onClose,
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Fechar',
              style:
                  IconButton.styleFrom(foregroundColor: const Color(0xFF60718D)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildToolbar(devices, readings.length),
        const SizedBox(height: 10),
        if (selectedDevice != null) ...[
          _buildQuickStatsBar(selectedDevice, selectedPosition, mergedAttrs),
          const SizedBox(height: 10),
        ],
        Expanded(
          child: readings.isEmpty
              ? _emptyState()
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildCarDiagram(readings),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildAveragesAndAlerts(readings),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: const Center(
        child: Text(
          'Nenhum sensor TPMS recebido ainda para este equipamento.',
          style: TextStyle(color: Color(0xFF526684), fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildToolbar(List<TraccarDevice> devices, int tireCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<int>(
              key: ValueKey<int?>(_deviceId),
              initialValue: _deviceId,
              items: [
                for (final d in devices)
                  DropdownMenuItem(
                    value: d.id,
                    child: Text(formatDisplayText(d.name)),
                  ),
              ],
              onChanged: (value) => setState(() => _deviceId = value),
              decoration: const InputDecoration(
                labelText: 'Veículo',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            width: 300,
            child: TextField(
              onChanged: (value) => setState(() => _search = value),
              decoration: const InputDecoration(
                hintText: 'Buscar sensor (ex.: posição, pneu)',
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.search_rounded, size: 18),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {
              ref.invalidate(devicesProvider);
              ref.invalidate(positionsProvider);
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Atualizar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF176EEB),
              side: const BorderSide(color: Color(0xFF176EEB)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          Text(
            'Sensores recebidos: $tireCount',
            style: const TextStyle(
              color: Color(0xFF526684),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsBar(
    TraccarDevice device,
    TraccarPosition? position,
    Map<String, dynamic> attrs,
  ) {
    final isOnline = device.status.trim().toLowerCase() == 'online';
    final ignition = _attrBool(attrs, const ['ignition', 'ignitionOn']);
    final gpsOk = position != null;
    final odometer =
        _attrDouble(attrs, const ['totalDistance', 'odometer', 'distance']);
    final odometerLabel =
        odometer != null ? '${(odometer / 1000).toStringAsFixed(2)} km' : '--';
    final lastRef = device.lastUpdate ?? position?.fixTime;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _quickStatCell(
              icon: Icons.circle,
              iconColor:
                  isOnline ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
              iconSize: 10,
              label: isOnline ? 'Online' : 'Offline',
              subtitle: isOnline ? 'Equipamento conectado' : 'Sem comunicação',
            ),
            const VerticalDivider(width: 1, color: Color(0xFFE8EFF7)),
            _quickStatCell(
              icon: Icons.power_settings_new_rounded,
              iconColor: ignition == null
                  ? const Color(0xFF94A3B8)
                  : ignition
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
              label: 'Ignição',
              subtitle:
                  ignition == null ? '--' : (ignition ? 'Ligada' : 'Desligada'),
            ),
            const VerticalDivider(width: 1, color: Color(0xFFE8EFF7)),
            _quickStatCell(
              icon: Icons.gps_fixed_rounded,
              iconColor:
                  gpsOk ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
              label: 'GPS ativo',
              subtitle: gpsOk ? 'Sinal OK' : 'Sem sinal',
            ),
            const VerticalDivider(width: 1, color: Color(0xFFE8EFF7)),
            _quickStatCell(
              icon: Icons.access_time_rounded,
              iconColor: const Color(0xFF526684),
              label: 'Última conexão',
              subtitle: _relativeTimeLabel(lastRef),
            ),
            const VerticalDivider(width: 1, color: Color(0xFFE8EFF7)),
            _quickStatCell(
              icon: Icons.speed_rounded,
              iconColor: const Color(0xFF526684),
              label: 'Odômetro',
              subtitle: odometerLabel,
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickStatCell({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subtitle,
    double iconSize = 18,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: iconSize),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF1F2A44),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF60718D),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // IDs vêm crus do sensor (ex: "11", "21", "14", "24" — eixo+posição, ainda
  // não documentado pelo fabricante). Por enquanto só numeramos 1..N pela
  // ordem crescente do ID, pra dar uma posição visual estável no desenho.
  List<_TireReading> _readingsFromAttributes(Map<String, dynamic> attrs) {
    final search = _search.trim().toLowerCase();
    final ids = <String>{
      for (final key in attrs.keys)
        if (key.startsWith('tire') && key.length >= 6) key.substring(4, 6),
    }.toList()
      ..sort();
    final all = [
      for (var i = 0; i < ids.length; i++)
        _TireReading(
          index: i + 1,
          rawId: ids[i],
          batteryVolts: (attrs['tire${ids[i]}Battery'] as num?)?.toDouble(),
          temperatureC: (attrs['tire${ids[i]}Temp'] as num?)?.toInt(),
          pressureRaw: (attrs['tire${ids[i]}Pressure'] as num?)?.toInt(),
        ),
    ];
    if (search.isEmpty) return all;
    return all
        .where((r) =>
            'pneu ${r.index}'.contains(search) ||
            r.rawId.toLowerCase().contains(search) ||
            'posição ${r.rawId}'.contains(search))
        .toList(growable: false);
  }

  Widget _buildCarDiagram(List<_TireReading> readings) {
    final left = <_TireReading>[];
    final right = <_TireReading>[];
    for (var i = 0; i < readings.length; i++) {
      (i.isEven ? left : right).add(readings[i]);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final reading in left) ...[
                  _TireCard(reading: reading),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 96,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.directions_car_filled_rounded,
                  size: 96,
                  color: Color(0xFF1F2A44),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final reading in right) ...[
                  _TireCard(reading: reading),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAveragesAndAlerts(List<_TireReading> readings) {
    final pressures = readings
        .map((r) => r.pressureRaw)
        .whereType<int>()
        .map((v) => v.toDouble())
        .toList();
    final temps = readings
        .map((r) => r.temperatureC)
        .whereType<int>()
        .map((v) => v.toDouble())
        .toList();
    final batteries = readings
        .map((r) => r.batteryVolts)
        .whereType<double>()
        .toList();

    final avgPressure =
        pressures.isEmpty ? 0.0 : pressures.reduce((a, b) => a + b) / pressures.length;
    final avgTemp =
        temps.isEmpty ? 0.0 : temps.reduce((a, b) => a + b) / temps.length;
    final avgBattery = batteries.isEmpty
        ? 0.0
        : batteries.reduce((a, b) => a + b) / batteries.length;

    final lowBattery = readings.where((r) => r.isLowBattery).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DialGauge(
                label: 'Pressão média',
                unit: 'bruto',
                value: avgPressure,
                max: 260,
                color: const Color(0xFF176EEB),
                ticks: const [0, 65, 130, 195, 260],
                loading: false,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DialGauge(
                label: 'Temperatura média',
                unit: '°C',
                value: avgTemp,
                max: 120,
                color: avgTemp > 60
                    ? const Color(0xFFDC2626)
                    : const Color(0xFFF59E0B),
                ticks: const [-20, 10, 40, 70, 100, 120],
                loading: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDDE5F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.battery_std_rounded,
                        size: 16, color: Color(0xFF4B5A72)),
                    const SizedBox(width: 6),
                    Text(
                      'Bateria média: ${avgBattery.toStringAsFixed(2)} V',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2A44),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 10),
                const Text(
                  'Alertas ativos',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2A44),
                  ),
                ),
                const SizedBox(height: 8),
                if (lowBattery.isEmpty)
                  const Text(
                    'Nenhum alerta de bateria baixa nos sensores.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF60718D),
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  for (final reading in lowBattery)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              size: 15, color: Color(0xFFE0533D)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Bateria baixa — Pneu ${reading.index} '
                              '(${reading.batteryVolts?.toStringAsFixed(2)} V)',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F2A44),
                              ),
                            ),
                          ),
                        ],
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

class _TireCard extends StatelessWidget {
  const _TireCard({required this.reading});

  final _TireReading reading;

  @override
  Widget build(BuildContext context) {
    final color = reading.isLowBattery
        ? const Color(0xFFE0533D)
        : const Color(0xFF2F9E5C);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tire_repair_rounded, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                'Pneu ${reading.index}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2A44),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            reading.pressureRaw == null
                ? 'Pressão: —'
                : 'Pressão: ${reading.pressureRaw}',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
          Text(
            reading.temperatureC == null
                ? 'Temp.: —'
                : 'Temp.: ${reading.temperatureC}°C',
            style: const TextStyle(fontSize: 11, color: Color(0xFF4B5A72)),
          ),
          Text(
            reading.batteryVolts == null
                ? 'Bateria: —'
                : 'Bateria: ${reading.batteryVolts!.toStringAsFixed(2)} V',
            style: const TextStyle(fontSize: 11, color: Color(0xFF4B5A72)),
          ),
        ],
      ),
    );
  }
}

bool? _attrBool(Map<String, dynamic> attrs, List<String> keys) {
  for (final key in keys) {
    final value = attrs[key];
    if (value == null) continue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.toLowerCase().trim();
      if (normalized == 'true' || normalized == 'on' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == 'off' || normalized == '0') {
        return false;
      }
    }
  }
  return null;
}

double? _attrDouble(Map<String, dynamic> attrs, List<String> keys) {
  for (final key in keys) {
    final value = attrs[key];
    if (value == null) continue;
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return null;
}

String _relativeTimeLabel(String? isoTime) {
  if (isoTime == null || isoTime.trim().isEmpty) return 'Não informado';
  final parsed = DateTime.tryParse(isoTime);
  if (parsed == null) return 'Não informado';
  final local = parsed.isUtc ? parsed.toLocal() : parsed;
  final diff = DateTime.now().difference(local);
  if (diff.inSeconds < 60) return 'Agora mesmo';
  if (diff.inMinutes < 60) return 'Há ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Há ${diff.inHours} h';
  return 'Há ${diff.inDays} dia(s)';
}

Map<int, TraccarPosition> _latestPositionByDevice(List<TraccarPosition> rows) {
  final latest = <int, TraccarPosition>{};
  for (final row in rows) {
    final current = latest[row.deviceId];
    if (current == null) {
      latest[row.deviceId] = row;
      continue;
    }
    final currentTime = DateTime.tryParse(current.fixTime);
    final nextTime = DateTime.tryParse(row.fixTime);
    if (nextTime != null &&
        (currentTime == null || nextTime.isAfter(currentTime))) {
      latest[row.deviceId] = row;
    }
  }
  return latest;
}
