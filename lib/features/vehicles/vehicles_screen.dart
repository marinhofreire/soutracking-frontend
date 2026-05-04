import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/session_state.dart';

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
        message: 'Falha ao carregar veículos: ${devicesAsync.error}',
      );
    }

    if (positionsAsync.hasError) {
      return _ErrorPanel(
        message: 'Falha ao carregar posições: ${positionsAsync.error}',
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
          _VehicleDetailPanel(vehicle: selected),
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

      final currentTime = _tryParseDateTime(current.fixTime);
      final nextTime = _tryParseDateTime(position.fixTime);
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

  DateTime? _tryParseDateTime(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
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
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
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
                color: Color(0xFFE2EAF8),
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
        color: color.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFD7E2F3),
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
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: const Center(
        child: Text(
          'Nenhum veículo disponível no momento',
          style: TextStyle(
            color: Color(0xFFE2EAF8),
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
                ? Colors.white.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFF4DA3FF).withValues(alpha: 0.62)
                  : Colors.white.withValues(alpha: 0.20),
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
                        color: Colors.white,
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
                    title: 'Última comunicação',
                    value: vehicle.lastCommunicationLabel,
                  ),
                  _InfoLine(title: 'Velocidade', value: vehicle.speedLabel),
                  _InfoLine(title: 'Ignição', value: vehicle.ignitionLabel),
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
  const _VehicleDetailPanel({required this.vehicle});

  final _VehicleViewData vehicle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detalhe do veículo',
            style: TextStyle(
              color: Colors.white,
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
                title: 'Status operacional',
                value: vehicle.operationalStatusLabel,
              ),
              _InfoLine(
                title: 'Última comunicação',
                value: vehicle.lastCommunicationLabel,
              ),
              _InfoLine(title: 'Velocidade', value: vehicle.speedLabel),
              _InfoLine(title: 'Ignição', value: vehicle.ignitionLabel),
              _InfoLine(title: 'Latitude/Longitude', value: vehicle.latLngLabel),
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
    final isOnline = label.toLowerCase() == 'online';
    final color = isOnline ? const Color(0xFF10B981) : const Color(0xFFE74B4B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.95),
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
        color: Color(0xFFE2EAF8),
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
  });

  final TraccarDevice device;
  final TraccarPosition? position;
  final Duration offlineStaleThreshold;

  String get nameLabel {
    final text = device.name.trim();
    return text.isEmpty ? 'Não informado' : text;
  }

  String get identifier {
    final raw = device.uniqueId ??
        device.attributes?['plate'] ??
        device.attributes?['plateNumber'] ??
        device.attributes?['licensePlate'] ??
        device.attributes?['registration'] ??
        device.attributes?['identifier'];
    final text = raw?.toString().trim() ?? '';
    return text.isEmpty ? 'Não informado' : text;
  }

  String get _normalizedStatus => device.status.trim().toLowerCase();

  bool get _statusUnknown =>
      _normalizedStatus.isEmpty ||
      _normalizedStatus == 'unknown' ||
      _normalizedStatus == 'nao informado' ||
      _normalizedStatus == 'não informado' ||
      _normalizedStatus == 'n/a';

  DateTime? get _lastCommunicationAt {
    final raw = device.lastUpdate ?? position?.fixTime;
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return parsed.isUtc ? parsed.toLocal() : parsed;
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
    if (isOperationalOffline) return 'Offline operacional';
    return 'Não informado';
  }

  double? get speed {
    final value = position?.speed;
    if (value == null || !value.isFinite) return null;
    return value;
  }

  bool get isMoving => position != null && (speed ?? 0) > 0;

  String get speedLabel {
    final current = speed;
    if (current == null) return 'Não informado';
    return '${current.toStringAsFixed(0)} km/h';
  }

  bool? get _ignition {
    final raw = position?.attributes?['ignition'] ??
        device.attributes?['ignition'] ??
        device.attributes?['ignitionOn'];
    if (raw == null) return null;
    if (raw is bool) return raw;
    if (raw is num) return raw > 0;
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized == 'true' ||
          normalized == 'on' ||
          normalized == 'ligada' ||
          normalized == '1') {
        return true;
      }
      if (normalized == 'false' ||
          normalized == 'off' ||
          normalized == 'desligada' ||
          normalized == '0') {
        return false;
      }
    }
    return null;
  }

  String get ignitionLabel {
    final ignition = _ignition;
    if (ignition == null) return 'Não informado';
    return ignition ? 'Ligada' : 'Desligada';
  }

  String get latLngLabel {
    final current = position;
    if (current == null) return 'Não informado';
    return '${current.latitude.toStringAsFixed(6)}, '
        '${current.longitude.toStringAsFixed(6)}';
  }

  String get lastCommunicationLabel {
    final value = _lastCommunicationAt;
    if (value == null) return 'Não informado';
    final dd = value.day.toString().padLeft(2, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final yyyy = value.year.toString().padLeft(4, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$min';
  }
}
