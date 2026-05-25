import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

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
  int? _selectedPointIndex;
  gmaps.GoogleMapController? _mapController;

  List<Map<String, dynamic>> _routeRows = const <Map<String, dynamic>>[];
  List<_RoutePoint> _points = const <_RoutePoint>[];

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

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
        const SnackBar(content: Text('Selecione um veiculo.')),
      );
      return;
    }

    if (_from.isAfter(_to)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Periodo inicial deve ser menor que final.')),
      );
      return;
    }

    final session = ref.read(sessionProvider);
    if (!session.isAuthenticated) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sessao nao autenticada.')),
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
      _selectedPointIndex = null;
    });

    try {
      final routeRows = await client.getList(
        path: '/reports/route',
        cookie: session.cookie,
        authHeader: session.authHeader,
        query: query,
      );

      final points = <_RoutePoint>[];
      for (final row in routeRows) {
        final point = _RoutePoint.fromMap(row);
        if (point != null) {
          points.add(point);
        }
      }

      points.sort((a, b) {
        final at = a.effectiveTime;
        final bt = b.effectiveTime;
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
        _selectedPointIndex = points.isEmpty ? null : 0;
      });

      await _fitMapToPoints(points);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Falha ao carregar replay da rota: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _fitMapToPoints(List<_RoutePoint> points) async {
    final controller = _mapController;
    if (controller == null || points.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (points.length == 1) {
          await controller.animateCamera(
            gmaps.CameraUpdate.newLatLngZoom(points.first.latLng, 15),
          );
          return;
        }

        var minLat = points.first.latitude;
        var maxLat = points.first.latitude;
        var minLng = points.first.longitude;
        var maxLng = points.first.longitude;
        for (final point in points) {
          minLat = math.min(minLat, point.latitude);
          maxLat = math.max(maxLat, point.latitude);
          minLng = math.min(minLng, point.longitude);
          maxLng = math.max(maxLng, point.longitude);
        }

        final bounds = gmaps.LatLngBounds(
          southwest: gmaps.LatLng(minLat, minLng),
          northeast: gmaps.LatLng(maxLat, maxLng),
        );

        await controller.animateCamera(
          gmaps.CameraUpdate.newLatLngBounds(bounds, 50),
        );
      } catch (_) {
        // Ignora erro de camera para nao quebrar render do replay.
      }
    });
  }

  void _selectPointIndex(int index) {
    if (index < 0 || index >= _points.length) {
      return;
    }
    setState(() => _selectedPointIndex = index);
  }

  _RoutePoint? get _selectedPoint {
    final index = _selectedPointIndex;
    if (index == null || index < 0 || index >= _points.length) {
      return null;
    }
    return _points[index];
  }

  void _moveSelectedPoint(int delta) {
    final current = _selectedPointIndex;
    if (current == null) {
      return;
    }
    final next = current + delta;
    if (next < 0 || next >= _points.length) {
      return;
    }
    _selectPointIndex(next);
  }

  String _formatPickerLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  String _formatDateTime(dynamic value) {
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

  String _formatSpeedKmh(double? speedKnots) {
    if (speedKnots == null) {
      return 'Não informado';
    }
    final kmh = speedKnots * 1.852;
    return '${kmh.toStringAsFixed(1)} km/h';
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

  double? _totalDistanceMeters() {
    if (_points.isEmpty) {
      return null;
    }

    final firstWithOdometer = _points.firstWhere(
      (point) => point.odometerMeters != null,
      orElse: () => _points.first,
    );
    final lastWithOdometer = _points.lastWhere(
      (point) => point.odometerMeters != null,
      orElse: () => _points.last,
    );
    final firstOdometer = firstWithOdometer.odometerMeters;
    final lastOdometer = lastWithOdometer.odometerMeters;
    if (firstOdometer != null &&
        lastOdometer != null &&
        lastOdometer >= firstOdometer) {
      return lastOdometer - firstOdometer;
    }

    var total = 0.0;
    var found = false;
    for (final point in _points) {
      final distance = point.distanceMeters;
      if (distance == null) {
        continue;
      }
      found = true;
      total += distance;
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
            'Replay de rota',
            style: TextStyle(
              color: Color(0xFFE2EAF8),
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Selecione veiculo e periodo para reproduzir no mapa',
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
                  labelText: 'Veiculo',
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
              'Falha ao carregar veiculos: $error',
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
            label: Text('Inicio: ${_formatPickerLabel(_from)}'),
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
            icon: const Icon(Icons.replay_outlined),
            label: const Text('Carregar replay'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final totalDistance = _totalDistanceMeters();
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
          label: 'Registros API',
          value: '${_routeRows.length}',
          icon: Icons.cloud_done_outlined,
          color: const Color(0xFF10B981),
        ),
        _RouteSummaryCard(
          label: 'Distancia total',
          value: _formatDistance(totalDistance),
          icon: Icons.straighten_outlined,
          color: const Color(0xFFF59E0B),
        ),
      ],
    );
  }

  Set<gmaps.Marker> _buildMapMarkers() {
    final markers = <gmaps.Marker>{};
    for (var index = 0; index < _points.length; index++) {
      final point = _points[index];

      var hue = gmaps.BitmapDescriptor.hueAzure;
      if (index == 0) {
        hue = gmaps.BitmapDescriptor.hueGreen;
      }
      if (index == _points.length - 1) {
        hue = gmaps.BitmapDescriptor.hueOrange;
      }
      if (_selectedPointIndex == index) {
        hue = gmaps.BitmapDescriptor.hueRed;
      }

      final title = index == 0
          ? 'Inicio'
          : index == _points.length - 1
              ? 'Fim'
              : 'Ponto ${index + 1}';

      markers.add(
        gmaps.Marker(
          markerId: gmaps.MarkerId('route-point-$index'),
          position: point.latLng,
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: gmaps.InfoWindow(
            title: title,
            snippet: _buildPointPopupSnippet(point),
          ),
          onTap: () => _selectPointIndex(index),
        ),
      );
    }
    return markers;
  }

  String _buildPointPopupSnippet(_RoutePoint point) {
    final address = point.addressLabel;
    final compactAddress =
        address.length > 64 ? '${address.substring(0, 61)}...' : address;
    return 'Data/hora ${_formatDateTime(point.rawEffectiveTime)} | '
        'Vel ${_formatSpeedKmh(point.speedKnots)} | '
        'Lat ${point.latitude.toStringAsFixed(6)} | '
        'Lng ${point.longitude.toStringAsFixed(6)} | '
        'Bat ${point.batteryLabel} | '
        'Ign ${point.ignitionLabel} | '
        'End $compactAddress';
  }

  Widget _buildReplayMap() {
    if (_points.isEmpty) {
      return const SizedBox.shrink();
    }

    final fallback = _selectedPoint?.latLng ?? _points.first.latLng;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mapa do replay',
          style: TextStyle(
            color: Color(0xFFE2EAF8),
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 320,
            child: gmaps.GoogleMap(
              initialCameraPosition: gmaps.CameraPosition(
                target: fallback,
                zoom: 13,
              ),
              mapType: gmaps.MapType.normal,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
              compassEnabled: true,
              onMapCreated: (controller) {
                _mapController = controller;
                _fitMapToPoints(_points);
              },
              markers: _buildMapMarkers(),
              polylines: {
                if (_points.length > 1)
                  gmaps.Polyline(
                    polylineId: const gmaps.PolylineId('replay-route'),
                    points: [
                      for (final point in _points) point.latLng,
                    ],
                    color: const Color(0xFF176EEB),
                    width: 5,
                  ),
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPointDetailsCard() {
    final point = _selectedPoint;
    final total = _points.length;
    final current = (_selectedPointIndex ?? -1) + 1;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: point == null
          ? const Text(
              'Selecione um ponto para ver os detalhes do replay.',
              style: TextStyle(
                color: Color(0xFFB7C5DA),
                fontWeight: FontWeight.w600,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Detalhe do ponto',
                      style: TextStyle(
                        color: Color(0xFFE2EAF8),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$current/$total',
                      style: const TextStyle(
                        color: Color(0xFFB7C5DA),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: (_selectedPointIndex ?? 0) <= 0
                          ? null
                          : () => _moveSelectedPoint(-1),
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('Anterior'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: (_selectedPointIndex ?? -1) >= total - 1
                          ? null
                          : () => _moveSelectedPoint(1),
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('Proximo'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _ReplayDetailLine(
                  label: 'Data/hora',
                  value: _formatDateTime(point.rawEffectiveTime),
                ),
                _ReplayDetailLine(
                  label: 'Latitude/Longitude',
                  value:
                      '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
                ),
                _ReplayDetailLine(
                  label: 'Velocidade',
                  value: _formatSpeedKmh(point.speedKnots),
                ),
                _ReplayDetailLine(
                  label: 'Bateria',
                  value: point.batteryLabel,
                ),
                _ReplayDetailLine(
                  label: 'Ignição',
                  value: point.ignitionLabel,
                ),
                _ReplayDetailLine(
                  label: 'Endereco',
                  value: point.addressLabel,
                ),
              ],
            ),
    );
  }

  Widget _buildPointsTable() {
    if (_points.isEmpty) {
      return const SizedBox.shrink();
    }

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
              DataColumn(label: Text('#')),
              DataColumn(label: Text('Horario')),
              DataColumn(label: Text('Latitude')),
              DataColumn(label: Text('Longitude')),
              DataColumn(label: Text('Velocidade')),
            ],
            rows: [
              for (var index = 0; index < _points.length; index++)
                DataRow(
                  selected: _selectedPointIndex == index,
                  onSelectChanged: (_) => _selectPointIndex(index),
                  cells: [
                    DataCell(Text('${index + 1}')),
                    DataCell(
                        Text(_formatDateTime(_points[index].rawEffectiveTime))),
                    DataCell(Text(_points[index].latitude.toStringAsFixed(6))),
                    DataCell(Text(_points[index].longitude.toStringAsFixed(6))),
                    DataCell(Text(_formatSpeedKmh(_points[index].speedKnots))),
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

    if (_hasSearched && _points.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: Text(
            'Nenhum ponto de rota encontrado no periodo selecionado.',
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
            'Selecione veiculo e periodo para consultar o replay.',
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
          _buildReplayMap(),
          const SizedBox(height: 12),
          _buildPointDetailsCard(),
          const SizedBox(height: 12),
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
    required this.rawDeviceTime,
    required this.rawServerTime,
    required this.fixTime,
    required this.deviceTime,
    required this.serverTime,
    required this.speedKnots,
    required this.address,
    required this.attributes,
    required this.distanceMeters,
    required this.odometerMeters,
  });

  final double latitude;
  final double longitude;
  final String? rawFixTime;
  final String? rawDeviceTime;
  final String? rawServerTime;
  final DateTime? fixTime;
  final DateTime? deviceTime;
  final DateTime? serverTime;
  final double? speedKnots;
  final String? address;
  final Map<String, dynamic> attributes;
  final double? distanceMeters;
  final double? odometerMeters;

  DateTime? get effectiveTime => fixTime ?? deviceTime ?? serverTime;

  String? get rawEffectiveTime => rawFixTime ?? rawDeviceTime ?? rawServerTime;

  gmaps.LatLng get latLng => gmaps.LatLng(latitude, longitude);

  String get addressLabel {
    final value = address ?? attributes['address'];
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'Não informado' : text;
  }

  bool? get ignition {
    final raw = attributes['ignition'] ?? attributes['ignitionOn'];
    return _asBool(raw);
  }

  String get ignitionLabel {
    final value = ignition;
    if (value == null) {
      return 'Não informado';
    }
    return value ? 'Ligada' : 'Desligada';
  }

  String get batteryLabel {
    final raw = attributes['battery'] ??
        attributes['batteryLevel'] ??
        attributes['power'] ??
        attributes['batteryVoltage'];
    if (raw == null) {
      return 'Não informado';
    }
    if (raw is num) {
      final value = raw.toDouble();
      if (!value.isFinite) {
        return 'Não informado';
      }
      if (value > 20) {
        return '${value.toStringAsFixed(0)}%';
      }
      return '${value.toStringAsFixed(2)} V';
    }
    final text = raw.toString().trim();
    return text.isEmpty ? 'Não informado' : text;
  }

  static _RoutePoint? fromMap(Map<String, dynamic> json) {
    final lat = _asDouble(json['latitude']);
    final lng = _asDouble(json['longitude']);
    if (lat == null || lng == null) {
      return null;
    }

    final attrsRaw = json['attributes'];
    final attrs = attrsRaw is Map
        ? attrsRaw.cast<String, dynamic>()
        : <String, dynamic>{};

    final rawFixTime = json['fixTime']?.toString();
    final rawDeviceTime = json['deviceTime']?.toString();
    final rawServerTime = json['serverTime']?.toString();

    return _RoutePoint(
      latitude: lat,
      longitude: lng,
      rawFixTime: rawFixTime,
      rawDeviceTime: rawDeviceTime,
      rawServerTime: rawServerTime,
      fixTime: _asDateTime(rawFixTime),
      deviceTime: _asDateTime(rawDeviceTime),
      serverTime: _asDateTime(rawServerTime),
      speedKnots: _asDouble(json['speed']),
      address: json['address']?.toString(),
      attributes: attrs,
      distanceMeters: _asDouble(attrs['distance']),
      odometerMeters: _asDouble(attrs['odometer']),
    );
  }

  static DateTime? _asDateTime(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
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

  static bool? _asBool(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value > 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) {
        return null;
      }
      if (normalized == 'true' ||
          normalized == '1' ||
          normalized == 'on' ||
          normalized == 'ligada' ||
          normalized == 'sim') {
        return true;
      }
      if (normalized == 'false' ||
          normalized == '0' ||
          normalized == 'off' ||
          normalized == 'desligada' ||
          normalized == 'nao' ||
          normalized == 'não') {
        return false;
      }
    }
    return null;
  }
}

class _ReplayDetailLine extends StatelessWidget {
  const _ReplayDetailLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Color(0xFFB7C5DA),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFFE2EAF8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
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
