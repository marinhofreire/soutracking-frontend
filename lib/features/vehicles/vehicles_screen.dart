import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/session_state.dart';
import '../telemetry/sensor_presentation.dart';

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
    return 'Não informado';
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
    return 'Não informado';
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
    return 'há ${minutes} min';
  }

  final hours = diff.inHours;
  if (hours < 24) {
    return 'há ${hours} h';
  }

  final days = diff.inDays;
  if (days == 1) {
    return 'há 1 dia';
  }
  return 'há ${days} dias';
}

String _formatBoolean(dynamic raw) {
  if (raw == null) {
    return 'Não informado';
  }
  final parsed = _toBool(raw);
  if (parsed == null) {
    return 'Não informado';
  }
  return parsed ? 'Sim' : 'Não';
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
    return 'Evento não identificado';
  }
  final withSpace = value
      .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'), (m) => '${m.group(1)} ${m.group(2)}')
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .trim();
  if (withSpace.isEmpty) {
    return 'Evento não identificado';
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

  final TextEditingController _searchController = TextEditingController();

  int? _selectedDeviceId;
  String _groupFilter = 'Todos os grupos';
  String _driverFilter = 'Todos os motoristas';
  String _statusFilter = 'Todos os status';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final includeTechnical = session.isAdministrator || kDebugMode;
    final devicesAsync = ref.watch(devicesProvider);
    final positionsAsync = ref.watch(positionsProvider);

    if (devicesAsync.isLoading || positionsAsync.isLoading) {
      return const SizedBox.expand(child: _VehiclesLoadingState());
    }

    if (devicesAsync.hasError) {
      return SizedBox.expand(
        child: _ErrorPanel(
          message: 'Falha ao carregar veículos: ${devicesAsync.error}',
        ),
      );
    }

    if (positionsAsync.hasError) {
      return SizedBox.expand(
        child: _ErrorPanel(
          message: 'Falha ao carregar posições: ${positionsAsync.error}',
        ),
      );
    }

    final devices = devicesAsync.valueOrNull ?? const <TraccarDevice>[];
    final positions = positionsAsync.valueOrNull ?? const <TraccarPosition>[];
    final vehicles = _buildVehicleViews(devices, positions);
    final kpis = _VehiclesKpis.fromVehicles(vehicles);

    final groupOptions = <String>[
      'Todos os grupos',
      ...{for (final item in vehicles) item.categoryLabel},
    ];
    final driverOptions = <String>[
      'Todos os motoristas',
      ...{for (final item in vehicles) _driverLabel(item)},
    ];
    const statusOptions = <String>[
      'Todos os status',
      'Online',
      'Offline',
      'Em movimento',
      'Parado',
      'Sem comunicação',
    ];
    final filteredVehicles = _applyFilters(vehicles);

    return SizedBox.expand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VehiclesPageHeader(
            onAddVehicle: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Cadastro visual de veículo em ajuste.')),
            ),
          ),
          const SizedBox(height: 10),
          _VehiclesKpiRow(summary: kpis),
          const SizedBox(height: 10),
          _VehiclesFiltersBar(
            searchController: _searchController,
            groupOptions: groupOptions,
            driverOptions: driverOptions,
            statusOptions: statusOptions,
            groupValue: _groupFilter,
            driverValue: _driverFilter,
            statusValue: _statusFilter,
            onSearchChanged: (_) => setState(() {}),
            onGroupChanged: (value) => setState(() => _groupFilter = value),
            onDriverChanged: (value) => setState(() => _driverFilter = value),
            onStatusChanged: (value) => setState(() => _statusFilter = value),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: filteredVehicles.isEmpty
                ? const _EmptyVehiclesPanel()
                : _VehiclesListPanel(
                    vehicles: filteredVehicles,
                    selectedDeviceId: _selectedDeviceId,
                    onSelect: (vehicle) {
                      setState(() => _selectedDeviceId = vehicle.device.id);
                    },
                  ),
          ),
          if (_selectedDeviceId != null && includeTechnical) ...[
            const SizedBox(height: 10),
            _VehicleDetailsInlinePanel(selectedDeviceId: _selectedDeviceId!),
          ],
        ],
      ),
    );
  }

  String _driverLabel(_VehicleViewData vehicle) {
    final raw = vehicle.device.attributes?['driverName'];
    final label = raw?.toString().trim() ?? '';
    return label.isEmpty ? 'Não informado' : label;
  }

  String _statusLabel(_VehicleViewData vehicle) {
    if (vehicle.isMoving) return 'Em movimento';
    if (vehicle.isOperationalOnline) return 'Parado';
    final normalized = vehicle.operationalStatusLabel.toLowerCase();
    if (normalized.contains('unknown')) return 'Sem comunicação';
    return 'Offline';
  }

  List<_VehicleViewData> _applyFilters(List<_VehicleViewData> vehicles) {
    final query = _searchController.text.trim().toLowerCase();
    return vehicles.where((vehicle) {
      if (query.isNotEmpty) {
        final driver = _driverLabel(vehicle).toLowerCase();
        final plate = vehicle.identifier.toLowerCase();
        final name = vehicle.nameLabel.toLowerCase();
        final group = vehicle.categoryLabel.toLowerCase();
        final found = plate.contains(query) ||
            name.contains(query) ||
            driver.contains(query) ||
            group.contains(query);
        if (!found) {
          return false;
        }
      }

      if (_groupFilter != 'Todos os grupos' &&
          vehicle.categoryLabel != _groupFilter) {
        return false;
      }

      if (_driverFilter != 'Todos os motoristas' &&
          _driverLabel(vehicle) != _driverFilter) {
        return false;
      }

      if (_statusFilter != 'Todos os status' &&
          _statusLabel(vehicle) != _statusFilter) {
        return false;
      }

      return true;
    }).toList();
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

class _VehiclesPageHeader extends StatelessWidget {
  const _VehiclesPageHeader({required this.onAddVehicle});

  final VoidCallback onAddVehicle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E0EE)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.directions_car_filled_outlined,
              color: Color(0xFF2D8CFF),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Veículos',
                  style: TextStyle(
                    color: Color(0xFF25344A),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Cadastro e ciclo de vida da frota',
                  style: TextStyle(
                    color: Color(0xFF5F738F),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onAddVehicle,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Adicionar veículo'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2D8CFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehiclesFiltersBar extends StatelessWidget {
  const _VehiclesFiltersBar({
    required this.searchController,
    required this.groupOptions,
    required this.driverOptions,
    required this.statusOptions,
    required this.groupValue,
    required this.driverValue,
    required this.statusValue,
    required this.onSearchChanged,
    required this.onGroupChanged,
    required this.onDriverChanged,
    required this.onStatusChanged,
  });

  final TextEditingController searchController;
  final List<String> groupOptions;
  final List<String> driverOptions;
  final List<String> statusOptions;
  final String groupValue;
  final String driverValue;
  final String statusValue;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onGroupChanged;
  final ValueChanged<String> onDriverChanged;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E0EE)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar por placa ou ID',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF8FBFF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFD6E0EE)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFD6E0EE)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF7CB0FF)),
                ),
              ),
            ),
          ),
          _FilterDropdown(
            label: 'Grupo',
            options: groupOptions,
            value: groupValue,
            onChanged: onGroupChanged,
          ),
          _FilterDropdown(
            label: 'Motorista',
            options: driverOptions,
            value: driverValue,
            onChanged: onDriverChanged,
          ),
          _FilterDropdown(
            label: 'Status',
            options: statusOptions,
            value: statusValue,
            onChanged: onStatusChanged,
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final normalizedValue = options.contains(value) ? value : options.first;
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<String>(
        initialValue: normalizedValue,
        isExpanded: true,
        items: [
          for (final option in options)
            DropdownMenuItem<String>(
              value: option,
              child: Text(
                option,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
        ],
        onChanged: (next) {
          if (next != null) {
            onChanged(next);
          }
        },
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFF8FBFF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD6E0EE)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD6E0EE)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF7CB0FF)),
          ),
        ),
      ),
    );
  }
}

class _VehiclesLoadingState extends StatelessWidget {
  const _VehiclesLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _VehiclesPageHeader(onAddVehicle: _noopAction),
        const SizedBox(height: 10),
        const _VehiclesKpiRow(
          summary: _VehiclesKpis(
            total: 0,
            online: 0,
            offline: 0,
            moving: 0,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD6E0EE)),
          ),
        ),
        const SizedBox(height: 10),
        const Expanded(child: _EmptyVehiclesPanel()),
      ],
    );
  }
}

class _VehicleDetailsInlinePanel extends ConsumerWidget {
  const _VehicleDetailsInlinePanel({required this.selectedDeviceId});

  final int selectedDeviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices =
        ref.watch(devicesProvider).valueOrNull ?? const <TraccarDevice>[];
    final positions =
        ref.watch(positionsProvider).valueOrNull ?? const <TraccarPosition>[];

    TraccarDevice? selectedDevice;
    for (final device in devices) {
      if (device.id == selectedDeviceId) {
        selectedDevice = device;
        break;
      }
    }
    if (selectedDevice == null) {
      return const SizedBox.shrink();
    }

    TraccarPosition? selectedPosition;
    for (final position in positions) {
      if (position.deviceId != selectedDeviceId) {
        continue;
      }
      final currentTime = _parseDateTime(selectedPosition?.fixTime);
      final nextTime = _parseDateTime(position.fixTime);
      if (selectedPosition == null ||
          (nextTime != null &&
              (currentTime == null || nextTime.isAfter(currentTime)))) {
        selectedPosition = position;
      }
    }

    final selectedPositionAsync =
        ref.watch(_devicePositionProvider(selectedDeviceId));
    final selectedEventsAsync =
        ref.watch(_deviceEventsProvider(selectedDeviceId));
    final events =
        selectedEventsAsync.valueOrNull ?? const <Map<String, dynamic>>[];
    final includeTechnical =
        ref.watch(sessionProvider).isAdministrator || kDebugMode;

    final vehicleData = _VehicleViewData(
      device: selectedDevice,
      position: selectedPosition,
      positionOverride: selectedPositionAsync.valueOrNull,
      offlineStaleThreshold: const Duration(minutes: 30),
    );

    return _VehicleDetailPanel(
      vehicle: vehicleData,
      includeTechnical: includeTechnical,
      recentEvents: events,
      eventsLoading: selectedEventsAsync.isLoading,
    );
  }
}

void _noopAction() {}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xD9FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6E0EE)),
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
                color: Color(0xFF25344A),
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
        color: const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E0EE)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF25344A),
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF5F738F),
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
        color: const Color(0xD9FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6E0EE)),
      ),
      child: const Center(
        child: Text(
          'Nenhum veiculo disponivel no momento',
          style: TextStyle(
            color: Color(0xFF25344A),
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6E0EE)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xCCF8FBFF),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFFD6E0EE).withValues(alpha: 0.9),
                ),
              ),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: _HeaderCell('Placa/ID')),
                Expanded(flex: 3, child: _HeaderCell('Veiculo')),
                Expanded(flex: 2, child: _HeaderCell('Grupo')),
                Expanded(flex: 2, child: _HeaderCell('Motorista')),
                Expanded(flex: 2, child: _HeaderCell('Status')),
                Expanded(flex: 3, child: _HeaderCell('Última atualizacao')),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: vehicles.length,
              separatorBuilder: (_, __) => Divider(
                color: const Color(0xFFD6E0EE).withValues(alpha: 0.9),
                height: 1,
              ),
              itemBuilder: (context, index) {
                final vehicle = vehicles[index];
                final selected = vehicle.device.id == selectedDeviceId;
                return _VehicleTile(
                  vehicle: vehicle,
                  selected: selected,
                  onTap: () => onSelect(vehicle),
                );
              },
            ),
          ),
        ],
      ),
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
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          color: selected
              ? const Color(0xFFEAF2FF).withValues(alpha: 0.55)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(flex: 3, child: _CellText(vehicle.identifier)),
              Expanded(flex: 3, child: _CellText(vehicle.nameLabel)),
              Expanded(flex: 2, child: _CellText(vehicle.categoryLabel)),
              Expanded(
                flex: 2,
                child: _CellText(
                  vehicle.device.attributes?['driverName']?.toString() ??
                      'Não informado',
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _StatusChip(
                    label: vehicle.isMoving
                        ? 'Em movimento'
                        : (vehicle.isOperationalOnline
                            ? 'Parado'
                            : (vehicle.operationalStatusLabel
                                    .toLowerCase()
                                    .contains('unknown')
                                ? 'Sem comunicação'
                                : 'Offline')),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: _CellText(vehicle.lastCommunicationAgoLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF5F738F),
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );
  }
}

class _CellText extends StatelessWidget {
  const _CellText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFF334155),
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }
}

class _VehicleDetailPanel extends StatelessWidget {
  const _VehicleDetailPanel({
    required this.vehicle,
    required this.includeTechnical,
    required this.recentEvents,
    required this.eventsLoading,
  });

  final _VehicleViewData vehicle;
  final bool includeTechnical;
  final List<Map<String, dynamic>> recentEvents;
  final bool eventsLoading;

  @override
  Widget build(BuildContext context) {
    final checklistReady = vehicle.isReadyForValidation;
    final sections = vehicle.sensorSections(includeTechnical: includeTechnical);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xD9FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6E0EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detalhe do veiculo',
            style: TextStyle(
              color: Color(0xFF25344A),
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
                title: 'Última comunicação',
                value: vehicle.lastCommunicationLabel,
              ),
              _InfoLine(
                title: 'Tempo desde última',
                value: vehicle.lastCommunicationAgoLabel,
              ),
              _InfoLine(title: 'Data GPS', value: vehicle.gpsDateLabel),
              _InfoLine(title: 'Latitude', value: vehicle.latitudeLabel),
              _InfoLine(title: 'Longitude', value: vehicle.longitudeLabel),
              _InfoLine(title: 'Velocidade', value: vehicle.speedLabel),
              _InfoLine(title: 'Direcao', value: vehicle.courseLabel),
              _InfoLine(title: 'Ignição', value: vehicle.ignitionLabel),
              _InfoLine(title: 'Bateria interna', value: vehicle.batteryLabel),
              _InfoLine(title: 'Sinal GSM', value: vehicle.signalLabel),
              _InfoLine(title: 'Bloqueio', value: vehicle.blockedLabel),
              _InfoLine(title: 'Movimento', value: vehicle.movementLabel),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Sensores NT20/X22',
            style: TextStyle(
              color: Color(0xFF25344A),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          if (sections.isEmpty)
            const Text(
              'Sensores n\u00E3o recebidos',
              style: TextStyle(
                color: Color(0xFF5F738F),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final section in sections) ...[
                  Text(
                    section.title,
                    style: const TextStyle(
                      color: Color(0xFF25344A),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      for (final item in section.items)
                        _InfoLine(title: item.label, value: item.value),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          const SizedBox(height: 10),
          const Text(
            'Eventos recentes',
            style: TextStyle(
              color: Color(0xFF25344A),
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
                color: Color(0xFF5F738F),
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
              color: Color(0xFF25344A),
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
                title: 'Comunicação recebida',
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
                title: 'Pronto para validação',
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
    final isGreen =
        normalized.contains('parado') || normalized.contains('movimento');
    final isWarning = normalized.contains('sem comunicacao');
    final fgColor = isGreen
        ? const Color(0xFF047857)
        : (isWarning ? const Color(0xFFB45309) : const Color(0xFFB42318));
    final bgColor = isGreen
        ? const Color(0xFFEAFBF3)
        : (isWarning ? const Color(0xFFFFF7ED) : const Color(0xFFFDECEC));
    final borderColor = isGreen
        ? const Color(0xFFA7F3D0)
        : (isWarning ? const Color(0xFFFBD38D) : const Color(0xFFFBCACA));
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
  Map<String, dynamic> get _mergedAttributes => {
        ...?device.attributes,
        ...?_effectivePosition?.attributes,
      };

  bool get hasValidGps => hasValidGpsPosition(
        latitude: _effectivePosition?.latitude,
        longitude: _effectivePosition?.longitude,
        attributes: _mergedAttributes,
      );

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

  String get categoryLabel {
    final raw = device.category ??
        device.attributes?['model'] ??
        device.attributes?['vehicleModel'] ??
        device.attributes?['type'];
    final text = raw?.toString().trim() ?? '';
    return text.isEmpty ? 'Não informado' : text;
  }

  String get _normalizedStatus => device.status.trim().toLowerCase();

  String get rawStatusLabel {
    final text = device.status.trim();
    return text.isEmpty ? 'Não informado' : text;
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
    return 'Não informado';
  }

  double? get speed {
    final value = _effectivePosition?.speed;
    if (value == null || !value.isFinite) return null;
    return value;
  }

  bool get isMoving => _effectivePosition != null && (speed ?? 0) > 1;

  String get speedLabel {
    final current = speed;
    if (current == null) return 'Não informado';
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
    if (ignition == null) return 'Não informado';
    return ignition ? 'Ligada' : 'Desligada';
  }

  String get batteryLabel {
    final levelRaw = _readAttr([
      'batteryLevel',
      'batteryPercent',
      'deviceBatteryLevel',
    ]);
    final level = _toNumber(levelRaw);
    if (level != null) {
      final normalized = level <= 1 ? level * 100 : level;
      return '${normalized.toStringAsFixed(0)}%';
    }

    final batteryRaw = _readAttr([
      'battery',
      'batteryVoltage',
      'deviceBattery',
    ]);
    final battery = _toNumber(batteryRaw);
    if (battery != null) {
      return '${battery.toStringAsFixed(2).replaceAll('.', ',')} V';
    }

    final powerRaw = _readAttr(['power', 'voltage']);
    final power = _toNumber(powerRaw);
    if (power != null) {
      return '${power.toStringAsFixed(2).replaceAll('.', ',')} V';
    }

    final text = (levelRaw ?? batteryRaw ?? powerRaw)?.toString().trim() ?? '';
    return text.isEmpty ? 'Não informado' : text;
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
    if (raw == null) return 'Não informado';
    if (raw is num) return raw.toString();
    final text = raw.toString().trim();
    return text.isEmpty ? 'Não informado' : text;
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
    if (value == null) return 'Não informado';
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
    if (raw == null) return 'Não informado';
    if (raw is num) {
      return '${raw.toStringAsFixed(0)}\u00B0';
    }
    final text = raw.toString().trim();
    return text.isEmpty ? 'Não informado' : text;
  }

  String get latLngLabel {
    return formatGpsCoordinateLabel(
      latitude: _effectivePosition?.latitude,
      longitude: _effectivePosition?.longitude,
      attributes: _mergedAttributes,
    );
  }

  String get latitudeLabel {
    final current = _effectivePosition;
    if (!hasValidGps || current == null) return 'Sem GPS v\u00E1lido';
    return current.latitude.toStringAsFixed(6);
  }

  String get longitudeLabel {
    final current = _effectivePosition;
    if (!hasValidGps || current == null) return 'Sem GPS v\u00E1lido';
    return current.longitude.toStringAsFixed(6);
  }

  String get lastCommunicationLabel => _formatDateTime(_lastCommunicationAt);

  String get lastCommunicationAgoLabel =>
      _formatRelativeTime(_lastCommunicationAt);

  DateTime? get _gpsAt => _parseDateTime(_effectivePosition?.fixTime);

  String get gpsDateLabel {
    if (!hasValidGps) return 'Sem GPS v\u00E1lido';
    final gps = _gpsAt;
    if (gps == null) return 'Não informado';
    final comm = _lastCommunicationAt;
    if (comm != null) {
      final delta = gps.difference(comm).inMinutes.abs();
      if (delta <= 1) {
        return 'Igual a última comunicação';
      }
    }
    return _formatDateTime(gps);
  }

  List<SensorDisplaySection> sensorSections({required bool includeTechnical}) {
    return buildSensorDisplaySections(
      deviceAttributes: device.attributes,
      positionAttributes: _effectivePosition?.attributes,
      includeTechnical: includeTechnical,
    );
  }

  bool get equipmentRegistered => device.id > 0;

  bool get communicationReceived => _lastCommunicationAt != null;

  bool get positionReceived => _effectivePosition != null;

  bool get isReadyForValidation =>
      equipmentRegistered && communicationReceived && positionReceived;

  double? _toNumber(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.trim();
      if (normalized.isEmpty) return null;
      return double.tryParse(normalized.replaceAll(',', '.'));
    }
    return null;
  }
}
