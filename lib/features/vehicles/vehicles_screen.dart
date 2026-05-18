import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/session_state.dart';

final _devicePositionProvider = FutureProvider.family
    .autoDispose<TraccarPosition?, int>((ref, deviceId) async {
  final session = ref.watch(sessionProvider);
  if (!session.isAuthenticated) {
    return null;
  }

  final client = ref.watch(traccarClientProvider);
  try {
    final positions = await client.getPositions(
      cookie: session.cookie,
      authHeader: session.authHeader,
      deviceId: deviceId,
    );
    if (positions.isEmpty) {
      return null;
    }

    positions.sort((a, b) {
      final ta = _parseDateTime(a.fixTime);
      final tb = _parseDateTime(b.fixTime);
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });

    return positions.first;
  } catch (_) {
    return null;
  }
});

final _deviceEventsProvider =
    FutureProvider.family.autoDispose<List<Map<String, dynamic>>, int>((
  ref,
  deviceId,
) async {
  final session = ref.watch(sessionProvider);
  if (!session.isAuthenticated) {
    return const [];
  }

  final client = ref.watch(traccarClientProvider);
  final from = DateTime.now().subtract(const Duration(days: 7)).toUtc();
  final to = DateTime.now().toUtc();

  try {
    final direct = await client.getList(
      path: '/events',
      cookie: session.cookie,
      authHeader: session.authHeader,
      query: {'deviceId': '$deviceId'},
    );
    if (direct.isNotEmpty) {
      return _normalizeEvents(direct);
    }
  } catch (_) {
    // Fallback para relatório quando /events não está disponível no perfil.
  }

  try {
    final report = await client.getList(
      path: '/reports/events',
      cookie: session.cookie,
      authHeader: session.authHeader,
      query: {
        'deviceId': '$deviceId',
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
      },
    );
    return _normalizeEvents(report);
  } catch (_) {
    return const [];
  }
});

List<Map<String, dynamic>> _normalizeEvents(List<Map<String, dynamic>> raw) {
  final rows = [...raw];
  rows.sort((a, b) {
    final ta = _parseDateTime(
      a['eventTime'] ?? a['serverTime'] ?? a['fixTime'] ?? a['deviceTime'],
    );
    final tb = _parseDateTime(
      b['eventTime'] ?? b['serverTime'] ?? b['fixTime'] ?? b['deviceTime'],
    );
    if (ta == null && tb == null) return 0;
    if (ta == null) return 1;
    if (tb == null) return -1;
    return tb.compareTo(ta);
  });

  if (rows.length > 5) {
    return rows.sublist(0, 5);
  }
  return rows;
}

DateTime? _parseDateTime(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  final parsed = DateTime.tryParse(text);
  if (parsed == null) {
    return null;
  }
  return parsed.isUtc ? parsed.toLocal() : parsed;
}

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return 'Nao informado';
  }
  final dd = value.day.toString().padLeft(2, '0');
  final mm = value.month.toString().padLeft(2, '0');
  final yyyy = value.year.toString().padLeft(4, '0');
  final hh = value.hour.toString().padLeft(2, '0');
  final min = value.minute.toString().padLeft(2, '0');
  return '$dd/$mm/$yyyy $hh:$min';
}

String _formatRelativeTime(DateTime? value) {
  if (value == null) {
    return 'Nao informado';
  }

  final diff = DateTime.now().difference(value);
  if (diff.isNegative) {
    return 'agora';
  }
  final seconds = diff.inSeconds;
  if (seconds < 60) {
    return 'agora';
  }

  final minutes = diff.inMinutes;
  if (minutes < 60) {
    return 'ha ${minutes}min';
  }

  final hours = diff.inHours;
  if (hours < 24) {
    return 'ha ${hours}h';
  }

  final days = diff.inDays;
  return 'ha ${days}d';
}

String _formatBoolean(dynamic raw) {
  if (raw == null) {
    return 'Nao informado';
  }
  final parsed = _toBool(raw);
  if (parsed == null) {
    return 'Nao informado';
  }
  return parsed ? 'Sim' : 'Nao';
}

bool? _toBool(dynamic raw) {
  if (raw is bool) return raw;
  if (raw is num) return raw > 0;
  if (raw is String) {
    final value = raw.trim().toLowerCase();
    if (value == 'true' || value == '1' || value == 'on' || value == 'sim') {
      return true;
    }
    if (value == 'false' ||
        value == '0' ||
        value == 'off' ||
        value == 'nao' ||
        value == 'não') {
      return false;
    }
  }
  return null;
}

String _eventTypeLabel(dynamic raw) {
  final value = raw?.toString().trim() ?? '';
  if (value.isEmpty) {
    return 'Evento nao identificado';
  }
  final withSpace = value
      .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'), (m) => '${m.group(1)} ${m.group(2)}')
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .trim();
  if (withSpace.isEmpty) {
    return 'Evento nao identificado';
  }
  final first = withSpace.substring(0, 1).toUpperCase();
  final rest = withSpace.length > 1 ? withSpace.substring(1) : '';
  return '$first$rest';
}

class VehiclesScreen extends ConsumerStatefulWidget {
  const VehiclesScreen({super.key});

  @override
  ConsumerState<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends ConsumerState<VehiclesScreen> {
  static const Duration _offlineStaleThreshold = Duration(minutes: 30);

  int? _selectedDeviceId;

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesProvider);
    final positionsAsync = ref.watch(positionsProvider);

    if (devicesAsync.isLoading || positionsAsync.isLoading) {
      return const _LoadingPanel();
    }

    if (devicesAsync.hasError) {
      return _ErrorPanel(
        message: 'Falha ao carregar veiculos: ${devicesAsync.error}',
      );
    }

    if (positionsAsync.hasError) {
      return _ErrorPanel(
        message: 'Falha ao carregar posicoes: ${positionsAsync.error}',
      );
    }

    final devices = devicesAsync.valueOrNull ?? const <TraccarDevice>[];
    final positions = positionsAsync.valueOrNull ?? const <TraccarPosition>[];
    final vehicles = _buildVehicleViews(devices, positions);
    final kpis = _VehiclesKpis.fromVehicles(vehicles);

    _VehicleViewData? selected;
    if (_selectedDeviceId != null) {
      for (final vehicle in vehicles) {
        if (vehicle.device.id == _selectedDeviceId) {
          selected = vehicle;
          break;
        }
      }
    }

    AsyncValue<TraccarPosition?>? selectedPositionAsync;
    AsyncValue<List<Map<String, dynamic>>>? selectedEventsAsync;

    final selectedDeviceId = _selectedDeviceId;
    if (selectedDeviceId != null) {
      selectedPositionAsync =
          ref.watch(_devicePositionProvider(selectedDeviceId));
      selectedEventsAsync = ref.watch(_deviceEventsProvider(selectedDeviceId));
    }

    final selectedPosition = selectedPositionAsync?.valueOrNull;
    final selectedEvents =
        selectedEventsAsync?.valueOrNull ?? const <Map<String, dynamic>>[];
    final eventsLoading = selectedEventsAsync?.isLoading == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _VehiclesKpiRow(summary: kpis),
        const SizedBox(height: 10),
        Expanded(
          child: vehicles.isEmpty
              ? const _EmptyVehiclesPanel()
              : _VehiclesListPanel(
                  vehicles: vehicles,
                  selectedDeviceId: _selectedDeviceId,
                  onSelect: (vehicle) {
                    setState(() => _selectedDeviceId = vehicle.device.id);
                  },
                ),
        ),
        if (selected != null) ...[
          const SizedBox(height: 10),
          _VehicleDetailPanel(
            vehicle: selected.copyWith(positionOverride: selectedPosition),
            eventsLoading: eventsLoading,
            recentEvents: selectedEvents,
          ),
        ],
      ],
    );
  }

  List<_VehicleViewData> _buildVehicleViews(
    List<TraccarDevice> devices,
    List<TraccarPosition> positions,
  ) {
    final latestByDevice = <int, TraccarPosition>{};

    for (final position in positions) {
      final current = latestByDevice[position.deviceId];
      if (current == null) {
        latestByDevice[position.deviceId] = position;
        continue;
      }

      final currentTime = _parseDateTime(current.fixTime);
      final nextTime = _parseDateTime(position.fixTime);
      if (nextTime != null &&
          (currentTime == null || nextTime.isAfter(currentTime))) {
        latestByDevice[position.deviceId] = position;
      }
    }

    return [
      for (final device in devices)
        _VehicleViewData(
          device: device,
          position: latestByDevice[device.id],
          offlineStaleThreshold: _offlineStaleThreshold,
        ),
    ];
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: const SizedBox(
        height: 160,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4DA3FF)),
          ),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: SizedBox(
        height: 160,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1F2A44),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VehiclesKpis {
  const _VehiclesKpis({
    required this.total,
    required this.online,
    required this.offline,
    required this.moving,
  });

  final int total;
  final int online;
  final int offline;
  final int moving;

  factory _VehiclesKpis.fromVehicles(List<_VehicleViewData> vehicles) {
    var online = 0;
    var moving = 0;

    for (final vehicle in vehicles) {
      if (vehicle.isOperationalOnline) {
        online++;
      }
      if (vehicle.isMoving) {
        moving++;
      }
    }

    final total = vehicles.length;
    final offline = total - online;

    return _VehiclesKpis(
      total: total,
      online: online,
      offline: offline < 0 ? 0 : offline,
      moving: moving,
    );
  }
}

class _VehiclesKpiRow extends StatelessWidget {
  const _VehiclesKpiRow({required this.summary});

  final _VehiclesKpis summary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _KpiCard(
          label: 'Total',
          value: summary.total.toString(),
          color: const Color(0xFF3D8BFF),
          icon: Icons.directions_car_filled_outlined,
        ),
        _KpiCard(
          label: 'Online',
          value: summary.online.toString(),
          color: const Color(0xFF10B981),
          icon: Icons.wifi_tethering_rounded,
        ),
        _KpiCard(
          label: 'Offline',
          value: summary.offline.toString(),
          color: const Color(0xFFE74B4B),
          icon: Icons.wifi_off_rounded,
        ),
        _KpiCard(
          label: 'Em movimento',
          value: summary.moving.toString(),
          color: const Color(0xFFF59E0B),
          icon: Icons.near_me_outlined,
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 186,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.46)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF1F2A44),
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF526684),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _EmptyVehiclesPanel extends StatelessWidget {
  const _EmptyVehiclesPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: const Center(
        child: Text(
          'Nenhum veiculo disponivel no momento',
          style: TextStyle(
            color: Color(0xFF1F2A44),
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _VehiclesListPanel extends StatelessWidget {
  const _VehiclesListPanel({
    required this.vehicles,
    required this.selectedDeviceId,
    required this.onSelect,
  });

  final List<_VehicleViewData> vehicles;
  final int? selectedDeviceId;
  final ValueChanged<_VehicleViewData> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: vehicles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final vehicle = vehicles[index];
        final selected = vehicle.device.id == selectedDeviceId;
        return _VehicleTile(
          vehicle: vehicle,
          selected: selected,
          onTap: () => onSelect(vehicle),
        );
      },
    );
  }
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({
    required this.vehicle,
    required this.selected,
    required this.onTap,
  });

  final _VehicleViewData vehicle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.94)
                : Colors.white.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFF4DA3FF).withValues(alpha: 0.72)
                  : const Color(0xFFDDE5F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      vehicle.nameLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1F2A44),
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  _StatusChip(label: vehicle.operationalStatusLabel),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _InfoLine(title: 'Identificador', value: vehicle.identifier),
                  _InfoLine(
                    title: 'Ultima comunicacao',
                    value: vehicle.lastCommunicationLabel,
                  ),
                  _InfoLine(
                    title: 'Tempo sem comunicacao',
                    value: vehicle.lastCommunicationAgoLabel,
                  ),
                  _InfoLine(title: 'Velocidade', value: vehicle.speedLabel),
                  _InfoLine(title: 'Ignicao', value: vehicle.ignitionLabel),
                  _InfoLine(title: 'Lat/Lng', value: vehicle.latLngLabel),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleDetailPanel extends StatelessWidget {
  const _VehicleDetailPanel({
    required this.vehicle,
    required this.recentEvents,
    required this.eventsLoading,
  });

  final _VehicleViewData vehicle;
  final List<Map<String, dynamic>> recentEvents;
  final bool eventsLoading;

  @override
  Widget build(BuildContext context) {
    final checklistReady = vehicle.isReadyForValidation;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detalhe do veiculo',
            style: TextStyle(
              color: Color(0xFF1F2A44),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _InfoLine(title: 'Nome', value: vehicle.nameLabel),
              _InfoLine(title: 'Identificador', value: vehicle.identifier),
              _InfoLine(
                  title: 'Categoria/modelo', value: vehicle.categoryLabel),
              _InfoLine(
                title: 'Status operacional',
                value: vehicle.operationalStatusLabel,
              ),
              _InfoLine(
                title: 'Status recebido da API',
                value: vehicle.rawStatusLabel,
              ),
              _InfoLine(
                title: 'Ultima comunicacao',
                value: vehicle.lastCommunicationLabel,
              ),
              _InfoLine(
                title: 'Tempo desde ultima',
                value: vehicle.lastCommunicationAgoLabel,
              ),
              _InfoLine(title: 'Data GPS', value: vehicle.gpsDateLabel),
              _InfoLine(title: 'Latitude', value: vehicle.latitudeLabel),
              _InfoLine(title: 'Longitude', value: vehicle.longitudeLabel),
              _InfoLine(title: 'Velocidade', value: vehicle.speedLabel),
              _InfoLine(title: 'Direcao', value: vehicle.courseLabel),
              _InfoLine(title: 'Ignicao', value: vehicle.ignitionLabel),
              _InfoLine(title: 'Bateria', value: vehicle.batteryLabel),
              _InfoLine(title: 'Sinal', value: vehicle.signalLabel),
              _InfoLine(title: 'Bloqueio', value: vehicle.blockedLabel),
              _InfoLine(title: 'Movimento', value: vehicle.movementLabel),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Eventos recentes',
            style: TextStyle(
              color: Color(0xFF1F2A44),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          if (eventsLoading)
            const SizedBox(
              height: 26,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (recentEvents.isEmpty)
            const Text(
              'Sem eventos recentes para este equipamento.',
              style: TextStyle(
                color: Color(0xFF526684),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (final event in recentEvents)
                  _InfoLine(
                    title: _eventTypeLabel(event['type']),
                    value: _formatDateTime(
                      _parseDateTime(
                        event['eventTime'] ??
                            event['serverTime'] ??
                            event['fixTime'] ??
                            event['deviceTime'],
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          const Text(
            'Checklist de homologacao',
            style: TextStyle(
              color: Color(0xFF1F2A44),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _InfoLine(
                title: 'Equipamento cadastrado',
                value: _formatBoolean(vehicle.equipmentRegistered),
              ),
              _InfoLine(
                title: 'Comunicacao recebida',
                value: _formatBoolean(vehicle.communicationReceived),
              ),
              _InfoLine(
                title: 'Posicao valida',
                value: _formatBoolean(vehicle.positionReceived),
              ),
              _InfoLine(
                title: 'Evento recente',
                value: _formatBoolean(recentEvents.isNotEmpty),
              ),
              _InfoLine(
                title: 'Pronto para validacao',
                value: checklistReady ? 'Sim (homologado)' : 'Pendente',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase();
    final isOnline = normalized.contains('online');
    final fgColor =
        isOnline ? const Color(0xFF047857) : const Color(0xFFB42318);
    final bgColor =
        isOnline ? const Color(0xFFEAFBF3) : const Color(0xFFFDECEC);
    final borderColor =
        isOnline ? const Color(0xFFA7F3D0) : const Color(0xFFFBCACA);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fgColor,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$title: $value',
      style: const TextStyle(
        color: Color(0xFF334155),
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }
}

class _VehicleViewData {
  const _VehicleViewData({
    required this.device,
    required this.position,
    required this.offlineStaleThreshold,
    this.positionOverride,
  });

  final TraccarDevice device;
  final TraccarPosition? position;
  final TraccarPosition? positionOverride;
  final Duration offlineStaleThreshold;

  _VehicleViewData copyWith({
    TraccarPosition? positionOverride,
  }) {
    return _VehicleViewData(
      device: device,
      position: position,
      positionOverride: positionOverride,
      offlineStaleThreshold: offlineStaleThreshold,
    );
  }

  TraccarPosition? get _effectivePosition => positionOverride ?? position;

  String get nameLabel {
    final text = device.name.trim();
    return text.isEmpty ? 'Nao informado' : text;
  }

  String get identifier {
    final raw = device.uniqueId ??
        device.attributes?['plate'] ??
        device.attributes?['plateNumber'] ??
        device.attributes?['licensePlate'] ??
        device.attributes?['registration'] ??
        device.attributes?['identifier'];
    final text = raw?.toString().trim() ?? '';
    return text.isEmpty ? 'Nao informado' : text;
  }

  String get categoryLabel {
    final raw = device.category ??
        device.attributes?['model'] ??
        device.attributes?['vehicleModel'] ??
        device.attributes?['type'];
    final text = raw?.toString().trim() ?? '';
    return text.isEmpty ? 'Nao informado' : text;
  }

  String get _normalizedStatus => device.status.trim().toLowerCase();

  String get rawStatusLabel {
    final text = device.status.trim();
    return text.isEmpty ? 'Nao informado' : text;
  }

  bool get _statusUnknown =>
      _normalizedStatus.isEmpty ||
      _normalizedStatus == 'unknown' ||
      _normalizedStatus == 'nao informado' ||
      _normalizedStatus == 'não informado' ||
      _normalizedStatus == 'n/a';

  DateTime? get _lastCommunicationAt {
    final raw = device.lastUpdate ?? _effectivePosition?.fixTime;
    return _parseDateTime(raw);
  }

  bool get _isStale {
    final last = _lastCommunicationAt;
    if (last == null) return true;
    return DateTime.now().difference(last) > offlineStaleThreshold;
  }

  bool get isOperationalOnline => _normalizedStatus == 'online' && !_isStale;

  bool get isOperationalOffline =>
      _normalizedStatus == 'offline' || _statusUnknown || _isStale;

  String get operationalStatusLabel {
    if (isOperationalOnline) return 'Online';
    if (_statusUnknown) return 'Unknown';
    if (isOperationalOffline) return 'Offline';
    return 'Nao informado';
  }

  double? get speed {
    final value = _effectivePosition?.speed;
    if (value == null || !value.isFinite) return null;
    return value;
  }

  bool get isMoving => _effectivePosition != null && (speed ?? 0) > 1;

  String get speedLabel {
    final current = speed;
    if (current == null) return 'Nao informado';
    return '${current.toStringAsFixed(0)} km/h';
  }

  dynamic _readAttr(List<String> keys) {
    final posAttrs = _effectivePosition?.attributes;
    final devAttrs = device.attributes;
    for (final key in keys) {
      if (posAttrs != null && posAttrs.containsKey(key)) {
        return posAttrs[key];
      }
      if (devAttrs != null && devAttrs.containsKey(key)) {
        return devAttrs[key];
      }
    }
    return null;
  }

  bool? get _ignition {
    final raw = _readAttr(['ignition', 'ignitionOn']);
    return _toBool(raw);
  }

  String get ignitionLabel {
    final ignition = _ignition;
    if (ignition == null) return 'Nao informado';
    return ignition ? 'Ligada' : 'Desligada';
  }

  String get batteryLabel {
    final raw = _readAttr([
      'batteryLevel',
      'battery',
      'batteryPercent',
      'charge',
      'power',
      'voltage',
      'batteryVoltage',
      'deviceBatteryLevel',
    ]);
    if (raw == null) return 'Nao informado';
    if (raw is num) {
      if (raw > 0 && raw <= 100) {
        return '${raw.toStringAsFixed(0)}%';
      }
      return raw.toStringAsFixed(1);
    }
    final text = raw.toString().trim();
    return text.isEmpty ? 'Nao informado' : text;
  }

  String get signalLabel {
    final raw = _readAttr([
      'signal',
      'gsmSignal',
      'rssi',
      'sat',
      'satellites',
      'gpsSignal',
    ]);
    if (raw == null) return 'Nao informado';
    if (raw is num) return raw.toString();
    final text = raw.toString().trim();
    return text.isEmpty ? 'Nao informado' : text;
  }

  String get blockedLabel {
    final raw = _readAttr([
      'blocked',
      'block',
      'engineBlocked',
      'relay',
      'immobilizer',
    ]);
    final value = _toBool(raw);
    if (value == null) return 'Nao informado';
    return value ? 'Bloqueado' : 'Desbloqueado';
  }

  String get movementLabel {
    final raw = _readAttr(['motion', 'moving']);
    final value = _toBool(raw);
    if (value != null) {
      return value ? 'Em movimento' : 'Parado';
    }
    return isMoving ? 'Em movimento' : 'Parado';
  }

  String get courseLabel {
    final raw = _readAttr(['course', 'heading']);
    if (raw == null) return 'Nao informado';
    if (raw is num) {
      return '${raw.toStringAsFixed(0)}°';
    }
    final text = raw.toString().trim();
    return text.isEmpty ? 'Nao informado' : text;
  }

  String get latLngLabel {
    final current = _effectivePosition;
    if (current == null) return 'Nao informado';
    return '${current.latitude.toStringAsFixed(6)}, '
        '${current.longitude.toStringAsFixed(6)}';
  }

  String get latitudeLabel {
    final current = _effectivePosition;
    if (current == null) return 'Nao informado';
    return current.latitude.toStringAsFixed(6);
  }

  String get longitudeLabel {
    final current = _effectivePosition;
    if (current == null) return 'Nao informado';
    return current.longitude.toStringAsFixed(6);
  }

  String get lastCommunicationLabel => _formatDateTime(_lastCommunicationAt);

  String get lastCommunicationAgoLabel =>
      _formatRelativeTime(_lastCommunicationAt);

  DateTime? get _gpsAt => _parseDateTime(_effectivePosition?.fixTime);

  String get gpsDateLabel {
    final gps = _gpsAt;
    if (gps == null) return 'Nao informado';
    final comm = _lastCommunicationAt;
    if (comm != null) {
      final delta = gps.difference(comm).inMinutes.abs();
      if (delta <= 1) {
        return 'Igual a ultima comunicacao';
      }
    }
    return _formatDateTime(gps);
  }

  bool get equipmentRegistered => device.id > 0;

  bool get communicationReceived => _lastCommunicationAt != null;

  bool get positionReceived => _effectivePosition != null;

  bool get isReadyForValidation =>
      equipmentRegistered && communicationReceived && positionReceived;
}
