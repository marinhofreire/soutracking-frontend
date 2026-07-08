import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/display_text_formatter.dart';
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
  const TelemetrySensorsScreen({super.key, this.onClose});

  final VoidCallback? onClose;

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

    if (snapshots.isEmpty) {
      _deviceId = null;
    } else if (_deviceId == null ||
        !snapshots.any((snapshot) => snapshot.device.id == _deviceId)) {
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
    final deviceHistory =
        historyAsync.valueOrNull ?? const <TraccarPosition>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
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
                Icons.space_dashboard_outlined,
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
                    'Telemetria',
                    style: TextStyle(
                      color: Color(0xFF1F2A44),
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'Sensores e dados operacionais',
                    style: TextStyle(color: Color(0xFF60718D), fontSize: 12, fontWeight: FontWeight.w600),
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
              style: IconButton.styleFrom(foregroundColor: const Color(0xFF60718D)),
            ),
            IconButton(
              onPressed: widget.onClose,
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Fechar',
              style: IconButton.styleFrom(foregroundColor: const Color(0xFF60718D)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildToolbar(devices, rowsCount),
        if (selectedSnapshot != null) ...[
          const SizedBox(height: 10),
          _buildQuickStatsBar(selectedSnapshot),
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            child: _buildGaugesRow(
              snapshot: selectedSnapshot,
              history: deviceHistory,
              loading: historyAsync.isLoading,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Expanded(
          child: _buildSensorGrid(filteredSections, selectedSnapshot),
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
                labelText: 'Equipamento',
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
                hintText: 'Buscar sensor (ex: ignição, bateria)',
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
              color: const Color(0xFFF8FAFD),
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
                'Nenhum equipamento recebido.',
                style: TextStyle(
                  color: Color(0xFF60718D),
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            Column(
              children: [
                for (var index = 0; index < snapshots.length; index++) ...[
                  Builder(
                    builder: (context) {
                      final snapshot = snapshots[index];
                      final selected = snapshot.device.id == _deviceId;
                      return InkWell(
                        onTap: () => setState(() => _deviceId = snapshot.device.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFEAF3FF)
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
                                  formatDisplayText(snapshot.device.name),
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
                                  formatDisplayText(
                                    snapshot.device.uniqueId,
                                    fallback: '--',
                                  ),
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
                  if (index < snapshots.length - 1) const Divider(height: 1),
                ],
              ],
            ),
        ],
      ),
    );
  }

  // ── Quick stats bar (5 metrics row) ─────────────────────────────────────
  Widget _buildQuickStatsBar(_TelemetryDeviceSnapshot snapshot) {
    final attrs = snapshot.position?.attributes ?? const <String, dynamic>{};
    final isOnline = snapshot.device.status.trim().toLowerCase() == 'online';
    final gpsOk = _attrBool(attrs, const ['gpsTracking', 'gps']) ?? (snapshot.position != null);
    final odometer = _attrDouble(attrs, const ['totalDistance', 'odometer', 'distance']);
    final odometerLabel = odometer != null
        ? '${(odometer / 1000).toStringAsFixed(2)} km'
        : '--';

    return _TranslucentCard(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _QuickStatCell(
              icon: Icons.circle,
              iconColor: isOnline ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
              iconSize: 10,
              label: isOnline ? 'Online' : 'Offline',
              subtitle: isOnline ? 'Equipamento conectado' : 'Sem comunicação',
            ),
            const VerticalDivider(width: 1, color: Color(0xFFE8EFF7)),
            _QuickStatCell(
              icon: Icons.power_settings_new_rounded,
              iconColor: _ignitionColor(snapshot.ignition),
              label: 'Ignição',
              subtitle: snapshot.ignition == null
                  ? '--'
                  : snapshot.ignition!
                      ? 'Ligada'
                      : 'Desligada',
            ),
            const VerticalDivider(width: 1, color: Color(0xFFE8EFF7)),
            _QuickStatCell(
              icon: Icons.gps_fixed_rounded,
              iconColor: gpsOk ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
              label: 'GPS ativo',
              subtitle: gpsOk ? 'Sinal OK' : 'Sem sinal',
            ),
            const VerticalDivider(width: 1, color: Color(0xFFE8EFF7)),
            _QuickStatCell(
              icon: Icons.access_time_rounded,
              iconColor: const Color(0xFF526684),
              label: 'Última conexão',
              subtitle: snapshot.lastConnectionLabel,
            ),
            const VerticalDivider(width: 1, color: Color(0xFFE8EFF7)),
            _QuickStatCell(
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

  // ── Gauges row (fluid, fills available width) ─────────────────────────────
  Widget _buildGaugesRow({
    required _TelemetryDeviceSnapshot snapshot,
    required List<TraccarPosition> history,
    required bool loading,
  }) {
    final attrs = snapshot.position?.attributes ?? const <String, dynamic>{};
    final rpmRaw = _attrDouble(attrs, const ['rpm', 'engineRpm', 'RPM']);
    final rpmKilo = rpmRaw != null ? rpmRaw / 1000 : null;
    final batPct = _batteryPct(snapshot);
    final gsmQuality = _gsmQualityPct(snapshot.gsmLevel);

    return Row(
      children: [
        Expanded(
          child: _DialGauge(
            label: 'Velocidade',
            unit: 'km/h',
            value: snapshot.speedKmh,
            max: 240,
            color: snapshot.speedKmh >= 1
                ? const Color(0xFF16A34A)
                : const Color(0xFF94A3B8),
            ticks: const [0, 60, 120, 180, 240],
            loading: loading,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DialGauge(
            label: 'RPM',
            unit: 'x1000',
            value: rpmKilo ?? 0,
            max: 8,
            color: (rpmKilo != null && rpmKilo > 0)
                ? const Color(0xFF176EEB)
                : const Color(0xFF94A3B8),
            ticks: const [0, 2, 4, 6, 8],
            loading: loading,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ArcGauge(
            label: 'Bateria',
            value: batPct,
            displayText: snapshot.batteryLabel,
            color: _batteryColor(snapshot),
            icon: Icons.battery_full_rounded,
            loading: loading,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ArcGauge(
            label: 'Sinal GSM',
            value: snapshot.gsmLevel == _GsmLevel.unknown ? null : gsmQuality,
            displayText: snapshot.gsmLabel,
            color: _gsmColor(snapshot.gsmLevel),
            icon: Icons.signal_cellular_alt_rounded,
            qualityLabel: _gsmQualityStr(snapshot.gsmLevel),
            loading: loading,
          ),
        ),
      ],
    );
  }

  // ── Sensor sections grid (4 columns, no scroll) ───────────────────────────
  Widget _buildSensorGrid(
    List<SensorDisplaySection> sections,
    _TelemetryDeviceSnapshot? snapshot,
  ) {
    if (snapshot == null) {
      return const _TranslucentCard(
        child: Center(
          child: Text(
            'Selecione um equipamento para visualizar a telemetria',
            style: TextStyle(color: Color(0xFF526684), fontWeight: FontWeight.w700),
          ),
        ),
      );
    }
    if (sections.isEmpty) {
      return const _TranslucentCard(
        child: Center(
          child: Text(
            'Sensores não recebidos para o dispositivo selecionado.',
            style: TextStyle(color: Color(0xFF526684), fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < sections.length; i++) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Text(
                      sections[i].title,
                      style: const TextStyle(
                        color: Color(0xFF1F2A44),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE8EFF7)),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int j = 0; j < sections[i].items.length; j++) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              child: Row(
                                children: [
                                  _BlinkingIcon(
                                    enabled: _sensorShouldBlink(sections[i].items[j]),
                                    child: Icon(
                                      sections[i].items[j].icon,
                                      size: 15,
                                      color: _sensorColor(sections[i].items[j]),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      sections[i].items[j].label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF526684),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    sections[i].items[j].value,
                                    style: TextStyle(
                                      color: _sensorValueColor(sections[i].items[j]),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (j < sections[i].items.length - 1)
                              const Divider(
                                height: 1,
                                color: Color(0xFFF0F4FA),
                                indent: 12,
                                endIndent: 12,
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (i < sections.length - 1)
              const VerticalDivider(width: 1, color: Color(0xFFE8EFF7)),
          ],
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
                  formatDisplayText(snapshot.device.name),
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
            'Selecione um equipamento para visualizar a telemetria',
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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

  double? _batteryPct(_TelemetryDeviceSnapshot snapshot) {
    if (snapshot.batteryLevel == null) return null;
    final v = snapshot.batteryLevel!;
    return (v <= 1 ? v * 100 : v).clamp(0.0, 100.0);
  }

  double _gsmQualityPct(_GsmLevel level) {
    switch (level) {
      case _GsmLevel.good:
        return 85;
      case _GsmLevel.medium:
        return 55;
      case _GsmLevel.low:
        return 25;
      case _GsmLevel.critical:
        return 8;
      case _GsmLevel.unknown:
        return 0;
    }
  }

  String _gsmQualityStr(_GsmLevel level) {
    switch (level) {
      case _GsmLevel.good:
        return 'Excelente';
      case _GsmLevel.medium:
        return 'Regular';
      case _GsmLevel.low:
        return 'Fraco';
      case _GsmLevel.critical:
        return 'Crítico';
      case _GsmLevel.unknown:
        return '--';
    }
  }

  Widget _buildTelemetryOverviewGrid({
    required _TelemetryDeviceSnapshot snapshot,
    required List<TraccarPosition> history,
    required bool loading,
  }) {
    final attrs = snapshot.position?.attributes ?? const <String, dynamic>{};
    final rpmRaw = _attrDouble(attrs, const ['rpm', 'engineRpm', 'RPM']);
    final rpmKilo = rpmRaw != null ? rpmRaw / 1000 : null;
    final batPct = _batteryPct(snapshot);
    final gsmQuality = _gsmQualityPct(snapshot.gsmLevel);
    final gsmLabel = _gsmQualityStr(snapshot.gsmLevel);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _DialGauge(
          label: 'Velocidade',
          unit: 'km/h',
          value: snapshot.speedKmh,
          max: 240,
          color: snapshot.speedKmh >= 1
              ? const Color(0xFF16A34A)
              : const Color(0xFF94A3B8),
          ticks: const [0, 60, 120, 180, 240],
          loading: loading,
        ),
        _DialGauge(
          label: 'RPM',
          unit: 'x1000',
          value: rpmKilo ?? 0,
          max: 8,
          color: (rpmKilo != null && rpmKilo > 0)
              ? const Color(0xFF176EEB)
              : const Color(0xFF94A3B8),
          ticks: const [0, 2, 4, 6, 8],
          loading: loading,
        ),
        _ArcGauge(
          label: 'Bateria',
          value: batPct,
          displayText: snapshot.batteryLabel,
          color: _batteryColor(snapshot),
          icon: Icons.battery_full_rounded,
          loading: loading,
        ),
        _ArcGauge(
          label: 'Sinal GSM',
          value: snapshot.gsmLevel == _GsmLevel.unknown ? null : gsmQuality,
          displayText: snapshot.gsmLabel,
          color: _gsmColor(snapshot.gsmLevel),
          icon: Icons.signal_cellular_alt_rounded,
          qualityLabel: gsmLabel,
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
        color: Colors.white,
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

    final normalizedKey = value.toLowerCase();
    switch (normalizedKey) {
      case 'devicemoving':
        return 'Em movimento';
      case 'deviceonline':
        return 'Online';
      case 'devicestopped':
        return 'Parado';
      case 'deviceoffline':
        return 'Offline';
      case 'deviceunknown':
        return 'Status desconhecido';
      case 'ignitionon':
        return 'Ignição ligada';
      case 'ignitionoff':
        return 'Ignição desligada';
    }

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

class _QuickStatCell extends StatelessWidget {
  const _QuickStatCell({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    this.iconSize = 18,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
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
        color: Colors.white,
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
        color: Colors.white,
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

// GSM/RSSI note: dBm scale is inverted — closer to 0 = better signal.
// Many Traccar device parsers store RSSI as a positive absolute value
// (e.g., 80 meaning -80 dBm). We normalise: positive rssi → negate.
// Reference thresholds (dBm): ≥-70 good, -70..-85 medium, -85..-100 low, <-100 critical.
_GsmLevel _resolveGsmLevel({required double? gsm, required double? rssi}) {
  if (rssi != null) {
    // Normalise: positive absolute value → actual negative dBm
    final dBm = rssi > 0 ? -rssi : rssi;
    if (dBm <= -100) return _GsmLevel.critical;
    if (dBm <= -85) return _GsmLevel.low;
    if (dBm <= -70) return _GsmLevel.medium;
    return _GsmLevel.good;
  }

  if (gsm == null) return _GsmLevel.unknown;

  // GSM ASU (0–31) or percentage (0–100): higher = better
  final value = gsm <= 1 ? gsm * 100 : gsm;
  if (value < 5) return _GsmLevel.critical;
  if (value < 12) return _GsmLevel.low;
  if (value < 20) return _GsmLevel.medium;
  return _GsmLevel.good;
}

String _gsmDisplayLabel({required double? gsm, required double? rssi}) {
  if (rssi != null) {
    final dBm = rssi > 0 ? -rssi : rssi;
    return '${dBm.toStringAsFixed(0)} dBm';
  }
  if (gsm == null) return '--';
  final value = gsm <= 1 ? gsm * 100 : gsm;
  return '${value.toStringAsFixed(0)}%';
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

// ── Circular Gauge Widgets ─────────────────────────────────────────────────

const double _gaugeStartAngle = math.pi * 3 / 4; // 135° — bottom-left
const double _gaugeSweep = math.pi * 3 / 2; // 270°

class _DialGauge extends StatelessWidget {
  const _DialGauge({
    required this.label,
    required this.unit,
    required this.value,
    required this.max,
    required this.color,
    required this.ticks,
    required this.loading,
  });

  final String label;
  final String unit;
  final double value;
  final double max;
  final Color color;
  final List<double> ticks;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : CustomPaint(
                painter: _DialPainter(
                  label: label,
                  unit: unit,
                  value: value.clamp(0.0, max),
                  max: max,
                  color: color,
                  ticks: ticks,
                ),
              ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.label,
    required this.unit,
    required this.value,
    required this.max,
    required this.color,
    required this.ticks,
  });

  final String label;
  final String unit;
  final double value;
  final double max;
  final Color color;
  final List<double> ticks;

  @override
  void paint(Canvas canvas, Size size) {
    final d = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = d / 2 - 10;
    const strokeW = 10.0;

    // Background track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _gaugeStartAngle,
      _gaugeSweep,
      false,
      Paint()
        ..color = const Color(0xFFE8EFF7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round,
    );

    // Value arc
    final frac = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    if (frac > 0.005) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        _gaugeStartAngle,
        _gaugeSweep * frac,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round,
      );
    }

    // Tick marks
    final innerEdge = radius - strokeW / 2 - 1;
    final majorPaint = Paint()..color = const Color(0xFFB0BEC5)..strokeWidth = 1.2;
    final minorPaint = Paint()..color = const Color(0xFFCDD5E0)..strokeWidth = 0.8;
    const int totalTicks = 48;
    final int majorEvery = totalTicks ~/ (ticks.length - 1);
    for (int i = 0; i <= totalTicks; i++) {
      final angle = _gaugeStartAngle + _gaugeSweep * i / totalTicks;
      final isMajor = i % majorEvery == 0;
      final outerR = innerEdge - 2;
      final innerR = outerR - (isMajor ? 9.0 : 4.0);
      final c = math.cos(angle);
      final s = math.sin(angle);
      canvas.drawLine(
        Offset(center.dx + c * outerR, center.dy + s * outerR),
        Offset(center.dx + c * innerR, center.dy + s * innerR),
        isMajor ? majorPaint : minorPaint,
      );
    }

    // Scale labels
    final lblR = innerEdge - 22;
    for (int i = 0; i < ticks.length; i++) {
      final angle = _gaugeStartAngle + _gaugeSweep * i / (ticks.length - 1);
      final lx = center.dx + math.cos(angle) * lblR;
      final ly = center.dy + math.sin(angle) * lblR;
      final tp = TextPainter(
        text: TextSpan(
          text: ticks[i].toStringAsFixed(0),
          style: const TextStyle(color: Color(0xFF5A6B84), fontSize: 10, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
    }

    // Needle
    final needleAngle = _gaugeStartAngle + _gaugeSweep * frac;
    final needleLen = innerEdge - 26;
    const halfBase = 5.0;
    final perp = needleAngle + math.pi / 2;
    final tip = Offset(center.dx + math.cos(needleAngle) * needleLen,
        center.dy + math.sin(needleAngle) * needleLen);
    final b1 = Offset(center.dx + math.cos(perp) * halfBase,
        center.dy + math.sin(perp) * halfBase);
    final b2 = Offset(center.dx - math.cos(perp) * halfBase,
        center.dy - math.sin(perp) * halfBase);
    canvas.drawPath(Path()..moveTo(tip.dx, tip.dy)..lineTo(b1.dx, b1.dy)..lineTo(b2.dx, b2.dy)..close(),
        Paint()..color = color);

    // Hub
    canvas.drawCircle(center, 7, Paint()..color = const Color(0xFF1F2A44));
    canvas.drawCircle(center, 4, Paint()..color = Colors.white);

    // Value + unit inside circle (bottom half)
    final valStr = max <= 10 ? value.toStringAsFixed(1) : value.toStringAsFixed(0);
    final valTp = TextPainter(
      text: TextSpan(
        text: valStr,
        style: TextStyle(
          color: value > (max <= 10 ? 0.05 : 0.5) ? color : const Color(0xFF94A3B8),
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final valY = center.dy + radius * 0.24;
    valTp.paint(canvas, Offset(center.dx - valTp.width / 2, valY));

    final unitTp = TextPainter(
      text: TextSpan(
        text: unit,
        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    unitTp.paint(canvas, Offset(center.dx - unitTp.width / 2, valY + 25));

    // Label text (Velocidade / RPM) at top-center inside
    final lblTp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Color(0xFF526684), fontSize: 11, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    lblTp.paint(canvas, Offset(center.dx - lblTp.width / 2, center.dy - radius * 0.52));
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.value != value || old.color != color || old.label != label;
}

class _ArcGauge extends StatelessWidget {
  const _ArcGauge({
    required this.label,
    required this.value,
    required this.displayText,
    required this.color,
    required this.icon,
    required this.loading,
    this.qualityLabel,
  });

  final String label;
  final double? value; // 0–100 percentage, null = unknown
  final String displayText;
  final Color color;
  final IconData icon;
  final bool loading;
  final String? qualityLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ArcPainter(value: value, color: color, label: label),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: color, size: 22),
                        const SizedBox(height: 6),
                        Text(
                          displayText,
                          style: TextStyle(
                            color: value != null
                                ? const Color(0xFF1F2A44)
                                : const Color(0xFF94A3B8),
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (qualityLabel != null && qualityLabel != '--')
                          Text(
                            qualityLabel!,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
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
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.value, required this.color, required this.label});

  final double? value;
  final Color color;
  final String label;

  // Same 270° arc as dial gauges
  static const List<String> _scaleLabels = ['0', '25', '50', '75', '100'];

  @override
  void paint(Canvas canvas, Size size) {
    final d = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = d / 2 - 14;
    const strokeW = 10.0;

    // Background track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _gaugeStartAngle,
      _gaugeSweep,
      false,
      Paint()
        ..color = const Color(0xFFE8EFF7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round,
    );

    // Value arc
    final frac = value != null ? (value! / 100).clamp(0.0, 1.0) : 0.0;
    if (frac > 0.005) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        _gaugeStartAngle,
        _gaugeSweep * frac,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round,
      );
    }

    // Indicator dot at current value
    if (value != null) {
      final dotAngle = _gaugeStartAngle + _gaugeSweep * frac;
      final dotX = center.dx + math.cos(dotAngle) * radius;
      final dotY = center.dy + math.sin(dotAngle) * radius;
      canvas.drawCircle(Offset(dotX, dotY), 8,
          Paint()..color = color.withValues(alpha: 0.2));
      canvas.drawCircle(Offset(dotX, dotY), 5, Paint()..color = color);
      canvas.drawCircle(Offset(dotX, dotY), 3, Paint()..color = Colors.white);
    }

    // Scale labels (0, 25, 50, 75, 100)
    final lblR = radius + strokeW / 2 + 10;
    for (int i = 0; i < _scaleLabels.length; i++) {
      final angle = _gaugeStartAngle + _gaugeSweep * i / (_scaleLabels.length - 1);
      final lx = center.dx + math.cos(angle) * lblR;
      final ly = center.dy + math.sin(angle) * lblR;
      final tp = TextPainter(
        text: TextSpan(
          text: _scaleLabels[i],
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
    }

    // Label at top-center (Bateria / Sinal GSM)
    final titleTp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Color(0xFF526684), fontSize: 11, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    titleTp.paint(canvas, Offset(center.dx - titleTp.width / 2, center.dy - radius * 0.52));
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.value != value || old.color != color;
}
