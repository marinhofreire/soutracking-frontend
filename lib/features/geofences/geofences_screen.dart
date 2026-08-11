import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final _searchController = TextEditingController();

  final List<_GeoPoint> _polygonPoints = [];
  final MapController _mapController = MapController();
  final LatLng _mapCenter = const LatLng(-23.55052, -46.633308);

  String _shapeMode = 'circle';
  String _typeFilter = 'Todos os tipos';
  String _statusFilter = 'Todos os status';
  String _groupFilter = 'Todos os grupos';
  bool _saving = false;
  int? _deletingId;
  int? _editingFenceId;

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _radiusController.dispose();
    _pointLatController.dispose();
    _pointLonController.dispose();
    _searchController.dispose();
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
    setState(() => _polygonPoints.removeLast());
  }

  Widget _buildGeofenceMapEditor() {
    final circleLat = double.tryParse(_latController.text.replaceAll(',', '.'));
    final circleLon = double.tryParse(_lonController.text.replaceAll(',', '.'));
    final circleRadius =
        double.tryParse(_radiusController.text.replaceAll(',', '.'));

    final polygonLatLng = _polygonPoints
        .map((point) => LatLng(point.lat, point.lon))
        .toList(growable: false);

    final center = _shapeMode == 'polygon'
        ? (polygonLatLng.isNotEmpty ? polygonLatLng.last : _mapCenter)
        : (circleLat != null && circleLon != null
            ? LatLng(circleLat, circleLon)
            : _mapCenter);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
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
                      color: Color(0xFF5F738F), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _shapeMode == 'polygon'
                          ? 'Clique no mapa para adicionar pontos do poligono'
                          : 'Clique no mapa para definir o centro da cerca',
                      style: const TextStyle(
                          color: Color(0xFF5F738F), fontSize: 12),
                    ),
                  ),
                  if (_shapeMode == 'polygon')
                    IconButton(
                      tooltip: 'Desfazer ultimo ponto',
                      visualDensity: VisualDensity.compact,
                      onPressed: _polygonPoints.isEmpty ? null : _undoLastPoint,
                      icon: const Icon(Icons.undo_rounded,
                          color: Color(0xFF5F738F)),
                    ),
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
                          color: const Color(0xFF176EEB),
                        ),
                      ],
                    ),
                  if (_shapeMode == 'polygon' && polygonLatLng.length >= 3)
                    PolygonLayer(
                      polygons: [
                        Polygon(
                          points: polygonLatLng,
                          borderColor: const Color(0xFF176EEB),
                          borderStrokeWidth: 2,
                          color: const Color(0xFF176EEB).withValues(alpha: 0.2),
                        ),
                      ],
                    ),
                  if (_shapeMode == 'polygon' && polygonLatLng.isNotEmpty)
                    MarkerLayer(
                      markers: [
                        for (var i = 0; i < polygonLatLng.length; i++)
                          Marker(
                            point: polygonLatLng[i],
                            width: 24,
                            height: 24,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: const Color(0xFF176EEB), width: 2),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF25344A),
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
                          borderColor: const Color(0xFF176EEB),
                          borderStrokeWidth: 2,
                          color:
                              const Color(0xFF176EEB).withValues(alpha: 0.18),
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
                          width: 30,
                          height: 30,
                          child: const Icon(Icons.place_rounded,
                              color: Color(0xFFE74B4B), size: 28),
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

  // Preenche o editor com os dados de uma cerca existente (modo edicao).
  // Faz o caminho inverso do que _saveGeofence monta ao criar: le a string
  // "area" (CIRCLE (...) ou POLYGON ((...))) de volta pros campos do form.
  void _prefillForEdit(Map<String, dynamic> fence) {
    final id = fence['id'];
    if (id is! int) return;

    final area = '${fence['area'] ?? ''}'.trim();
    final circleMatch = RegExp(
      r'CIRCLE\s*\(\s*([\-0-9.]+)\s+([\-0-9.]+)\s*,\s*([0-9.]+)\s*\)',
      caseSensitive: false,
    ).firstMatch(area);
    final polygonMatch = RegExp(
      r'POLYGON\s*\(\(\s*(.+?)\s*\)\)',
      caseSensitive: false,
    ).firstMatch(area);

    setState(() {
      _editingFenceId = id;
      _nameController.text = '${fence['name'] ?? ''}';
      _polygonPoints.clear();
      _latController.clear();
      _lonController.clear();
      _radiusController.clear();

      if (polygonMatch != null) {
        _shapeMode = 'polygon';
        final rawPoints = polygonMatch.group(1)!.split(',');
        final parsed = rawPoints
            .map((pair) => pair.trim().split(RegExp(r'\s+')))
            .where((parts) => parts.length == 2)
            .map((parts) => _GeoPoint(
                  lat: double.tryParse(parts[0]) ?? 0,
                  lon: double.tryParse(parts[1]) ?? 0,
                ))
            .toList();
        // O ultimo ponto fecha o poligono repetindo o primeiro — tira pra
        // nao duplicar quando _saveGeofence remontar a string.
        if (parsed.length > 1 &&
            parsed.first.lat == parsed.last.lat &&
            parsed.first.lon == parsed.last.lon) {
          parsed.removeLast();
        }
        _polygonPoints.addAll(parsed);
      } else if (circleMatch != null) {
        _shapeMode = 'circle';
        _latController.text = circleMatch.group(1) ?? '';
        _lonController.text = circleMatch.group(2) ?? '';
        _radiusController.text = circleMatch.group(3) ?? '';
      } else {
        _shapeMode = 'circle';
      }
    });
  }

  void _resetEditorForm() {
    _editingFenceId = null;
    _nameController.clear();
    _latController.clear();
    _lonController.clear();
    _radiusController.clear();
    _pointLatController.clear();
    _pointLonController.clear();
    _polygonPoints.clear();
    _shapeMode = 'circle';
  }

  Future<void> _saveGeofence() async {
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
              content: Text('Adicione no minimo 3 pontos para o poligono.')),
        );
        return;
      }
      final points = [..._polygonPoints, _polygonPoints.first]
          .map((point) => '${point.lat} ${point.lon}')
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
              content: Text('Latitude, longitude e raio sao obrigatorios.')),
        );
        return;
      }
      area = 'CIRCLE ($lat $lon, $radius)';
    }

    setState(() => _saving = true);
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    final editingId = _editingFenceId;

    try {
      if (editingId != null) {
        await client.updateEntityById(
          path: '/geofences',
          id: editingId,
          cookie: session.cookie,
          authHeader: session.authHeader,
          body: {'id': editingId, 'name': name, 'area': area},
        );
      } else {
        await client.createEntity(
          path: '/geofences',
          cookie: session.cookie,
          authHeader: session.authHeader,
          body: {'name': name, 'area': area},
        );
      }
      ref.invalidate(geofencesProvider);
      _resetEditorForm();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            editingId != null
                ? 'Cerca atualizada com sucesso.'
                : 'Cerca criada com sucesso.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            editingId != null
                ? 'Falha ao atualizar cerca: $error'
                : 'Falha ao criar cerca: $error',
          ),
        ),
      );
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
        content: Text('Excluir "$name" do servidor de rastreamento?'),
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
        const SnackBar(content: Text('Cerca excluida.')),
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

  String _geofenceType(Map<String, dynamic> fence) {
    final area = '${fence['area'] ?? ''}'.toUpperCase();
    if (area.contains('POLYGON')) return 'Poligonal';
    if (area.contains('CIRCLE')) return 'Circular';
    return 'Não informado';
  }

  String _geofenceAreaLabel(Map<String, dynamic> fence) {
    final area = '${fence['area'] ?? ''}'.trim();
    if (area.isEmpty) return '-';

    final match = RegExp(r'CIRCLE\s*\([^,]+,\s*([0-9.]+)\)')
        .firstMatch(area.toUpperCase());
    if (match != null) {
      final radius = double.tryParse(match.group(1) ?? '');
      if (radius != null) {
        return '${(radius / 1000).toStringAsFixed(1)} km';
      }
    }
    return '-';
  }

  String _geofenceStatus(Map<String, dynamic> fence) {
    final enabledRaw =
        fence['enabled'] ?? fence['active'] ?? fence['status'] ?? true;
    if (enabledRaw is bool) {
      return enabledRaw ? 'Ativa' : 'Inativa';
    }
    final text = enabledRaw.toString().trim().toLowerCase();
    if (text == 'false' || text == '0' || text == 'inactive') {
      return 'Inativa';
    }
    return 'Ativa';
  }

  List<Map<String, dynamic>> _applyFilters(
      List<Map<String, dynamic>> geofences) {
    final query = _searchController.text.trim().toLowerCase();
    return geofences.where((fence) {
      final name = '${fence['name'] ?? ''}'.toLowerCase();
      final type = _geofenceType(fence);
      final status = _geofenceStatus(fence);
      final area = _geofenceAreaLabel(fence).toLowerCase();

      if (query.isNotEmpty &&
          !name.contains(query) &&
          !type.toLowerCase().contains(query) &&
          !area.contains(query)) {
        return false;
      }

      if (_typeFilter != 'Todos os tipos') {
        if (_typeFilter == 'Circular' && type != 'Circular') return false;
        if (_typeFilter == 'Poligonal' && type != 'Poligonal') return false;
      }

      if (_statusFilter != 'Todos os status' && status != _statusFilter) {
        return false;
      }

      return true;
    }).toList(growable: false);
  }

  Future<void> _openCreateEditorDialog({Map<String, dynamic>? existing}) async {
    if (existing != null) {
      _prefillForEdit(existing);
    } else {
      setState(_resetEditorForm);
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120, maxHeight: 720),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 940;
                  if (!wide) {
                    return Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: _buildEditorForm(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 300,
                          child: _buildGeofenceMapEditor(),
                        ),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 360,
                        child: SingleChildScrollView(child: _buildEditorForm()),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _buildGeofenceMapEditor()),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
    // Fechou sem salvar (tocou fora, voltou) — nao deixa dado de edicao
    // vazando pro proximo "Adicionar cerca".
    if (mounted && _editingFenceId != null) {
      setState(_resetEditorForm);
    }
  }

  Widget _buildEditorForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _editingFenceId != null ? 'Editar cerca' : 'Editor de cerca',
                style: const TextStyle(
                  color: Color(0xFF25344A),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _saving ? null : _saveGeofence,
              icon: _saving
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(_saving
                  ? 'Salvando...'
                  : (_editingFenceId != null
                      ? 'Atualizar cerca'
                      : 'Salvar cerca')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _shapeMode,
          decoration: const InputDecoration(labelText: 'Tipo de cerca'),
          items: const [
            DropdownMenuItem(value: 'circle', child: Text('Circular')),
            DropdownMenuItem(value: 'polygon', child: Text('Poligonal')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _shapeMode = value);
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
                  decoration:
                      const InputDecoration(labelText: 'Latitude do ponto'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _pointLonController,
                  decoration:
                      const InputDecoration(labelText: 'Longitude do ponto'),
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
                    : () => setState(() => _polygonPoints.clear()),
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Limpar pontos'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final geofencesAsync = ref.watch(geofencesProvider);
    final geofences =
        geofencesAsync.valueOrNull ?? const <Map<String, dynamic>>[];
    final filtered = _applyFilters(geofences);
    final activeCount =
        geofences.where((fence) => _geofenceStatus(fence) == 'Ativa').length;
    final eventsToday = geofences.length;
    final violationsToday =
        geofences.where((fence) => _geofenceType(fence) == 'Poligonal').length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cercas Eletrônicas',
                      style: TextStyle(
                        color: Color(0xFF1F2A44),
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Gerencie áreas de segurança e monitore violações em tempo real.',
                      style: TextStyle(color: Color(0xFF5A6B84), fontSize: 13),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const Text('Exportar'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _saving ? null : _openCreateEditorDialog,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Adicionar cerca'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD6E0EE)),
                  ),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _SimpleFilterDropdown(
                        label: 'Tipo',
                        value: _typeFilter,
                        options: const [
                          'Todos os tipos',
                          'Circular',
                          'Poligonal'
                        ],
                        onChanged: (value) =>
                            setState(() => _typeFilter = value),
                      ),
                      _SimpleFilterDropdown(
                        label: 'Status',
                        value: _statusFilter,
                        options: const ['Todos os status', 'Ativa', 'Inativa'],
                        onChanged: (value) =>
                            setState(() => _statusFilter = value),
                      ),
                      _SimpleFilterDropdown(
                        label: 'Grupo',
                        value: _groupFilter,
                        options: const ['Todos os grupos'],
                        onChanged: (value) =>
                            setState(() => _groupFilter = value),
                      ),
                      SizedBox(
                        width: 230,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Buscar cerca...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFFF8FBFF),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Color(0xFFD6E0EE)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Color(0xFFD6E0EE)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Color(0xFF7CB0FF)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const SizedBox(width: 250, height: 120, child: _MiniMapPreview()),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _GeofenceKpiCard(
                label: 'Cercas ativas',
                value: activeCount,
                accent: const Color(0xFF2D8CFF),
                icon: Icons.shield_outlined,
              ),
              _GeofenceKpiCard(
                label: 'Eventos hoje',
                value: eventsToday,
                accent: const Color(0xFF22A06B),
                icon: Icons.event_note_outlined,
              ),
              _GeofenceKpiCard(
                label: 'Violações hoje',
                value: violationsToday,
                accent: const Color(0xFFE74B4B),
                icon: Icons.warning_amber_rounded,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Stack(
            children: [
              _GeofenceTable(
                geofences: filtered,
                geofenceType: _geofenceType,
                geofenceAreaLabel: _geofenceAreaLabel,
                geofenceStatus: _geofenceStatus,
                deletingId: _deletingId,
                onDelete: _deleteGeofence,
                onEdit: (fence) => _openCreateEditorDialog(existing: fence),
              ),
              if (geofencesAsync.isLoading)
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: LinearProgressIndicator(
                    minHeight: 2,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SimpleFilterDropdown extends StatelessWidget {
  const _SimpleFilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = options.contains(value) ? value : options.first;
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String>(
        initialValue: selected,
        items: [
          for (final option in options)
            DropdownMenuItem<String>(
              value: option,
              child: Text(option),
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

class _GeofenceKpiCard extends StatelessWidget {
  const _GeofenceKpiCard({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
  });

  final String label;
  final int value;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E0EE)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
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
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
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

class _MiniMapPreview extends StatelessWidget {
  const _MiniMapPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E0EE)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FAFD), Color(0xFFEFF4FB)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 24,
            top: 24,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0x663B82F6),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF3B82F6), width: 2),
              ),
            ),
          ),
          Positioned(
            right: 20,
            top: 22,
            child: Transform.rotate(
              angle: 0.5,
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: const Color(0x6655C57A),
                  border: Border.all(color: const Color(0xFF2EA85F), width: 2),
                ),
              ),
            ),
          ),
          Positioned(
            right: 54,
            bottom: 14,
            child: Transform.rotate(
              angle: -0.3,
              child: Container(
                width: 58,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0x66FF8A8A),
                  border: Border.all(color: const Color(0xFFE74B4B), width: 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GeofenceTable extends StatelessWidget {
  const _GeofenceTable({
    required this.geofences,
    required this.geofenceType,
    required this.geofenceAreaLabel,
    required this.geofenceStatus,
    required this.deletingId,
    required this.onDelete,
    required this.onEdit,
  });

  final List<Map<String, dynamic>> geofences;
  final String Function(Map<String, dynamic>) geofenceType;
  final String Function(Map<String, dynamic>) geofenceAreaLabel;
  final String Function(Map<String, dynamic>) geofenceStatus;
  final int? deletingId;
  final ValueChanged<Map<String, dynamic>> onDelete;
  final ValueChanged<Map<String, dynamic>> onEdit;

  @override
  Widget build(BuildContext context) {
    if (geofences.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD6E0EE)),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Nenhuma cerca cadastrada',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF60718D),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Adicione uma cerca para monitorar áreas de segurança.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF60718D),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E0EE)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xCCF8FBFF),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFFD6E0EE).withValues(alpha: 0.9),
                ),
              ),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: _HeaderCell('Nome')),
                Expanded(flex: 2, child: _HeaderCell('Tipo')),
                Expanded(flex: 2, child: _HeaderCell('Área')),
                Expanded(flex: 2, child: _HeaderCell('Status')),
                SizedBox(width: 72),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: geofences.length,
            separatorBuilder: (_, __) => Divider(
              color: const Color(0xFFD6E0EE).withValues(alpha: 0.9),
              height: 1,
            ),
            itemBuilder: (context, index) {
              final fence = geofences[index];
              final status = geofenceStatus(fence);
              final statusColor = status == 'Ativa'
                  ? const Color(0xFF10B981)
                    : const Color(0xFF94A3B8);

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _CellText('${fence['name'] ?? 'Cerca'}'),
                      ),
                      Expanded(
                        flex: 2,
                        child: _CellText(geofenceType(fence)),
                      ),
                      Expanded(
                        flex: 2,
                        child: _CellText(geofenceAreaLabel(fence)),
                      ),
                      Expanded(
                        flex: 2,
                        child: _StatusCell(
                          label: status,
                          color: statusColor,
                        ),
                      ),
                      SizedBox(
                        width: 72,
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: 'Editar',
                              onPressed: () => onEdit(fence),
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Color(0xFF176EEB),
                                size: 16,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Excluir',
                              onPressed: deletingId == fence['id']
                                  ? null
                                  : () => onDelete(fence),
                              icon: deletingId == fence['id']
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.delete_outline,
                                      color: Color(0xFFE74B4B),
                                      size: 16,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
          ),
        ],
      ),
    );
  }
}

class _GeoPoint {
  const _GeoPoint({required this.lat, required this.lon});

  final double lat;
  final double lon;
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

class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
