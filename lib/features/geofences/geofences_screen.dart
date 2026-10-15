import 'package:flutter/material.dart';
import '../../ui/module_scaffold.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/map_config.dart';
import '../../state/session_state.dart';
import '../reports/services/report_export_downloader_stub.dart'
    if (dart.library.html) '../reports/services/report_export_downloader_web.dart'
    as downloader;

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
  VoidCallback? _refreshEditor;
  int? _selectedFenceId;
  int? _editingFenceId;
  int? _togglingId;

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
    _refreshEditor?.call();
  }

  void _onMapTap(TapPosition _, LatLng latLng) {
    if (_shapeMode == 'polygon') {
      setState(() {
        _polygonPoints
            .add(_GeoPoint(lat: latLng.latitude, lon: latLng.longitude));
      });
      _refreshEditor?.call();
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
    _refreshEditor?.call();
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

  // O Traccar nao tem um campo nativo "enabled"/"active" pra geofence (isso
  // existe pra device, nao pra geofence) — por isso o status usava campos
  // que nunca vinham preenchidos e sempre caia no default "Ativa". Guardamos
  // esse estado em attributes.disabled, que e um mapa livre em toda entidade
  // do Traccar.
  bool _geofenceDisabled(Map<String, dynamic> fence) {
    final attributes = fence['attributes'];
    if (attributes is Map) {
      return attributes['disabled'] == true;
    }
    return false;
  }

  String _geofenceStatus(Map<String, dynamic> fence) {
    return _geofenceDisabled(fence) ? 'Inativa' : 'Ativa';
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<void> _exportGeofencesCsv(List<Map<String, dynamic>> geofences) async {
    if (geofences.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma cerca para exportar.')),
      );
      return;
    }
    final rows = <List<String>>[
      ['Nome', 'Tipo', 'Status', 'Área/raio', 'Descrição bruta'],
      for (final fence in geofences)
        [
          '${fence['name'] ?? ''}',
          _geofenceType(fence),
          _geofenceStatus(fence),
          _geofenceAreaLabel(fence),
          '${fence['area'] ?? ''}',
        ],
    ];
    final csv = rows.map((row) => row.map(_csvEscape).join(',')).join('\r\n');
    final timestamp = DateTime.now();
    final fileName = 'cercas_'
        '${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}'
        '${timestamp.day.toString().padLeft(2, '0')}_'
        '${timestamp.hour.toString().padLeft(2, '0')}'
        '${timestamp.minute.toString().padLeft(2, '0')}.csv';
    try {
      await downloader.downloadTextFile(
        fileName: fileName,
        mimeType: 'text/csv;charset=utf-8',
        content: csv,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV exportado com sucesso.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Falha ao gerar download. Verifique o navegador e tente novamente.',
          ),
        ),
      );
    }
  }

  Future<void> _toggleGeofenceEnabled(Map<String, dynamic> fence) async {
    final id = fence['id'];
    if (id is! int) return;
    final currentlyDisabled = _geofenceDisabled(fence);
    final attributes = Map<String, dynamic>.from(
      (fence['attributes'] as Map?)?.cast<String, dynamic>() ?? {},
    );
    attributes['disabled'] = !currentlyDisabled;

    setState(() => _togglingId = id);
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);

    try {
      await client.updateEntityById(
        path: '/geofences',
        id: id,
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'id': id,
          'name': fence['name'],
          'area': fence['area'],
          'attributes': attributes,
        },
      );
      ref.invalidate(geofencesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentlyDisabled ? 'Cerca ativada.' : 'Cerca desativada.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao atualizar status: $error')),
      );
    } finally {
      if (mounted) setState(() => _togglingId = null);
    }
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
            insetPadding: const EdgeInsets.all(24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: SizedBox(
                width: 1104,
                height: 580,
                child: StatefulBuilder(builder: (context, setModal) {
                  _refreshEditor = () => setModal(() {});
                  return AnimatedBuilder(
                      animation: Listenable.merge([
                        _nameController,
                        _latController,
                        _lonController,
                        _radiusController
                      ]),
                      builder: (context, _) => ModuleScaffold(
                              title: _editingFenceId == null
                                  ? 'Adicionar cerca'
                                  : 'Editar cerca',
                              navigation: _buildEditorForm(),
                              content: _buildGeofenceMapEditor(),
                              detail: ModuleCard(
                                  title: 'Resumo da cerca',
                                  child: Column(children: [
                                    ModuleDetailRow(
                                        'Nome',
                                        _nameController.text.trim().isEmpty
                                            ? 'Não informado'
                                            : _nameController.text.trim()),
                                    ModuleDetailRow(
                                        'Tipo',
                                        _shapeMode == 'circle'
                                            ? 'Circular'
                                            : 'Poligonal'),
                                    if (_shapeMode == 'circle')
                                      ModuleDetailRow(
                                          'Raio',
                                          _radiusController.text.trim().isEmpty
                                              ? 'Não informado'
                                              : '${_radiusController.text} m'),
                                    if (_shapeMode == 'polygon')
                                      ModuleDetailRow(
                                          'Pontos', '${_polygonPoints.length}')
                                  ])),
                              actions: [
                                OutlinedButton(
                                    onPressed: _saving
                                        ? null
                                        : () =>
                                            Navigator.of(dialogContext).pop(),
                                    child: const Text('Cancelar')),
                                FilledButton.icon(
                                    onPressed: _saving ? null : _saveGeofence,
                                    icon: const Icon(Icons.save_outlined,
                                        size: 16),
                                    label: Text(_saving
                                        ? 'Salvando...'
                                        : _editingFenceId == null
                                            ? 'Salvar cerca'
                                            : 'Atualizar cerca'))
                              ]));
                })));
      },
    );
    _refreshEditor = null;
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
            _refreshEditor?.call();
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
                        setState(() => _polygonPoints.clear());
                        _refreshEditor?.call();
                      },
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

    final selected =
        filtered.where((f) => f['id'] == _selectedFenceId).firstOrNull;
    return ModuleScaffold(
      title: 'Cercas eletrônicas',
      subtitle: 'Gerencie as áreas de segurança dos seus equipamentos.',
      navigation:
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const ModuleSectionLabel('Grupos e filtros'),
        _SimpleFilterDropdown(
            label: 'Grupo',
            value: _groupFilter,
            options: const ['Todos os grupos'],
            onChanged: (v) => setState(() => _groupFilter = v)),
        const SizedBox(height: 14),
        _SimpleFilterDropdown(
            label: 'Tipo',
            value: _typeFilter,
            options: const ['Todos os tipos', 'Circular', 'Poligonal'],
            onChanged: (v) => setState(() => _typeFilter = v)),
        const SizedBox(height: 14),
        _SimpleFilterDropdown(
            label: 'Status',
            value: _statusFilter,
            options: const ['Todos os status', 'Ativa', 'Inativa'],
            onChanged: (v) => setState(() => _statusFilter = v)),
      ]),
      content:
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
                hintText: 'Buscar cerca...',
                prefixIcon: Icon(Icons.search_rounded))),
        const SizedBox(height: 14),
        const ModuleSectionLabel('Cercas cadastradas'),
        if (geofencesAsync.isLoading) const LinearProgressIndicator(),
        if (geofencesAsync.hasError)
          const ModuleEmpty('Não foi possível carregar as cercas',
              'Tente novamente em instantes.')
        else if (filtered.isEmpty)
          const ModuleEmpty('Nenhuma cerca cadastrada',
              'Adicione uma cerca para acompanhar uma área de segurança.',
              icon: Icons.shield_outlined)
        else
          for (final fence in filtered)
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ModuleListItem(
                  title: '${fence['name'] ?? 'Sem nome'}',
                  subtitle:
                      '${_geofenceType(fence)} · ${_geofenceAreaLabel(fence)}',
                  icon: Icons.shield_outlined,
                  selected: selected?['id'] == fence['id'],
                  onTap: () =>
                      setState(() => _selectedFenceId = fence['id'] as int),
                  trailing: ModuleStatusChip(_geofenceStatus(fence),
                      tone: _geofenceDisabled(fence)
                          ? ModuleTone.neutral
                          : ModuleTone.success)),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                IconButton(
                    tooltip: 'Editar cerca',
                    onPressed: () => _openCreateEditorDialog(existing: fence),
                    icon: const Icon(Icons.edit_outlined, size: 17)),
                IconButton(
                    tooltip: 'Excluir cerca',
                    onPressed: _deletingId == fence['id']
                        ? null
                        : () => _deleteGeofence(fence),
                    icon: const Icon(Icons.delete_outline_rounded, size: 17)),
                Switch(
                    value: !_geofenceDisabled(fence),
                    onChanged: _togglingId == fence['id']
                        ? null
                        : (_) => _toggleGeofenceEnabled(fence))
              ]),
            ]),
      ]),
      detail: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const ModuleSectionLabel('Área da cerca'),
        if (selected == null)
          const ModuleCard(
              title: 'Selecione uma cerca',
              child: ModuleEmpty('Nenhuma cerca selecionada',
                  'Selecione uma área para consultar seus limites.',
                  icon: Icons.place_rounded))
        else ...[
          SizedBox(
              height: 180,
              child: GeofenceAreaPreview(area: '${selected['area'] ?? ''}')),
          const SizedBox(height: 12),
          ModuleCard(
              title: '${selected['name'] ?? 'Cerca'}',
              child: Column(children: [
                ModuleDetailRow('Tipo', _geofenceType(selected)),
                ModuleDetailRow('Status', _geofenceStatus(selected)),
                ModuleDetailRow('Área', _geofenceAreaLabel(selected))
              ]))
        ],
        ModuleCard(
            title: 'Resumo',
            child: Column(children: [
              ModuleDetailRow('Cercas', '${geofences.length}'),
              ModuleDetailRow('Ativas', '$activeCount')
            ])),
      ]),
      actions: [
        OutlinedButton.icon(
            onPressed: () => _exportGeofencesCsv(filtered),
            icon: const Icon(Icons.file_download_outlined, size: 16),
            label: const Text('Exportar')),
        FilledButton.icon(
            onPressed: _saving ? null : _openCreateEditorDialog,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Adicionar cerca'))
      ],
      footerLabel: '${filtered.length} cercas exibidas',
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

class _GeoPoint {
  const _GeoPoint({required this.lat, required this.lon});

  final double lat;
  final double lon;
}

/// Read-only rendering of the geometry already stored with the selected area.
class GeofenceAreaPreview extends StatelessWidget {
  const GeofenceAreaPreview({super.key, required this.area});
  final String area;
  @override
  Widget build(BuildContext context) {
    final circle = RegExp(
            r'CIRCLE\s*\(\s*([\-0-9.]+)\s+([\-0-9.]+)\s*,\s*([0-9.]+)\s*\)',
            caseSensitive: false)
        .firstMatch(area);
    final polygon =
        RegExp(r'POLYGON\s*\(\(\s*(.+?)\s*\)\)', caseSensitive: false)
            .firstMatch(area);
    final points = <LatLng>[];
    double? radius;
    void add(String? lat, String? lon) {
      final a = double.tryParse(lat ?? ''), b = double.tryParse(lon ?? '');
      if (a != null &&
          b != null &&
          a.isFinite &&
          b.isFinite &&
          a.abs() <= 90 &&
          b.abs() <= 180) points.add(LatLng(a, b));
    }

    if (circle != null) {
      add(circle.group(1), circle.group(2));
      radius = double.tryParse(circle.group(3) ?? '');
    }
    if (polygon != null) {
      for (final pair in polygon.group(1)!.split(',')) {
        final values = pair.trim().split(RegExp(r'\s+'));
        if (values.length == 2) add(values[0], values[1]);
      }
    }
    if (points.isEmpty)
      return const ModuleEmpty(
          'Área indisponível', 'Não há geometria válida para esta cerca.');
    return ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: FlutterMap(
            key: ValueKey(area),
            options: MapOptions(
                initialCenter: points.first,
                initialZoom: 13,
                minZoom: MapConfig.minZoom,
                maxZoom: MapConfig.maxZoom),
            children: [
              TileLayer(
                  urlTemplate: MapConfig.openStreetMapTileUrl,
                  userAgentPackageName: 'com.soutracking.app'),
              if (circle != null &&
                  radius != null &&
                  radius.isFinite &&
                  radius > 0)
                CircleLayer(circles: [
                  CircleMarker(
                      point: points.first,
                      radius: radius,
                      useRadiusInMeter: true,
                      color: const Color(0x33176EEB),
                      borderColor: const Color(0xFF176EEB),
                      borderStrokeWidth: 2)
                ]),
              if (polygon != null && points.length >= 3)
                PolygonLayer(polygons: [
                  Polygon(
                      points: points,
                      color: const Color(0x33176EEB),
                      borderColor: const Color(0xFF176EEB),
                      borderStrokeWidth: 2)
                ]),
              const RichAttributionWidget(attributions: [
                TextSourceAttribution('OpenStreetMap contributors')
              ]),
            ]));
  }
}
