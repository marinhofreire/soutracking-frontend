import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/map_config.dart';
import '../../state/session_state.dart';

class GeofencesScreen extends ConsumerStatefulWidget {
  const GeofencesScreen({super.key});

  @override
  ConsumerState<GeofencesScreen> createState() => _GeofencesScreenState();
}

class _GeofencesScreenState extends ConsumerState<GeofencesScreen> {
  final _nameController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _radiusController = TextEditingController();
  final _pointLatController = TextEditingController();
  final _pointLonController = TextEditingController();
  final List<_GeoPoint> _polygonPoints = [];
  final MapController _mapController = MapController();
  final LatLng _mapCenter = const LatLng(-23.55052, -46.633308);
  String _shapeMode = 'circle';
  bool _saving = false;
  int? _deletingId;

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _radiusController.dispose();
    _pointLatController.dispose();
    _pointLonController.dispose();
    super.dispose();
  }

  void _addPolygonPoint() {
    final lat = double.tryParse(_pointLatController.text.replaceAll(',', '.'));
    final lon = double.tryParse(_pointLonController.text.replaceAll(',', '.'));

    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe latitude e longitude validas.')),
      );
      return;
    }

    setState(() {
      _polygonPoints.add(_GeoPoint(lat: lat, lon: lon));
      _pointLatController.clear();
      _pointLonController.clear();
    });
    _mapController.move(LatLng(lat, lon), _mapController.camera.zoom);
  }

  void _onMapTap(TapPosition _, LatLng latLng) {
    if (_shapeMode == 'polygon') {
      setState(() {
        _polygonPoints
            .add(_GeoPoint(lat: latLng.latitude, lon: latLng.longitude));
      });
      return;
    }

    setState(() {
      _latController.text = latLng.latitude.toStringAsFixed(6);
      _lonController.text = latLng.longitude.toStringAsFixed(6);
      if (_radiusController.text.trim().isEmpty) {
        _radiusController.text = '200';
      }
    });
  }

  void _undoLastPoint() {
    if (_polygonPoints.isEmpty) return;
    setState(() {
      _polygonPoints.removeLast();
    });
  }

  Widget _buildGeofenceMapEditor() {
    final circleLat = double.tryParse(_latController.text.replaceAll(',', '.'));
    final circleLon = double.tryParse(_lonController.text.replaceAll(',', '.'));
    final circleRadius =
        double.tryParse(_radiusController.text.replaceAll(',', '.'));

    final polygonLatLng =
        _polygonPoints.map((p) => LatLng(p.lat, p.lon)).toList(growable: false);

    final center = _shapeMode == 'polygon'
        ? (polygonLatLng.isNotEmpty ? polygonLatLng.last : _mapCenter)
        : (circleLat != null && circleLon != null
            ? LatLng(circleLat, circleLon)
            : _mapCenter);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: const Color(0xFFE7EEF8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: const Color(0xFFFFFFFF),
              child: Row(
                children: [
                  const Icon(Icons.edit_location_alt_outlined,
                      color: Color(0xFF526684), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _shapeMode == 'polygon'
                          ? 'Clique no mapa para adicionar os pontos do poligono'
                          : 'Clique no mapa para definir o centro da cerca',
                      style: const TextStyle(
                          color: Color(0xFF526684), fontSize: 12),
                    ),
                  ),
                  if (_shapeMode == 'polygon') ...[
                    IconButton(
                      tooltip: 'Desfazer ultimo ponto',
                      visualDensity: VisualDensity.compact,
                      onPressed: _polygonPoints.isEmpty ? null : _undoLastPoint,
                      icon: const Icon(Icons.undo_rounded,
                          color: Color(0xFF526684)),
                    ),
                    IconButton(
                      tooltip: 'Limpar todos os pontos',
                      visualDensity: VisualDensity.compact,
                      onPressed: _polygonPoints.isEmpty
                          ? null
                          : () {
                              setState(() {
                                _polygonPoints.clear();
                              });
                            },
                      icon: const Icon(Icons.delete_sweep_rounded,
                          color: Color(0xFF526684)),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              height: 320,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 13,
                  minZoom: MapConfig.minZoom,
                  maxZoom: MapConfig.maxZoom,
                  onTap: _onMapTap,
                ),
                children: [
                  TileLayer(
                    urlTemplate: MapConfig.openStreetMapTileUrl,
                    userAgentPackageName: 'com.soutracking.app',
                  ),
                  if (_shapeMode == 'polygon' && polygonLatLng.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: polygonLatLng,
                          strokeWidth: 3,
                          color: Colors.lightBlueAccent,
                        ),
                      ],
                    ),
                  if (_shapeMode == 'polygon' && polygonLatLng.length >= 3)
                    PolygonLayer(
                      polygons: [
                        Polygon(
                          points: polygonLatLng,
                          borderColor: Colors.lightBlueAccent,
                          borderStrokeWidth: 2,
                          color: Colors.lightBlueAccent.withValues(alpha: 0.25),
                        ),
                      ],
                    ),
                  if (_shapeMode == 'polygon' && polygonLatLng.isNotEmpty)
                    MarkerLayer(
                      markers: [
                        for (var i = 0; i < polygonLatLng.length; i++)
                          Marker(
                            point: polygonLatLng[i],
                            width: 26,
                            height: 26,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.lightBlueAccent,
                                  width: 2,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  if (_shapeMode == 'circle' &&
                      circleLat != null &&
                      circleLon != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: LatLng(circleLat, circleLon),
                          radius: (circleRadius ?? 200) / 4,
                          borderColor: Colors.lightBlueAccent,
                          borderStrokeWidth: 2,
                          color: Colors.lightBlueAccent.withValues(alpha: 0.22),
                          useRadiusInMeter: true,
                        ),
                      ],
                    ),
                  if (_shapeMode == 'circle' &&
                      circleLat != null &&
                      circleLon != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(circleLat, circleLon),
                          width: 32,
                          height: 32,
                          child: const Icon(
                            Icons.place_rounded,
                            color: Colors.redAccent,
                            size: 30,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createGeofence() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome da cerca e obrigatorio.')),
      );
      return;
    }

    late final String area;
    if (_shapeMode == 'polygon') {
      if (_polygonPoints.length < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Adicione no minimo 3 pontos para o poligono.'),
          ),
        );
        return;
      }
      final points = [..._polygonPoints, _polygonPoints.first]
          .map((p) => '${p.lat} ${p.lon}')
          .join(', ');
      area = 'POLYGON (($points))';
    } else {
      final lat = double.tryParse(_latController.text.replaceAll(',', '.'));
      final lon = double.tryParse(_lonController.text.replaceAll(',', '.'));
      final radius =
          double.tryParse(_radiusController.text.replaceAll(',', '.'));

      if (lat == null || lon == null || radius == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nome, latitude, longitude e raio sao obrigatorios.'),
          ),
        );
        return;
      }
      area = 'CIRCLE ($lat $lon, $radius)';
    }

    setState(() => _saving = true);
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);

    try {
      await client.createEntity(
        path: '/geofences',
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {'name': name, 'area': area},
      );
      ref.invalidate(geofencesProvider);
      _nameController.clear();
      _latController.clear();
      _lonController.clear();
      _radiusController.clear();
      _pointLatController.clear();
      _pointLonController.clear();
      _polygonPoints.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cerca criada com sucesso.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Falha ao criar cerca: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteGeofence(Map<String, dynamic> fence) async {
    final id = fence['id'];
    if (id is! int) return;
    final name = '${fence['name'] ?? 'Cerca #$id'}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir cerca'),
        content: Text('Excluir "$name" do Traccar real?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deletingId = id);
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    try {
      await client.deleteEntity(
        path: '/geofences/$id',
        cookie: session.cookie,
        authHeader: session.authHeader,
      );
      ref.invalidate(geofencesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cerca excluída.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao excluir cerca: $error')),
      );
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final geofencesAsync = ref.watch(geofencesProvider);

    final list = geofencesAsync.when(
      data: (geofences) {
        if (geofences.isEmpty) {
          return const Center(child: Text('Nenhuma cerca encontrada'));
        }
        return ListView.separated(
          itemCount: geofences.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final fence = geofences[index];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Theme.of(context).colorScheme.outline),
              ),
              child: Row(
                children: [
                  const Icon(Icons.fence_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${fence['name'] ?? 'Cerca'}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (fence['area'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${fence['area']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF60718D),
                                    ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Excluir cerca',
                    onPressed: _deletingId == fence['id']
                        ? null
                        : () => _deleteGeofence(fence),
                    icon: _deletingId == fence['id']
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFEF4444),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
      error: (error, _) => Center(child: Text('Erro: $error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cercas', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _shapeMode,
          decoration: const InputDecoration(labelText: 'Tipo de cerca'),
          items: const [
            DropdownMenuItem(value: 'circle', child: Text('Circular')),
            DropdownMenuItem(value: 'polygon', child: Text('Poligono')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _shapeMode = value;
            });
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Nome da cerca'),
        ),
        const SizedBox(height: 12),
        if (_shapeMode == 'circle') ...[
          TextField(
            controller: _latController,
            decoration: const InputDecoration(labelText: 'Latitude'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lonController,
            decoration: const InputDecoration(labelText: 'Longitude'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _radiusController,
            decoration: const InputDecoration(labelText: 'Raio (metros)'),
            keyboardType: TextInputType.number,
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pointLatController,
                  decoration: const InputDecoration(labelText: 'Lat do ponto'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _pointLonController,
                  decoration: const InputDecoration(labelText: 'Lon do ponto'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _addPolygonPoint,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Adicionar ponto'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _polygonPoints.isEmpty
                    ? null
                    : () {
                        setState(() {
                          _polygonPoints.clear();
                        });
                      },
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Limpar pontos'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_polygonPoints.isEmpty)
            const Text(
              'Adicione os pontos na ordem do contorno da cerca.',
              style: TextStyle(color: Color(0xFF60718D)),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDDE5F0)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _polygonPoints.length,
                separatorBuilder: (_, __) => const Divider(height: 10),
                itemBuilder: (context, index) {
                  final p = _polygonPoints[index];
                  return Row(
                    children: [
                      Text(
                        '${index + 1}. ${p.lat.toStringAsFixed(6)}, ${p.lon.toStringAsFixed(6)}',
                        style: const TextStyle(color: Color(0xFF1F2A44)),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Remover ponto',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.close,
                          color: Color(0xFF60718D),
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() {
                            _polygonPoints.removeAt(index);
                          });
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _saving ? null : _createGeofence,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _shapeMode == 'polygon'
                      ? 'Criar cerca poligonal'
                      : 'Criar cerca',
                ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 380,
                margin: const EdgeInsets.only(left: 16, right: 20, top: 24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF183153).withValues(alpha: 0.12),
                        blurRadius: 14,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SingleChildScrollView(child: form),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24, right: 16),
                  child: Column(
                    children: [
                      _buildGeofenceMapEditor(),
                      const SizedBox(height: 16),
                      Expanded(child: list),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
        return ListView(
          children: [
            form,
            const SizedBox(height: 20),
            SizedBox(height: 320, child: _buildGeofenceMapEditor()),
            const SizedBox(height: 20),
            SizedBox(height: 420, child: list),
          ],
        );
      },
    );
  }
}

class _GeoPoint {
  const _GeoPoint({required this.lat, required this.lon});

  final double lat;
  final double lon;
}
