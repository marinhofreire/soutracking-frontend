import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/session_state.dart';

class RoutesScreen extends ConsumerStatefulWidget {
  const RoutesScreen({super.key});

  @override
  ConsumerState<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends ConsumerState<RoutesScreen> {
  int? _deviceId;
  DateTime _from = DateTime.now().subtract(const Duration(hours: 24));
  DateTime _to = DateTime.now();
  bool _loading = false;
  bool _hasSearched = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _routeRows = const <Map<String, dynamic>>[];
  List<_RoutePoint> _points = const <_RoutePoint>[];

  Future<void> _pickDateTime({required bool isFrom}) async {
    final current = isFrom ? _from : _to;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) {
      return;
    }

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isFrom) {
        _from = selected;
      } else {
        _to = selected;
      }
    });
  }

  Future<void> _searchHistory() async {
    if (_deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um veículo.')),
      );
      return;
    }

    if (_from.isAfter(_to)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('O período inicial deve ser menor que o final.')),
      );
      return;
    }

    final session = ref.read(sessionProvider);
    if (!session.isAuthenticated) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sessão não autenticada.')),
      );
      return;
    }

    final client = ref.read(traccarClientProvider);
    final query = <String, dynamic>{
      'deviceId': '$_deviceId',
      'from': _from.toUtc().toIso8601String(),
      'to': _to.toUtc().toIso8601String(),
    };

    setState(() {
      _loading = true;
      _hasSearched = true;
      _errorMessage = null;
      _routeRows = const <Map<String, dynamic>>[];
      _points = const <_RoutePoint>[];
    });

    try {
      final routeRows = await client.getList(
        path: '/reports/route',
        cookie: session.cookie,
        authHeader: session.authHeader,
        query: query,
      );
      final positionRows = await client.getList(
        path: '/positions',
        cookie: session.cookie,
        authHeader: session.authHeader,
        query: query,
      );

      final points = <_RoutePoint>[];
      for (final row in positionRows) {
        final point = _RoutePoint.fromMap(row);
        if (point != null) {
          points.add(point);
        }
      }
      points.sort((a, b) {
        final at = a.fixTime;
        final bt = b.fixTime;
        if (at == null && bt == null) return 0;
        if (at == null) return -1;
        if (bt == null) return 1;
        return at.compareTo(bt);
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _routeRows = routeRows;
        _points = points;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Falha ao carregar histórico de rota: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _formatPickerLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  String _formatServerDate(dynamic value) {
    final parsed = _toDateTime(value);
    if (parsed == null) {
      final raw = '$value'.trim();
      return raw.isEmpty ? 'Não informado' : raw;
    }
    final local = parsed.isUtc ? parsed.toLocal() : parsed;
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute:$second';
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    final text = '$value'.trim();
    if (text.isEmpty) {
      return null;
    }
    return DateTime.tryParse(text);
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value == null) {
      return null;
    }
    return double.tryParse('$value');
  }

  String _formatSpeed(double? speed) {
    if (speed == null) {
      return 'Não informado';
    }
    return speed.toStringAsFixed(1);
  }

  String _formatDistance(double? meters) {
    if (meters == null) {
      return 'Não informado';
    }
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  double? _totalDistance() {
    var total = 0.0;
    var found = false;
    for (final row in _routeRows) {
      final meters = _toDouble(row['distance']);
      if (meters == null) {
        continue;
      }
      found = true;
      total += meters;
    }
    if (!found) {
      return null;
    }
    return total;
  }

  Widget _buildFilterPanel(AsyncValue<List<TraccarDevice>> devicesAsync) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Histórico de rota',
            style: TextStyle(
              color: Color(0xFFE2EAF8),
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Consulta real por veículo e período',
            style: TextStyle(
              color: Color(0xFFB7C5DA),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          devicesAsync.when(
            data: (devices) {
              return DropdownButtonFormField<int>(
                initialValue: _deviceId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Veículo',
                ),
                items: [
                  for (final device in devices)
                    DropdownMenuItem<int>(
                      value: device.id,
                      child: Text(
                        device.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _loading
                    ? null
                    : (value) {
                        setState(() => _deviceId = value);
                      },
              );
            },
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (error, _) => Text(
              'Falha ao carregar veículos: $error',
              style: const TextStyle(
                color: Color(0xFFE2EAF8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _loading ? null : () => _pickDateTime(isFrom: true),
            icon: const Icon(Icons.event_outlined),
            label: Text('Início: ${_formatPickerLabel(_from)}'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _loading ? null : () => _pickDateTime(isFrom: false),
            icon: const Icon(Icons.event_outlined),
            label: Text('Final: ${_formatPickerLabel(_to)}'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _loading ? null : _searchHistory,
            icon: const Icon(Icons.history_outlined),
            label: const Text('Buscar histórico'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final totalDistance = _totalDistance();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _RouteSummaryCard(
          label: 'Pontos da rota',
          value: '${_points.length}',
          icon: Icons.location_on_outlined,
          color: const Color(0xFF3D8BFF),
        ),
        _RouteSummaryCard(
          label: 'Trechos',
          value: '${_routeRows.length}',
          icon: Icons.alt_route_outlined,
          color: const Color(0xFF10B981),
        ),
        _RouteSummaryCard(
          label: 'Distância total',
          value: _formatDistance(totalDistance),
          icon: Icons.straighten_outlined,
          color: const Color(0xFFF59E0B),
        ),
      ],
    );
  }

  Widget _buildRouteRowsTable() {
    if (_routeRows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trechos da rota',
          style: TextStyle(
            color: Color(0xFFE2EAF8),
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingTextStyle: const TextStyle(
              color: Color(0xFFB7C5DA),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            dataTextStyle: const TextStyle(
              color: Color(0xFFE2EAF8),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            columns: const [
              DataColumn(label: Text('Início')),
              DataColumn(label: Text('Fim')),
              DataColumn(label: Text('Distância')),
              DataColumn(label: Text('Vel. média')),
              DataColumn(label: Text('Vel. máx')),
            ],
            rows: [
              for (final row in _routeRows)
                DataRow(
                  cells: [
                    DataCell(Text(_formatServerDate(row['startTime']))),
                    DataCell(Text(_formatServerDate(row['endTime']))),
                    DataCell(Text(_formatDistance(_toDouble(row['distance'])))),
                    DataCell(
                        Text(_formatSpeed(_toDouble(row['averageSpeed'])))),
                    DataCell(Text(_formatSpeed(_toDouble(row['maxSpeed'])))),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPointsTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pontos da rota',
          style: TextStyle(
            color: Color(0xFFE2EAF8),
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        if (_points.isEmpty)
          const Text(
            'Sem pontos no período selecionado.',
            style: TextStyle(
              color: Color(0xFFB7C5DA),
              fontWeight: FontWeight.w600,
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: const TextStyle(
                color: Color(0xFFB7C5DA),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              dataTextStyle: const TextStyle(
                color: Color(0xFFE2EAF8),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              columns: const [
                DataColumn(label: Text('Horário')),
                DataColumn(label: Text('Latitude')),
                DataColumn(label: Text('Longitude')),
                DataColumn(label: Text('Velocidade')),
              ],
              rows: [
                for (final point in _points)
                  DataRow(
                    cells: [
                      DataCell(Text(_formatServerDate(point.rawFixTime))),
                      DataCell(Text(point.latitude.toStringAsFixed(6))),
                      DataCell(Text(point.longitude.toStringAsFixed(6))),
                      DataCell(Text(_formatSpeed(point.speed))),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildResultsPanel() {
    if (_loading) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFE2EAF8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (_hasSearched && _routeRows.isEmpty && _points.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: const Center(
          child: Text(
            'Nenhuma rota encontrada para o período selecionado',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFE2EAF8),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    if (!_hasSearched) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: const Center(
          child: Text(
            'Selecione veículo e período para consultar a rota.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFE2EAF8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          _buildSummary(),
          const SizedBox(height: 12),
          _buildRouteRowsTable(),
          if (_routeRows.isNotEmpty) const SizedBox(height: 12),
          _buildPointsTable(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;
        if (compact) {
          return Column(
            children: [
              _buildFilterPanel(devicesAsync),
              const SizedBox(height: 10),
              Expanded(child: _buildResultsPanel()),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 360, child: _buildFilterPanel(devicesAsync)),
            const SizedBox(width: 10),
            Expanded(child: _buildResultsPanel()),
          ],
        );
      },
    );
  }
}

class _RoutePoint {
  const _RoutePoint({
    required this.latitude,
    required this.longitude,
    required this.rawFixTime,
    required this.fixTime,
    required this.speed,
  });

  final double latitude;
  final double longitude;
  final String? rawFixTime;
  final DateTime? fixTime;
  final double? speed;

  static _RoutePoint? fromMap(Map<String, dynamic> json) {
    final lat = _asDouble(json['latitude']);
    final lng = _asDouble(json['longitude']);
    if (lat == null || lng == null) {
      return null;
    }
    final rawFixTime = json['fixTime'] == null ? null : '${json['fixTime']}';
    return _RoutePoint(
      latitude: lat,
      longitude: lng,
      rawFixTime: rawFixTime,
      fixTime: rawFixTime == null ? null : DateTime.tryParse(rawFixTime),
      speed: _asDouble(json['speed']),
    );
  }

  static double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value == null) {
      return null;
    }
    return double.tryParse('$value');
  }
}

class _RouteSummaryCard extends StatelessWidget {
  const _RouteSummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
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
