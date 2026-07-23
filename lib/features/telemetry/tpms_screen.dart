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

  // Altura fixa por card: é o que permite calcular o ponto de saída da
  // linha conectora sem precisar medir o layout renderizado.
  static const double _diagramCardHeight = 92;
  static const double _diagramCardGap = 12;
  static const double _diagramBodyWidth = 58;

  Widget _buildCarDiagram(List<_TireReading> readings) {
    final left = <_TireReading>[];
    final right = <_TireReading>[];
    for (var i = 0; i < readings.length; i++) {
      (i.isEven ? left : right).add(readings[i]);
    }
    final rows = left.length > right.length ? left.length : right.length;
    final columnHeight = rows == 0
        ? 0.0
        : rows * _diagramCardHeight + (rows - 1) * _diagramCardGap;

    Widget buildColumn(List<_TireReading> items) {
      return SizedBox(
        width: 200,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              SizedBox(
                height: _diagramCardHeight,
                child: _TireCard(reading: items[i]),
              ),
              if (i != items.length - 1)
                const SizedBox(height: _diagramCardGap),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: Center(
        child: SizedBox(
          height: columnHeight == 0 ? null : columnHeight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              buildColumn(left),
              SizedBox(
                width: _diagramBodyWidth + _diagramCardGap * 2,
                height: columnHeight == 0 ? 220 : columnHeight,
                child: CustomPaint(
                  painter: _TruckDiagramPainter(
                    leftCount: left.length,
                    rightCount: right.length,
                    cardHeight: _diagramCardHeight,
                    cardGap: _diagramCardGap,
                    bodyWidth: _diagramBodyWidth,
                  ),
                ),
              ),
              buildColumn(right),
            ],
          ),
        ),
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

/// Desenha a silhueta do veiculo visto de cima (cabine + carroceria) e as
/// linhas conectando cada eixo/roda ao card correspondente nas colunas
/// esquerda/direita. Alturas fixas (cardHeight/cardGap) permitem calcular o
/// ponto de saida da linha sem medir o layout renderizado.
class _TruckDiagramPainter extends CustomPainter {
  const _TruckDiagramPainter({
    required this.leftCount,
    required this.rightCount,
    required this.cardHeight,
    required this.cardGap,
    required this.bodyWidth,
  });

  final int leftCount;
  final int rightCount;
  final double cardHeight;
  final double cardGap;
  final double bodyWidth;

  double _rowCenterY(int index, int count, double totalHeight) {
    final columnHeight = count * cardHeight + (count - 1) * cardGap;
    final offset = (totalHeight - columnHeight) / 2;
    return offset + index * (cardHeight + cardGap) + cardHeight / 2;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cabHeight = 34.0;
    final bodyTop = 6.0 + cabHeight - 6;
    final bodyLeft = (size.width - bodyWidth) / 2;
    final bodyRight = bodyLeft + bodyWidth;
    final bodyRect = Rect.fromLTRB(bodyLeft, bodyTop, bodyRight, size.height - 6);

    final bodyPaint = Paint()..color = const Color(0xFFDCE3ED);
    final bodyBorder = Paint()
      ..color = const Color(0xFFAFBBCC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    // Carroceria: retangulo estreito e alongado (contêiner visto de cima).
    final bodyRRect =
        RRect.fromRectAndRadius(bodyRect, const Radius.circular(6));
    canvas.drawRRect(bodyRRect, bodyPaint);
    canvas.drawRRect(bodyRRect, bodyBorder);

    // Linhas finas sugerindo as juntas da carroceria.
    final seamPaint = Paint()
      ..color = const Color(0xFFAFBBCC).withValues(alpha: 0.7)
      ..strokeWidth = 1;
    final seamCount = (bodyRect.height / 26).floor();
    for (var i = 1; i < seamCount; i++) {
      final y = bodyRect.top + (bodyRect.height / seamCount) * i;
      canvas.drawLine(
        Offset(bodyLeft + 4, y),
        Offset(bodyRight - 4, y),
        seamPaint,
      );
    }

    // Cabine: mais estreita na frente, com para-brisa e retrovisores —
    // silhueta de caminhão visto de cima, nao um "dedo" com ponta redonda.
    final cabWidth = bodyWidth * 0.86;
    final cabTop = 6.0;
    final cabPath = Path()
      ..moveTo(size.width / 2 - cabWidth * 0.36, cabTop + cabHeight)
      ..lineTo(size.width / 2 - cabWidth / 2, cabTop + 10)
      ..quadraticBezierTo(
        size.width / 2 - cabWidth / 2, cabTop,
        size.width / 2 - cabWidth * 0.28, cabTop,
      )
      ..lineTo(size.width / 2 + cabWidth * 0.28, cabTop)
      ..quadraticBezierTo(
        size.width / 2 + cabWidth / 2, cabTop,
        size.width / 2 + cabWidth / 2, cabTop + 10,
      )
      ..lineTo(size.width / 2 + cabWidth * 0.36, cabTop + cabHeight)
      ..close();
    canvas.drawPath(cabPath, Paint()..color = const Color(0xFF1F2A44));

    // Para-brisa.
    final windshieldPath = Path()
      ..moveTo(size.width / 2 - cabWidth * 0.24, cabTop + 4)
      ..lineTo(size.width / 2 - cabWidth * 0.34, cabTop + cabHeight * 0.62)
      ..lineTo(size.width / 2 + cabWidth * 0.34, cabTop + cabHeight * 0.62)
      ..lineTo(size.width / 2 + cabWidth * 0.24, cabTop + 4)
      ..close();
    canvas.drawPath(
      windshieldPath,
      Paint()..color = const Color(0xFF6FA3E8).withValues(alpha: 0.55),
    );

    // Retrovisores.
    final mirrorPaint = Paint()..color = const Color(0xFF1F2A44);
    final mirrorY = cabTop + cabHeight * 0.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width / 2 - cabWidth / 2 - 3, mirrorY),
          width: 6,
          height: 10,
        ),
        const Radius.circular(2),
      ),
      mirrorPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width / 2 + cabWidth / 2 + 3, mirrorY),
          width: 6,
          height: 10,
        ),
        const Radius.circular(2),
      ),
      mirrorPaint,
    );

    final linePaint = Paint()
      ..color = const Color(0xFFB7C3D6)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final wheelPaint = Paint()..color = const Color(0xFF2B3648);

    void drawWheel(Offset center) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: 10, height: 16),
          const Radius.circular(3),
        ),
        wheelPaint,
      );
    }

    for (var i = 0; i < leftCount; i++) {
      final y = _rowCenterY(i, leftCount, size.height);
      canvas.drawLine(Offset(0, y), Offset(bodyLeft, y), linePaint);
      drawWheel(Offset(bodyLeft, y));
    }
    for (var i = 0; i < rightCount; i++) {
      final y = _rowCenterY(i, rightCount, size.height);
      canvas.drawLine(Offset(bodyRight, y), Offset(size.width, y), linePaint);
      drawWheel(Offset(bodyRight, y));
    }
  }

  @override
  bool shouldRepaint(covariant _TruckDiagramPainter oldDelegate) {
    return oldDelegate.leftCount != leftCount ||
        oldDelegate.rightCount != rightCount ||
        oldDelegate.cardHeight != cardHeight ||
        oldDelegate.cardGap != cardGap ||
        oldDelegate.bodyWidth != bodyWidth;
  }
}
