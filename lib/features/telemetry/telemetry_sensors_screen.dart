import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/session_state.dart';
import 'sensor_presentation.dart';

final _telemetryDeviceHistoryProvider =
    FutureProvider.family.autoDispose<List<TraccarPosition>, int>(
  (ref, deviceId) async {
    final session = ref.watch(sessionProvider);
    if (!session.isAuthenticated) {
      return const <TraccarPosition>[];
    }
    final client = ref.watch(traccarClientProvider);
    try {
      final rows = await client.getPositions(
        cookie: session.cookie,
        authHeader: session.authHeader,
        deviceId: deviceId,
      );
      rows.sort((a, b) {
        final ta = _parseDate(a.fixTime);
        final tb = _parseDate(b.fixTime);
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });
      return rows;
    } catch (_) {
      return const <TraccarPosition>[];
    }
  },
);

class TelemetrySensorsScreen extends ConsumerStatefulWidget {
  const TelemetrySensorsScreen({super.key});

  @override
  ConsumerState<TelemetrySensorsScreen> createState() =>
      _TelemetrySensorsScreenState();
}

class _TelemetrySensorsScreenState
    extends ConsumerState<TelemetrySensorsScreen> {
  int? _deviceId;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final includeTechnical = session.isAdministrator || kDebugMode;
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
    final snapshots = _buildSnapshots(devices, latestByDevice);

    if (_deviceId == null && snapshots.isNotEmpty) {
      _deviceId = snapshots.first.device.id;
    }

    _TelemetryDeviceSnapshot? selectedSnapshot;
    if (_deviceId != null) {
      for (final snapshot in snapshots) {
        if (snapshot.device.id == _deviceId) {
          selectedSnapshot = snapshot;
          break;
        }
      }
    }

    final sections = buildSensorDisplaySections(
      deviceAttributes: selectedSnapshot?.device.attributes,
      positionAttributes: selectedSnapshot?.position?.attributes,
      includeTechnical: includeTechnical,
    );
    final filteredSections = _filterSensorSections(sections, _search);
    final rowsCount = filteredSections.fold<int>(
        0, (sum, section) => sum + section.items.length);
    final historyAsync = _deviceId == null
        ? const AsyncData<List<TraccarPosition>>(<TraccarPosition>[])
        : ref.watch(_telemetryDeviceHistoryProvider(_deviceId!));
    final eventsAsync = _deviceId == null
        ? const AsyncData<List<Map<String, dynamic>>>(
            <Map<String, dynamic>>[],
          )
        : ref.watch(deviceEventsProvider(_deviceId!));
    final deviceHistory =
        historyAsync.valueOrNull ?? const <TraccarPosition>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildToolbar(devices, rowsCount),
        const SizedBox(height: 10),
        _buildTelemetryGrid(snapshots),
        if (selectedSnapshot != null) ...[
          const SizedBox(height: 10),
          _buildSelectedVehicleHeader(selectedSnapshot),
        ],
        const SizedBox(height: 10),
        Expanded(
          child: _buildSensorDetails(
            selectedSnapshot: selectedSnapshot,
            filteredSections: filteredSections,
            deviceHistory: deviceHistory,
            historyLoading: historyAsync.isLoading,
            eventsAsync: eventsAsync,
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(List<TraccarDevice> devices, int rowsCount) {
    return _TranslucentCard(
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
                hintText: 'Buscar sensor (ex: ignição, bateria)',
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
            'Sensores recebidos: $rowsCount',
            style: const TextStyle(
              color: Color(0xFF526684),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryGrid(List<_TelemetryDeviceSnapshot> snapshots) {
    return _TranslucentCard(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 6),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FBFF).withValues(alpha: 0.75),
              border: const Border(
                bottom: BorderSide(color: Color(0xFFDDE5F0)),
              ),
            ),
            child: const Row(
              children: [
                _TelemetryHeaderCell(flex: 16, label: 'Status'),
                _TelemetryHeaderCell(flex: 26, label: 'Equipamento'),
                _TelemetryHeaderCell(flex: 16, label: 'IMEI / ID'),
                _TelemetryHeaderCell(flex: 18, label: 'Última conexão'),
                _TelemetryHeaderCell(flex: 10, label: 'Velocidade'),
                _TelemetryHeaderCell(flex: 8, label: 'Ignição'),
                _TelemetryHeaderCell(flex: 10, label: 'Bateria'),
                _TelemetryHeaderCell(flex: 10, label: 'Sinal GSM'),
              ],
            ),
          ),
          if (snapshots.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Nenhum dispositivo recebido.',
                style: TextStyle(
                  color: Color(0xFF60718D),
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            SizedBox(
              height: 228,
              child: ListView.separated(
                itemCount: snapshots.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final snapshot = snapshots[index];
                  final selected = snapshot.device.id == _deviceId;
                  return InkWell(
                    onTap: () => setState(() => _deviceId = snapshot.device.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFEAF3FF).withValues(alpha: 0.72)
                            : Colors.transparent,
                        border: selected
                            ? Border(
                                left: BorderSide(
                                  color: const Color(0xFF176EEB),
                                  width: 2,
                                ),
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 16,
                            child: _StatusPill(snapshot: snapshot),
                          ),
                          Expanded(
                            flex: 26,
                            child: Text(
                              snapshot.device.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF1F2A44),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 16,
                            child: Text(
                              snapshot.device.uniqueId ?? '--',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF4B5C77),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 18,
                            child: Text(
                              snapshot.lastConnectionLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF4B5C77),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 10,
                            child: Text(
                              snapshot.speedLabel,
                              style: TextStyle(
                                color: snapshot.speedKmh >= 1
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFF4B5C77),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 8,
                            child: Icon(
                              Icons.power_settings_new_rounded,
                              color: _ignitionColor(snapshot.ignition),
                              size: 19,
                            ),
                          ),
                          Expanded(
                            flex: 10,
                            child: Text(
                              snapshot.batteryLabel,
                              style: TextStyle(
                                color: _batteryColor(snapshot),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 10,
                            child: Row(
                              children: [
                                _BlinkingIcon(
                                  enabled:
                                      snapshot.gsmLevel == _GsmLevel.critical,
                                  child: Icon(
                                    _gsmIcon(snapshot.gsmLevel),
                                    color: _gsmColor(snapshot.gsmLevel),
                                    size: 19,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    snapshot.gsmLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _gsmColor(snapshot.gsmLevel),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
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
    );
  }

  Widget _buildSelectedVehicleHeader(_TelemetryDeviceSnapshot snapshot) {
    final statusText = snapshot.device.status.trim().toLowerCase() == 'online'
        ? 'Online'
        : snapshot.device.status.trim().toLowerCase() == 'offline'
            ? 'Offline'
            : 'Sem comunicação';
    return _TranslucentCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          const Icon(
            Icons.directions_car_filled_rounded,
            color: Color(0xFF176EEB),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot.device.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1F2A44),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$statusText • Última atualização: ${snapshot.lastConnectionLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF526684),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _HeaderQuickMetric(
            label: 'Velocidade',
            value: snapshot.speedLabel,
            color: snapshot.speedKmh >= 1
                ? const Color(0xFF16A34A)
                : const Color(0xFF64748B),
          ),
          const SizedBox(width: 6),
          _HeaderQuickMetric(
            label: 'Sinal',
            value: snapshot.gsmLabel,
            color: _gsmColor(snapshot.gsmLevel),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorDetails({
    required _TelemetryDeviceSnapshot? selectedSnapshot,
    required List<SensorDisplaySection> filteredSections,
    required List<TraccarPosition> deviceHistory,
    required bool historyLoading,
    required AsyncValue<List<Map<String, dynamic>>> eventsAsync,
  }) {
    if (selectedSnapshot == null) {
      return const _TranslucentCard(
        child: Center(
          child: Text(
            'Selecione um dispositivo para visualizar a telemetria.',
            style: TextStyle(
              color: Color(0xFF526684),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    final events = _sortedEvents(eventsAsync.valueOrNull ?? const []);

    return _TranslucentCard(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildTelemetryOverviewGrid(
            snapshot: selectedSnapshot,
            history: deviceHistory,
            loading: historyLoading,
          ),
          const SizedBox(height: 10),
          _buildEventsPanel(
            events: events,
            loading: eventsAsync.isLoading,
          ),
          const SizedBox(height: 10),
          if (filteredSections.isEmpty)
            const Text(
              'Sensores não recebidos para o dispositivo selecionado.',
              style: TextStyle(
                color: Color(0xFF526684),
                fontWeight: FontWeight.w700,
              ),
            )
          else
            for (final section in filteredSections) ...[
              Text(
                section.title,
                style: const TextStyle(
                  color: Color(0xFF1F2A44),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              for (final item in section.items) ...[
                Row(
                  children: [
                    _BlinkingIcon(
                      enabled: _sensorShouldBlink(item),
                      child: Icon(
                        item.icon,
                        size: 16,
                        color: _sensorColor(item),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          color: Color(0xFF1F2A44),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        item.value,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: _sensorValueColor(item),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 10),
              ],
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Widget _buildTelemetryOverviewGrid({
    required _TelemetryDeviceSnapshot snapshot,
    required List<TraccarPosition> history,
    required bool loading,
  }) {
    final recentRows = history.take(24).toList(growable: false);
    final speedSeries = [
      for (final row in recentRows.reversed) (row.speed ?? 0) * 1.852,
    ];
    final batterySeries = [
      for (final row in recentRows.reversed)
        _attrDouble(
              row.attributes ?? const <String, dynamic>{},
              const ['batteryLevel', 'batteryPercent', 'deviceBatteryLevel'],
            ) ??
            0,
    ];
    final gsmSeries = [
      for (final row in recentRows.reversed)
        _attrDouble(
              row.attributes ?? const <String, dynamic>{},
              const ['gsm', 'signal', 'gsmSignal'],
            ) ??
            0,
    ];
    final ignitionSeries = [
      for (final row in recentRows.reversed)
        _attrBool(
              row.attributes ?? const <String, dynamic>{},
              const ['ignition', 'ignitionOn'],
            ) ==
            true
            ? 1.0
            : 0.0,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _TelemetryMetricSparkCard(
          title: 'Velocidade',
          value: snapshot.speedLabel,
          color: const Color(0xFF16A34A),
          points: speedSeries,
          maxY: 160,
          loading: loading,
        ),
        _TelemetryMetricSparkCard(
          title: 'Bateria',
          value: snapshot.batteryLabel,
          color: _batteryColor(snapshot),
          points: batterySeries,
          maxY: 100,
          loading: loading,
        ),
        _TelemetryMetricSparkCard(
          title: 'Sinal GSM',
          value: snapshot.gsmLabel,
          color: _gsmColor(snapshot.gsmLevel),
          points: gsmSeries,
          maxY: 32,
          loading: loading,
        ),
        _TelemetryMetricSparkCard(
          title: 'Ignição',
          value: snapshot.ignition == null
              ? 'Não informado'
              : snapshot.ignition!
                  ? 'Ligada'
                  : 'Desligada',
          color: _ignitionColor(snapshot.ignition),
          points: ignitionSeries,
          maxY: 1,
          loading: loading,
        ),
      ],
    );
  }

  Widget _buildEventsPanel({
    required List<Map<String, dynamic>> events,
    required bool loading,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Últimos eventos',
            style: TextStyle(
              color: Color(0xFF1F2A44),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          if (loading)
            const LinearProgressIndicator(minHeight: 2.4)
          else if (events.isEmpty)
            const Text(
              'Não informado',
              style: TextStyle(
                color: Color(0xFF60718D),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            )
          else
            for (final event in events.take(8)) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatEventType(event['type']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1F2A44),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _eventTimeLabel(event),
                    style: const TextStyle(
                      color: Color(0xFF526684),
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
              const Divider(height: 10),
            ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _sortedEvents(List<Map<String, dynamic>> raw) {
    final rows = [...raw];
    rows.sort((a, b) {
      final ta = _parseDate(
        '${a['eventTime'] ?? a['serverTime'] ?? a['deviceTime'] ?? a['fixTime'] ?? ''}',
      );
      final tb = _parseDate(
        '${b['eventTime'] ?? b['serverTime'] ?? b['deviceTime'] ?? b['fixTime'] ?? ''}',
      );
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });
    return rows;
  }

  String _eventTimeLabel(Map<String, dynamic> event) {
    final parsed = _parseDate(
      '${event['eventTime'] ?? event['serverTime'] ?? event['deviceTime'] ?? event['fixTime'] ?? ''}',
    );
    if (parsed == null) return 'Não informado';
    final dd = parsed.day.toString().padLeft(2, '0');
    final mm = parsed.month.toString().padLeft(2, '0');
    final hh = parsed.hour.toString().padLeft(2, '0');
    final min = parsed.minute.toString().padLeft(2, '0');
    return '$dd/$mm $hh:$min';
  }

  String _formatEventType(dynamic raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return 'Não informado';
    final withSpaces = value
        .replaceAllMapped(
            RegExp(r'([a-z])([A-Z])'), (m) => '${m.group(1)} ${m.group(2)}')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim();
    if (withSpaces.isEmpty) return 'Não informado';
    final first = withSpaces.substring(0, 1).toUpperCase();
    final rest = withSpaces.length > 1 ? withSpaces.substring(1) : '';
    return '$first$rest';
  }

  List<_TelemetryDeviceSnapshot> _buildSnapshots(
    List<TraccarDevice> devices,
    Map<int, TraccarPosition> latestByDevice,
  ) {
    final rows = <_TelemetryDeviceSnapshot>[];
    for (final device in devices) {
      final position = latestByDevice[device.id];
      final attrs = <String, dynamic>{
        ...?device.attributes,
        ...?position?.attributes,
      };

      final ignition = _attrBool(attrs, const ['ignition', 'ignitionOn']);
      final batteryLevel = _attrDouble(
        attrs,
        const ['batteryLevel', 'batteryPercent', 'deviceBatteryLevel'],
      );
      final batteryVoltage = _attrDouble(
        attrs,
        const ['battery', 'batteryVoltage', 'deviceBattery'],
      );
      final speedKnots = position?.speed ?? 0;
      final speedKmh = speedKnots * 1.852;
      final lastRef = device.lastUpdate ?? position?.fixTime;
      final gsm = _attrDouble(attrs, const ['gsm', 'signal', 'gsmSignal']);
      final rssi = _attrDouble(attrs, const ['rssi']);
      final gsmLevel = _resolveGsmLevel(gsm: gsm, rssi: rssi);

      rows.add(
        _TelemetryDeviceSnapshot(
          device: device,
          position: position,
          ignition: ignition,
          batteryLevel: batteryLevel,
          batteryVoltage: batteryVoltage,
          speedKmh: speedKmh,
          lastConnectionLabel: _relativeTimeLabel(lastRef),
          gsmLevel: gsmLevel,
          gsmLabel: _gsmDisplayLabel(gsm: gsm, rssi: rssi),
        ),
      );
    }

    rows.sort((a, b) {
      final byStatus =
          _statusRank(a.device.status).compareTo(_statusRank(b.device.status));
      if (byStatus != 0) return byStatus;
      return a.device.name.toLowerCase().compareTo(b.device.name.toLowerCase());
    });

    return rows;
  }

  int _statusRank(String status) {
    final normalized = status.trim().toLowerCase();
    if (normalized == 'online') return 0;
    if (normalized == 'unknown') return 1;
    return 2;
  }

  Color _ignitionColor(bool? value) {
    if (value == null) return const Color(0xFF94A3B8);
    return value ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
  }

  Color _batteryColor(_TelemetryDeviceSnapshot snapshot) {
    if (snapshot.batteryLevel == null) return const Color(0xFF4B5C77);
    if (snapshot.batteryLevel! < 20) return const Color(0xFFDC2626);
    if (snapshot.batteryLevel! < 35) return const Color(0xFFF59E0B);
    return const Color(0xFF16A34A);
  }

  Color _gsmColor(_GsmLevel level) {
    switch (level) {
      case _GsmLevel.good:
        return const Color(0xFF16A34A);
      case _GsmLevel.medium:
        return const Color(0xFFF59E0B);
      case _GsmLevel.low:
        return const Color(0xFFEA580C);
      case _GsmLevel.critical:
        return const Color(0xFFDC2626);
      case _GsmLevel.unknown:
        return const Color(0xFF94A3B8);
    }
  }

  IconData _gsmIcon(_GsmLevel level) {
    switch (level) {
      case _GsmLevel.good:
        return Icons.signal_cellular_4_bar_rounded;
      case _GsmLevel.medium:
        return Icons.signal_cellular_alt_2_bar_rounded;
      case _GsmLevel.low:
        return Icons.signal_cellular_alt_1_bar_rounded;
      case _GsmLevel.critical:
        return Icons.signal_cellular_0_bar_rounded;
      case _GsmLevel.unknown:
        return Icons.signal_cellular_alt_rounded;
    }
  }

  Color _sensorColor(SensorDisplayItem item) {
    switch (item.key) {
      case 'ignition':
      case 'gpsTracking':
      case 'activated':
        return _boolSensorColor(item.value, positiveGreen: true);
      case 'motion':
        return _boolSensorColor(item.value, positiveGreen: true);
      case 'blocked':
        return _boolSensorColor(item.value, positiveGreen: false);
      case 'charge':
        return _boolSensorColor(item.value, positiveGreen: true);
      case 'gsm':
      case 'rssi':
        return _gsmColor(_sensorGsmLevel(item));
      case 'batteryLevel':
        final number = _numberFromText(item.value);
        if (number == null) return const Color(0xFF60718D);
        if (number < 20) return const Color(0xFFDC2626);
        if (number < 35) return const Color(0xFFF59E0B);
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF60718D);
    }
  }

  Color _sensorValueColor(SensorDisplayItem item) {
    if (item.key == 'ignition') {
      final boolValue = _valueAsBool(item.value);
      if (boolValue == null) return const Color(0xFF334155);
      return boolValue ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    }
    if (item.key == 'gsm' || item.key == 'rssi') {
      return _gsmColor(_sensorGsmLevel(item));
    }
    return const Color(0xFF334155);
  }

  bool _sensorShouldBlink(SensorDisplayItem item) {
    if (item.key != 'gsm' && item.key != 'rssi') return false;
    return _sensorGsmLevel(item) == _GsmLevel.critical;
  }

  _GsmLevel _sensorGsmLevel(SensorDisplayItem item) {
    final number = _numberFromText(item.value);
    if (number == null) return _GsmLevel.unknown;
    if (item.key == 'rssi') {
      return _resolveGsmLevel(gsm: null, rssi: number);
    }
    return _resolveGsmLevel(gsm: number, rssi: null);
  }

  Color _boolSensorColor(String value, {required bool positiveGreen}) {
    final boolValue = _valueAsBool(value);
    if (boolValue == null) return const Color(0xFF60718D);
    if (positiveGreen) {
      return boolValue ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    }
    return boolValue ? const Color(0xFFDC2626) : const Color(0xFF16A34A);
  }

  bool? _valueAsBool(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'sim' || normalized == 'true' || normalized == 'on') {
      return true;
    }
    if (normalized == 'nao' ||
        normalized == 'não' ||
        normalized == 'false' ||
        normalized == 'off') {
      return false;
    }
    return null;
  }

  double? _numberFromText(String text) {
    final match = RegExp(r'-?\d+(?:[\.,]\d+)?').firstMatch(text);
    if (match == null) return null;
    return double.tryParse(match.group(0)!.replaceAll(',', '.'));
  }
}

class _TelemetryHeaderCell extends StatelessWidget {
  const _TelemetryHeaderCell({
    required this.flex,
    required this.label,
  });

  final int flex;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF526684),
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.snapshot});

  final _TelemetryDeviceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final status = snapshot.device.status.trim().toLowerCase();
    final (label, bg, text) = switch (status) {
      'online' => ('Online', const Color(0xFFE8F7EE), const Color(0xFF15803D)),
      'offline' => (
          'Offline',
          const Color(0xFFF4F4F5),
          const Color(0xFF52525B)
        ),
      _ => ('Alerta', const Color(0xFFFEF2F2), const Color(0xFFB91C1C)),
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: text.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 8, color: text),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: text,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderQuickMetric extends StatelessWidget {
  const _HeaderQuickMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 92),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF526684),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetryMetricSparkCard extends StatelessWidget {
  const _TelemetryMetricSparkCard({
    required this.title,
    required this.value,
    required this.color,
    required this.points,
    required this.maxY,
    required this.loading,
  });

  final String title;
  final String value;
  final Color color;
  final List<double> points;
  final double maxY;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 208,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF526684),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 28,
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.6),
                    ),
                  )
                : CustomPaint(
                    painter: _SparklinePainter(
                      points: points,
                      color: color,
                      maxY: maxY,
                    ),
                    child: const SizedBox.expand(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.points,
    required this.color,
    required this.maxY,
  });

  final List<double> points;
  final Color color;
  final double maxY;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFDDE5F0);
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      bgPaint,
    );

    if (points.length < 2) return;

    final seriesMax =
        points.reduce((a, b) => a > b ? a : b).clamp(1.0, maxY).toDouble();
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = i * (size.width / (points.length - 1));
      final clamped = points[i].clamp(0.0, seriesMax).toDouble();
      final y = size.height - (clamped / seriesMax) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    if (oldDelegate.points.length != points.length ||
        oldDelegate.color != color ||
        oldDelegate.maxY != maxY) {
      return true;
    }
    for (var i = 0; i < points.length; i++) {
      if (points[i] != oldDelegate.points[i]) {
        return true;
      }
    }
    return false;
  }
}

class _TranslucentCard extends StatelessWidget {
  const _TranslucentCard({
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: child,
    );
  }
}

class _BlinkingIcon extends StatefulWidget {
  const _BlinkingIcon({
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  State<_BlinkingIcon> createState() => _BlinkingIconState();
}

class _BlinkingIconState extends State<_BlinkingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _opacity = Tween<double>(begin: 1, end: 0.22).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _syncBlink();
  }

  @override
  void didUpdateWidget(covariant _BlinkingIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      _syncBlink();
    }
  }

  void _syncBlink() {
    if (widget.enabled) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}

class _TelemetryDeviceSnapshot {
  const _TelemetryDeviceSnapshot({
    required this.device,
    required this.position,
    required this.ignition,
    required this.batteryLevel,
    required this.batteryVoltage,
    required this.speedKmh,
    required this.lastConnectionLabel,
    required this.gsmLevel,
    required this.gsmLabel,
  });

  final TraccarDevice device;
  final TraccarPosition? position;
  final bool? ignition;
  final double? batteryLevel;
  final double? batteryVoltage;
  final double speedKmh;
  final String lastConnectionLabel;
  final _GsmLevel gsmLevel;
  final String gsmLabel;

  String get speedLabel {
    if (speedKmh <= 0.4) return '0 km/h';
    return '${speedKmh.toStringAsFixed(0)} km/h';
  }

  String get batteryLabel {
    if (batteryLevel != null) {
      final value = batteryLevel! <= 1 ? batteryLevel! * 100 : batteryLevel!;
      return '${value.toStringAsFixed(0)}%';
    }
    if (batteryVoltage != null) {
      return '${batteryVoltage!.toStringAsFixed(1)} V';
    }
    return '--';
  }
}

enum _GsmLevel { unknown, good, medium, low, critical }

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
    if (nextTime != null &&
        (currentTime == null || nextTime.isAfter(currentTime))) {
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

List<SensorDisplaySection> _filterSensorSections(
  List<SensorDisplaySection> sections,
  String search,
) {
  final term = search.trim().toLowerCase();
  if (term.isEmpty) return sections;

  final filtered = <SensorDisplaySection>[];
  for (final section in sections) {
    final items = section.items.where((item) {
      final bag = '${item.label} ${item.value}'.toLowerCase();
      return bag.contains(term);
    }).toList(growable: false);
    if (items.isEmpty) continue;
    filtered.add(
      SensorDisplaySection(
        group: section.group,
        title: section.title,
        items: items,
      ),
    );
  }
  return filtered;
}

String _normalizeKey(String raw) {
  return raw.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

dynamic _attrValue(Map<String, dynamic> attrs, List<String> keys) {
  if (attrs.isEmpty || keys.isEmpty) return null;
  final wanted = keys.map(_normalizeKey).toSet();

  for (final entry in attrs.entries) {
    if (wanted.contains(_normalizeKey(entry.key))) {
      return entry.value;
    }
  }
  return null;
}

double? _attrDouble(Map<String, dynamic> attrs, List<String> keys) {
  final raw = _attrValue(attrs, keys);
  if (raw is num) return raw.toDouble();
  if (raw is String) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text.replaceAll(',', '.'));
  }
  return null;
}

bool? _attrBool(Map<String, dynamic> attrs, List<String> keys) {
  final raw = _attrValue(attrs, keys);
  if (raw is bool) return raw;
  if (raw is num) return raw > 0;
  if (raw is String) {
    final text = raw.trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'sim' || text == 'on') {
      return true;
    }
    if (text == 'false' ||
        text == '0' ||
        text == 'nao' ||
        text == 'não' ||
        text == 'off') {
      return false;
    }
  }
  return null;
}

_GsmLevel _resolveGsmLevel({required double? gsm, required double? rssi}) {
  if (rssi != null) {
    if (rssi <= -100) return _GsmLevel.critical;
    if (rssi <= -92) return _GsmLevel.low;
    if (rssi <= -80) return _GsmLevel.medium;
    return _GsmLevel.good;
  }

  if (gsm == null) return _GsmLevel.unknown;

  final value = gsm <= 1 ? gsm * 100 : gsm;
  if (value < 8) return _GsmLevel.critical;
  if (value < 16) return _GsmLevel.low;
  if (value < 26) return _GsmLevel.medium;
  return _GsmLevel.good;
}

String _gsmDisplayLabel({required double? gsm, required double? rssi}) {
  if (rssi != null) {
    return '${rssi.toStringAsFixed(0)} dBm';
  }
  if (gsm == null) return '--';
  final value = gsm <= 1 ? gsm * 100 : gsm;
  return value.toStringAsFixed(0);
}

String _relativeTimeLabel(String? raw) {
  final date = _parseDate(raw);
  if (date == null) return 'Não informado';
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inMinutes < 1) return 'agora';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'há ${diff.inHours} h';
  if (diff.inDays == 1) return 'há 1 dia';
  return 'há ${diff.inDays} dias';
}
