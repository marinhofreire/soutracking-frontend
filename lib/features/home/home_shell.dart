import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' hide Image;
import 'dart:ui' as ui show Image;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../core/app_constants.dart';
import '../../core/display_text_formatter.dart';
import '../../core/white_label.dart';
import '../../data/bridge_client.dart';
import '../../data/models.dart';
import '../../data/openf1_client.dart';
import '../../state/session_state.dart';
import '../../widgets/dial_gauge.dart';
import '../../widgets/status_pill.dart';
import '../alerts/alerts_screen.dart';
import '../calls/calls_screen.dart';
import '../communication/zpro_communication_screen.dart';
import '../common/placeholder_screen.dart';
import '../clients/clients_screen.dart';
import '../commands/commands_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../devices/devices_screen.dart';
import '../finance/finance_screen.dart';
import '../geofences/geofences_screen.dart';
import '../history/history_screen.dart';
import '../inventory/inventory_screen.dart';
import '../login/login_screen.dart';
import '../maintenance/maintenance_screen.dart';
import '../map/map_screen.dart';
import '../mdvr/mdvr_devices_screen.dart';
import '../reports/reports_screen.dart';
import '../routes/routes_screen.dart';
import '../settings/settings_screen.dart';
import '../automations/automations_screen.dart';
import '../ia/ia_screen.dart';
import '../telemetry/sensor_presentation.dart';
import '../telemetry/telemetry_sensors_screen.dart';
import '../telemetry/tpms_screen.dart';
import '../vehicles/vehicles_screen.dart';
import 'visual_settings_controller.dart';

class _ReplayQuery {
  const _ReplayQuery({
    required this.deviceId,
    required this.from,
    required this.to,
  });

  final int deviceId;
  final DateTime from;
  final DateTime to;

  @override
  bool operator ==(Object other) {
    return other is _ReplayQuery &&
        other.deviceId == deviceId &&
        other.from == from &&
        other.to == to;
  }

  @override
  int get hashCode => Object.hash(deviceId, from, to);
}

class _ReplayPoint {
  const _ReplayPoint({
    required this.latitude,
    required this.longitude,
    required this.effectiveTime,
    required this.rawTime,
    required this.speedKph,
    required this.course,
    required this.address,
  });

  final double latitude;
  final double longitude;
  final DateTime? effectiveTime;
  final String? rawTime;
  final double? speedKph;
  final double? course;
  final String address;

  gmaps.LatLng get latLng => gmaps.LatLng(latitude, longitude);

  String get timeLabel {
    final parsed = effectiveTime;
    if (parsed == null)
      return rawTime?.trim().isNotEmpty == true ? rawTime! : '--';
    final local = parsed.isUtc ? parsed.toLocal() : parsed;
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }

  String get speedLabel {
    final value = speedKph;
    if (value == null || !value.isFinite) return '0 km/h';
    return '${value.toStringAsFixed(0)} km/h';
  }

  static _ReplayPoint? fromReportRow(Map<String, dynamic> row) {
    final latitude = _readReportDouble(
      row['latitude'] ?? row['lat'] ?? row['startLatitude'],
    );
    final longitude = _readReportDouble(
      row['longitude'] ?? row['lon'] ?? row['lng'] ?? row['startLongitude'],
    );
    if (latitude == null || longitude == null) return null;

    final rawTime = [
      row['fixTime'],
      row['deviceTime'],
      row['serverTime'],
      row['eventTime'],
    ].whereType<Object>().map((it) => it.toString().trim()).firstWhere(
          (it) => it.isNotEmpty,
          orElse: () => '',
        );
    final parsedTime = rawTime.isEmpty ? null : DateTime.tryParse(rawTime);
    final speedKnots = _readReportDouble(
      row['speed'] ?? row['speedKnots'] ?? row['maxSpeed'],
    );
    final course = _readReportDouble(
      row['course'] ?? row['heading'] ?? row['bearing'],
    );
    final address =
        (row['address'] ?? row['formattedAddress'] ?? '').toString().trim();

    return _ReplayPoint(
      latitude: latitude,
      longitude: longitude,
      effectiveTime: parsedTime,
      rawTime: rawTime.isEmpty ? null : rawTime,
      speedKph: speedKnots == null ? null : speedKnots * 1.852,
      course: course,
      address: address.isEmpty ? 'Nao informado' : address,
    );
  }
}

class _ReportRouteReplayFrame {
  const _ReportRouteReplayFrame({
    required this.point,
    required this.bearing,
  });

  final ReportRouteMapPoint? point;
  final double? bearing;
}

double? _readReportDouble(Object? raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toDouble();
  if (raw is String) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }
  return null;
}

final vehicleReplayProvider =
    FutureProvider.family<List<_ReplayPoint>, _ReplayQuery>((ref, query) async {
  final session = ref.watch(sessionProvider);
  if (!session.isAuthenticated) {
    return const <_ReplayPoint>[];
  }

  final client = ref.watch(traccarClientProvider);
  final rows = await client.getList(
    path: '/reports/route',
    cookie: session.cookie,
    authHeader: session.authHeader,
    query: {
      'deviceId': '${query.deviceId}',
      'from': query.from.toUtc().toIso8601String(),
      'to': query.to.toUtc().toIso8601String(),
    },
  );

  final points = rows
      .map(_ReplayPoint.fromReportRow)
      .whereType<_ReplayPoint>()
      .toList(growable: false);
  points.sort((a, b) {
    final at = a.effectiveTime;
    final bt = b.effectiveTime;
    if (at == null && bt == null) return 0;
    if (at == null) return -1;
    if (bt == null) return 1;
    return at.compareTo(bt);
  });
  return points;
});

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  static const Duration _replayTick = Duration(milliseconds: 80);
  static const Duration _replaySegment = Duration(milliseconds: 1400);
  // Segmentos com distância maior que isso (ex: buraco de conexão do
  // rastreador) não são animados suavemente — o marcador salta direto pro
  // próximo ponto em vez de "correr" por um trecho gigante em pouco tempo.
  static const double _replaySegmentMaxAnimatedDistanceKm = 0.6;
  static const Duration _operationalRefreshInterval = Duration(seconds: 30);
  static const Duration _positionRefreshInterval = Duration(seconds: 3);

  gmaps.GoogleMapController? _googleMapController;
  final Map<int, List<gmaps.LatLng>> _positionTrailByDeviceId = {};
  String? _lastFollowedSelectedPositionKey;
  Timer? _replayTimer;
  Timer? _operationalRefreshTimer;
  Timer? _positionRefreshTimer;
  int _selectedReplayIndex = 0;
  double _routeReplaySegmentProgress = 0;
  int _replayDebugLinesEmitted = 0;
  Duration _replayWindow = const Duration(hours: 24);
  int? _replayDeviceId;
  int? _replayQueryAnchorDeviceId;
  DateTime? _replayQueryAnchorTo;
  String? _lastFollowedReplayKey;
  String? _lastFollowedReportRouteReplayKey;
  double? _lastResolvedReportRouteBearing;
  bool _reportRouteReplay3dEnabled = true;
  String? _lastFocusedReportRouteKey;
  String? _lastReportRouteMapTypeNonce;
  int? _lastVehicleTapDeviceId;
  DateTime? _lastVehicleTapTime;
  int? _liveGaugesDeviceId;

  // Pacotes TPMS (E6) chegam bem mais raro que os pacotes de posição normais
  // (AA), então o servidor não devolve os atributos tireXXBattery/Temp/Pressure
  // em toda posição — só na posição exata em que o sensor reportou. Sem esse
  // cache local, o desenho do pneu piscaria/sumiria a cada posição comum.
  final Map<int, Map<String, dynamic>> _lastKnownTireAttributesByDevice = {};

  final bool _showHighlightsRail = false;

  bool _menuOpen = true;
  bool _sidebarHidden = false;
  bool _kpiListOpen = false;
  _KpiFilter _activeKpiFilter = _KpiFilter.online;
  _VehicleBottomTab _activeBottomTab = _VehicleBottomTab.overview;
  _VehiclePanelMode _vehiclePanelMode = _VehiclePanelMode.summary;
  TraccarDevice? _selectedVehicle;
  bool _showBottomVehiclePanel = true;
  String? _activePanelId;
  String? _activePanelTitle;
  bool _copilotPanelOpen = false;
  _VisualDiagnosis? _lastVisualDiagnosis;
  double _currentZoom = 13.0;
  gmaps.MapType _mapViewType = gmaps.MapType.hybrid;
  bool _mapTrafficEnabled = true;
  DateTime _blockSurfaceClearUntil = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _applyInitialPanelFromUrl();
  }

  @override
  void dispose() {
    _replayTimer?.cancel();
    _operationalRefreshTimer?.cancel();
    _positionRefreshTimer?.cancel();
    super.dispose();
  }

  void _applyInitialPanelFromUrl() {
    if (!kIsWeb) return;
    final requested = Uri.base.queryParameters['panel']?.trim();
    if (requested == null || requested.isEmpty) return;

    final normalized = _normalizePanelId(requested);
    final target = _operationalMenu
        .where((item) => item.id == normalized)
        .cast<_OperationalMenuItem?>()
        .firstOrNull;
    if (target == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openPanel(target);
    });
  }

  String _normalizePanelId(String raw) {
    final key = raw.trim().toLowerCase();
    switch (key) {
      case 'equipamentos':
      case 'dispositivos':
      case 'devices':
        return 'devices';
      case 'veículos':
      case 've\u00EDculos':
      case 'vehicles':
        return 'vehicles';
      case 'alertas':
      case 'alerts':
        return 'alerts';
      case 'relatórios':
      case 'relat\u00F3rios':
      case 'reports':
        return 'reports';
      case 'telemetria':
      case 'telemetry':
        return 'telemetry';
      case 'comandos':
      case 'commands':
        return 'commands';
      case 'datlog':
      case 'data-log':
      case 'logs':
        return 'logs';
      case 'cercas':
      case 'fences':
      case 'geofences':
        return 'geofences';
      case 'manutenção':
      case 'manutencao':
      case 'Manutenção':
      case 'manutenção':
      case 'maintenance':
        return 'maintenance';
      case 'comunicação':
      case 'comunica\u00E7\u00E3o':
      case 'communication':
        return 'communication';
      case 'chamados':
      case 'tickets':
      case 'calls':
        return 'tickets';
      case 'configurações':
      case 'configura\u00E7\u00F5es':
      case 'settings':
        return 'settings';
      case 'dashboard':
        return 'dashboard';
      case 'mapa':
      case 'map':
      default:
        return 'map';
    }
  }

  void _toggleCopilotPanel() {
    setState(() => _copilotPanelOpen = !_copilotPanelOpen);
  }

  void _runVisualDiagnosis(VisualSettings settings) {
    final screenName = _activePanelTitle?.trim().isNotEmpty == true
        ? _activePanelTitle!.trim()
        : 'Mapa';
    final hasCompact = settings.cardDensity == VisualCardDensity.compact;
    final highTransparency = settings.transparency == VisualTransparency.high;

    final problem = hasCompact
        ? 'Hierarquia comprimida: blocos importantes podem ficar densos demais.'
        : highTransparency
            ? 'Contraste pode oscilar em mapas claros e reduzir legibilidade.'
            : 'Distribuicao geral boa, com pequenos ganhos em destaque de status.';
    final suggestion = highTransparency
        ? 'Subir transparencia para media e manter cards confortaveis.'
        : settings.fontSize == VisualFontSize.large
            ? 'Manter fonte grande e reduzir densidade somente em tabelas.'
            : 'Aumentar contraste dos blocos criticos e reforcar a leitura dos KPIs.';

    final prompt = 'Tela: $screenName. '
        'Aplicar ajustes visuais sem alterar backend: '
        'mapa=${settings.mapMode.name}, '
        'cards=${settings.cardDensity.name}, '
        'transparencia=${settings.transparency.name}, '
        'fonte=${settings.fontSize.name}, '
        'baloes=${settings.balloonSize.name}. '
        'Priorizar legibilidade de status operacionais, reduzir ruido visual e '
        'preservar navegacao existente.';

    setState(() {
      _lastVisualDiagnosis = _VisualDiagnosis(
        screenName: screenName,
        probableIssue: problem,
        adjustmentSuggestion: suggestion,
        technicalPrompt: prompt,
      );
      _copilotPanelOpen = true;
    });
  }

  void _clearOperationalSurface({bool force = false}) {
    if (!force && DateTime.now().isBefore(_blockSurfaceClearUntil)) {
      return;
    }
    setState(() {
      if (!_sidebarHidden) _menuOpen = false;
      _kpiListOpen = false;
      _selectedVehicle = null;
      _vehiclePanelMode = _VehiclePanelMode.summary;
      _activePanelId = null;
      _activePanelTitle = null;
    });
  }

  void _toggleMenu() {
    setState(() {
      if (_sidebarHidden) {
        _sidebarHidden = false;
        _menuOpen = true;
      } else {
        _sidebarHidden = true;
      }
    });
  }

  void _toggleSidebarCompact() {
    setState(() {
      if (_sidebarHidden) {
        // Hidden → Open
        _sidebarHidden = false;
        _menuOpen = true;
      } else if (_menuOpen) {
        // Open → Collapsed
        _menuOpen = false;
      } else {
        // Collapsed → Hidden
        _sidebarHidden = true;
      }
    });
  }

  void _openKpi(_KpiFilter filter) {
    setState(() {
      ref.read(reportRouteMapSelectionProvider.notifier).state = null;
      _lastFocusedReportRouteKey = null;
      _lastFollowedReportRouteReplayKey = null;
      _routeReplaySegmentProgress = 0;
      _activeKpiFilter = filter;
      _kpiListOpen = true;
      _showBottomVehiclePanel = false;
      _replayTimer?.cancel();
      _replayTimer = null;
      _selectedVehicle = null;
      _vehiclePanelMode = _VehiclePanelMode.summary;
      _activePanelId = null;
      _activePanelTitle = null;
    });
  }

  void _clearKpiSelection() {
    setState(() {
      _kpiListOpen = false;
    });
  }

  void _openPanel(_OperationalMenuItem item) {
    if (item.id == 'map') {
      _blockSurfaceClearUntil = DateTime.now().add(
        const Duration(milliseconds: 700),
      );
      setState(() {
        ref.read(reportRouteMapSelectionProvider.notifier).state = null;
        _lastFocusedReportRouteKey = null;
        _lastFollowedReportRouteReplayKey = null;
        _routeReplaySegmentProgress = 0;
        _showBottomVehiclePanel = true;
        _activePanelId = null;
        _activePanelTitle = null;
        _replayTimer?.cancel();
        _replayTimer = null;
        _routeReplaySegmentProgress = 0;
        _sidebarHidden = false;
        _menuOpen = true;
        _kpiListOpen = false;
        _selectedVehicle = null;
        _vehiclePanelMode = _VehiclePanelMode.summary;
      });
      return;
    }

    _blockSurfaceClearUntil = DateTime.now().add(
      const Duration(milliseconds: 700),
    );
    setState(() {
      ref.read(reportRouteMapSelectionProvider.notifier).state = null;
      _lastFocusedReportRouteKey = null;
      _lastFollowedReportRouteReplayKey = null;
      _routeReplaySegmentProgress = 0;
      _showBottomVehiclePanel = false;
      _replayTimer?.cancel();
      _replayTimer = null;
      _activePanelId = item.id;
      _activePanelTitle = formatDisplayText(item.label);
      _sidebarHidden = false;
      _menuOpen = true;
      _kpiListOpen = false;
      _selectedVehicle = null;
      _vehiclePanelMode = _VehiclePanelMode.summary;
    });
  }

  void _openVehicleDetails(
    _VehicleSnapshot snapshot, {
    _VehicleBottomTab initialTab = _VehicleBottomTab.overview,
  }) {
    // Prevent accidental map tap propagation from clearing the opened panel.
    _blockSurfaceClearUntil = DateTime.now().add(
      const Duration(milliseconds: 1200),
    );
    setState(() {
      ref.read(reportRouteMapSelectionProvider.notifier).state = null;
      _lastFocusedReportRouteKey = null;
      _lastFollowedReportRouteReplayKey = null;
      _replayTimer?.cancel();
      _replayTimer = null;
      _routeReplaySegmentProgress = 0;
      _showBottomVehiclePanel = true;
      _selectedVehicle = snapshot.device;
      _activeBottomTab = initialTab;
      _selectedReplayIndex = 0;
      _replayDeviceId = snapshot.device.id;
      _vehiclePanelMode = _VehiclePanelMode.summary;
      _sidebarHidden = false;
      _kpiListOpen = false;
      _activePanelId = null;
      _activePanelTitle = null;
    });
    _focusVehicle(snapshot);
    _googleMapController?.hideMarkerInfoWindow(
      gmaps.MarkerId('vehicle-${snapshot.device.id}'),
    );
  }

  void _selectVehicleOnMap(_VehicleSnapshot snapshot) {
    // Detecta duplo clique manualmente (Marker do Google Maps só tem onTap).
    final now = DateTime.now();
    final isDoubleTap = _lastVehicleTapDeviceId == snapshot.device.id &&
        _lastVehicleTapTime != null &&
        now.difference(_lastVehicleTapTime!) < const Duration(milliseconds: 400);
    _lastVehicleTapDeviceId = snapshot.device.id;
    _lastVehicleTapTime = now;

    if (isDoubleTap) {
      setState(() {
        _liveGaugesDeviceId = snapshot.device.id;
        _selectedVehicle = snapshot.device;
      });
      _focusVehicle(snapshot);
      _googleMapController?.hideMarkerInfoWindow(
        gmaps.MarkerId('vehicle-${snapshot.device.id}'),
      );
      return;
    }

    _blockSurfaceClearUntil = DateTime.now().add(
      const Duration(milliseconds: 700),
    );
    setState(() {
      _selectedVehicle = snapshot.device;
      _showBottomVehiclePanel = false;
      _activePanelId = null;
      _activePanelTitle = null;
      _kpiListOpen = false;
      _vehiclePanelMode = _VehiclePanelMode.summary;
    });
    _focusVehicle(snapshot);
    _googleMapController?.hideMarkerInfoWindow(
      gmaps.MarkerId('vehicle-${snapshot.device.id}'),
    );
  }

  void _closeLiveGauges() {
    setState(() => _liveGaugesDeviceId = null);
  }

  double? _attrAsDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  bool? _attrAsBool(Object? value) {
    if (value == null) return null;
    if (value is bool) return value;
    final text = value.toString().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return null;
  }

  // Zoom estilo "chase cam": aproxima em baixa velocidade (detalhe de manobra),
  // afasta suavemente em velocidade alta (visão de contexto da via).
  static double _chaseCamZoomForSpeed(double? speedKmh) {
    final speed = speedKmh ?? 0;
    const zoomSlow = 18.0;
    const zoomFast = 15.5;
    const speedSlowThreshold = 30.0;
    const speedFastThreshold = 80.0;
    if (speed <= speedSlowThreshold) return zoomSlow;
    if (speed >= speedFastThreshold) return zoomFast;
    final t = (speed - speedSlowThreshold) /
        (speedFastThreshold - speedSlowThreshold);
    return zoomSlow - (zoomSlow - zoomFast) * t;
  }

  void _focusVehicle(_VehicleSnapshot snapshot) {
    final latLng = snapshot.latLngOrNull;
    if (latLng == null) return;
    _googleMapController?.animateCamera(
      gmaps.CameraUpdate.newCameraPosition(
        gmaps.CameraPosition(
          target: latLng,
          zoom: _chaseCamZoomForSpeed(snapshot.speedKmh),
          tilt: 55,
          bearing: snapshot.mapBearing,
        ),
      ),
    );
  }

  void _focusReportRoute(ReportRouteMapSelection selection) {
    final controller = _googleMapController;
    final points = selection.points;
    if (controller == null || points.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        if (points.length == 1) {
          await controller.animateCamera(
            gmaps.CameraUpdate.newLatLngZoom(
              gmaps.LatLng(points.first.latitude, points.first.longitude),
              15,
            ),
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

        await controller.animateCamera(
          gmaps.CameraUpdate.newLatLngBounds(
            gmaps.LatLngBounds(
              southwest: gmaps.LatLng(minLat, minLng),
              northeast: gmaps.LatLng(maxLat, maxLng),
            ),
            72,
          ),
        );
      } catch (_) {
        // Mantem o mapa estavel caso o provedor web rejeite o ajuste de bounds.
      }
    });
  }

  void _focusReportRouteIfNeeded(ReportRouteMapSelection? selection) {
    if (selection == null || selection.points.isEmpty) {
      _lastFocusedReportRouteKey = null;
      return;
    }
    if (_lastFocusedReportRouteKey == selection.requestKey) {
      return;
    }
    _lastFocusedReportRouteKey = selection.requestKey;
    _focusReportRoute(selection);
  }

  // Nao usar DateTime.now() direto aqui: isso gera um _ReplayQuery diferente
  // a cada rebuild (o widget reconstroi a cada frame enquanto o mapa anima),
  // e como vehicleReplayProvider e um FutureProvider.family, cada instancia
  // "nova" da query dispara uma busca de rede nova — vira um loop infinito
  // de chamadas a /api/reports/route. O "to" so avanca a cada 30s ou quando
  // o veiculo selecionado muda.
  _ReplayQuery? _buildReplayQuery(int? deviceId) {
    if (deviceId == null) {
      _replayQueryAnchorDeviceId = null;
      _replayQueryAnchorTo = null;
      return null;
    }
    final now = DateTime.now();
    final anchor = _replayQueryAnchorTo;
    if (_replayQueryAnchorDeviceId != deviceId ||
        anchor == null ||
        now.difference(anchor) > const Duration(seconds: 30)) {
      _replayQueryAnchorDeviceId = deviceId;
      _replayQueryAnchorTo = now;
    }
    final to = _replayQueryAnchorTo!;
    final from = to.subtract(_replayWindow);
    return _ReplayQuery(deviceId: deviceId, from: from, to: to);
  }

  void _setReplayWindow(Duration window) {
    _replayTimer?.cancel();
    setState(() {
      _replayWindow = window;
      _selectedReplayIndex = 0;
      _routeReplaySegmentProgress = 0;
    });
  }

  void _setReplayIndex(int next, int total) {
    if (total <= 0) return;
    final bounded = next.clamp(0, total - 1).toInt();
    setState(() {
      _selectedReplayIndex = bounded;
      _routeReplaySegmentProgress = 0;
    });
  }

  double? _normalizeBearing(double? raw) {
    if (raw == null || !raw.isFinite) return null;
    final normalized = raw % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  double? _bearingBetweenRoutePoints(
    ReportRouteMapPoint from,
    ReportRouteMapPoint to,
  ) {
    final startLat = from.latitude;
    final startLng = from.longitude;
    final endLat = to.latitude;
    final endLng = to.longitude;
    if ((startLat - endLat).abs() < 0.0000001 &&
        (startLng - endLng).abs() < 0.0000001) {
      return null;
    }

    final startLatRad = startLat * math.pi / 180.0;
    final endLatRad = endLat * math.pi / 180.0;
    final deltaLngRad = (endLng - startLng) * math.pi / 180.0;
    final y = math.sin(deltaLngRad) * math.cos(endLatRad);
    final x = math.cos(startLatRad) * math.sin(endLatRad) -
        math.sin(startLatRad) * math.cos(endLatRad) * math.cos(deltaLngRad);
    final bearingRad = math.atan2(y, x);
    return _normalizeBearing((bearingRad * 180.0 / math.pi + 360.0) % 360.0);
  }

  double? _resolveReportRouteBearing(
    List<ReportRouteMapPoint> points,
    int? index, {
    bool lockToCurrentSegment = false,
  }) {
    if (index == null ||
        points.isEmpty ||
        index < 0 ||
        index >= points.length) {
      return _lastResolvedReportRouteBearing;
    }

    final current = points[index];
    if (lockToCurrentSegment) {
      if (index + 1 < points.length) {
        final segmentBearing =
            _bearingBetweenRoutePoints(current, points[index + 1]);
        if (segmentBearing != null) {
          _lastResolvedReportRouteBearing = segmentBearing;
          return segmentBearing;
        }

        final segmentCourse = _normalizeBearing(current.course);
        if (segmentCourse != null) {
          _lastResolvedReportRouteBearing = segmentCourse;
          return segmentCourse;
        }

        return _lastResolvedReportRouteBearing;
      }

      if (index > 0) {
        final previousSegmentBearing = _bearingBetweenRoutePoints(
          points[index - 1],
          current,
        );
        if (previousSegmentBearing != null) {
          _lastResolvedReportRouteBearing = previousSegmentBearing;
          return previousSegmentBearing;
        }
      }

      final segmentCourse = _normalizeBearing(current.course);
      if (segmentCourse != null) {
        _lastResolvedReportRouteBearing = segmentCourse;
        return segmentCourse;
      }

      return _lastResolvedReportRouteBearing;
    }

    final directCourse = _normalizeBearing(current.course);
    if (directCourse != null) {
      _lastResolvedReportRouteBearing = directCourse;
      return directCourse;
    }

    if (index + 1 < points.length) {
      final forward = _bearingBetweenRoutePoints(current, points[index + 1]);
      if (forward != null) {
        _lastResolvedReportRouteBearing = forward;
        return forward;
      }
    }

    if (index > 0) {
      final backward = _bearingBetweenRoutePoints(points[index - 1], current);
      if (backward != null) {
        _lastResolvedReportRouteBearing = backward;
        return backward;
      }
    }

    return _lastResolvedReportRouteBearing;
  }

  DateTime? _interpolateDateTime(
    DateTime? start,
    DateTime? end,
    double t,
  ) {
    if (start == null) return end;
    if (end == null) return start;
    final safeT = t.clamp(0.0, 1.0);
    final deltaMs = end.millisecondsSinceEpoch - start.millisecondsSinceEpoch;
    return DateTime.fromMillisecondsSinceEpoch(
      start.millisecondsSinceEpoch + (deltaMs * safeT).round(),
      isUtc: start.isUtc,
    );
  }

  ReportRouteMapPoint _interpolateReportRoutePoint(
    ReportRouteMapPoint from,
    ReportRouteMapPoint to,
    double t,
    double? bearing,
  ) {
    final safeT = t.clamp(0.0, 1.0);
    double? lerpNullable(double? a, double? b) {
      if (a == null && b == null) return null;
      final start = a ?? b!;
      final end = b ?? a!;
      return start + ((end - start) * safeT);
    }

    return ReportRouteMapPoint(
      latitude: from.latitude + ((to.latitude - from.latitude) * safeT),
      longitude: from.longitude + ((to.longitude - from.longitude) * safeT),
      effectiveTime:
          _interpolateDateTime(from.effectiveTime, to.effectiveTime, safeT),
      course: bearing ?? from.course ?? to.course,
      address: from.address ?? to.address,
      speedKmh: lerpNullable(from.speedKmh, to.speedKmh),
      rpm: lerpNullable(from.rpm, to.rpm),
      batteryVoltage: lerpNullable(from.batteryVoltage, to.batteryVoltage),
      ignition: safeT < 0.5 ? from.ignition : to.ignition,
      batteryLabel: safeT < 0.5 ? from.batteryLabel : to.batteryLabel,
      satellites: lerpNullable(from.satellites, to.satellites),
      odometerKm: lerpNullable(from.odometerKm, to.odometerKm),
      hourmeterHours: lerpNullable(from.hourmeterHours, to.hourmeterHours),
      motion: safeT < 0.5 ? from.motion : to.motion,
      signalLabel: safeT < 0.5 ? from.signalLabel : to.signalLabel,
    );
  }

  double _distanceBetweenReportRoutePointsKm(
    ReportRouteMapPoint a,
    ReportRouteMapPoint b,
  ) {
    const earthRadiusKm = 6371.0;
    final lat1 = a.latitude * (math.pi / 180.0);
    final lat2 = b.latitude * (math.pi / 180.0);
    final deltaLat = (b.latitude - a.latitude) * (math.pi / 180.0);
    final deltaLng = (b.longitude - a.longitude) * (math.pi / 180.0);
    final haversine = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    final arc = 2 * math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
    return earthRadiusKm * arc;
  }

  double _reportRouteDisplayProgress(
    double rawProgress,
    double segmentDistanceKm,
  ) {
    const longSegmentThresholdKm = 1.0;
    if (segmentDistanceKm < longSegmentThresholdKm) {
      return rawProgress.clamp(0.0, 1.0);
    }
    final safeProgress = rawProgress.clamp(0.0, 1.0);
    if (safeProgress <= 0.35) {
      return 0.0;
    }
    if (safeProgress >= 0.65) {
      return 1.0;
    }
    return ((safeProgress - 0.35) / 0.30).clamp(0.0, 1.0);
  }

  int? _resolveReportRouteSegmentIndex(
    List<ReportRouteMapPoint> points,
    int? pointIndex,
  ) {
    if (points.length < 2) {
      return pointIndex == null || points.isEmpty ? null : 0;
    }
    final rawIndex = pointIndex ?? 0;
    return rawIndex.clamp(0, points.length - 2).toInt();
  }

  _ReportRouteReplayFrame _buildReportRouteReplayFrame(
    List<ReportRouteMapPoint> points,
    int? index,
    bool playing,
  ) {
    if (points.isEmpty ||
        index == null ||
        index < 0 ||
        index >= points.length) {
      return const _ReportRouteReplayFrame(point: null, bearing: null);
    }

    if (points.length == 1) {
      return _ReportRouteReplayFrame(
        point: points.first,
        bearing: _lastResolvedReportRouteBearing,
      );
    }

    final isLastPoint = index >= points.length - 1;
    final segmentIndex = _resolveReportRouteSegmentIndex(points, index);
    if (segmentIndex == null) {
      return const _ReportRouteReplayFrame(point: null, bearing: null);
    }

    final current = points[segmentIndex];
    final next = points[segmentIndex + 1];
    final segmentDistanceKm =
        _distanceBetweenReportRoutePointsKm(current, next);
    final displayProgress = _reportRouteDisplayProgress(
      _routeReplaySegmentProgress,
      segmentDistanceKm,
    );
    final segmentBearing = _resolveReportRouteBearing(
      points,
      segmentIndex,
      lockToCurrentSegment: true,
    );
    final segmentBearingDirect = _bearingBetweenRoutePoints(current, next);
    const debugBucketSize = 15;
    final normalizedBearing = ((segmentBearing ?? 0) % 360 + 360) % 360;
    final segmentBucket =
        ((normalizedBearing / debugBucketSize).round() * debugBucketSize) % 360;
    final finalAngle = segmentBucket.toDouble();

    final isLargeGap =
        segmentDistanceKm > _replaySegmentMaxAnimatedDistanceKm;

    if (!playing || isLastPoint || isLargeGap) {
      final bearing = _resolveReportRouteBearing(
        points,
        segmentIndex,
        lockToCurrentSegment: true,
      );
      // Buraco de conexão do rastreador (distância grande num "segmento" só):
      // não anima a câmera correndo por ele — só troca de ponto direto,
      // evitando o efeito de sumir/pular na tela.
      return _ReportRouteReplayFrame(
        point: isLastPoint ? points.last : current,
        bearing: bearing,
      );
    }

    final interpolated = _interpolateReportRoutePoint(
      current,
      next,
      displayProgress,
      segmentBearing,
    );
    if (playing && _replayDebugLinesEmitted < 10) {
      debugPrint(
        't=${_routeReplaySegmentProgress.toStringAsFixed(3)} '
        'REPLAY_DEBUG '
        'segment=$segmentIndex '
        'A=(${current.latitude.toStringAsFixed(6)},${current.longitude.toStringAsFixed(6)}) '
        'B=(${next.latitude.toStringAsFixed(6)},${next.longitude.toStringAsFixed(6)}) '
        'P=(${interpolated.latitude.toStringAsFixed(6)},${interpolated.longitude.toStringAsFixed(6)}) '
        'bearing=${segmentBearing?.toStringAsFixed(2) ?? 'null'} '
        'angle=${finalAngle.toStringAsFixed(2)} '
        'bucket=$segmentBucket '
        'distanceKm=${segmentDistanceKm.toStringAsFixed(3)} '
        'displayT=${displayProgress.toStringAsFixed(3)}',
      );
      _replayDebugLinesEmitted += 1;
    }
    return _ReportRouteReplayFrame(
      point: interpolated,
      bearing: segmentBearing,
    );
  }

  void _toggleReportRouteReplay(
      List<ReportRouteMapPoint> points, int deviceId) {
    if (points.length < 2) return;
    if (_replayTimer != null) {
      _replayTimer?.cancel();
      setState(() {
        _replayTimer = null;
        _routeReplaySegmentProgress = 0;
      });
      return;
    }

    if (_replayDeviceId != deviceId || _selectedReplayIndex >= points.length) {
      _selectedReplayIndex = 0;
      _replayDeviceId = deviceId;
      _routeReplaySegmentProgress = 0;
      _replayDebugLinesEmitted = 0;
    }

    final timer = Timer.periodic(_replayTick, (_) {
      if (!mounted) return;
      setState(() {
        _routeReplaySegmentProgress +=
            _replayTick.inMilliseconds / _replaySegment.inMilliseconds;

        while (_routeReplaySegmentProgress >= 1) {
          if (_selectedReplayIndex >= points.length - 2) {
            _selectedReplayIndex = 0;
            _routeReplaySegmentProgress = 0;
            break;
          }
          _selectedReplayIndex += 1;
          _routeReplaySegmentProgress -= 1;
        }
      });
    });

    setState(() => _replayTimer = timer);
  }

  void _toggleReplay(
    List<_ReplayPoint> points,
    int? deviceId,
  ) {
    if (points.length < 2 || deviceId == null) return;
    if (_replayTimer != null) {
      _replayTimer?.cancel();
      setState(() => _replayTimer = null);
      return;
    }

    if (_replayDeviceId != deviceId || _selectedReplayIndex >= points.length) {
      _selectedReplayIndex = 0;
      _replayDeviceId = deviceId;
      _routeReplaySegmentProgress = 0;
    }

    final timer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!mounted) return;
      setState(() {
        if (_selectedReplayIndex >= points.length - 1) {
          _selectedReplayIndex = 0;
        } else {
          _selectedReplayIndex += 1;
        }
      });
    });

    setState(() => _replayTimer = timer);
  }

  void _followReplayPointIfNeeded(_ReplayPoint? point, int? deviceId) {
    if (point == null || deviceId == null) {
      _lastFollowedReplayKey = null;
      return;
    }
    final key = '$deviceId:${point.latitude.toStringAsFixed(6)}:'
        '${point.longitude.toStringAsFixed(6)}:${point.rawTime ?? ''}';
    if (_lastFollowedReplayKey == key) return;
    _lastFollowedReplayKey = key;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _googleMapController?.animateCamera(
        gmaps.CameraUpdate.newCameraPosition(
          gmaps.CameraPosition(
            target: point.latLng,
            zoom: 16,
            tilt: 45,
            bearing: point.course ?? 0,
          ),
        ),
      );
    });
  }

  void _followReportRoutePointIfNeeded(
    ReportRouteMapPoint? point,
    int? deviceId,
    bool active,
    double? bearing,
    bool camera3dEnabled,
  ) {
    if (!active || point == null || deviceId == null) {
      _lastFollowedReportRouteReplayKey = null;
      return;
    }
    final key = '$deviceId:${point.latitude.toStringAsFixed(6)}:'
        '${point.longitude.toStringAsFixed(6)}:${point.effectiveTime?.toIso8601String() ?? ''}';
    if (_lastFollowedReportRouteReplayKey == key) return;
    _lastFollowedReportRouteReplayKey = key;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _googleMapController?.animateCamera(
        gmaps.CameraUpdate.newCameraPosition(
          gmaps.CameraPosition(
            target: gmaps.LatLng(point.latitude, point.longitude),
            zoom: camera3dEnabled
                ? _chaseCamZoomForSpeed(point.speedKmh)
                : 14.6,
            tilt: camera3dEnabled ? 55 : 0,
            bearing: camera3dEnabled ? (bearing ?? 0) : 0,
          ),
        ),
      );
    });
  }

  void _recordPositionTrails(List<_VehicleSnapshot> snapshots) {
    final activeIds = <int>{};
    for (final snapshot in snapshots) {
      final point = snapshot.latLngOrNull;
      if (point == null) continue;
      activeIds.add(snapshot.device.id);
      final trail = _positionTrailByDeviceId.putIfAbsent(
        snapshot.device.id,
        () => <gmaps.LatLng>[],
      );
      if (trail.isEmpty || !_isSameTrailPoint(trail.last, point)) {
        trail.add(point);
        if (trail.length > 24) {
          trail.removeRange(0, trail.length - 24);
        }
      }
    }
    _positionTrailByDeviceId.removeWhere((id, _) => !activeIds.contains(id));
  }

  bool _isSameTrailPoint(gmaps.LatLng a, gmaps.LatLng b) {
    return (a.latitude - b.latitude).abs() < 0.00001 &&
        (a.longitude - b.longitude).abs() < 0.00001;
  }

  List<gmaps.LatLng> _selectedTrail() {
    final id = _selectedVehicle?.id;
    if (id == null) return const <gmaps.LatLng>[];
    final trail = _positionTrailByDeviceId[id];
    if (trail == null) return const <gmaps.LatLng>[];
    return List<gmaps.LatLng>.unmodifiable(trail);
  }

  void _followSelectedVehicleIfNeeded(_VehicleSnapshot? snapshot) {
    if (snapshot == null || !snapshot.hasValidGps) {
      _lastFollowedSelectedPositionKey = null;
      return;
    }

    final point = snapshot.latLng;
    final key = '${snapshot.device.id}:'
        '${point.latitude.toStringAsFixed(6)}:'
        '${point.longitude.toStringAsFixed(6)}:'
        '${snapshot.position?.fixTime ?? ''}';
    if (_lastFollowedSelectedPositionKey == key) return;
    _lastFollowedSelectedPositionKey = key;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedVehicle?.id != snapshot.device.id) return;
      _focusVehicle(snapshot);
    });
  }

  void _zoomBy(double delta) {
    final nextZoom = (_currentZoom + delta).clamp(4.0, 19.0).toDouble();
    setState(() => _currentZoom = nextZoom);
    _googleMapController?.animateCamera(gmaps.CameraUpdate.zoomTo(nextZoom));
  }

  void _setMapViewType(gmaps.MapType mapType) {
    setState(() => _mapViewType = mapType);
  }

  void _toggleMapTraffic() {
    setState(() => _mapTrafficEnabled = !_mapTrafficEnabled);
  }

  void _recenter(List<_VehicleSnapshot> snapshots) {
    final selected = _snapshotForDevice(
      _selectedVehicle,
      snapshots,
    );
    final firstWithPosition = snapshots
        .where((snapshot) => snapshot.hasValidGps)
        .cast<_VehicleSnapshot?>()
        .firstOrNull;
    final target = selected?.latLngOrNull ??
        firstWithPosition?.latLngOrNull ??
        const gmaps.LatLng(-23.55052, -46.633308);
    _googleMapController?.animateCamera(
      gmaps.CameraUpdate.newCameraPosition(
        gmaps.CameraPosition(target: target, zoom: 14.5, tilt: 35),
      ),
    );
  }

  void _closePanel() {
    setState(() {
      _showBottomVehiclePanel = true;
      _activePanelId = null;
      _activePanelTitle = null;
      _replayTimer?.cancel();
      _replayTimer = null;
    });
  }

  void _openSettingsPanel() {
    final settingsItem = _operationalMenu
        .where((item) => item.id == 'settings')
        .cast<_OperationalMenuItem?>()
        .firstOrNull;
    if (settingsItem == null) return;
    _openPanel(settingsItem);
  }

  void _refreshOperationalData() {
    ref.invalidate(devicesProvider);
    ref.invalidate(positionsProvider);
    ref.invalidate(latestEventsProvider);
    ref.invalidate(ordersProvider);
    ref.invalidate(statisticsProvider);
    ref.invalidate(serverProvider);
    ref.invalidate(notificationTypesProvider);
    ref.invalidate(timezonesProvider);
  }

  void _syncOperationalRealtimePolling({
    required bool enabled,
    required bool immediateRefresh,
  }) {
    if (!enabled) {
      _operationalRefreshTimer?.cancel();
      _operationalRefreshTimer = null;
      _positionRefreshTimer?.cancel();
      _positionRefreshTimer = null;
      return;
    }

    if (_operationalRefreshTimer == null) {
      if (immediateRefresh) {
        _refreshOperationalData();
      }
      _operationalRefreshTimer = Timer.periodic(
        _operationalRefreshInterval,
        (_) {
          if (!mounted) return;
          _refreshOperationalData();
        },
      );
    }

    if (_positionRefreshTimer == null) {
      _positionRefreshTimer = Timer.periodic(
        _positionRefreshInterval,
        (_) {
          if (!mounted) return;
          ref.invalidate(positionsProvider);
        },
      );
    }
  }

  Future<void> _handleLogout() async {
    await ref.read(sessionProvider.notifier).logout();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSession = ref.watch(sessionProvider);
    final devicesAsync = ref.watch(devicesProvider);
    final positionsAsync = ref.watch(positionsProvider);
    final latestEventsAsync = ref.watch(latestEventsProvider);
    final brand =
        ref.watch(whiteLabelProvider).value ?? WhiteLabelConfig.fallback;
    final rawVisualSettings = ref.watch(visualSettingsProvider);
    final visualSettings = rawVisualSettings.cardDensity ==
            VisualCardDensity.compact
        ? rawVisualSettings
        : rawVisualSettings.copyWith(cardDensity: VisualCardDensity.compact);
    final visualController = ref.read(visualSettingsProvider.notifier);
    final realtimeMapVisible =
        currentSession.isAuthenticated && _activePanelId == null;
    _syncOperationalRealtimePolling(
      enabled: realtimeMapVisible,
      immediateRefresh: true,
    );

    final devices = devicesAsync.valueOrNull ?? const <TraccarDevice>[];
    final positions = positionsAsync.valueOrNull ?? const <TraccarPosition>[];
    final latestEvents =
        latestEventsAsync.valueOrNull ?? const <Map<String, dynamic>>[];
    final snapshots = _buildSnapshots(devices, positions);
    _recordPositionTrails(snapshots);
    _VehicleSnapshot? enrichSnapshot(_VehicleSnapshot? snapshot) {
      if (snapshot == null) return null;
      final geocodeKey = _geocodeKey(snapshot);
      final selectedAddress = geocodeKey == null
          ? null
          : ref.watch(reverseGeocodeProvider(geocodeKey)).valueOrNull;
      final selectedEvents =
          ref.watch(deviceEventsProvider(snapshot.device.id)).valueOrNull ??
              const <Map<String, dynamic>>[];
      return snapshot.copyWith(
        resolvedAddress: selectedAddress,
        recentEvents: selectedEvents,
      );
    }

    final rawSelectedSnapshot = _snapshotForDevice(
      _selectedVehicle,
      snapshots,
    );
    final selectedSnapshot = enrichSnapshot(rawSelectedSnapshot);
    final defaultMapSnapshot = enrichSnapshot(
      snapshots
          .where((snapshot) => snapshot.hasValidGps)
          .cast<_VehicleSnapshot?>()
          .firstOrNull,
    );
    final reportRouteSelection = ref.watch(reportRouteMapSelectionProvider);
    final liveGaugesSnapshot = _liveGaugesDeviceId == null
        ? null
        : snapshots
            .cast<_VehicleSnapshot?>()
            .firstWhere((s) => s?.device.id == _liveGaugesDeviceId,
                orElse: () => null);
    final showLiveGauges =
        liveGaugesSnapshot != null && reportRouteSelection == null;
    final reportRouteReplayActive = reportRouteSelection != null;
    // Efeito Waze: ao ENTRAR num replay novo, troca uma única vez pro mapa
    // normal (vetorial, com prédio 3D de verdade) — mas sem travar o seletor
    // de mapa depois: o usuário pode trocar livremente durante o replay.
    if (reportRouteSelection != null &&
        reportRouteSelection.requestNonce != _lastReportRouteMapTypeNonce) {
      _lastReportRouteMapTypeNonce = reportRouteSelection.requestNonce;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _mapViewType = gmaps.MapType.normal);
      });
    }
    final bottomSnapshot = reportRouteReplayActive
        ? null
        : (_showBottomVehiclePanel ? selectedSnapshot : null) ??
            (_showBottomVehiclePanel && !_activePanelVisible && !_kpiListOpen
                ? defaultMapSnapshot
                : null);
    final showVehicleCompactPopup = !reportRouteReplayActive &&
        !showLiveGauges &&
        selectedSnapshot != null &&
        !_showBottomVehiclePanel &&
        !_activePanelVisible &&
        !_kpiListOpen;
    _followSelectedVehicleIfNeeded(selectedSnapshot);
    if (showLiveGauges) {
      _followSelectedVehicleIfNeeded(liveGaugesSnapshot);
    }
    final reportRoutePoints =
        reportRouteSelection?.points ?? const <ReportRouteMapPoint>[];
    final reportRoutePath = reportRoutePoints
        .map((point) => gmaps.LatLng(point.latitude, point.longitude))
        .toList(growable: false);
    // Trajeto corrigido pelo OSRM, já dividido em trechos contínuos — cada
    // trecho vira sua própria polyline, então um buraco de conexão real
    // aparece como buraco visual, não como reta falsa conectando pedaços.
    final reportRouteMatchedSegments = (reportRouteSelection?.matchedPath ??
            const <List<MatchedLatLng>>[])
        .map((segment) => segment
            .map((point) => gmaps.LatLng(point.latitude, point.longitude))
            .toList(growable: false))
        .where((segment) => segment.length > 1)
        .toList(growable: false);
    final reportRouteReplayIndex = reportRoutePoints.isEmpty
        ? null
        : _selectedReplayIndex.clamp(0, reportRoutePoints.length - 1).toInt();
    final reportRouteReplayPlaying =
        reportRouteSelection != null && _replayTimer != null;
    final reportRouteFrame = _buildReportRouteReplayFrame(
      reportRoutePoints,
      reportRouteReplayIndex,
      reportRouteReplayPlaying,
    );
    final reportRouteActivePoint = reportRouteFrame.point;
    final reportRouteActiveBearing = reportRouteFrame.bearing;
    final reportRouteStart =
        reportRoutePoints.isEmpty ? null : reportRoutePoints.first;
    final reportRouteEnd =
        reportRoutePoints.isEmpty ? null : reportRoutePoints.last;
    final selectedMapDevice = _selectedVehicle;
    final selectedMapDeviceId = selectedMapDevice?.id;
    final effectiveSelectedDeviceId =
        reportRouteSelection?.deviceId ?? selectedMapDeviceId;
    final replayQuery = reportRouteSelection == null
        ? _buildReplayQuery(effectiveSelectedDeviceId)
        : null;
    final replayAsync = replayQuery == null
        ? const AsyncData<List<_ReplayPoint>>(<_ReplayPoint>[])
        : ref.watch(vehicleReplayProvider(replayQuery));
    final replayPoints = replayAsync.valueOrNull ?? const <_ReplayPoint>[];
    final replayIndex = replayPoints.isEmpty
        ? null
        : _selectedReplayIndex.clamp(0, replayPoints.length - 1).toInt();
    final replayModeActive = reportRouteSelection == null &&
        effectiveSelectedDeviceId != null &&
        _activeBottomTab == _VehicleBottomTab.chart &&
        replayPoints.isNotEmpty;
    final selectedReplayPoint = replayModeActive && replayIndex != null
        ? replayPoints[replayIndex]
        : null;
    final selectedReplayPath = replayModeActive
        ? replayPoints.map((point) => point.latLng).toList(growable: false)
        : const <gmaps.LatLng>[];
    _followReplayPointIfNeeded(selectedReplayPoint, effectiveSelectedDeviceId);
    _followReportRoutePointIfNeeded(
      reportRouteActivePoint,
      reportRouteSelection?.deviceId,
      reportRouteReplayPlaying,
      reportRouteActiveBearing,
      _reportRouteReplay3dEnabled,
    );
    _focusReportRouteIfNeeded(reportRouteSelection);
    final snapshotKpis = _FleetKpis.fromSnapshots(snapshots);
    final realAlertCount = latestEvents.isNotEmpty
        ? latestEvents.where((e) {
            final type = (e['type'] ?? '')
                .toString()
                .toLowerCase()
                .replaceAll(RegExp(r'[^a-z0-9]'), '');
            final attrs = e['attributes'];
            final alarm = (attrs is Map ? attrs['alarm'] : null)
                    ?.toString()
                    .toLowerCase() ??
                '';
            return type.contains('overspeed') ||
                type.contains('geofenceenter') ||
                type.contains('geofenceexit') ||
                type.contains('panic') ||
                type.contains('sos') ||
                type.contains('alarm') ||
                type.contains('jammer') ||
                type.contains('powercut') ||
                type.contains('lowbattery') ||
                type.contains('batterylow') ||
                alarm.contains('overspeed') ||
                alarm.contains('panic') ||
                alarm.contains('sos') ||
                alarm.contains('jammer') ||
                alarm.contains('vibration') ||
                alarm.contains('shock');
          }).length
        : snapshotKpis.alerts;
    final noCommunicationCount =
        snapshots.where((snapshot) => snapshot.hasNoCommunication).length;
    final kpis = snapshotKpis.copyWith(alerts: realAlertCount);
    final filteredSnapshots = _filterSnapshots(snapshots, _activeKpiFilter);
    final hasValidMapSnapshots =
        snapshots.any((snapshot) => snapshot.hasValidGps);
    final sessionUsers =
        ref.watch(usersProvider).valueOrNull ?? const <TraccarUser>[];
    final isPixeltiSession = _isPixeltiUser(currentSession);
    final profileName = _resolveProfileName(currentSession, sessionUsers);
    final profileDetail = _resolveProfileDetail(currentSession, sessionUsers);
    final menuItems = _menuWithRealtimeBadges(
      session: currentSession,
      alertCount: realAlertCount,
      showDataLog: _shouldShowDataLogMenu(currentSession),
    );
    // Legacy telemetry workspace disabled: all screens now render through the
    // same integrated panel pipeline (single visual source of truth).
    final pixelTelemetryMode = _activePanelId == '__legacy_telemetry__';
    final fullMapVisible =
        _activePanelId == null && !_kpiListOpen && _selectedVehicle == null;
    final showTopStatusCards =
        _activePanelId == null || _activePanelId == 'dashboard';
    final showMapQuickActions =
        (_activePanelId == null || _activePanelId == 'dashboard') &&
            !_kpiListOpen;
    final sidebarVisible = !_sidebarHidden;
    final textScaler = TextScaler.linear(visualSettings.textScale);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      body: VisualSettingsScope(
        settings: visualSettings,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: Stack(
            children: [
              Positioned.fill(
                child: _OperationalMap(
                  snapshots: snapshots,
                  selectedDeviceId: effectiveSelectedDeviceId,
                  selectedTrail: _selectedTrail(),
                  selectedReplayPath: selectedReplayPath,
                  selectedReplayPoint: selectedReplayPoint,
                  reportRoutePath: reportRoutePath,
                  reportRouteMatchedSegments: reportRouteMatchedSegments,
                  reportRouteStart: reportRouteStart,
                  reportRouteEnd: reportRouteEnd,
                  reportRouteActivePoint: reportRouteActivePoint,
                  reportRouteActiveBearing: reportRouteActiveBearing,
                  mapMode: visualSettings.mapMode,
                  mapType: _mapViewType,
                  mapZoom: _currentZoom,
                  trafficEnabled: _mapTrafficEnabled,
                  onMapCreated: (controller) =>
                      _googleMapController = controller,
                  onCameraMove: (position) {
                    final nextZoom = position.zoom;
                    final clusterModeChanged =
                        (_currentZoom < _OperationalMap.clusterZoomThreshold) !=
                            (nextZoom < _OperationalMap.clusterZoomThreshold);
                    final labelModeChanged =
                        (_currentZoom >= 13.0) != (nextZoom >= 13.0);
                    final iconTierChanged =
                        _OperationalMap._zoomIconTier(_currentZoom) !=
                            _OperationalMap._zoomIconTier(nextZoom);
                    if (clusterModeChanged ||
                        labelModeChanged ||
                        iconTierChanged ||
                        (nextZoom - _currentZoom).abs() >= 0.5) {
                      setState(() => _currentZoom = nextZoom);
                    } else {
                      _currentZoom = nextZoom;
                    }
                  },
                  onMapTap: _clearOperationalSurface,
                  onVehicleTap: _selectVehicleOnMap,
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: (visualSettings.backdropOverlayAlpha - 0.08)
                            .clamp(0.10, 0.26),
                      ),
                    ),
                  ),
                ),
              ),
              if (!hasValidMapSnapshots && !_activePanelVisible)
                const Positioned.fill(
                  child: _NoVehiclesMapHint(),
                ),
              if (!pixelTelemetryMode)
                _TopSearchBar(
                  brand: brand,
                  cardDensity: visualSettings.cardDensity,
                  logoMode: visualSettings.logoMode,
                  hideLogoOnFullMap: fullMapVisible,
                  kpis: kpis,
                  activeFilter: _kpiListOpen ? _activeKpiFilter : null,
                  onKpiTap: _openKpi,
                  onMenuTap: _toggleSidebarCompact,
                  menuOpen: _menuOpen,
                  sidebarVisible: sidebarVisible,
                  alertCount: realAlertCount,
                  panelOpen: _activePanelVisible,
                  activeTitle: _activePanelTitle,
                  activeSubtitle: formatDisplayText(
                    _panelSubtitle(_activePanelId),
                  ),
                  onRefresh: _refreshOperationalData,
                  onClosePanel: _closePanel,
                  onOpenSettingsPanel: _openSettingsPanel,
                  showStatusCards: showTopStatusCards,
                  onLogout: () {
                    _handleLogout();
                  },
                  profileName: profileName,
                  profileDetail: profileDetail,
                  compactProfileMenu: isPixeltiSession,
                  noCommunicationCount: noCommunicationCount,
                  showMapQuickActions: showMapQuickActions,
                  mapType: _mapViewType,
                  trafficEnabled: _mapTrafficEnabled,
                  onMapTypeChanged: _setMapViewType,
                  onTrafficToggle: _toggleMapTraffic,
                  onRecenter: () => _recenter(snapshots),
                  onRefreshPositions: _refreshOperationalData,
                  onFilterSelected: _openKpi,
                  onClearFilters: _clearKpiSelection,
                  onAiTap: _toggleCopilotPanel,
                  aiPanelOpen: _copilotPanelOpen,
                ),
              if (!pixelTelemetryMode &&
                  reportRouteSelection == null &&
                  !showLiveGauges)
                _MapRightControls(
                  onZoomIn: () => _zoomBy(1),
                  onZoomOut: () => _zoomBy(-1),
                ),
              if (!pixelTelemetryMode && sidebarVisible)
                _SideMenu(
                  open: _menuOpen,
                  cardDensity: visualSettings.cardDensity,
                  brandName: brand.appName,
                  brandLogoAsset: brand.logoAsset,
                  onToggle: _toggleSidebarCompact,
                  items: menuItems,
                  activeId: _activePanelId ?? 'map',
                  onSelect: _openPanel,
                  userEmail: ref.watch(sessionProvider).email ?? '',
                  isAdmin: ref.watch(sessionProvider).isAdministrator,
                  onLogout: () {
                    _handleLogout();
                  },
                ),
              if (_showHighlightsRail)
                _HighlightsRail(open: !_activePanelVisible),
              if (!pixelTelemetryMode)
                _RouteReplayControls(
                  visible: reportRouteSelection != null,
                  sidebarOpen: _menuOpen,
                  sidebarVisible: sidebarVisible,
                  playing: reportRouteReplayPlaying,
                  camera3dEnabled: _reportRouteReplay3dEnabled,
                  total: reportRoutePoints.length,
                  index: reportRouteReplayIndex ?? 0,
                  vehicleName: reportRouteSelection?.vehicleName ?? '',
                  onToggle3d: () {
                    setState(() {
                      _reportRouteReplay3dEnabled =
                          !_reportRouteReplay3dEnabled;
                      _lastFollowedReportRouteReplayKey = null;
                    });
                  },
                  onPrevious: () => _setReplayIndex(
                    (reportRouteReplayIndex ?? 0) - 1,
                    reportRoutePoints.length,
                  ),
                  onToggle: () {
                    final selection = reportRouteSelection;
                    if (selection == null) return;
                    _toggleReportRouteReplay(
                      reportRoutePoints,
                      selection.deviceId,
                    );
                  },
                  onNext: () => _setReplayIndex(
                    (reportRouteReplayIndex ?? 0) + 1,
                    reportRoutePoints.length,
                  ),
                  onChanged: (value) => _setReplayIndex(
                    value.round(),
                    reportRoutePoints.length,
                  ),
                ),
              if (!pixelTelemetryMode)
                _RouteReplaySpeedGauge(
                  visible: reportRouteSelection != null,
                  speedKmh: reportRouteActivePoint?.speedKmh,
                  rpm: reportRouteActivePoint?.rpm == null
                      ? null
                      : reportRouteActivePoint!.rpm! / 1000,
                  sidebarOpen: _menuOpen,
                  sidebarVisible: sidebarVisible,
                ),
              if (!pixelTelemetryMode)
                _RouteReplayStatusCard(
                  visible: reportRouteSelection != null,
                  ignition: reportRouteActivePoint?.ignition,
                  motion: reportRouteActivePoint?.motion,
                  batteryLabel: reportRouteActivePoint?.batteryLabel,
                  satellites: reportRouteActivePoint?.satellites,
                  signalLabel: reportRouteActivePoint?.signalLabel,
                  odometerKm: reportRouteActivePoint?.odometerKm,
                  hourmeterHours: reportRouteActivePoint?.hourmeterHours,
                ),
              if (!pixelTelemetryMode)
                _RouteReplaySpeedGauge(
                  visible: showLiveGauges,
                  speedKmh: liveGaugesSnapshot?.speedKmh,
                  rpm: _attrAsDouble(
                        liveGaugesSnapshot?._mergedAttributes['rpm'],
                      ) ==
                          null
                      ? null
                      : _attrAsDouble(
                            liveGaugesSnapshot?._mergedAttributes['rpm'],
                          )! /
                          1000,
                  sidebarOpen: _menuOpen,
                  sidebarVisible: sidebarVisible,
                ),
              if (!pixelTelemetryMode)
                _RouteReplayStatusCard(
                  visible: showLiveGauges,
                  ignition: liveGaugesSnapshot?.ignition,
                  motion: _attrAsBool(
                    liveGaugesSnapshot?._mergedAttributes['motion'],
                  ),
                  batteryLabel: liveGaugesSnapshot?.batteryLabel,
                  satellites: _attrAsDouble(
                    liveGaugesSnapshot?._mergedAttributes['sat'],
                  ),
                  signalLabel: liveGaugesSnapshot?.gsmSignalLabel,
                  odometerKm: (() {
                    final meters = _attrAsDouble(
                      liveGaugesSnapshot?._mergedAttributes['odometer'],
                    );
                    return meters == null ? null : meters / 1000.0;
                  })(),
                  hourmeterHours: (() {
                    final hours = _attrAsDouble(
                      liveGaugesSnapshot?._mergedAttributes['hours'],
                    );
                    return hours == null ? null : hours / 3600000.0;
                  })(),
                  tireReadings:
                      liveGaugesSnapshot?.tireReadings ?? const [],
                ),
              if (!pixelTelemetryMode && showLiveGauges)
                _LiveGaugesBar(
                  vehicleName: liveGaugesSnapshot?.device.name ?? '',
                  onClose: _closeLiveGauges,
                ),
              if (!pixelTelemetryMode)
                _KpiVehicleList(
                  open: _kpiListOpen,
                  cardDensity: visualSettings.cardDensity,
                  sidebarOpen: _menuOpen,
                  sidebarVisible: sidebarVisible,
                  title: _activeKpiFilter.title,
                  snapshots: filteredSnapshots,
                  onVehicleTap: _openVehicleDetails,
                ),
              if (!pixelTelemetryMode)
                _IntegratedPanel(
                  open: _activePanelVisible,
                  cardDensity: visualSettings.cardDensity,
                  sidebarOpen: _menuOpen,
                  sidebarVisible: sidebarVisible,
                  title: _activePanelTitle ?? '',
                  subtitle: formatDisplayText(_panelSubtitle(_activePanelId)),
                  hideHeader: true,
                  onClose: _closePanel,
                  child: _panelFor(_activePanelId),
                ),
              if (!pixelTelemetryMode && showVehicleCompactPopup)
                _VehicleCompactPopup(
                  snapshot: selectedSnapshot,
                  balloonScale: visualSettings.balloonScale,
                  cardDensity: visualSettings.cardDensity,
                  sidebarOpen: _menuOpen,
                  onDetails: () => _openVehicleDetails(selectedSnapshot),
                  onTelemetry: () => setState(
                    () => _liveGaugesDeviceId = selectedSnapshot.device.id,
                  ),
                  onAlerts: () => _openPanel(
                    _operationalMenu.firstWhere((item) => item.id == 'alerts'),
                  ),
                  onShare: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Compartilhamento rapido segue disponivel apenas na visao detalhada.',
                        ),
                      ),
                    );
                  },
                  onMore: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Mais acoes do veiculo continuam concentradas na barra inferior.',
                        ),
                      ),
                    );
                  },
                  onClose: () => setState(() {
                    _selectedVehicle = null;
                    _showBottomVehiclePanel = false;
                    _vehiclePanelMode = _VehiclePanelMode.summary;
                  }),
                ),
              if (pixelTelemetryMode)
                Positioned.fill(
                  child: _SurfaceGuard(
                    child: _PixelTelemetryWorkspace(
                      snapshots: snapshots,
                      onClose: _closePanel,
                      onRefresh: _refreshOperationalData,
                      onOpenMenuItem: _openPanel,
                      menuItems: menuItems,
                    ),
                  ),
                ),
              if (!pixelTelemetryMode)
                _VehicleBottomBar(
                  snapshot: bottomSnapshot,
                  replayAsync: replayAsync,
                  replayPoints: replayPoints,
                  replayIndex: replayIndex,
                  replayWindow: _replayWindow,
                  replayPlaying: _replayTimer != null,
                  cardDensity: visualSettings.cardDensity,
                  sidebarOpen: _menuOpen,
                  sidebarVisible: sidebarVisible,
                  activeTab: _activeBottomTab,
                  panelMode: _vehiclePanelMode,
                  onTabChanged: (tab) => setState(() {
                    if (tab != _VehicleBottomTab.chart) {
                      _replayTimer?.cancel();
                      _replayTimer = null;
                    }
                    _activeBottomTab = tab;
                  }),
                  onReplayWindowChanged: _setReplayWindow,
                  onReplayIndexChanged: (next) =>
                      _setReplayIndex(next, replayPoints.length),
                  onReplayToggle: () =>
                      _toggleReplay(replayPoints, selectedMapDeviceId),
                  onModeChanged: (mode) =>
                      setState(() => _vehiclePanelMode = mode),
                  onAiTap: _toggleCopilotPanel,
                  onClose: () => setState(() {
                    _replayTimer?.cancel();
                    _replayTimer = null;
                    _selectedVehicle = null;
                    _showBottomVehiclePanel = false;
                    _vehiclePanelMode = _VehiclePanelMode.summary;
                  }),
                ),
              // Copiloto removido do mapa — virou item de menu "IA Operacional"
            ],
          ),
        ),
      ),
    );
  }

  bool get _activePanelVisible => _activePanelId != null;

  String _panelSubtitle(String? id) {
    switch (id) {
      case 'dashboard':
        return 'Visão geral da Operação';
      case 'map':
        return 'Monitoramento em tempo real';
      case 'vehicles':
        return 'Cadastro e ciclo de vida da frota';
      case 'devices':
        return 'Gestão operacional de rastreadores';
      case 'telemetry':
        return 'Sensores e dados operacionais';
      case 'tpms':
        return 'Sensores e dados operacionais dos pneus';
      case 'routes':
        return 'Hist\u00F3rico, replay e quilometragem';
      case 'alerts':
        return 'Eventos, regras e notificações';
      case 'maintenance':
        return 'Planos e hist\u00F3rico de manuten\u00E7\u00E3o';
      case 'geofences':
        return 'Cercas e zonas inteligentes';
      case 'tickets':
        return 'Abertura e acompanhamento de chamados';
      case 'communication':
        return 'Atendimento e mensagens operacionais';
      case 'ai-operations':
        return 'Assistente inteligente da Operação';
      case 'finance':
        return 'Gestão financeira e cobranças';
      case 'inventory':
        return 'Estoque e equipamentos vinculados';
      case 'mdvr':
        return 'Monitoramento de câmeras e evidências';
      case 'telemetry-demo':
        return 'Sensores e dados operacionais';
      case 'logs':
        return 'Data log por comunicação do dispositivo';
      case 'reports':
        return 'Relatórios operacionais e executivos';
      case 'commands':
        return 'Comandos remotos e a\u00E7\u00F5es operacionais';
      case 'automations':
        return 'Regras e gatilhos automáticos';
      case 'settings':
        return 'Governança e parâmetros do ambiente';
      default:
        return 'Painel integrado';
    }
  }

  List<_VehicleSnapshot> _buildSnapshots(
    List<TraccarDevice> devices,
    List<TraccarPosition> positions,
  ) {
    final positionByDeviceId = <int, TraccarPosition>{};
    for (final position in positions) {
      final current = positionByDeviceId[position.deviceId];
      if (current == null) {
        positionByDeviceId[position.deviceId] = position;
        continue;
      }
      final currentTime = DateTime.tryParse(current.fixTime);
      final nextTime = DateTime.tryParse(position.fixTime);
      if (nextTime != null &&
          (currentTime == null || nextTime.isAfter(currentTime))) {
        positionByDeviceId[position.deviceId] = position;
      }
    }

    for (final entry in positionByDeviceId.entries) {
      final attrs = entry.value.attributes;
      if (attrs == null) continue;
      final tireEntries = <String, dynamic>{
        for (final attrEntry in attrs.entries)
          if (attrEntry.key.startsWith('tire')) attrEntry.key: attrEntry.value,
      };
      if (tireEntries.isEmpty) continue;
      final cached = _lastKnownTireAttributesByDevice.putIfAbsent(
        entry.key,
        () => {},
      );
      cached.addAll(tireEntries);
    }

    return [
      for (var i = 0; i < devices.length; i++)
        _VehicleSnapshot(
          device: devices[i],
          position: positionByDeviceId[devices[i].id],
          index: i,
          tireAttributes:
              _lastKnownTireAttributesByDevice[devices[i].id] ?? const {},
        ),
    ];
  }

  _VehicleSnapshot? _snapshotForDevice(
    TraccarDevice? selected,
    List<_VehicleSnapshot> snapshots,
  ) {
    if (selected == null) return null;
    for (final snapshot in snapshots) {
      if (snapshot.device.id == selected.id) return snapshot;
    }
    return null;
  }

  String? _geocodeKey(_VehicleSnapshot snapshot) {
    final latLng = snapshot.latLngOrNull;
    if (latLng == null) return null;
    return '${latLng.latitude.toStringAsFixed(6)},'
        '${latLng.longitude.toStringAsFixed(6)}';
  }

  List<_VehicleSnapshot> _filterSnapshots(
    List<_VehicleSnapshot> snapshots,
    _KpiFilter filter,
  ) {
    switch (filter) {
      case _KpiFilter.online:
        return snapshots
            .where((it) => it.isOperationalOnline)
            .toList(growable: false);
      case _KpiFilter.offline:
        return snapshots
            .where((it) => it.isOffline)
            .toList(growable: false);
      case _KpiFilter.moving:
        return snapshots
            .where((it) => it.isOperationalMoving)
            .toList(growable: false);
      case _KpiFilter.alerts:
        return snapshots.where((it) => it.hasAlert).toList(growable: false);
      case _KpiFilter.noCommunication:
        return snapshots
            .where((it) => it.hasNoCommunication)
            .toList(growable: false);
    }
  }

  List<_OperationalMenuItem> _menuWithRealtimeBadges({
    required SessionState session,
    required int alertCount,
    required bool showDataLog,
  }) {
    final rawMenu = _operationalMenu;
    final baseMenu = showDataLog
        ? rawMenu
        : rawMenu.where((item) => item.id != 'logs').toList(growable: false);
    final filteredMenu = _filterMenuForSession(baseMenu, session);

    return [
      for (final item in filteredMenu)
        if (item.id == 'alerts')
          item.copyWith(badge: _badgeText(alertCount))
        else
          item,
    ];
  }

  List<_OperationalMenuItem> _filterMenuForSession(
    List<_OperationalMenuItem> items,
    SessionState session,
  ) {
    final baseItems = _isPixelDemoMode(session)
        ? items
            .where(
              (item) => const <String>{
                'dashboard',
                'map',
                'devices',
                'telemetry',
                'alerts',
                'reports',
              }.contains(item.id),
            )
            .toList(growable: false)
        : items;

    final profile = session.profileCode.trim().toUpperCase();
    final modules = session.tenantConfig.modules;
    final preserveDemoModules = _shouldPreserveMenuModulesInFallback(session);

    bool featureEnabledForMenu(String menuId) {
      if (preserveDemoModules) {
        return true;
      }

      String? featureKey;
      switch (menuId) {
        case 'dashboard':
        case 'map':
        case 'vehicles':
        case 'devices':
        case 'alerts':
        case 'geofences':
        case 'maintenance':
        case 'reports':
        case 'commands':
        case 'telemetry':
        case 'logs':
        case 'settings':
          featureKey = 'tracking';
          break;
        case 'communication':
          featureKey = 'zpro';
          break;
        case 'tickets':
          featureKey = modules['assist'] == true ? 'assist' : 'demand';
          break;
        case 'ai-operations':
          featureKey = modules['ai_ops'] == true ? 'ai_ops' : 'ai';
          break;
        case 'finance':
          featureKey = 'finance';
          break;
        case 'inventory':
          featureKey = 'inventory';
          break;
        case 'mdvr':
          featureKey = 'mdvr';
          break;
        case 'automations':
          featureKey = modules['automations'] == true ? 'automations' : 'rules';
          break;
      }

      if (featureKey == null || featureKey.isEmpty) {
        return true;
      }
      return modules[featureKey] == true;
    }

    Set<String> allowedMenuIdsForProfile() {
      switch (profile) {
        case 'MA':
        case 'AE':
          return baseItems.map((item) => item.id).toSet();
        case 'SO':
          return const {
            'dashboard',
            'map',
            'vehicles',
            'devices',
            'alerts',
            'geofences',
            'maintenance',
            'reports',
            'commands',
            'communication',
            'tickets',
            'mdvr',
            'telemetry',
            'logs',
            'settings',
          };
        case 'TEC':
          return const {
            'dashboard',
            'map',
            'vehicles',
            'devices',
            'alerts',
            'maintenance',
            'tickets',
            'communication',
            'mdvr',
            'telemetry',
          };
        case 'GC':
        case 'CF':
          return const {
            'dashboard',
            'map',
            'vehicles',
            'devices',
            'alerts',
            'geofences',
            'reports',
            'communication',
            'mdvr',
          };
        case 'SAC':
          return const {
            'dashboard',
            'map',
            'vehicles',
            'devices',
            'alerts',
            'geofences',
            'reports',
            'communication',
            'tickets',
            'telemetry',
          };
        case 'FIN':
          return const {
            'dashboard',
            'reports',
            'finance',
          };
        case 'EST':
          return const {
            'dashboard',
            'devices',
            'maintenance',
            'inventory',
            'reports',
          };
        case 'OM':
        default:
          return const {
            'dashboard',
            'map',
            'vehicles',
            'devices',
            'alerts',
            'geofences',
            'maintenance',
            'reports',
            'commands',
            'communication',
            'tickets',
            'telemetry',
            'logs',
          };
      }
    }

    final allowedMenuIds = allowedMenuIdsForProfile();
    return baseItems
        .where((item) => allowedMenuIds.contains(item.id))
        .where((item) => featureEnabledForMenu(item.id))
        .toList(growable: false);
  }

  bool _isPixelDemoMode(SessionState session) {
    if (session.isAdministrator) {
      return false;
    }

    final email = (session.email ?? '').trim().toLowerCase();
    final explicitPixelUser = email.contains('pixel');
    if (!kIsWeb) {
      return explicitPixelUser;
    }

    final pixelFlag = Uri.base.queryParameters['pixel']?.trim().toLowerCase();
    final enabledByUrl = pixelFlag == '1' ||
        pixelFlag == 'true' ||
        pixelFlag == 'on' ||
        pixelFlag == 'yes';
    return explicitPixelUser || enabledByUrl;
  }

  String? _badgeText(int value) {
    if (value <= 0) return null;
    return value > 99 ? '99+' : '$value';
  }

  String _resolveProfileName(
    SessionState session,
    List<TraccarUser> users,
  ) {
    final email = (session.email ?? '').trim().toLowerCase();
    if (email.isNotEmpty) {
      for (final user in users) {
        if (user.email.trim().toLowerCase() == email) {
          final name = user.name.trim();
          if (name.isNotEmpty) {
            return name;
          }
          break;
        }
      }
      return session.email!.trim();
    }

    return 'Usuario';
  }

  String _resolveProfileDetail(
    SessionState session,
    List<TraccarUser> users,
  ) {
    final email = (session.email ?? '').trim();
    if (email.isNotEmpty) {
      return email;
    }

    for (final user in users) {
      final name = user.name.trim();
      final mail = user.email.trim();
      if (name.isNotEmpty && mail.isNotEmpty) {
        return mail;
      }
    }

    final company = session.tenantConfig.companyName.trim();
    if (company.isNotEmpty) {
      return company;
    }

    return 'Conta SouTracking';
  }

  bool _isPixeltiUser(SessionState session) {
    return (session.email ?? '').trim().toLowerCase() ==
        'pixelti@soutracking.com.br';
  }

  bool _isAdminSession(SessionState session) {
    final profile = session.profileCode.trim().toUpperCase();
    return session.isAdministrator ||
        profile == 'MA' ||
        profile == 'AE' ||
        session.tenantConfig.isMasterAdmin ||
        session.tenantConfig.isCompanyAdmin;
  }

  bool _isPilotView(SessionState session) {
    // Legacy pilot branch disabled to keep a single visual pipeline.
    return false;
  }

  bool _shouldPreserveMenuModulesInFallback(SessionState session) {
    if (!session.usingLocalTenantFallback) {
      return false;
    }

    if (_isAdminSession(session)) {
      return true;
    }

    final email = (session.email ?? '').trim().toLowerCase();
    return email.contains('demo') ||
        email.contains('homolog') ||
        email.contains('hml') ||
        email.contains('sandbox') ||
        email.contains('teste') ||
        email.contains('test');
  }

  bool _shouldShowDataLogMenu(SessionState session) {
    return true;
  }

  Widget _panelFor(String? id) {
    switch (id) {
      case 'dashboard':
        return _buildDashboardPanel();
      case 'map':
        return _buildMapPanel();
      case 'vehicles':
        return _buildVehiclesPanel();
      case 'devices':
        return _buildDevicesPanel();
      case 'telemetry':
        return _buildTelemetryPanel();
      case 'tpms':
        return _buildTpmsPanel();
      case 'routes':
        return _buildRoutesPanel();
      case 'alerts':
        return _buildAlertsPanel();
      case 'maintenance':
        return _buildMaintenancePanel();
      case 'geofences':
        return _buildGeofencesPanel();
      case 'tickets':
        return _buildTicketsPanel();
      case 'communication':
        return _buildCommunicationPanel();
      case 'ai-operations':
        return _buildAiOperationsPanel();
      case 'finance':
        return _buildFinancePanel();
      case 'inventory':
        return _buildInventoryPanel();
      case 'mdvr':
        return _buildMdvrPanel();
      case 'telemetry-demo':
        return _buildTelemetryPanel();
      case 'logs':
        return _buildLogsPanel();
      case 'reports':
        return _buildReportsPanel();
      case 'commands':
        return _buildCommandsPanel();
      case 'automations':
        return _buildAutomationsPanel();
      case 'settings':
        return _buildSettingsPanel();
      default:
        return const PlaceholderScreen(
          title: 'M\u00F3dulo em prepara\u00E7\u00E3o',
          subtitle: 'M\u00F3dulo em prepara\u00E7\u00E3o',
        );
    }
  }

  _PanelToolEntry _placeholderEntry({
    required String moduleTitle,
    required String label,
    required IconData icon,
    required String description,
    String? detail,
    List<String> cards = const [],
  }) {
    return _PanelToolEntry(
      label: label,
      icon: icon,
      detail: detail ?? 'Estrutura criada',
      child: _ModulePlaceholderScreen(
        moduleTitle: moduleTitle,
        submenuTitle: label,
        description: description,
        cards: cards,
      ),
    );
  }

  List<_PanelToolEntry> _placeholderEntries({
    required String moduleTitle,
    required List<({String label, IconData icon, String description})> items,
  }) {
    // Legacy placeholder decks disabled in the new pixel-perfect flow.
    return const <_PanelToolEntry>[];
  }

  Widget _buildDashboardPanel() {
    return const DashboardScreen();
  }

  Widget _buildMapPanel() {
    return const MapScreen();
  }

  Widget _buildVehiclesPanel() {
    return const VehiclesScreen();
  }

  Widget _buildDevicesPanel() {
    // Single-source render: devices now use the new screen directly,
    // without legacy tool-wrapper tabs that caused mixed old/new visuals.
    return const DevicesScreen();
  }

  Widget _buildTelemetryPanel() {
    return TelemetrySensorsScreen(onClose: _closePanel);
  }

  Widget _buildTpmsPanel() {
    return TpmsScreen(onClose: _closePanel);
  }

  Widget _buildRoutesPanel() {
    if (_isPilotView(ref.watch(sessionProvider))) {
      return _TraccarToolsPanel(
        key: const ValueKey('routes-tools'),
        title: 'Rotas',
        entries: const [
          _PanelToolEntry(
            label: 'Histórico de rota',
            icon: Icons.route_outlined,
            detail: 'Consulta real',
            child: RoutesScreen(),
          ),
          _PanelToolEntry(
            label: 'Replay',
            icon: Icons.replay_circle_filled_outlined,
            detail: 'Replay visual',
            child: RoutesScreen(),
          ),
        ],
      );
    }

    return _TraccarToolsPanel(
      key: const ValueKey('routes-tools'),
      title: 'Rotas',
      entries: [
        const _PanelToolEntry(
          label: 'Histórico de rota',
          icon: Icons.route_outlined,
          detail: 'Consulta real',
          child: RoutesScreen(),
        ),
        const _PanelToolEntry(
          label: 'Replay',
          icon: Icons.replay_circle_filled_outlined,
          detail: 'Replay visual',
          child: RoutesScreen(),
        ),
        ..._placeholderEntries(
          moduleTitle: 'relatórios',
          items: const [
            (
              label: 'Paradas',
              icon: Icons.pause_circle_outline,
              description: 'Analise de paradas por periodo e local.',
            ),
            (
              label: 'Viagens',
              icon: Icons.luggage_outlined,
              description: 'Resumo de viagens com inicio e termino.',
            ),
            (
              label: 'Quilometragem',
              icon: Icons.speed_outlined,
              description: 'Consolidado de quilometragem rodada por veículo.',
            ),
            (
              label: 'Rota obrigatoria',
              icon: Icons.fact_check_outlined,
              description: 'Regras visuais para trajetos obrigatorios.',
            ),
            (
              label: 'Rota proibida',
              icon: Icons.block_outlined,
              description: 'Definicao visual de trajetos proibidos.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAlertsPanel() {
    return const AlertsScreen();
  }

  Widget _buildMaintenancePanel() {
    return const MaintenanceScreen();
  }

  Widget _buildGeofencesPanel() {
    return const GeofencesScreen();
  }

  Widget _buildTicketsPanel() {
    return CallsScreen(onClose: _closePanel);
  }

  Widget _buildCommunicationPanel() {
    return ZproCommunicationScreen(onClose: _closePanel);
  }

  Widget _buildAiOperationsPanel() {
    return IaScreen(onClose: _closePanel);
  }

  Widget _buildFinancePanel() {
    return _TraccarToolsPanel(
      key: const ValueKey('finance-tools'),
      title: 'Financeiro',
      entries: [
        const _PanelToolEntry(
          label: 'Clientes',
          icon: Icons.groups_outlined,
          detail: 'Carteira atual',
          child: ClientsScreen(),
        ),
        const _PanelToolEntry(
          label: 'cobranças',
          icon: Icons.receipt_long_outlined,
          detail: 'Painel financeiro atual',
          child: FinanceScreen(),
        ),
        ..._placeholderEntries(
          moduleTitle: 'relatórios',
          items: const [
            (
              label: 'Pix',
              icon: Icons.pix_outlined,
              description: 'Estrutura visual de cobranças por Pix.',
            ),
            (
              label: 'Boleto',
              icon: Icons.description_outlined,
              description: 'Estrutura visual de cobranças por boleto.',
            ),
            (
              label: 'Cartao',
              icon: Icons.credit_card_outlined,
              description: 'Estrutura visual de cobranças por cartao.',
            ),
            (
              label: 'Recorrencias',
              icon: Icons.autorenew_outlined,
              description: 'Controle visual de planos recorrentes.',
            ),
            (
              label: 'Inadimplentes',
              icon: Icons.warning_rounded,
              description: 'Painel de clientes inadimplentes.',
            ),
            (
              label: 'Vencimentos',
              icon: Icons.event_note_outlined,
              description: 'Agenda visual de vencimentos financeiros.',
            ),
            (
              label: 'relatórios financeiros',
              icon: Icons.bar_chart_outlined,
              description: 'Conjunto de relatórios financeiros.',
            ),
            (
              label: 'Split/comissoes',
              icon: Icons.call_split_outlined,
              description: 'Estrutura visual para split e comissoes.',
            ),
            (
              label: 'Integracao Asaas futuramente',
              icon: Icons.link_outlined,
              description: 'Integracao sera plugada em etapa futura.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInventoryPanel() {
    return const InventoryScreen();
  }

  Widget _buildMdvrPanel() {
    return const MdvrDevicesScreen();
  }

  Widget _buildTelemetryDemoPanel() {
    return _TraccarToolsPanel(
      key: const ValueKey('telemetry-demo-tools'),
      title: 'Telemetria',
      entries: [
        const _PanelToolEntry(
          label: 'Frota em tempo real',
          icon: Icons.directions_car_outlined,
          detail: 'Visão operacional',
          child: VehiclesScreen(),
        ),
        const _PanelToolEntry(
          label: 'Dispositivos',
          icon: Icons.gps_fixed_outlined,
          detail: 'Visão operacional em tempo real',
          child: DevicesScreen(),
        ),
        const _PanelToolEntry(
          label: 'Comandos',
          icon: Icons.terminal_outlined,
          detail: 'ações remotas no equipamento',
          child: CommandsScreen(),
        ),
        const _PanelToolEntry(
          label: 'Sensores',
          icon: Icons.sensors_outlined,
          detail: 'Dados enviados pelo equipamento',
          child: TelemetrySensorsScreen(),
        ),
        if (kEnableFormulaTelemetryDemo)
          const _PanelToolEntry(
            label: 'Demo Formula 1',
            icon: Icons.sports_motorsports_outlined,
            detail: 'Opcional para apresentacao',
            child: _TelemetryRaceShowcaseScreen(),
          ),
      ],
    );
  }

  Widget _buildCommandsPanel() {
    return const CommandsScreen();
  }

  Widget _buildLogsPanel() {
    return const HistoryScreen();
  }

  Widget _buildReportsPanel() {
    return ReportsScreen(onClose: _closePanel);
  }

  Widget _buildAutomationsPanel() {
    return AutomationsScreen(onClose: _closePanel);
  }

  Widget _buildAutomationsPanelLegacy() {
    return _TraccarToolsPanel(
      key: const ValueKey('automations-tools'),
      title: 'Automações',
      entries: const [
        _PanelToolEntry(
          label: 'Regras automaticas',
          icon: Icons.rule_folder_outlined,
          detail: 'Cadastro ativo de regras',
          child: _AutomationWorkbenchScreen(
            title: 'Regras automaticas',
            description: 'Cria regras operacionais com condicoes e acao.',
            scope: 'rules',
            actionType: 'evento',
          ),
        ),
        _PanelToolEntry(
          label: 'Gatilhos',
          icon: Icons.flash_on_outlined,
          detail: 'Definicao ativa de gatilhos',
          child: _AutomationWorkbenchScreen(
            title: 'Gatilhos',
            description: 'Define os eventos que disparam automacao.',
            scope: 'triggers',
            actionType: 'evento',
          ),
        ),
        _PanelToolEntry(
          label: 'ações',
          icon: Icons.playlist_add_check_outlined,
          detail: 'Catálogo ativo de ações',
          child: _AutomationWorkbenchScreen(
            title: 'ações',
            description: 'Configura a resposta automática após cada gatilho.',
            scope: 'actions',
            actionType: 'evento',
          ),
        ),
        _PanelToolEntry(
          label: 'Webhooks',
          icon: Icons.webhook_outlined,
          detail: 'Teste ativo de webhook',
          child: _AutomationWorkbenchScreen(
            title: 'Webhooks',
            description:
                'Configura e testa callbacks para integrações externas.',
            scope: 'webhooks',
            actionType: 'webhook',
          ),
        ),
        _PanelToolEntry(
          label: 'Alertas automáticos',
          icon: Icons.notification_important_outlined,
          detail: 'Automação ativa de alertas',
          child: _AutomationWorkbenchScreen(
            title: 'Alertas automáticos',
            description:
                'Dispara alertas automáticos quando o gatilho ocorrer.',
            scope: 'alerts',
            actionType: 'alerta',
          ),
        ),
        _PanelToolEntry(
          label: 'WhatsApp automático',
          icon: Icons.forum_outlined,
          detail: 'Automação ativa de WhatsApp',
          child: _AutomationWorkbenchScreen(
            title: 'WhatsApp automático',
            description:
                'Envia mensagem automática para o destino configurado.',
            scope: 'whatsapp',
            actionType: 'whatsapp',
          ),
        ),
        _PanelToolEntry(
          label: 'Criação automática de chamado',
          icon: Icons.add_box_outlined,
          detail: 'Abertura automática ativa',
          child: _AutomationWorkbenchScreen(
            title: 'Criação automática de chamado',
            description: 'Abre chamado automaticamente com dados do evento.',
            scope: 'tickets',
            actionType: 'ticket',
          ),
        ),
        _PanelToolEntry(
          label: 'Relatórios automáticos',
          icon: Icons.description_outlined,
          detail: 'Agendamento ativo de relatórios',
          child: _AutomationWorkbenchScreen(
            title: 'Relatórios automáticos',
            description: 'Agenda e testa geração automática de relatórios.',
            scope: 'reports',
            actionType: 'relatorio',
          ),
        ),
        _PanelToolEntry(
          label: 'Integração MackFlow/Bridge',
          icon: Icons.link_outlined,
          detail: 'Registro ativo de integração',
          child: _AutomationWorkbenchScreen(
            title: 'Integração MackFlow/Bridge',
            description:
                'Registra payloads de integração para uso do Bridge.',
            scope: 'bridge',
            actionType: 'evento',
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsPanel() {
    return SettingsScreen(
      onLogout: () {
        _handleLogout();
      },
    );
  }
}

class _OperationalMap extends StatelessWidget {
  const _OperationalMap({
    required this.snapshots,
    required this.selectedDeviceId,
    required this.selectedTrail,
    required this.selectedReplayPath,
    required this.selectedReplayPoint,
    required this.reportRoutePath,
    this.reportRouteMatchedSegments = const [],
    required this.reportRouteStart,
    required this.reportRouteEnd,
    required this.reportRouteActivePoint,
    required this.reportRouteActiveBearing,
    required this.mapMode,
    required this.mapType,
    required this.mapZoom,
    required this.trafficEnabled,
    required this.onMapCreated,
    required this.onCameraMove,
    required this.onMapTap,
    required this.onVehicleTap,
  });

  final List<_VehicleSnapshot> snapshots;
  final int? selectedDeviceId;
  final List<gmaps.LatLng> selectedTrail;
  final List<gmaps.LatLng> selectedReplayPath;
  final _ReplayPoint? selectedReplayPoint;
  final List<gmaps.LatLng> reportRoutePath;
  final List<List<gmaps.LatLng>> reportRouteMatchedSegments;
  final ReportRouteMapPoint? reportRouteStart;
  final ReportRouteMapPoint? reportRouteEnd;
  final ReportRouteMapPoint? reportRouteActivePoint;
  final double? reportRouteActiveBearing;
  final VisualMapMode mapMode;
  final gmaps.MapType mapType;
  final double mapZoom;
  final bool trafficEnabled;
  final ValueChanged<gmaps.GoogleMapController> onMapCreated;
  final ValueChanged<gmaps.CameraPosition> onCameraMove;
  final VoidCallback onMapTap;
  final ValueChanged<_VehicleSnapshot> onVehicleTap;
  static const double clusterZoomThreshold = 11.0;
  static const double _clusterGridSize = 0.035;

  static const String _cleanMapStyle = '''
[
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.business","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.government","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.medical","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.park","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.place_of_worship","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.school","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.sports_complex","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]}
]
''';

  static const String _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#1f2835"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#a8bedb"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#111827"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.park","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#233247"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#c8d4e4"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#34506d"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#17202b"}]}
]
''';

  static final Map<int, Future<Map<_VehicleMarkerIconKey, gmaps.BitmapDescriptor>>>
      _vehicleMarkerIconsFutureByTier = {};

  // Escala suave do ícone do veículo conforme o zoom (em vez de saltos
  // grandes entre poucas faixas fixas) — mesmo espírito do zoom por
  // velocidade da câmera chase-cam. Arredonda pro inteiro mais próximo só
  // pra não gerar um bitmap novo a cada micro-variação de zoom.
  static int _zoomIconTier(double zoom) => zoom.round().clamp(6, 20);
  static double _iconSizeForTier(int tier) {
    const minZoom = 9.0;
    const maxZoom = 18.0;
    const minSize = 36.0;
    const maxSize = 58.0;
    final t = ((tier - minZoom) / (maxZoom - minZoom)).clamp(0.0, 1.0);
    return minSize + (maxSize - minSize) * t;
  }
  static final Map<int, Future<gmaps.BitmapDescriptor>>
      _replayRouteMarkerFutureByBucket =
      <int, Future<gmaps.BitmapDescriptor>>{};
  static const double _replayRouteMarkerRotationOffset = 0;
  // Cache de labels dos veículos: chave = "id_speedLabel_colorValue"
  static final Map<String, gmaps.BitmapDescriptor> _vehicleLabelCache = {};
  // Cache de clusters por contagem (1-999)
  static final Map<int, gmaps.BitmapDescriptor> _clusterIconCache = {};

  static Future<Map<_VehicleMarkerIconKey, gmaps.BitmapDescriptor>>
      _loadVehicleMarkerIcons({double iconSize = 72}) async {
    final entries = <_VehicleOperationalStatus, Color>{
      _VehicleOperationalStatus.online: const Color(0xFF22C55E),
      _VehicleOperationalStatus.moving: const Color(0xFF22C55E),
      _VehicleOperationalStatus.alert: const Color(0xFFEF4444),
      _VehicleOperationalStatus.offline: const Color(0xFF9CA3AF),
      _VehicleOperationalStatus.noCommunication: const Color(0xFFF59E0B),
    };
    final vehicleImages = <_VehicleMarkerType, ui.Image?>{};
    for (final type in _VehicleMarkerType.values) {
      vehicleImages[type] = await _loadMarkerAsset(type.assetPath);
    }

    final icons = <_VehicleMarkerIconKey, gmaps.BitmapDescriptor>{};
    for (final statusEntry in entries.entries) {
      for (final type in _VehicleMarkerType.values) {
        for (int dir = 0; dir < 8; dir++) {
          final key = _VehicleMarkerIconKey(type, statusEntry.key, dir);
          final bytes = await _buildVehicleMarkerIconBytes(
            statusColor: statusEntry.value,
            vehicleImage: vehicleImages[type],
            course: dir * 45.0,
            iconSize: iconSize,
          );
          icons[key] = gmaps.BitmapDescriptor.bytes(bytes);
        }
      }
    }
    return icons;
  }

  static Future<ui.Image?> _loadMarkerAsset(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final codec = await instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List> _buildVehicleMarkerIconBytes({
    required Color statusColor,
    required ui.Image? vehicleImage,
    double course = 0,
    double iconSize = 72,
  }) async {
    final center = Offset(iconSize / 2, iconSize / 2);
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    if (vehicleImage != null) {
      // Rotaciona o carro no canvas antes de desenhar — garante direção
      // correta em todas as plataformas (web/mobile).
      final maxDim = vehicleImage.height > vehicleImage.width
          ? vehicleImage.height.toDouble()
          : vehicleImage.width.toDouble();
      final scale = 64 / maxDim;
      final w = vehicleImage.width * scale;
      final h = vehicleImage.height * scale;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(course * math.pi / 180);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawImageRect(
        vehicleImage,
        Rect.fromLTWH(
            0, 0, vehicleImage.width.toDouble(), vehicleImage.height.toDouble()),
        Rect.fromCenter(center: center, width: w, height: h),
        Paint()..isAntiAlias = true,
      );
      canvas.restore();
    } else {
      // Fallback: seta colorida rotacionada.
      final fill = Paint()
        ..color = statusColor
        ..style = PaintingStyle.fill;
      final stroke = Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round;
      // Seta base apontando para norte (cima). Rotação gira para a direção.
      final arrow = Path()
        ..moveTo(center.dx, 4)
        ..lineTo(center.dx - 13, iconSize - 6)
        ..lineTo(center.dx, iconSize - 16)
        ..lineTo(center.dx + 13, iconSize - 6)
        ..close();
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(course * math.pi / 180);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawPath(arrow, fill);
      canvas.drawPath(arrow, stroke);
      canvas.restore();
    }

    // Ponto de status fixo (não roda com o carro) — sempre canto inferior direito.
    final dot = Offset(iconSize - 11, iconSize - 11);
    canvas.drawCircle(dot, 7, Paint()..color = Colors.white);
    canvas.drawCircle(dot, 5, Paint()..color = statusColor);

    final image = await recorder
        .endRecording()
        .toImage(iconSize.toInt(), iconSize.toInt());
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    if (byteData == null) return Uint8List(0);
    return byteData.buffer.asUint8List();
  }

  static int _courseToBucket8(double? course) {
    if (course == null) return 0;
    return ((course + 22.5) / 45).floor() % 8;
  }

  // Bitmap de label flutuante: card branco com nome + velocidade,
  // 40px transparentes abaixo para posicionar acima do ícone do carro.
  static Future<Uint8List> _buildVehicleLabelBytes({
    required String name,
    required String speedLabel,
    required Color statusColor,
  }) async {
    const cardW = 190.0;
    const cardH = 44.0;
    const bottomPad = 44.0; // empurra label acima do ícone (72px, ancor 0.5,0.5)
    const totalH = cardH + bottomPad;
    const r = 9.0;

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    // Sombra suave
    final shadowPaint = Paint()
      ..color = const Color(0x22000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3, 3, cardW - 2, cardH - 1),
        const Radius.circular(r),
      ),
      shadowPaint,
    );

    // Fundo branco
    final rrect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(1, 1, cardW - 2, cardH - 2),
      const Radius.circular(r),
    );
    canvas.drawRRect(rrect, Paint()..color = Colors.white);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xFFDDE5F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Ponto de status
    canvas.drawCircle(
      const Offset(13, cardH / 2),
      5,
      Paint()..color = statusColor,
    );

    // Nome do veículo
    final namePainter = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(
          color: Color(0xFF1F2A44),
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.none,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: cardW - 26);
    namePainter.paint(canvas, const Offset(23, 6));

    // Velocidade / status
    final speedPainter = TextPainter(
      text: TextSpan(
        text: speedLabel,
        style: const TextStyle(
          color: Color(0xFF6B7C95),
          fontSize: 11,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.none,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: cardW - 26);
    speedPainter.paint(canvas, const Offset(23, 24));

    final image = await recorder
        .endRecording()
        .toImage(cardW.toInt(), totalH.toInt());
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    if (byteData == null) return Uint8List(0);
    return byteData.buffer.asUint8List();
  }

  // Badge circular para clusters: círculo azul com número branco.
  static Future<gmaps.BitmapDescriptor> _getClusterIcon(int count) async {
    if (_clusterIconCache.containsKey(count)) return _clusterIconCache[count]!;
    const size = 64.0;
    const center = Offset(size / 2, size / 2);
    const r = 28.0;
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    // Anel externo translúcido
    canvas.drawCircle(
        center, r + 6, Paint()..color = const Color(0x332F80FF));
    // Círculo sólido
    canvas.drawCircle(center, r, Paint()..color = const Color(0xFF2F80FF));
    // Borda branca
    canvas.drawCircle(
        center, r,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);

    // Número
    final label = count > 99 ? '99+' : '$count';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: label.length > 2 ? 14 : 17,
          fontWeight: FontWeight.w800,
          decoration: TextDecoration.none,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));

    final image =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final byteData =
        await image.toByteData(format: ImageByteFormat.png);
    final desc = gmaps.BitmapDescriptor.bytes(
        byteData?.buffer.asUint8List() ?? Uint8List(0));
    _clusterIconCache[count] = desc;
    return desc;
  }

  static int _replayRotationBucket(double? bearing) {
    // Bucket fino (3°) para o marcador girar de forma suave em vez de "saltar"
    // em degraus grandes — ainda cacheado por ângulo pra não recriar o bitmap à toa.
    const bucketSize = 3;
    final normalized = ((bearing ?? 0) % 360 + 360) % 360;
    final bucket = ((normalized / bucketSize).round() * bucketSize) % 360;
    return bucket.toInt();
  }

  static Future<gmaps.BitmapDescriptor> _loadReplayRouteMarkerIcon(
    double? bearing,
  ) async {
    final bytes = await _buildReplayRouteMarkerBytes(
      rotationDegrees: _replayRotationBucket(bearing).toDouble() +
          _replayRouteMarkerRotationOffset,
    );
    return gmaps.BitmapDescriptor.bytes(bytes);
  }

  static Future<Uint8List> _buildReplayRouteMarkerBytes({
    required double rotationDegrees,
  }) async {
    const iconSize = 64.0;
    const center = Offset(iconSize / 2, iconSize / 2);
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final shadowPaint = Paint()
      ..color = const Color(0xFF0F172A).withValues(alpha: 0.24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final bodyPaint = Paint()..color = const Color(0xFF2F80FF);
    final roofPaint = Paint()..color = const Color(0xFF1B5FD6);
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white;
    final glassPaint = Paint()..color = Colors.white.withAlpha(230);
    final wheelPaint = Paint()..color = const Color(0xFF0F172A).withAlpha(210);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationDegrees * math.pi / 180.0);

    // Silhueta do carro visto de cima: capô mais estreito na frente (topo),
    // alargando na traseira — traçada com curvas suaves em vez de retângulo puro.
    final carBody = Path()
      ..moveTo(-7, -17)
      ..quadraticBezierTo(-9, -17, -9, -11)
      ..lineTo(-11, -4)
      ..quadraticBezierTo(-12, 6, -11, 13)
      ..quadraticBezierTo(-10.5, 17, -6, 17)
      ..lineTo(6, 17)
      ..quadraticBezierTo(10.5, 17, 11, 13)
      ..quadraticBezierTo(12, 6, 11, -4)
      ..lineTo(9, -11)
      ..quadraticBezierTo(9, -17, 7, -17)
      ..close();
    canvas.drawPath(carBody.shift(const Offset(0, 2)), shadowPaint);
    canvas.drawPath(carBody, bodyPaint);
    canvas.drawPath(carBody, strokePaint);

    // Rodas (visíveis nas laterais, discretas).
    for (final dx in [-11.5, 11.5]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(dx, -6), width: 3, height: 8),
          const Radius.circular(1.5),
        ),
        wheelPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(dx, 8), width: 3, height: 8),
          const Radius.circular(1.5),
        ),
        wheelPaint,
      );
    }

    // Teto do carro (área central mais escura).
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, 1), width: 13, height: 20),
        const Radius.circular(6),
      ),
      roofPaint,
    );

    // Para-brisa dianteiro.
    canvas.drawPath(
      Path()
        ..moveTo(-5, -9)
        ..lineTo(5, -9)
        ..lineTo(4, -3)
        ..lineTo(-4, -3)
        ..close(),
      glassPaint,
    );

    // Vidro traseiro.
    canvas.drawPath(
      Path()
        ..moveTo(-4.5, 6)
        ..lineTo(4.5, 6)
        ..lineTo(5, 11)
        ..lineTo(-5, 11)
        ..close(),
      glassPaint,
    );

    canvas.restore();

    final image = await recorder
        .endRecording()
        .toImage(iconSize.toInt(), iconSize.toInt());
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    if (byteData == null) {
      return Uint8List(0);
    }
    return byteData.buffer.asUint8List();
  }

  String _clusterKey(gmaps.LatLng point) {
    final lat = (point.latitude / _clusterGridSize).floor();
    final lng = (point.longitude / _clusterGridSize).floor();
    return '$lat:$lng';
  }

  gmaps.LatLng _clusterCenter(List<_VehicleSnapshot> cluster) {
    var lat = 0.0;
    var lng = 0.0;
    for (final snapshot in cluster) {
      lat += snapshot.latLng.latitude;
      lng += snapshot.latLng.longitude;
    }
    return gmaps.LatLng(lat / cluster.length, lng / cluster.length);
  }

  @override
  Widget build(BuildContext context) {
    final iconTier = _zoomIconTier(mapZoom);
    final markerIconsFuture = _vehicleMarkerIconsFutureByTier.putIfAbsent(
      iconTier,
      () => _loadVehicleMarkerIcons(iconSize: _iconSizeForTier(iconTier)),
    );
    return FutureBuilder<Map<_VehicleMarkerIconKey, gmaps.BitmapDescriptor>>(
      future: markerIconsFuture,
      builder: (context, assetsSnapshot) {
        final markerIcons = assetsSnapshot.hasData
            ? assetsSnapshot.data!
            : const <_VehicleMarkerIconKey, gmaps.BitmapDescriptor>{};
        // Reaproveita o MESMO ícone do veículo usado no mapa ao vivo (imagem
        // de verdade, não o carrinho desenhado à mão) — só troca a direção
        // conforme o rumo do ponto ativo do replay.
        final replayVehicleSnapshot = selectedDeviceId == null
            ? null
            : snapshots
                .cast<_VehicleSnapshot?>()
                .firstWhere((s) => s?.device.id == selectedDeviceId,
                    orElse: () => null);
        final replayMarkerType =
            replayVehicleSnapshot?.markerType ?? _VehicleMarkerType.car;
        final replayBearing8 = _courseToBucket8(reportRouteActiveBearing);
        final replayRouteMarkerIcon = markerIcons[_VehicleMarkerIconKey(
              replayMarkerType,
              _VehicleOperationalStatus.moving,
              replayBearing8,
            )] ??
            gmaps.BitmapDescriptor.defaultMarkerWithHue(
              gmaps.BitmapDescriptor.hueAzure,
            );
        final snapshotsWithPosition = snapshots
            .where((snapshot) => snapshot.hasValidGps)
            .toList(growable: false);

        final initialTarget = snapshotsWithPosition.isEmpty
            ? const gmaps.LatLng(-23.55052, -46.633308)
            : snapshotsWithPosition.first.latLng;
        final selected = snapshotsWithPosition
            .where((snapshot) => snapshot.device.id == selectedDeviceId)
            .cast<_VehicleSnapshot?>()
            .firstOrNull;
        final selectedCenter = selected?.latLngOrNull;
        final mapStyle = switch (mapMode) {
          VisualMapMode.dark => _darkMapStyle,
          VisualMapMode.normal || VisualMapMode.premium => _cleanMapStyle,
        };
        final reportRouteMode = reportRoutePath.length > 1;
        final markers = <gmaps.Marker>{};
        final circles = <gmaps.Circle>{};
        final polylines = <gmaps.Polyline>{};
        final reportRouteActiveLatLng = reportRouteActivePoint == null
            ? null
            : gmaps.LatLng(
                reportRouteActivePoint!.latitude,
                reportRouteActivePoint!.longitude,
              );

        void addVehicleMarker(_VehicleSnapshot snapshot) {
          final isSelectedRouteVehicle = snapshot.device.id == selectedDeviceId;
          final markerPosition = isSelectedRouteVehicle
              ? (selectedReplayPoint?.latLng ??
                  reportRouteActiveLatLng ??
                  snapshot.latLng)
              : snapshot.latLng;
          final statusSummary = snapshot.speed != null
              ? '${snapshot.statusLabel} - ${snapshot.speedLabel}'
              : snapshot.statusLabel;
          final course = selectedReplayPoint?.course ??
              reportRouteActiveBearing ??
              snapshot.markerRotation;
          final bearing8 = _courseToBucket8(course);
          final markerIcon = markerIcons[_VehicleMarkerIconKey(
                snapshot.markerType, snapshot.operationalStatus, bearing8)] ??
              gmaps.BitmapDescriptor.defaultMarkerWithHue(snapshot.markerHue);
          markers.add(
            gmaps.Marker(
              markerId: gmaps.MarkerId('vehicle-${snapshot.device.id}'),
              position: markerPosition,
              anchor: const Offset(0.5, 0.5),
              consumeTapEvents: true,
              icon: markerIcon,
              infoWindow: gmaps.InfoWindow(
                title: '${snapshot.device.name} • $statusSummary',
              ),
              onTap: () => onVehicleTap(snapshot),
            ),
          );

          // Labels removidos — card de seleção e painel inferior já exibem as infos.
          final showLabel = false;
          if (showLabel) {
            final labelKey =
                '${snapshot.device.id}_${snapshot.speedLabel}_${snapshot.statusColor.value}';
            final cachedLabel = _vehicleLabelCache[labelKey];
            if (cachedLabel != null) {
              markers.add(
                gmaps.Marker(
                  markerId: gmaps.MarkerId('label-${snapshot.device.id}'),
                  position: markerPosition,
                  anchor: const Offset(0.5, 1.0),
                  consumeTapEvents: true,
                  icon: cachedLabel,
                  onTap: () => onVehicleTap(snapshot),
                ),
              );
            } else {
              _buildVehicleLabelBytes(
                name: snapshot.device.name,
                speedLabel: snapshot.speedLabel,
                statusColor: snapshot.statusColor,
              ).then((bytes) {
                _vehicleLabelCache[labelKey] =
                    gmaps.BitmapDescriptor.bytes(bytes);
              });
            }
          }
        }

        if (!reportRouteMode && mapZoom < clusterZoomThreshold) {
          final clusters = <String, List<_VehicleSnapshot>>{};
          for (final snapshot in snapshotsWithPosition) {
            if (snapshot.device.id == selectedDeviceId) {
              addVehicleMarker(snapshot);
              continue;
            }
            final key = _clusterKey(snapshot.latLng);
            clusters.putIfAbsent(key, () => <_VehicleSnapshot>[]).add(snapshot);
          }
          for (final entry in clusters.entries) {
            final cluster = entry.value;
            if (cluster.length == 1) {
              addVehicleMarker(cluster.first);
              continue;
            }
            final clusterCount = cluster.length;
            final clusterIcon = _clusterIconCache[clusterCount];
            markers.add(
              gmaps.Marker(
                markerId: gmaps.MarkerId('cluster-${entry.key}'),
                position: _clusterCenter(cluster),
                anchor: const Offset(0.5, 0.5),
                icon: clusterIcon ??
                    gmaps.BitmapDescriptor.defaultMarkerWithHue(
                        gmaps.BitmapDescriptor.hueAzure),
                infoWindow: gmaps.InfoWindow(
                  title: '$clusterCount ve\u00EDculos pr\u00F3ximos',
                ),
              ),
            );
            if (clusterIcon == null) {
              _getClusterIcon(clusterCount);
            }
          }
        } else if (!reportRouteMode) {
          for (final snapshot in snapshotsWithPosition) {
            addVehicleMarker(snapshot);
          }
        }

        final highlightedCenter = selectedReplayPoint?.latLng ??
            reportRouteActiveLatLng ??
            selectedCenter;

        final routePoints = reportRoutePath.length > 1
            ? reportRoutePath
            : (selectedReplayPath.length > 1
                ? selectedReplayPath
                : selectedTrail);
        if (selectedDeviceId != null && reportRouteMatchedSegments.isNotEmpty) {
          // Trajeto corrigido pelo OSRM: um segmento por trecho contínuo —
          // buraco de conexão real vira buraco visual, não reta falsa.
          for (var i = 0; i < reportRouteMatchedSegments.length; i++) {
            polylines.add(
              gmaps.Polyline(
                polylineId: gmaps.PolylineId('trail-$selectedDeviceId-seg$i'),
                points: reportRouteMatchedSegments[i],
                color: const Color(0xFF2F80FF).withValues(alpha: 0.62),
                width: 4,
              ),
            );
          }
        } else if (selectedDeviceId != null && routePoints.length > 1) {
          polylines.add(
            gmaps.Polyline(
              polylineId: gmaps.PolylineId('trail-$selectedDeviceId'),
              points: routePoints,
              color: const Color(0xFF2F80FF).withValues(alpha: 0.62),
              width: 4,
            ),
          );
        }

        if (reportRouteStart != null) {
          markers.add(
            gmaps.Marker(
              markerId: gmaps.MarkerId('route-start-${selectedDeviceId ?? 0}'),
              position: gmaps.LatLng(
                reportRouteStart!.latitude,
                reportRouteStart!.longitude,
              ),
              icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
                gmaps.BitmapDescriptor.hueGreen,
              ),
              infoWindow: const gmaps.InfoWindow(title: 'Inicio da rota'),
            ),
          );
        }

        if (reportRouteEnd != null) {
          markers.add(
            gmaps.Marker(
              markerId: gmaps.MarkerId('route-end-${selectedDeviceId ?? 0}'),
              position: gmaps.LatLng(
                reportRouteEnd!.latitude,
                reportRouteEnd!.longitude,
              ),
              icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
                gmaps.BitmapDescriptor.hueRed,
              ),
              infoWindow: const gmaps.InfoWindow(title: 'Fim da rota'),
            ),
          );
        }

        if (reportRouteMode &&
            selectedDeviceId != null &&
            reportRouteActiveLatLng != null) {
          markers.add(
            gmaps.Marker(
              markerId: gmaps.MarkerId('route-active-$selectedDeviceId'),
              position: reportRouteActiveLatLng,
              anchor: const Offset(0.5, 0.5),
              icon: replayRouteMarkerIcon,
              zIndexInt: 1000,
              infoWindow: const gmaps.InfoWindow(title: 'Ponto ativo da rota'),
            ),
          );
        }

        return gmaps.GoogleMap(
          style: mapStyle,
          initialCameraPosition: gmaps.CameraPosition(
            target: initialTarget,
            zoom: 13,
            tilt: 0,
          ),
          mapType: mapType,
          trafficEnabled: trafficEnabled,
          buildingsEnabled: true,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: false,
          rotateGesturesEnabled: true,
          tiltGesturesEnabled: false,
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
          onMapCreated: onMapCreated,
          onCameraMove: onCameraMove,
          onTap: (_) => onMapTap(),
          markers: markers,
          circles: circles,
          polylines: polylines,
        );
      },
    );
  }
}

class _MapDeviceCardsOverlay extends StatelessWidget {
  const _MapDeviceCardsOverlay({
    required this.snapshots,
    required this.selectedDeviceId,
    required this.sidebarOpen,
    required this.cardDensity,
    required this.onVehicleTap,
  });

  final List<_VehicleSnapshot> snapshots;
  final int? selectedDeviceId;
  final bool sidebarOpen;
  final VisualCardDensity cardDensity;
  final ValueChanged<_VehicleSnapshot> onVehicleTap;

  static const Offset _selectedAnchor = Offset(0.50, 0.40);
  static const List<Offset> _secondaryAnchors = <Offset>[
    Offset(0.26, 0.12),
    Offset(0.19, 0.36),
    Offset(0.74, 0.20),
    Offset(0.72, 0.52),
  ];

  @override
  Widget build(BuildContext context) {
    final positionedSnapshots = snapshots
        .where((snapshot) => snapshot.hasValidGps)
        .toList(growable: false);
    if (positionedSnapshots.isEmpty) return const SizedBox.shrink();

    final compactDensity = cardDensity == VisualCardDensity.compact;
    final sidebarWidth = sidebarOpen ? (compactDensity ? 208.0 : 224.0) : 72.0;
    final visibleSnapshots =
        positionedSnapshots.take(5).toList(growable: false);
    final selectedSnapshot = visibleSnapshots
            .where((snapshot) => snapshot.device.id == selectedDeviceId)
            .cast<_VehicleSnapshot?>()
            .firstOrNull ??
        visibleSnapshots.first;
    final orderedSnapshots = <_VehicleSnapshot>[
      selectedSnapshot,
      ...visibleSnapshots.where(
        (snapshot) => snapshot.device.id != selectedSnapshot.device.id,
      ),
    ];
    final bottomInset =
        MediaQuery.sizeOf(context).width >= 1200 ? 324.0 : 284.0;

    return Positioned(
      left: 16 + sidebarWidth + 14,
      right: 86,
      top: 132,
      bottom: bottomInset,
      child: _SurfaceGuard(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
              return const SizedBox.shrink();
            }
            return Stack(
              children: [
                for (var index = 0; index < orderedSnapshots.length; index++)
                  () {
                    final snapshot = orderedSnapshots[index];
                    final anchor = index == 0
                        ? _selectedAnchor
                        : _secondaryAnchors[
                            (index - 1) % _secondaryAnchors.length];
                    final highlighted = index == 0;
                    final cardWidth = highlighted
                        ? (compactDensity ? 196.0 : 228.0)
                        : (compactDensity ? 150.0 : 174.0);
                    final cardHeight = highlighted
                        ? (compactDensity ? 68.0 : 82.0)
                        : (compactDensity ? 52.0 : 62.0);
                    final left =
                        (constraints.maxWidth * anchor.dx - cardWidth / 2)
                            .clamp(0.0, constraints.maxWidth - cardWidth)
                            .toDouble();
                    final top =
                        (constraints.maxHeight * anchor.dy - cardHeight / 2)
                            .clamp(0.0, constraints.maxHeight - cardHeight)
                            .toDouble();
                    return Positioned(
                      left: left,
                      top: top,
                      child: _MapDeviceCard(
                        snapshot: snapshot,
                        selected: snapshot.device.id == selectedDeviceId,
                        highlighted: highlighted,
                        compact: compactDensity,
                        onTap: () => onVehicleTap(snapshot),
                      ),
                    );
                  }(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MapDeviceCard extends StatelessWidget {
  const _MapDeviceCard({
    required this.snapshot,
    required this.selected,
    required this.highlighted,
    required this.compact,
    required this.onTap,
  });

  final _VehicleSnapshot snapshot;
  final bool selected;
  final bool highlighted;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = snapshot.statusColor;
    final speedOrState = snapshot.speed != null
        ? '${snapshot.statusLabel} - ${snapshot.speedLabel}'
        : snapshot.statusLabel;
    if (highlighted) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            width: compact ? 196 : 228,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 14,
              vertical: compact ? 9 : 11,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? const Color(0xFFCFE2FF)
                    : const Color(0xFFE3EAF4),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF152A47).withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  snapshot.device.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF1F2A44),
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 14 : 16,
                    height: 1.02,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        speedOrState,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF334155),
                          fontWeight: FontWeight.w800,
                          fontSize: compact ? 12 : 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          width: compact ? 150 : 174,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: selected ? 0.96 : 0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? const Color(0xFF76B4FF)
                  : statusColor.withValues(alpha: 0.40),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF152A47).withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 28 : 32,
                height: compact ? 28 : 32,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.directions_car_filled_rounded,
                  color: statusColor,
                  size: compact ? 17 : 19,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      snapshot.device.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF1F2A44),
                        fontWeight: FontWeight.w900,
                        fontSize: compact ? 14 : 16,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      speedOrState,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: compact ? 12 : 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurfaceGuard extends StatelessWidget {
  const _SurfaceGuard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(child: child);
  }
}

ThemeData _panelLightTheme(BuildContext context) {
  final base = Theme.of(context);
  const primary = Color(0xFF176EEB);
  const text = Color(0xFF1F2A44);
  const muted = Color(0xFF60718D);
  const surface = Color(0xFFFFFFFF);
  const field = Color(0xFFF7F9FD);
  const border = Color(0xFFDDE5F0);

  final scheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: primary,
    secondary: const Color(0xFF37C1A3),
    surface: surface,
    outline: border,
  );

  return base.copyWith(
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: surface,
    cardColor: surface,
    dividerColor: border,
    textTheme: base.textTheme.apply(
      bodyColor: text,
      displayColor: text,
    ),
    iconTheme: const IconThemeData(color: Color(0xFF526684)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: field,
      labelStyle: const TextStyle(color: muted),
      hintStyle: const TextStyle(color: Color(0xFF8A99AD)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 1.2),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Color(0xFF526684),
      textColor: text,
      selectedColor: primary,
      selectedTileColor: Color(0xFFE7F0FF),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      textStyle: const TextStyle(color: text),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: border),
      ),
    ),
    dropdownMenuTheme: const DropdownMenuThemeData(
      textStyle: TextStyle(color: text),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
    ),
  );
}

class _RouteReplayStatusCard extends StatelessWidget {
  const _RouteReplayStatusCard({
    required this.visible,
    required this.ignition,
    required this.motion,
    required this.batteryLabel,
    required this.satellites,
    required this.signalLabel,
    required this.odometerKm,
    required this.hourmeterHours,
    this.tireReadings = const [],
  });

  final bool visible;
  final bool? ignition;
  final bool? motion;
  final String? batteryLabel;
  final double? satellites;
  final String? signalLabel;
  final double? odometerKm;
  final double? hourmeterHours;
  final List<TireReading> tireReadings;

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      right: visible ? 20 : -220,
      top: 100,
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: visible ? 1 : 0,
          child: PointerInterceptor(
            child: Container(
              width: 190,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFDDE5F0)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    _ReplayStatusGroup(
                      title: 'Status do veículo',
                      rows: [
                        _ReplayStatusRow(
                          icon: Icons.power_settings_new_rounded,
                          label: 'Ignição',
                          active: ignition,
                        ),
                        const SizedBox(height: 6),
                        _ReplayStatusRow(
                          icon: Icons.directions_car_filled_rounded,
                          label: 'Movimento',
                          active: motion,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 10),
                    _ReplayStatusGroup(
                      title: 'Energia',
                      rows: [
                        _ReplayStatusValueRow(
                          icon: Icons.battery_std_rounded,
                          label: 'Bateria',
                          value: (batteryLabel == null || batteryLabel!.trim().isEmpty)
                              ? 'Sem dado'
                              : batteryLabel!,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 10),
                    _ReplayStatusGroup(
                      title: 'Comunicação',
                      rows: [
                        _ReplayStatusValueRow(
                          icon: Icons.satellite_alt_rounded,
                          label: 'Satélites',
                          value: satellites == null
                              ? 'Sem dado'
                              : satellites!.toStringAsFixed(0),
                        ),
                        _ReplayStatusValueRow(
                          icon: Icons.signal_cellular_alt_rounded,
                          label: 'Sinal',
                          value: (signalLabel == null || signalLabel!.trim().isEmpty)
                              ? 'Sem dado'
                              : signalLabel!,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 10),
                    _ReplayStatusGroup(
                      title: 'Operacional',
                      rows: [
                        _ReplayStatusValueRow(
                          icon: Icons.speed_outlined,
                          label: 'Odômetro',
                          value: odometerKm == null
                              ? 'Sem dado'
                              : '${odometerKm!.toStringAsFixed(1)} km',
                        ),
                        _ReplayStatusValueRow(
                          icon: Icons.timer_outlined,
                          label: 'Horímetro',
                          value: hourmeterHours == null
                              ? 'Sem dado'
                              : '${hourmeterHours!.toStringAsFixed(1)} h',
                        ),
                      ],
                    ),
                    if (tireReadings.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 10),
                      _TireDiagramGroup(readings: tireReadings),
                    ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TireDiagramGroup extends StatelessWidget {
  const _TireDiagramGroup({required this.readings});

  final List<TireReading> readings;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pneus (TPMS)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2A44),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final reading in readings) _TireChip(reading: reading),
            ],
          ),
        ],
      ),
    );
  }
}

class _TireChip extends StatelessWidget {
  const _TireChip({required this.reading});

  final TireReading reading;

  @override
  Widget build(BuildContext context) {
    final color =
        reading.isLowBattery ? const Color(0xFFE0533D) : const Color(0xFF2F9E5C);
    return Container(
      width: 78,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.tire_repair_rounded, size: 16, color: color),
          const SizedBox(height: 2),
          Text(
            'Pneu ${reading.index}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2A44),
            ),
          ),
          Text(
            reading.pressureRaw == null ? '—' : '${reading.pressureRaw} psi',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            reading.temperatureC == null ? '—' : '${reading.temperatureC}°C',
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFF4B5A72),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplayStatusGroup extends StatelessWidget {
  const _ReplayStatusGroup({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2A44),
            ),
          ),
          const SizedBox(height: 10),
          for (final row in rows) ...[row, const SizedBox(height: 8)],
        ],
      ),
    );
  }
}

class _ReplayStatusValueRow extends StatelessWidget {
  const _ReplayStatusValueRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF4B5A72)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF243044),
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2A44),
          ),
        ),
      ],
    );
  }
}

class _ReplayStatusRow extends StatelessWidget {
  const _ReplayStatusRow({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool? active;

  @override
  Widget build(BuildContext context) {
    final color = active == null
        ? const Color(0xFF94A3B8)
        : (active! ? const Color(0xFF16A34A) : const Color(0xFFDC2626));
    final text = active == null ? 'Sem dado' : (active! ? 'Ligada' : 'Desligada');
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF243044),
            ),
          ),
        ),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _LiveGaugesBar extends StatelessWidget {
  const _LiveGaugesBar({
    required this.vehicleName,
    required this.onClose,
  });

  final String vehicleName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      left: 222,
      right: 20,
      bottom: 20,
      child: PointerInterceptor(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFD6E0EE)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF111827).withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      vehicleName.isEmpty
                          ? 'Telemetria ao vivo'
                          : 'Telemetria ao vivo • $vehicleName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2A44),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(999),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Color(0xFF5B6B84),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteReplaySpeedGauge extends StatelessWidget {
  const _RouteReplaySpeedGauge({
    required this.visible,
    required this.speedKmh,
    required this.rpm,
    required this.sidebarOpen,
    required this.sidebarVisible,
  });

  final bool visible;
  final double? speedKmh;
  final double? rpm;
  final bool sidebarOpen;
  final bool sidebarVisible;

  @override
  Widget build(BuildContext context) {
    final sidebarLeft = !sidebarVisible ? 20.0 : (sidebarOpen ? 222.0 : 90.0);
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      left: visible ? sidebarLeft : sidebarLeft - 180,
      top: 100,
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: visible ? 1 : 0,
          child: PointerInterceptor(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 170,
                  height: 170,
                  child: DialGauge(
                    label: 'km/h',
                    unit: '',
                    value: speedKmh ?? 0,
                    max: 240,
                    color: const Color(0xFF2D8CFF),
                    ticks: const [0, 40, 80, 120, 160, 200, 240],
                    loading: false,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 170,
                  height: 170,
                  child: DialGauge(
                    label: 'RPM',
                    unit: 'x1000',
                    value: rpm ?? 0,
                    max: 8,
                    color: const Color(0xFFEF4444),
                    ticks: const [0, 2, 4, 6, 8],
                    loading: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteReplayControls extends StatelessWidget {
  const _RouteReplayControls({
    required this.visible,
    required this.sidebarOpen,
    required this.sidebarVisible,
    required this.playing,
    required this.camera3dEnabled,
    required this.total,
    required this.index,
    required this.vehicleName,
    required this.onToggle3d,
    required this.onPrevious,
    required this.onToggle,
    required this.onNext,
    required this.onChanged,
  });

  final bool visible;
  final bool sidebarOpen;
  final bool sidebarVisible;
  final bool playing;
  final bool camera3dEnabled;
  final int total;
  final int index;
  final String vehicleName;
  final VoidCallback onToggle3d;
  final VoidCallback onPrevious;
  final VoidCallback onToggle;
  final VoidCallback onNext;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeTotal = total <= 0 ? 1 : total;
    final boundedIndex = index.clamp(0, safeTotal - 1).toInt();
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      left: 222,
      right: 20,
      bottom: visible ? 20 : -180,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: visible ? 1 : 0,
          child: PointerInterceptor(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFD6E0EE)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF111827).withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              vehicleName.isEmpty
                                  ? 'Replay da rota'
                                  : 'Replay da rota • $vehicleName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F2A44),
                              ),
                            ),
                          ),
                          Text(
                            '${boundedIndex + 1}/$safeTotal',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF667792),
                            ),
                          ),
                          const SizedBox(width: 10),
                          InkWell(
                            onTap: onToggle3d,
                            borderRadius: BorderRadius.circular(999),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: camera3dEnabled
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFFF4F7FB),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: camera3dEnabled
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFFD6E0EE),
                                ),
                              ),
                              child: Text(
                                '3D',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: camera3dEnabled
                                      ? Colors.white
                                      : const Color(0xFF5B6B84),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _ReplayControlButton(
                            icon: Icons.skip_previous_rounded,
                            onTap: total > 0 ? onPrevious : null,
                          ),
                          const SizedBox(width: 8),
                          _ReplayControlButton(
                            icon: playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            onTap: total > 1 ? onToggle : null,
                            highlighted: true,
                          ),
                          const SizedBox(width: 8),
                          _ReplayControlButton(
                            icon: Icons.skip_next_rounded,
                            onTap: total > 0 ? onNext : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 7,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 14,
                                ),
                              ),
                              child: Slider(
                                value: boundedIndex.toDouble(),
                                min: 0,
                                max: math.max(0, safeTotal - 1).toDouble(),
                                onChanged: total > 1 ? onChanged : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReplayControlButton extends StatelessWidget {
  const _ReplayControlButton({
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color:
              highlighted ? const Color(0xFF2F80FF) : const Color(0xFFF3F6FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                highlighted ? const Color(0xFF2F80FF) : const Color(0xFFD6E0EE),
          ),
        ),
        child: Icon(
          icon,
          size: 22,
          color: !enabled
              ? const Color(0xFFB5C1D2)
              : (highlighted ? Colors.white : const Color(0xFF1F2A44)),
        ),
      ),
    );
  }
}

class _TopSearchBar extends StatelessWidget {
  const _TopSearchBar({
    required this.brand,
    required this.logoMode,
    required this.hideLogoOnFullMap,
    required this.profileName,
    required this.profileDetail,
    required this.compactProfileMenu,
    required this.kpis,
    required this.activeFilter,
    required this.onKpiTap,
    required this.onMenuTap,
    required this.menuOpen,
    required this.alertCount,
    required this.panelOpen,
    required this.activeTitle,
    required this.activeSubtitle,
    required this.onRefresh,
    required this.onClosePanel,
    required this.onLogout,
    // extra params from extended call-site (unused in build)
    this.cardDensity,
    this.sidebarVisible = true,
    this.onOpenSettingsPanel,
    this.showStatusCards = false,
    this.noCommunicationCount = 0,
    this.showMapQuickActions = false,
    this.mapType,
    this.trafficEnabled,
    this.onMapTypeChanged,
    this.onTrafficToggle,
    this.onRecenter,
    this.onRefreshPositions,
    this.onFilterSelected,
    this.onClearFilters,
    this.onAiTap,
    this.aiPanelOpen = false,
  });

  final WhiteLabelConfig brand;
  final VisualLogoMode logoMode;
  final bool hideLogoOnFullMap;
  final String profileName;
  final String profileDetail;
  final bool compactProfileMenu;
  final _FleetKpis kpis;
  final _KpiFilter? activeFilter;
  final ValueChanged<_KpiFilter> onKpiTap;
  final VoidCallback onMenuTap;
  final bool menuOpen;
  final int alertCount;
  final bool panelOpen;
  final String? activeTitle;
  final String activeSubtitle;
  final VoidCallback onRefresh;
  final VoidCallback onClosePanel;
  final VoidCallback onLogout;
  final VisualCardDensity? cardDensity;
  final bool sidebarVisible;
  final VoidCallback? onOpenSettingsPanel;
  final bool showStatusCards;
  final int noCommunicationCount;
  final bool showMapQuickActions;
  final gmaps.MapType? mapType;
  final bool? trafficEnabled;
  final ValueChanged<gmaps.MapType>? onMapTypeChanged;
  final VoidCallback? onTrafficToggle;
  final VoidCallback? onRecenter;
  final VoidCallback? onRefreshPositions;
  final ValueChanged<_KpiFilter>? onFilterSelected;
  final VoidCallback? onClearFilters;
  final VoidCallback? onAiTap;
  final bool aiPanelOpen;

  @override
  Widget build(BuildContext context) {
    final title = activeTitle?.trim().isNotEmpty == true
        ? activeTitle!.trim()
        : 'Operacao';
    final brandName =
        brand.appName.trim().isEmpty ? 'SouTracking' : brand.appName.trim();
    final brandLogoAsset = brand.logoAsset?.trim() ?? '';
    final hasBrandLogo = brandLogoAsset.isNotEmpty;
    final hideBrand = sidebarVisible ||
        (logoMode == VisualLogoMode.hideOnFullMap && hideLogoOnFullMap);
    final compactLogo = logoMode == VisualLogoMode.compact;
    final logoHeight = compactLogo ? 18.0 : 24.0;
    final brandWidth = compactLogo ? 178.0 : (hasBrandLogo ? 236.0 : 186.0);
    final isCompactDensity = cardDensity == VisualCardDensity.compact;
    final sidebarLeft = isCompactDensity ? 12.0 : 16.0;
    final sidebarW = menuOpen
        ? (isCompactDensity ? 190.0 : 206.0)
        : (isCompactDensity ? 52.0 : 56.0);
    final topBarLeft =
        sidebarVisible ? sidebarLeft + sidebarW + 10 : 16.0;

    return Positioned.fill(
      child: Stack(
        children: [
        // ── LEFT GROUP: sidebar toggle + optional logo + search ──
        AnimatedPositioned(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          left: topBarLeft,
          top: 16,
          child: _SurfaceGuard(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _GlassButton(
                  tooltip: menuOpen ? 'Recolher menu' : 'Expandir menu',
                  icon: Icons.apps_rounded,
                  onTap: onMenuTap,
                ),
                if (!hideBrand) ...[
                  const SizedBox(width: 10),
                  _GlassSurface(
                    width: brandWidth,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: hasBrandLogo
                              ? Image.asset(
                                  brandLogoAsset,
                                  height: logoHeight,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.centerLeft,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Text(
                                      brandName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: const Color(0xFF1F2A44),
                                        fontWeight: FontWeight.w900,
                                        fontSize: compactLogo ? 13 : 16,
                                      ),
                                    );
                                  },
                                )
                              : Text(
                                  brandName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: const Color(0xFF1F2A44),
                                    fontWeight: FontWeight.w900,
                                    fontSize: compactLogo ? 13 : 16,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(width: 10),
                _GlassButton(
                  tooltip: 'Buscar',
                  icon: Icons.search_rounded,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),

        // ── CENTER GROUP: KPI chips or panel title — FIXED at screen center ──
        Positioned(
          left: 0,
          right: 0,
          top: 16,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: panelOpen
                  ? _SurfaceGuard(
                      child: _GlassSurface(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFF176EEB)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(
                                Icons.dashboard_customize_outlined,
                                color: Color(0xFF176EEB),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 280),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF1F2A44),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    activeSubtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF60718D),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Atualizar dados',
                              visualDensity: VisualDensity.compact,
                              onPressed: onRefresh,
                              icon: const Icon(
                                Icons.refresh_rounded,
                                color: Color(0xFF52627C),
                                size: 20,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Fechar painel',
                              visualDensity: VisualDensity.compact,
                              onPressed: onClosePanel,
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFF52627C),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _SurfaceGuard(
                      child: _KpiStrip(
                        kpis: kpis,
                        activeFilter: activeFilter,
                        onTap: onKpiTap,
                      ),
                    ),
            ),
          ),
        ),

        // ── RIGHT GROUP: notifications + map layers + avatar ──
        Positioned(
          right: 16,
          top: 16,
          child: _SurfaceGuard(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TopIcon(
                  icon: Icons.notifications_none_outlined,
                  count: alertCount > 0 ? alertCount : null,
                ),
                const SizedBox(width: 10),
                _MapLayersButton(
                  mapType: mapType,
                  trafficEnabled: trafficEnabled,
                  onMapTypeChanged: onMapTypeChanged,
                  onTrafficToggle: onTrafficToggle,
                  onRecenter: onRecenter,
                ),
                const SizedBox(width: 10),
                _ProfileMenuButton(
                  onLogout: onLogout,
                  profileName: profileName,
                  profileDetail: profileDetail,
                  compactMenu: compactProfileMenu,
                  avatarOnly: true,
                ),
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }
}

class _TopSearchToggleField extends StatefulWidget {
  const _TopSearchToggleField({this.compact = false});

  final bool compact;

  @override
  State<_TopSearchToggleField> createState() => _TopSearchToggleFieldState();
}

class _TopSearchToggleFieldState extends State<_TopSearchToggleField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _expanded) {
        setState(() => _expanded = false);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _expand() {
    if (_expanded) return;
    setState(() => _expanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _collapse() {
    if (!_expanded) return;
    _focusNode.unfocus();
    setState(() => _expanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final expandedWidth = widget.compact ? 220.0 : 300.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: _expanded ? expandedWidth : 44,
      child: _GlassSurface(
        padding: EdgeInsets.symmetric(
          horizontal: _expanded ? 10 : 0,
          vertical: _expanded ? 4 : 0,
        ),
        child: _expanded
            ? Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    size: 16,
                    color: Color(0xFF60718D),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onTapOutside: (_) => _collapse(),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Buscar',
                        hintStyle: TextStyle(
                          color: Color(0xFF8A99AD),
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                      style: const TextStyle(
                        color: Color(0xFF1F2A44),
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar busca',
                    visualDensity: VisualDensity.compact,
                    constraints:
                        const BoxConstraints(minWidth: 30, minHeight: 30),
                    padding: EdgeInsets.zero,
                    onPressed: _collapse,
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Color(0xFF60718D),
                    ),
                  ),
                ],
              )
            : IconButton(
                tooltip: 'Buscar',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: _expand,
                icon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Color(0xFF60718D),
                ),
              ),
      ),
    );
  }
}

class _MapKpiCard extends StatelessWidget {
  const _MapKpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final int value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: _GlassSurface(
          width: 148,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          borderColor:
              selected ? const Color(0xFFBBD7FF) : const Color(0xFFDDE6F2),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF60718D),
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      '$value',
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFF0B63D8)
                            : const Color(0xFF1F2A44),
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        height: 0.95,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF60718D),
                        fontWeight: FontWeight.w700,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileMenuButton extends StatelessWidget {
  const _ProfileMenuButton({
    required this.onLogout,
    required this.profileName,
    required this.profileDetail,
    required this.compactMenu,
    this.avatarOnly = false,
    this.showQuickActions = false,
    this.onFilterSelected,
    this.onClearFilters,
    this.mapType,
    this.trafficEnabled,
    this.onMapTypeChanged,
    this.onTrafficToggle,
    this.onRecenter,
    this.onRefreshPositions,
    this.onOpenQuickSettings,
  });

  final VoidCallback onLogout;
  final String profileName;
  final String profileDetail;
  final bool compactMenu;
  final bool avatarOnly;
  final bool showQuickActions;
  final ValueChanged<_KpiFilter>? onFilterSelected;
  final VoidCallback? onClearFilters;
  final gmaps.MapType? mapType;
  final bool? trafficEnabled;
  final ValueChanged<gmaps.MapType>? onMapTypeChanged;
  final VoidCallback? onTrafficToggle;
  final VoidCallback? onRecenter;
  final VoidCallback? onRefreshPositions;
  final VoidCallback? onOpenQuickSettings;

  static const String _profileMenuKey = 'my-profile';
  static const String _quickSettingsKey = 'quick-settings';
  static const String _filterOnlineKey = 'filter-online';
  static const String _filterOfflineKey = 'filter-offline';
  static const String _filterMovingKey = 'filter-moving';
  static const String _filterAlertsKey = 'filter-alerts';
  static const String _filterNoComKey = 'filter-no-com';
  static const String _filterClearKey = 'filter-clear';
  static const String _mapNormalKey = 'map-normal';
  static const String _mapSatelliteKey = 'map-satellite';
  static const String _mapHybridKey = 'map-hybrid';
  static const String _mapTrafficKey = 'map-traffic';
  static const String _mapRecenterKey = 'map-recenter';
  static const String _mapRefreshKey = 'map-refresh';
  static const String _logoutMenuKey = 'logout';

  @override
  Widget build(BuildContext context) {
    final displayName =
        profileName.trim().isEmpty ? 'Usuario' : profileName.trim();
    final displayDetail =
        profileDetail.trim().isEmpty ? 'Conta SouTracking' : profileDetail;
    final width = avatarOnly ? 44.0 : (compactMenu ? 186.0 : 218.0);

    return PopupMenuButton<String>(
      tooltip: 'Menu do perfil',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      color: const Color(0xFFFDFEFF),
      elevation: 14,
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFD8E3F2)),
      ),
      onSelected: (value) {
        switch (value) {
          case _logoutMenuKey:
            onLogout();
            return;
          case _quickSettingsKey:
            onOpenQuickSettings?.call();
            return;
          case _filterOnlineKey:
            onFilterSelected?.call(_KpiFilter.online);
            return;
          case _filterOfflineKey:
            onFilterSelected?.call(_KpiFilter.offline);
            return;
          case _filterMovingKey:
            onFilterSelected?.call(_KpiFilter.moving);
            return;
          case _filterAlertsKey:
            onFilterSelected?.call(_KpiFilter.alerts);
            return;
          case _filterNoComKey:
            onFilterSelected?.call(_KpiFilter.noCommunication);
            return;
          case _filterClearKey:
            onClearFilters?.call();
            return;
          case _mapNormalKey:
            onMapTypeChanged?.call(gmaps.MapType.normal);
            return;
          case _mapSatelliteKey:
            onMapTypeChanged?.call(gmaps.MapType.satellite);
            return;
          case _mapHybridKey:
            onMapTypeChanged?.call(gmaps.MapType.hybrid);
            return;
          case _mapTrafficKey:
            onTrafficToggle?.call();
            return;
          case _mapRecenterKey:
            onRecenter?.call();
            return;
          case _mapRefreshKey:
            onRefreshPositions?.call();
            return;
          default:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Perfil ativo nesta sessao.'),
              ),
            );
        }
      },
      itemBuilder: (context) {
        final isNormalMap = mapType == gmaps.MapType.normal;
        final isSatelliteMap = mapType == gmaps.MapType.satellite;
        final isHybridMap = mapType == gmaps.MapType.hybrid;
        final trafficOn = trafficEnabled == true;

        return [
          const PopupMenuItem<String>(
            value: _profileMenuKey,
            child: Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 18,
                  color: Color(0xFF52627C),
                ),
                SizedBox(width: 10),
                Expanded(child: Text('Perfil')),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: _quickSettingsKey,
            child: Row(
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: Color(0xFF52627C),
                ),
                SizedBox(width: 10),
                Expanded(child: Text('Configurações rápidas')),
              ],
            ),
          ),
          if (showQuickActions) ...[
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              enabled: false,
              height: 28,
              child: Text(
                'Filtros',
                style: TextStyle(
                  color: Color(0xFF60718D),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
            const PopupMenuItem<String>(
              value: _filterOnlineKey,
              child: Text('Online'),
            ),
            const PopupMenuItem<String>(
              value: _filterOfflineKey,
              child: Text('Offline'),
            ),
            const PopupMenuItem<String>(
              value: _filterMovingKey,
              child: Text('Em movimento'),
            ),
            const PopupMenuItem<String>(
              value: _filterAlertsKey,
              child: Text('Alertas'),
            ),
            const PopupMenuItem<String>(
              value: _filterNoComKey,
              child: Text('Sem comunicação'),
            ),
            const PopupMenuItem<String>(
              value: _filterClearKey,
              child: Text('Limpar filtros'),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              enabled: false,
              height: 28,
              child: Text(
                'Opções de mapa',
                style: TextStyle(
                  color: Color(0xFF60718D),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
            PopupMenuItem<String>(
              value: _mapNormalKey,
              child: Row(
                children: [
                  Icon(
                    isNormalMap
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text('Mapa'),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: _mapSatelliteKey,
              child: Row(
                children: [
                  Icon(
                    isSatelliteMap
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text('Satélite'),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: _mapHybridKey,
              child: Row(
                children: [
                  Icon(
                    isHybridMap
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text('Híbrido'),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: _mapTrafficKey,
              child: Row(
                children: [
                  Icon(
                    trafficOn
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text('Trânsito on/off'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: _mapRecenterKey,
              child: Text('Centralizar frota'),
            ),
            const PopupMenuItem<String>(
              value: _mapRefreshKey,
              child: Text('Atualizar posições'),
            ),
          ],
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: _logoutMenuKey,
            child: Row(
              children: [
                Icon(
                  Icons.logout_outlined,
                  size: 18,
                  color: Color(0xFFB42318),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sair',
                    style: TextStyle(color: Color(0xFFB42318)),
                  ),
                ),
              ],
            ),
          ),
        ];
      },
      child: _GlassSurface(
        width: width,
        padding: EdgeInsets.symmetric(
          horizontal: avatarOnly ? 0 : 12,
          vertical: avatarOnly ? 0 : (compactMenu ? 6 : 7),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Tooltip(
              message: '$displayName\n$displayDetail',
              child: const CircleAvatar(
                radius: 15,
                backgroundColor: Color(0xFFF7F9FD),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: Color(0xFF52627C),
                  size: 17,
                ),
              ),
            ),
            if (!avatarOnly) ...[
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1F2A44),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      displayDetail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF60718D),
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF52627C),
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SideMenu extends StatelessWidget {
  const _SideMenu({
    required this.open,
    required this.cardDensity,
    required this.items,
    required this.activeId,
    required this.onSelect,
    required this.onLogout,
    this.brandName,
    this.brandLogoAsset,
    this.onToggle,
    this.userEmail = '',
    this.isAdmin = false,
  });

  final bool open;
  final VisualCardDensity cardDensity;
  final List<_OperationalMenuItem> items;
  final String? activeId;
  final ValueChanged<_OperationalMenuItem> onSelect;
  final VoidCallback onLogout;
  final String? brandName;
  final String? brandLogoAsset;
  final VoidCallback? onToggle;
  final String userEmail;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final expanded = open;
    final compactDensity = cardDensity == VisualCardDensity.compact;
    final logoAsset = brandLogoAsset?.trim() ?? '';
    final hasLogo = logoAsset.isNotEmpty;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      left: compactDensity ? 12 : 16,
      top: 16,
      bottom: 18,
      width:
          expanded ? (compactDensity ? 190 : 206) : (compactDensity ? 52 : 56),
      child: IgnorePointer(
        ignoring: false,
        child: _SurfaceGuard(
          child: AnimatedOpacity(
            opacity: 1,
            duration: const Duration(milliseconds: 160),
            child: _GlassSurface(
              padding: EdgeInsets.fromLTRB(
                compactDensity ? 6 : 8,
                compactDensity ? 8 : 10,
                compactDensity ? 6 : 8,
                compactDensity ? 8 : 10,
              ),
              child: Column(
                children: [
                  if (expanded) ...[
                    Row(
                      children: [
                        Expanded(
                          child: hasLogo
                              ? Image.asset(
                                  logoAsset,
                                  height: 22,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.centerLeft,
                                )
                              : Text(
                                  brandName ?? 'SouTracking',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF25344A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: onToggle,
                          child: const Icon(
                            Icons.apps_rounded,
                            color: Color(0xFF94A3B8),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(color: Color(0xFFE2E8F0), height: 1),
                    const SizedBox(height: 4),
                  ] else ...[
                    GestureDetector(
                      onTap: onToggle,
                      child: SizedBox(
                        height: 34,
                        child: Center(
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF176EEB), Color(0xFF0D4DB8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Center(
                              child: Text('S', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 3),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _MenuTile(
                          item: item,
                          expanded: expanded,
                          selected: activeId == item.id,
                          onTap: () => onSelect(item),
                        );
                      },
                    ),
                  ),
                  if (expanded) ...[
                    const Divider(color: Color(0xFFE2E8F0), height: 1),
                    const SizedBox(height: 8),
                    _SideMenuFooter(
                      userEmail: userEmail,
                      isAdmin: isAdmin,
                      onLogout: onLogout,
                    ),
                  ] else ...[
                    const SizedBox(height: 6),
                    _SideMenuFooterCollapsed(
                      userEmail: userEmail,
                      onLogout: onLogout,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
// ── Sidebar footer widgets ─────────────────────────────────────────────────────

class _SideMenuFooter extends StatelessWidget {
  const _SideMenuFooter({required this.userEmail, required this.isAdmin, required this.onLogout});
  final String userEmail;
  final bool isAdmin;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final initial = userEmail.isNotEmpty ? userEmail[0].toUpperCase() : 'U';
    final role = isAdmin ? 'Administrador' : 'Operador';

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF176EEB), Color(0xFF0D4DB8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(role, style: const TextStyle(color: Color(0xFF1F2A44), fontWeight: FontWeight.w800, fontSize: 11)),
                    Text(
                      userEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF9DB1CC), fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Sair',
                onPressed: onLogout,
                icon: const Icon(Icons.logout_rounded, size: 16),
                style: IconButton.styleFrom(
                  foregroundColor: const Color(0xFF60718D),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(28, 28),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text('Online', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w700)),
              const Spacer(),
              const Text('v1.0.1', style: TextStyle(color: Color(0xFF9DB1CC), fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SideMenuFooterCollapsed extends StatelessWidget {
  const _SideMenuFooterCollapsed({required this.userEmail, required this.onLogout});
  final String userEmail;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final initial = userEmail.isNotEmpty ? userEmail[0].toUpperCase() : 'U';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28, height: 28,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF176EEB), Color(0xFF0D4DB8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
          ),
        ),
        const SizedBox(height: 4),
        IconButton(
          tooltip: 'Sair',
          onPressed: onLogout,
          icon: const Icon(Icons.logout_rounded, size: 16),
          style: IconButton.styleFrom(
            foregroundColor: const Color(0xFF60718D),
            padding: EdgeInsets.zero,
            minimumSize: const Size(28, 28),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.item,
    required this.expanded,
    required this.selected,
    required this.onTap,
  });

  final _OperationalMenuItem item;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final safeLabel = formatDisplayText(item.label);
    final accent = item.color ?? const Color(0xFF176EEB);
    final iconColor = selected
        ? accent
        : accent.withValues(alpha: 0.55);
    final textColor = selected ? accent : const Color(0xFF3D4F6B);
    final bgColor = selected
        ? accent.withValues(alpha: 0.10)
        : Colors.transparent;
    final borderColor = selected
        ? accent.withValues(alpha: 0.28)
        : Colors.transparent;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: EdgeInsets.symmetric(horizontal: expanded ? 10 : 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisAlignment:
                expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              if (expanded)
                Icon(item.icon, color: iconColor, size: 18)
              else
                Tooltip(
                  message: safeLabel,
                  child: Icon(item.icon, color: iconColor, size: 18),
                ),
              if (expanded) ...[
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    safeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                if (item.badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      item.badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({
    required this.kpis,
    required this.activeFilter,
    required this.onTap,
  });

  final _FleetKpis kpis;
  final _KpiFilter? activeFilter;
  final ValueChanged<_KpiFilter> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < _KpiFilter.values.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _KpiChip(
            filter: _KpiFilter.values[i],
            value: kpis.valueFor(_KpiFilter.values[i]),
            selected: activeFilter == _KpiFilter.values[i],
            onTap: () => onTap(_KpiFilter.values[i]),
          ),
        ],
      ],
    );
  }
}

class _KpiChip extends StatelessWidget {
  const _KpiChip({
    required this.filter,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final _KpiFilter filter;
  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFEAF3FF)
                : Colors.white.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFFB7D5FF)
                  : const Color(0xFFE3EAF3),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF183153).withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF176EEB).withValues(alpha: 0.18)
                      : filter.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  filter.icon,
                  size: 18,
                  color: selected ? const Color(0xFF176EEB) : filter.color,
                ),
              ),
              Positioned(
                top: -6,
                right: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF176EEB) : filter.color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$value',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapRightControls extends StatelessWidget {
  const _MapRightControls({
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      top: 190,
      child: _SurfaceGuard(
        child: Column(
          children: [
            _GlassButton(
              tooltip: 'Aproximar',
              icon: Icons.add_rounded,
              onTap: onZoomIn,
            ),
            const SizedBox(height: 6),
            _GlassButton(
              tooltip: 'Afastar',
              icon: Icons.remove_rounded,
              onTap: onZoomOut,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoVehiclesMapHint extends StatelessWidget {
  const _NoVehiclesMapHint();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: _GlassSurface(
          width: 360,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.gps_off_rounded,
                color: Color(0xFF60718D),
                size: 24,
              ),
              SizedBox(height: 8),
              Text(
                'Nenhum equipamento com posição válida no momento',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF1F2A44),
                  fontWeight: FontWeight.w800,
                  fontSize: 12.8,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Atualize os filtros ou aguarde novos dados do servidor.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF60718D),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiVehicleList extends StatelessWidget {
  const _KpiVehicleList({
    required this.open,
    required this.cardDensity,
    required this.sidebarOpen,
    required this.sidebarVisible,
    required this.title,
    required this.snapshots,
    required this.onVehicleTap,
  });

  final bool open;
  final VisualCardDensity cardDensity;
  final bool sidebarOpen;
  final bool sidebarVisible;
  final String title;
  final List<_VehicleSnapshot> snapshots;
  final ValueChanged<_VehicleSnapshot> onVehicleTap;

  @override
  Widget build(BuildContext context) {
    final compactDensity = cardDensity == VisualCardDensity.compact;
    final panelWidth = compactDensity ? 320.0 : 348.0;
    final sidebarWidth = !sidebarVisible
        ? 0.0
        : (sidebarOpen ? (compactDensity ? 208.0 : 224.0) : 72.0);
    final openedLeft = sidebarWidth + (compactDensity ? 12.0 : 16.0);
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      left: open ? openedLeft : -panelWidth - 28,
      top: 126,
      bottom: 18,
      width: panelWidth,
      child: IgnorePointer(
        ignoring: !open,
        child: _SurfaceGuard(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: open ? 1 : 0,
            child: _GlassSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: const Color(0xFF1F2A44),
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        Text(
                          '${snapshots.length}',
                          style: const TextStyle(
                            color: Color(0xFF60718D),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  Expanded(
                    child: snapshots.isEmpty
                        ? const Center(
                            child: Text(
                              'Nenhum veículo disponivel no momento',
                              style: TextStyle(color: Color(0xFF52627C)),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(10),
                            itemCount: snapshots.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final snapshot = snapshots[index];
                              return _VehicleListTile(
                                snapshot: snapshot,
                                onTap: () => onVehicleTap(snapshot),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VehicleListTile extends StatelessWidget {
  const _VehicleListTile({
    required this.snapshot,
    required this.onTap,
  });

  final _VehicleSnapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.76),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _VehicleAvatar(snapshot: snapshot, size: 44, iconSize: 22),
              const SizedBox(width: 10),
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
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${snapshot.speedLabel} | ${snapshot.ignitionLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(status: snapshot.device.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntegratedPanel extends StatelessWidget {
  const _IntegratedPanel({
    required this.open,
    required this.cardDensity,
    required this.sidebarOpen,
    required this.sidebarVisible,
    required this.title,
    required this.subtitle,
    this.hideHeader = false,
    required this.child,
    required this.onClose,
  });

  final bool open;
  final VisualCardDensity cardDensity;
  final bool sidebarOpen;
  final bool sidebarVisible;
  final String title;
  final String subtitle;
  final bool hideHeader;
  final Widget child;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 760;
    final compactDensity = cardDensity == VisualCardDensity.compact;
    final double sidebarEdge;
    if (!sidebarVisible) {
      sidebarEdge = 0.0;
    } else if (sidebarOpen) {
      sidebarEdge = compactDensity ? 202.0 : 222.0;
    } else {
      sidebarEdge = compactDensity ? 64.0 : 72.0;
    }
    final double panelGap = sidebarVisible ? (compactDensity ? 14.0 : 16.0) : 0.0;
    final leftInset = compact ? 16.0 : (sidebarVisible ? sidebarEdge + panelGap : 16.0);
    const rightInset = 24.0;
    final availableWidth = screenWidth - leftInset - rightInset;
    final width = availableWidth
        .clamp(320.0, compactDensity ? 1280.0 : 1240.0)
        .toDouble();
    final centeredOffset =
        ((availableWidth - width) / 2).clamp(0.0, 1000.0).toDouble();
    final centeredLeft = leftInset + centeredOffset;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      left: open ? centeredLeft : screenWidth + 36,
      top: 92,
      bottom: 24,
      width: width,
      child: IgnorePointer(
        ignoring: !open,
        child: _SurfaceGuard(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: open ? 1 : 0,
            child: _GlassSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (!hideHeader)
                    SizedBox(
                      height: 68,
                      child: Row(
                        children: [
                          const SizedBox(width: 18),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFF176EEB)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.space_dashboard_outlined,
                              color: Color(0xFF176EEB),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF1F2A44),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF60718D),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Fechar painel',
                            onPressed: onClose,
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF60718D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!hideHeader)
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(hideHeader ? 10 : 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: ColoredBox(
                          color: Colors.white.withValues(alpha: 0.92),
                          child: Theme(
                            data: _panelLightTheme(context),
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PixelTelemetryWorkspace extends StatelessWidget {
  const _PixelTelemetryWorkspace({
    required this.snapshots,
    required this.onClose,
    required this.onRefresh,
    required this.onOpenMenuItem,
    required this.menuItems,
  });

  final List<_VehicleSnapshot> snapshots;
  final VoidCallback onClose;
  final VoidCallback onRefresh;
  final ValueChanged<_OperationalMenuItem> onOpenMenuItem;
  final List<_OperationalMenuItem> menuItems;

  static const _workspacePadding = EdgeInsets.fromLTRB(12, 12, 12, 16);

  @override
  Widget build(BuildContext context) {
    final mapById = {
      for (final item in menuItems) item.id: item,
    };
    final total = snapshots.length;
    final online = snapshots.where((it) => it.isOperationalOnline).length;
    final moving = snapshots.where((it) => it.isOperationalMoving).length;
    final alerts = snapshots.where((it) => it.hasAlert).length;
    final offline = snapshots.where((it) => it.isOperationalOffline).length;
    final noSignal = snapshots
        .where((it) => !it.hasPosition || it.hasStaleLastUpdate)
        .length;
    final tableRows = snapshots.take(6).toList(growable: false);
    final mainSnapshot = tableRows.isNotEmpty ? tableRows.first : null;
    final logs = _buildLogRows(mainSnapshot);
    final media = MediaQuery.sizeOf(context);
    final compact = media.width < 1180;

    return Padding(
      padding: _workspacePadding,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF1F3A63)),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xDE071223),
              Color(0xE807111E),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.52),
              blurRadius: 26,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: compact
              ? Column(
                  children: [
                    _PixelTelemetryTopBar(
                      onClose: onClose,
                      onRefresh: onRefresh,
                    ),
                    Expanded(
                      child: _PixelTelemetryContent(
                        tableRows: tableRows,
                        logs: logs,
                        total: total,
                        online: online,
                        moving: moving,
                        alerts: alerts,
                        offline: offline,
                        noSignal: noSignal,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    _PixelTelemetrySidebar(
                      menuMap: mapById,
                      onOpenMenuItem: onOpenMenuItem,
                      onRefresh: onRefresh,
                    ),
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: Color(0xFF1A2E4A),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          _PixelTelemetryTopBar(
                            onClose: onClose,
                            onRefresh: onRefresh,
                          ),
                          Expanded(
                            child: _PixelTelemetryContent(
                              tableRows: tableRows,
                              logs: logs,
                              total: total,
                              online: online,
                              moving: moving,
                              alerts: alerts,
                              offline: offline,
                              noSignal: noSignal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  List<_PixelLogRow> _buildLogRows(_VehicleSnapshot? snapshot) {
    if (snapshot == null) {
      return const <_PixelLogRow>[
        _PixelLogRow(
          dateTime: '--',
          equipment: '--',
          type: 'Posicao',
          severity: 'Info',
          description: 'Latitude',
          value: '--',
          unit: '-',
          source: 'GPS',
        ),
      ];
    }

    final timestamp = snapshot.lastCommunicationLabel;
    final equipment =
        snapshot.device.name.isEmpty ? 'Sem nome' : snapshot.device.name;
    final speedValue = snapshot.speedLabel.replaceAll(' km/h', '');
    final batteryRaw = snapshot.batteryLabel;

    return <_PixelLogRow>[
      _PixelLogRow(
        dateTime: '$timestamp:15',
        equipment: equipment,
        type: 'Posicao',
        severity: 'Info',
        description: 'Latitude',
        value: snapshot.latLng.latitude.toStringAsFixed(5),
        unit: 'deg',
        source: 'GPS',
      ),
      _PixelLogRow(
        dateTime: '$timestamp:15',
        equipment: equipment,
        type: 'Posicao',
        severity: 'Info',
        description: 'Longitude',
        value: snapshot.latLng.longitude.toStringAsFixed(5),
        unit: 'deg',
        source: 'GPS',
      ),
      _PixelLogRow(
        dateTime: '$timestamp:15',
        equipment: equipment,
        type: 'Velocidade',
        severity: 'Info',
        description: 'Velocidade',
        value: speedValue,
        unit: 'km/h',
        source: 'GPS',
      ),
      _PixelLogRow(
        dateTime: '$timestamp:15',
        equipment: equipment,
        type: 'Ignição',
        severity: snapshot.ignition == true ? 'Info' : 'Alerta',
        description: 'Estado da ignicao',
        value: snapshot.ignitionLabel,
        unit: '-',
        source: 'Digital',
      ),
      _PixelLogRow(
        dateTime: '$timestamp:15',
        equipment: equipment,
        type: 'Bateria',
        severity: 'Info',
        description: 'Tensao da bateria',
        value: batteryRaw,
        unit: batteryRaw.contains('%') ? '%' : 'V',
        source: 'Telemetria',
      ),
      _PixelLogRow(
        dateTime: '$timestamp:15',
        equipment: equipment,
        type: 'Sinal GSM',
        severity: 'Info',
        description: 'Intensidade do sinal',
        value: _rssiText(snapshot),
        unit: 'dBm',
        source: 'GSM',
      ),
      _PixelLogRow(
        dateTime: '$timestamp:15',
        equipment: equipment,
        type: 'Evento',
        severity: 'Alerta',
        description: 'Excesso de velocidade',
        value: speedValue,
        unit: 'km/h',
        source: 'Sistema',
      ),
      _PixelLogRow(
        dateTime: '$timestamp:15',
        equipment: equipment,
        type: 'Saida digital',
        severity: 'Aviso',
        description: 'Bloqueio motor',
        value: snapshot.ignition == true ? 'Desativado' : 'Ativado',
        unit: '-',
        source: 'Comando',
      ),
    ];
  }
}

class _PixelTelemetryTopBar extends StatelessWidget {
  const _PixelTelemetryTopBar({
    required this.onClose,
    required this.onRefresh,
  });

  final VoidCallback onClose;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF1A2E4A)),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xB90B1830),
            Color(0x9609162A),
          ],
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.track_changes_outlined,
            color: Color(0xFF56A3FF),
            size: 18,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Telemetria operacional - modo pixel test (1536 x 864)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFFE6F2FF),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          _PixelActionButton(
            icon: Icons.refresh_rounded,
            label: 'Atualizar',
            onTap: onRefresh,
          ),
          const SizedBox(width: 8),
          _PixelActionButton(
            icon: Icons.close_rounded,
            label: 'Fechar',
            onTap: onClose,
          ),
        ],
      ),
    );
  }
}

class _PixelTelemetrySidebar extends StatelessWidget {
  const _PixelTelemetrySidebar({
    required this.menuMap,
    required this.onOpenMenuItem,
    required this.onRefresh,
  });

  final Map<String, _OperationalMenuItem> menuMap;
  final ValueChanged<_OperationalMenuItem> onOpenMenuItem;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    const ids = <({String id, String label, IconData icon, bool selected})>[
      (
        id: 'dashboard',
        label: 'Dashboard',
        icon: Icons.space_dashboard_outlined,
        selected: false
      ),
      (id: 'map', label: 'Mapa', icon: Icons.map_outlined, selected: false),
      (
        id: 'vehicles',
        label: 'Equipamentos',
        icon: Icons.directions_car_outlined,
        selected: false
      ),
      (
        id: 'devices',
        label: 'Dispositivos',
        icon: Icons.gps_fixed_outlined,
        selected: true
      ),
      (
        id: 'alerts',
        label: 'Alertas',
        icon: Icons.notifications_active_outlined,
        selected: false
      ),
      (
        id: 'geofences',
        label: 'Cercas',
        icon: Icons.fence_outlined,
        selected: false
      ),
      (
        id: 'reports',
        label: 'relatórios',
        icon: Icons.insert_chart_outlined,
        selected: false
      ),
      (
        id: 'communication',
        label: 'comunicação',
        icon: Icons.chat_bubble_outline,
        selected: false
      ),
      (
        id: 'settings',
        label: 'Configurações',
        icon: Icons.settings_outlined,
        selected: false
      ),
      (id: 'logs', label: 'Logs', icon: Icons.article_outlined, selected: true),
    ];

    return SizedBox(
      width: 212,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xE5081426),
              Color(0xE2061020),
            ],
          ),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      size: 18, color: Color(0xFFF7C62A)),
                  SizedBox(width: 8),
                  Text(
                    'SOUTRACKING',
                    style: TextStyle(
                      color: Color(0xFFF2F7FF),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF1A2E4A)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                children: [
                  for (final item in ids) ...[
                    _PixelSidebarTile(
                      label: formatDisplayText(item.label),
                      icon: item.icon,
                      selected: item.selected,
                      onTap: () {
                        final menuItem = menuMap[item.id];
                        if (menuItem != null) {
                          onOpenMenuItem(menuItem);
                        }
                      },
                    ),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 9, color: Color(0xFF2EDD87)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Online',
                      style: TextStyle(
                        color: Color(0xFF8CA5C9),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onRefresh,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Color(0xFF8CA5C9),
                      size: 18,
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

class _PixelSidebarTile extends StatelessWidget {
  const _PixelSidebarTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF0E2A53) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? const Color(0xFF2159A8) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? const Color(0xFF8CC4FF)
                    : const Color(0xFF91A7CA),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFFD8E9FF)
                        : const Color(0xFF91A7CA),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PixelTelemetryContent extends StatelessWidget {
  const _PixelTelemetryContent({
    required this.tableRows,
    required this.logs,
    required this.total,
    required this.online,
    required this.moving,
    required this.alerts,
    required this.offline,
    required this.noSignal,
  });

  final List<_VehicleSnapshot> tableRows;
  final List<_PixelLogRow> logs;
  final int total;
  final int online;
  final int moving;
  final int alerts;
  final int offline;
  final int noSignal;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      child: Column(
        children: [
          _PixelSectionShell(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Equipamentos / Dispositivos',
                            style: TextStyle(
                              color: Color(0xFFE8F1FF),
                              fontWeight: FontWeight.w800,
                              fontSize: 31 / 2,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Visão geral dos equipamentos da Operação',
                            style: TextStyle(
                              color: Color(0xFF8DA7CC),
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _PixelActionButton(
                      icon: Icons.filter_list_rounded,
                      label: 'Filtros',
                    ),
                    SizedBox(width: 8),
                    _PixelActionButton(
                      icon: Icons.file_download_outlined,
                      label: 'Exportar',
                    ),
                    SizedBox(width: 8),
                    _PixelActionButton(
                      icon: Icons.add_rounded,
                      label: 'Novo Equipamento',
                      primary: true,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = (constraints.maxWidth - 40) / 6;
                    final wrap = cardWidth < 170;
                    final cards = [
                      _PixelKpiCard(
                        title: 'Total de Equipamentos',
                        value: '$total',
                        hint: '100% do total',
                        color: const Color(0xFF2FA6FF),
                        icon: Icons.inventory_2_outlined,
                      ),
                      _PixelKpiCard(
                        title: 'Online',
                        value: '$online',
                        hint: total > 0
                            ? '${((online / total) * 100).round()}% do total'
                            : '0% do total',
                        color: const Color(0xFF2EDD87),
                        icon: Icons.wifi_tethering_rounded,
                      ),
                      _PixelKpiCard(
                        title: 'Em Movimento',
                        value: '$moving',
                        hint: total > 0
                            ? '${((moving / total) * 100).round()}% do total'
                            : '0% do total',
                        color: const Color(0xFF40A0FF),
                        icon: Icons.near_me_outlined,
                      ),
                      _PixelKpiCard(
                        title: 'Alertas Ativos',
                        value: '$alerts',
                        hint: total > 0
                            ? '${((alerts / total) * 100).round()}% do total'
                            : '0% do total',
                        color: const Color(0xFFFF6A55),
                        icon: Icons.warning_amber_rounded,
                      ),
                      _PixelKpiCard(
                        title: 'Offline',
                        value: '$offline',
                        hint: total > 0
                            ? '${((offline / total) * 100).round()}% do total'
                            : '0% do total',
                        color: const Color(0xFF93A4BC),
                        icon: Icons.wifi_off_rounded,
                      ),
                      _PixelKpiCard(
                        title: 'Sem comunicação',
                        value: '$noSignal',
                        hint: total > 0
                            ? '${((noSignal / total) * 100).round()}% do total'
                            : '0% do total',
                        color: const Color(0xFFF5A623),
                        icon: Icons.portable_wifi_off_rounded,
                      ),
                    ];
                    if (!wrap) {
                      return Row(
                        children: [
                          for (var i = 0; i < cards.length; i++) ...[
                            Expanded(child: cards[i]),
                            if (i != cards.length - 1) const SizedBox(width: 8),
                          ],
                        ],
                      );
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final card in cards)
                          SizedBox(width: 220, child: card),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                _PixelTableShell(
                  child: _PixelDevicesTable(rows: tableRows, total: total),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _PixelSectionShell(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Logs / Data Log',
                            style: TextStyle(
                              color: Color(0xFFE8F1FF),
                              fontWeight: FontWeight.w800,
                              fontSize: 30 / 2,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Histórico detalhado de dados e eventos dos equipamentos',
                            style: TextStyle(
                              color: Color(0xFF8DA7CC),
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _PixelActionButton(
                      icon: Icons.file_download_outlined,
                      label: 'Exportar',
                    ),
                    SizedBox(width: 8),
                    _PixelActionButton(
                      icon: Icons.view_column_outlined,
                      label: 'Configurar Colunas',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _PixelTableShell(
                  child: _PixelLogsTable(rows: logs),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PixelSectionShell extends StatelessWidget {
  const _PixelSectionShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1B3555)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xCE0B172A),
            Color(0xB30A1526),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }
}

class _PixelActionButton extends StatelessWidget {
  const _PixelActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final bg = primary ? const Color(0xFF2C7BEA) : const Color(0xFF121F33);
    final fg = primary ? Colors.white : const Color(0xFFE4EEFF);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  primary ? const Color(0xFF468DEB) : const Color(0xFF263D5D),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PixelKpiCard extends StatelessWidget {
  const _PixelKpiCard({
    required this.title,
    required this.value,
    required this.hint,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final String hint;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFF233D5E)),
        color: const Color(0xE0101F33),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF91A9CC),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFFF0F6FF),
                    fontSize: 23 / 2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  hint,
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
    );
  }
}

class _PixelTableShell extends StatelessWidget {
  const _PixelTableShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFF223A5B)),
        color: const Color(0xC80C1A2C),
      ),
      child: child,
    );
  }
}

class _PixelDevicesTable extends StatelessWidget {
  const _PixelDevicesTable({
    required this.rows,
    required this.total,
  });

  final List<_VehicleSnapshot> rows;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: Row(
            children: const [
              Expanded(
                child: _PixelFilterField(
                    text: 'Buscar equipamento, IMEI ou placa...'),
              ),
              SizedBox(width: 10),
              _PixelFilterField(text: 'Todos os Status', width: 170),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFF213757)),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 20,
            headingRowHeight: 38,
            dataRowMinHeight: 43,
            dataRowMaxHeight: 54,
            dividerThickness: 0.6,
            headingTextStyle: const TextStyle(
              color: Color(0xFFCFE1FF),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            dataTextStyle: const TextStyle(
              color: Color(0xFFE3EEFF),
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            columns: const [
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Equipamento')),
              DataColumn(label: Text('IMEI / ID')),
              DataColumn(label: Text('veículo / Ativo')),
              DataColumn(label: Text('Grupo')),
              DataColumn(label: Text('Ultima Conexao')),
              DataColumn(label: Text('Velocidade')),
              DataColumn(label: Text('Ignição')),
              DataColumn(label: Text('Bateria')),
              DataColumn(label: Text('Sinal GSM')),
              DataColumn(label: Text('ações')),
            ],
            rows: [
              for (final row in rows) _deviceRow(row),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFF213757)),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Text(
                'Mostrando 1 a ${rows.length} de $total equipamentos',
                style: const TextStyle(
                  color: Color(0xFF89A4CA),
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                ),
              ),
              const Spacer(),
              const _PixelPager(),
            ],
          ),
        ),
      ],
    );
  }

  DataRow _deviceRow(_VehicleSnapshot row) {
    final statusText = _statusLabel(row);
    final statusColor = _statusColor(row);
    final model = (row.modelLabel.isEmpty || row.modelLabel == '—' || row.modelLabel == 'Não informado')
        ? row.device.name
        : row.modelLabel;
    final groupRaw = row.device.attributes?['groupId'] ??
        row.device.attributes?['group'] ??
        row.device.attributes?['groupName'];
    final groupLabel = '$groupRaw'.trim().isEmpty || '$groupRaw' == 'null'
        ? 'Sem grupo'
        : 'Grupo $groupRaw';
    final signalLevel = _pixelSignalLevelForRow(row);
    final signalColor = _pixelSignalColor(signalLevel);
    final signalLabel = _pixelSignalLabelForRow(row);
    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              Icon(Icons.circle, size: 8, color: statusColor),
              const SizedBox(width: 6),
              Text(
                statusText,
                style:
                    TextStyle(color: statusColor, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        DataCell(Text(row.device.name.isEmpty ? 'Sem nome' : row.device.name)),
        DataCell(Text(row.identifierLabel)),
        DataCell(Text(model)),
        DataCell(Text(groupLabel)),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(row.lastCommunicationLabel),
              Text(
                row.relativeLastPoint,
                style: const TextStyle(
                  color: Color(0xFF6CB1FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        DataCell(Text(row.speedLabel)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.power_settings_new_rounded,
                size: 16,
                color: _pixelIgnitionColor(row.ignition),
              ),
              const SizedBox(width: 6),
              _PixelBooleanPill(text: row.ignitionLabel, active: row.ignition),
            ],
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.battery_6_bar_rounded,
                size: 16,
                color: _pixelBatteryColorForRow(row),
              ),
              const SizedBox(width: 6),
              Text(
                row.batteryLabel,
                style: TextStyle(
                  color: _pixelBatteryColorForRow(row),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PixelBlinkingIcon(
                enabled: signalLevel == _PixelSignalLevel.critical,
                child: Icon(
                  _pixelSignalIcon(signalLevel),
                  size: 16,
                  color: signalColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                signalLabel,
                style: TextStyle(
                  color: signalColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const DataCell(
          Row(
            children: [
              Icon(Icons.remove_red_eye_outlined,
                  size: 15, color: Color(0xFF9AB5DA)),
              SizedBox(width: 8),
              Icon(Icons.history_rounded, size: 15, color: Color(0xFF9AB5DA)),
              SizedBox(width: 8),
              Icon(Icons.more_horiz_rounded,
                  size: 17, color: Color(0xFF9AB5DA)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PixelLogsTable extends StatelessWidget {
  const _PixelLogsTable({required this.rows});

  final List<_PixelLogRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: Row(
            children: const [
              _PixelFilterField(
                  text: '14/05/2026 00:00 ate 14/05/2026 23:59', width: 250),
              SizedBox(width: 8),
              _PixelFilterField(text: 'Equipamento: PTI-0001', width: 230),
              SizedBox(width: 8),
              _PixelFilterField(text: 'Tipo de Log: Todos', width: 160),
              SizedBox(width: 8),
              _PixelFilterField(text: 'Severidade: Todos', width: 160),
              SizedBox(width: 8),
              _PixelActionButton(
                  icon: Icons.search_rounded, label: 'Buscar', primary: true),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFF213757)),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 20,
            headingRowHeight: 38,
            dataRowMinHeight: 42,
            dataRowMaxHeight: 50,
            dividerThickness: 0.6,
            headingTextStyle: const TextStyle(
              color: Color(0xFFCFE1FF),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            dataTextStyle: const TextStyle(
              color: Color(0xFFE3EEFF),
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            columns: const [
              DataColumn(label: Text('Data/Hora')),
              DataColumn(label: Text('Equipamento')),
              DataColumn(label: Text('Tipo de Log')),
              DataColumn(label: Text('Severidade')),
              DataColumn(label: Text('Descricao')),
              DataColumn(label: Text('Valor')),
              DataColumn(label: Text('Unidade')),
              DataColumn(label: Text('Origem')),
            ],
            rows: [
              for (final row in rows)
                DataRow(
                  cells: [
                    DataCell(Text(row.dateTime)),
                    DataCell(Text(row.equipment)),
                    DataCell(Text(row.type)),
                    DataCell(_PixelSeverityPill(text: row.severity)),
                    DataCell(Text(row.description)),
                    DataCell(Text(row.value)),
                    DataCell(Text(row.unit)),
                    DataCell(Text(row.source)),
                  ],
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFF213757)),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Text(
                'Mostrando 1 a 10 de 15.842 registros',
                style: TextStyle(
                  color: Color(0xFF89A4CA),
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                ),
              ),
              Spacer(),
              _PixelPager(),
            ],
          ),
        ),
      ],
    );
  }
}

class _PixelFilterField extends StatelessWidget {
  const _PixelFilterField({
    required this.text,
    this.width,
  });

  final String text;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 33,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFF0E1A2C),
        border: Border.all(color: const Color(0xFF223A5B)),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFA6BEDF),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _PixelPager extends StatelessWidget {
  const _PixelPager();

  @override
  Widget build(BuildContext context) {
    final pages = [1, 2, 3, 4, 5];
    return Row(
      children: [
        const Icon(Icons.chevron_left_rounded, color: Color(0xFF7C95B9)),
        const SizedBox(width: 3),
        for (final page in pages) ...[
          Container(
            width: 30,
            height: 28,
            alignment: Alignment.center,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: page == 1 ? const Color(0xFF123564) : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: page == 1
                    ? const Color(0xFF2E79D8)
                    : const Color(0xFF223A5B),
              ),
            ),
            child: Text(
              '$page',
              style: TextStyle(
                color: page == 1
                    ? const Color(0xFFDCF0FF)
                    : const Color(0xFF88A7CD),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
        const Icon(Icons.chevron_right_rounded, color: Color(0xFF7C95B9)),
      ],
    );
  }
}

class _PixelBooleanPill extends StatelessWidget {
  const _PixelBooleanPill({
    required this.text,
    required this.active,
  });

  final String text;
  final bool? active;

  @override
  Widget build(BuildContext context) {
    final color = active == null
        ? const Color(0xFF9FB2CC)
        : active == true
            ? const Color(0xFF2EDD87)
            : const Color(0xFFEB5962);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.52)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PixelBlinkingIcon extends StatefulWidget {
  const _PixelBlinkingIcon({
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  State<_PixelBlinkingIcon> createState() => _PixelBlinkingIconState();
}

class _PixelBlinkingIconState extends State<_PixelBlinkingIcon>
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
    _opacity = Tween<double>(begin: 1, end: 0.25).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _sync();
  }

  @override
  void didUpdateWidget(covariant _PixelBlinkingIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      _sync();
    }
  }

  void _sync() {
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

class _PixelSeverityPill extends StatelessWidget {
  const _PixelSeverityPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final lower = text.toLowerCase();
    final color = lower == 'alerta'
        ? const Color(0xFFF5A623)
        : lower == 'aviso'
            ? const Color(0xFFF8D04C)
            : const Color(0xFF3B97FF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10.5,
        ),
      ),
    );
  }
}

class _PixelLogRow {
  const _PixelLogRow({
    required this.dateTime,
    required this.equipment,
    required this.type,
    required this.severity,
    required this.description,
    required this.value,
    required this.unit,
    required this.source,
  });

  final String dateTime;
  final String equipment;
  final String type;
  final String severity;
  final String description;
  final String value;
  final String unit;
  final String source;
}

String _statusLabel(_VehicleSnapshot row) {
  return row.statusLabel;
}

Color _statusColor(_VehicleSnapshot row) {
  return row.statusColor;
}

String _rssiText(_VehicleSnapshot row) {
  final rssi = _pixelRssiFromRow(row);
  if (rssi != null) {
    final dBm = rssi > 0 ? -rssi : rssi;
    return dBm.toStringAsFixed(0);
  }
  final gsm = _pixelGsmFromRow(row);
  if (gsm != null) {
    return '${gsm.toStringAsFixed(0)}%';
  }
  return '--';
}

enum _PixelSignalLevel { unknown, good, medium, low, critical }

Color _pixelIgnitionColor(bool? value) {
  if (value == null) return const Color(0xFF9FB2CC);
  return value ? const Color(0xFF2EDD87) : const Color(0xFFEB5962);
}

Color _pixelBatteryColorForRow(_VehicleSnapshot row) {
  final label = row.batteryLabel.trim().toLowerCase();
  final number = _pixelNumberFromText(label);
  if (number == null) return const Color(0xFF9FB2CC);

  final isPercent = label.contains('%') || number > 30;
  if (isPercent) {
    if (number < 20) return const Color(0xFFEB5962);
    if (number < 35) return const Color(0xFFF5A623);
    return const Color(0xFF2EDD87);
  }

  if (number < 11.8) return const Color(0xFFEB5962);
  if (number < 12.2) return const Color(0xFFF5A623);
  return const Color(0xFF2EDD87);
}

_PixelSignalLevel _pixelSignalLevelForRow(_VehicleSnapshot row) {
  final rssi = _pixelRssiFromRow(row);
  if (rssi != null) {
    // Positive values are absolute dBm (some parsers omit the minus sign)
    final dBm = rssi > 0 ? -rssi : rssi;
    if (dBm <= -100) return _PixelSignalLevel.critical;
    if (dBm <= -85) return _PixelSignalLevel.low;
    if (dBm <= -70) return _PixelSignalLevel.medium;
    return _PixelSignalLevel.good;
  }

  final gsm = _pixelGsmFromRow(row);
  if (gsm == null) return _PixelSignalLevel.unknown;
  // GSM ASU (0–31) or normalised %: higher = better
  if (gsm < 5) return _PixelSignalLevel.critical;
  if (gsm < 12) return _PixelSignalLevel.low;
  if (gsm < 20) return _PixelSignalLevel.medium;
  return _PixelSignalLevel.good;
}

Color _pixelSignalColor(_PixelSignalLevel level) {
  switch (level) {
    case _PixelSignalLevel.good:
      return const Color(0xFF2EDD87);
    case _PixelSignalLevel.medium:
      return const Color(0xFFF5A623);
    case _PixelSignalLevel.low:
      return const Color(0xFFFF8C42);
    case _PixelSignalLevel.critical:
      return const Color(0xFFEB5962);
    case _PixelSignalLevel.unknown:
      return const Color(0xFF9FB2CC);
  }
}

IconData _pixelSignalIcon(_PixelSignalLevel level) {
  switch (level) {
    case _PixelSignalLevel.good:
      return Icons.signal_cellular_4_bar_rounded;
    case _PixelSignalLevel.medium:
      return Icons.signal_cellular_alt_2_bar_rounded;
    case _PixelSignalLevel.low:
      return Icons.signal_cellular_alt_1_bar_rounded;
    case _PixelSignalLevel.critical:
      return Icons.signal_cellular_0_bar_rounded;
    case _PixelSignalLevel.unknown:
      return Icons.signal_cellular_alt_rounded;
  }
}

String _pixelSignalLabelForRow(_VehicleSnapshot row) {
  final rssi = _pixelRssiFromRow(row);
  if (rssi != null) {
    final dBm = rssi > 0 ? -rssi : rssi;
    return '${dBm.toStringAsFixed(0)} dBm';
  }
  final gsm = _pixelGsmFromRow(row);
  if (gsm != null) return '${gsm.toStringAsFixed(0)}%';
  return '--';
}

double? _pixelRssiFromRow(_VehicleSnapshot row) {
  final raw =
      row.position?.attributes?['rssi'] ?? row.device.attributes?['rssi'];
  return _pixelToDouble(raw);
}

double? _pixelGsmFromRow(_VehicleSnapshot row) {
  final raw = row.position?.attributes?['gsm'] ??
      row.position?.attributes?['signal'] ??
      row.position?.attributes?['gsmSignal'] ??
      row.device.attributes?['gsm'] ??
      row.device.attributes?['signal'] ??
      row.device.attributes?['gsmSignal'];
  final value = _pixelToDouble(raw);
  if (value == null) return null;
  return value <= 1 ? value * 100 : value;
}

double? _pixelToDouble(dynamic raw) {
  if (raw is num) {
    final value = raw.toDouble();
    return value.isFinite ? value : null;
  }
  if (raw is String) {
    final parsed = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (parsed != null && parsed.isFinite) {
      return parsed;
    }
  }
  return null;
}

double? _pixelNumberFromText(String text) {
  final match = RegExp(r'-?\d+(?:[\.,]\d+)?').firstMatch(text);
  if (match == null) return null;
  return double.tryParse(match.group(0)!.replaceAll(',', '.'));
}

class _HighlightsRail extends StatelessWidget {
  const _HighlightsRail({required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      right: open ? 16 : -270,
      top: 126,
      width: 250,
      child: IgnorePointer(
        ignoring: !open,
        child: _SurfaceGuard(
          child: AnimatedOpacity(
            opacity: open ? 1 : 0,
            duration: const Duration(milliseconds: 160),
            child: _GlassSurface(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Destaques',
                    style: TextStyle(
                      color: Color(0xFF1F2A44),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 12),
                  _HighlightItem(
                    icon: Icons.map_outlined,
                    title: 'Mapa como plano de fundo',
                    text:
                        'Google Maps híbrido sempre visível.',
                  ),
                  _HighlightItem(
                    icon: Icons.layers_outlined,
                    title:
                        'Menus translúcidos',
                    text:
                        'Painéis claros sobre o mapa.',
                  ),
                  _HighlightItem(
                    icon: Icons.speed_rounded,
                    title:
                        'Tráfego e velocidade',
                    text:
                        'Tráfego Google + telemetria do veículo.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HighlightItem extends StatelessWidget {
  const _HighlightItem({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F0FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF176EEB), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1F2A44),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFF60718D),
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

class _VehicleCompactPopup extends StatelessWidget {
  const _VehicleCompactPopup({
    required this.snapshot,
    required this.balloonScale,
    required this.cardDensity,
    required this.sidebarOpen,
    required this.onDetails,
    required this.onAlerts,
    required this.onShare,
    required this.onMore,
    required this.onClose,
    this.onTelemetry,
  });

  final _VehicleSnapshot snapshot;
  final double balloonScale;
  final VisualCardDensity cardDensity;
  final bool sidebarOpen;
  final VoidCallback onDetails;
  final VoidCallback onAlerts;
  final VoidCallback onShare;
  final VoidCallback onMore;
  final VoidCallback onClose;
  final VoidCallback? onTelemetry;

  @override
  Widget build(BuildContext context) {
    final compactDensity = cardDensity == VisualCardDensity.compact;
    final statusColor = snapshot.statusColor;
    final isMoving = snapshot.isMoving;
    return Positioned(
      left: compactDensity ? 242 : 270,
      top: 142,
      child: _SurfaceGuard(
        child: Transform.scale(
          scale: balloonScale,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 320,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFDDE5F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22183153),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                      child: Row(

                children: [
                          _VehicleAvatar(snapshot: snapshot, size: 44, iconSize: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  snapshot.device.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF1A2540),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Container(
                                      width: 6, height: 6,
                                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(snapshot.statusLabel,
                                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
                                    if (isMoving) ...[
                                      const SizedBox(width: 6),
                                      Text('· ${snapshot.speedLabel}',
                                          style: const TextStyle(color: Color(0xFF52627C), fontSize: 11, fontWeight: FontWeight.w600)),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: onClose,
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.close_rounded, size: 16, color: Color(0xFF8899B0)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F9FD),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE8EFF8)),
                      ),
                      child: Row(
                        children: [
                          _PopupMetric(icon: Icons.speed_rounded, label: 'Velocidade', value: snapshot.speedLabel, color: const Color(0xFF176EEB)),
                          _popupDivider(),
                          _PopupMetric(
                            icon: Icons.power_settings_new_rounded, label: 'Ignição', value: snapshot.ignitionLabel,
                            color: snapshot.ignition == true ? const Color(0xFF16A34A) : const Color(0xFF6B7B94),
                          ),
                          _popupDivider(),
                          _PopupMetric(icon: Icons.battery_charging_full_rounded, label: 'Bateria', value: snapshot.batteryLabel, color: const Color(0xFF0F766E)),
                          _popupDivider(),
                          _PopupMetric(icon: Icons.network_cell_rounded, label: 'GSM', value: snapshot.gsmSignalLabel, color: const Color(0xFF7C3AED)),
                        ],
                      ),
                    ),
                    if (snapshot.address.isNotEmpty && snapshot.address != 'Não informado')
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                        child: Row(
                          children: [
                            const Icon(Icons.place_outlined, size: 13, color: Color(0xFF8899B0)),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(snapshot.address, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Color(0xFF52627C), fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: onDetails,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(color: const Color(0xFF176EEB), borderRadius: BorderRadius.circular(9)),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.open_in_full_rounded, color: Colors.white, size: 14),
                                    SizedBox(width: 6),
                                    Text('Ver detalhes', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (onTelemetry != null) ...[
                            _PopupAction(icon: Icons.speed_rounded, tooltip: 'Telemetria ao vivo', onTap: onTelemetry!),
                            const SizedBox(width: 6),
                          ],
                          _PopupAction(icon: Icons.notifications_none_outlined, tooltip: 'Alertas', onTap: onAlerts),
                          const SizedBox(width: 6),
                          _PopupAction(icon: Icons.share_outlined, tooltip: 'Compartilhar', onTap: onShare),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _popupDivider() => Container(
        width: 1, height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: const Color(0xFFDDE5F0),
      );
}

class _PopupMetric extends StatelessWidget {
  const _PopupMetric({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: Color(0xFF8899B0), fontSize: 8.5, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF1A2540), fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _VehicleBottomBar extends StatelessWidget {
  const _VehicleBottomBar({
    required this.snapshot,
    required this.replayAsync,
    required this.replayPoints,
    required this.replayIndex,
    required this.replayWindow,
    required this.replayPlaying,
    required this.cardDensity,
    required this.sidebarOpen,
    required this.sidebarVisible,
    required this.activeTab,
    required this.onReplayWindowChanged,
    required this.onReplayIndexChanged,
    required this.onReplayToggle,
    required this.panelMode,
    required this.onTabChanged,
    required this.onModeChanged,
    required this.onClose,
    this.onAiTap,
  });

  final _VehicleSnapshot? snapshot;
  final AsyncValue<List<_ReplayPoint>> replayAsync;
  final List<_ReplayPoint> replayPoints;
  final int? replayIndex;
  final Duration replayWindow;
  final bool replayPlaying;
  final VisualCardDensity cardDensity;
  final bool sidebarOpen;
  final bool sidebarVisible;
  final _VehicleBottomTab activeTab;
  final ValueChanged<Duration> onReplayWindowChanged;
  final ValueChanged<int> onReplayIndexChanged;
  final VoidCallback onReplayToggle;
  final _VehiclePanelMode panelMode;
  final ValueChanged<_VehicleBottomTab> onTabChanged;
  final ValueChanged<_VehiclePanelMode> onModeChanged;
  final VoidCallback onClose;
  final VoidCallback? onAiTap;

  @override
  Widget build(BuildContext context) {
    final visible = snapshot != null;
    final width = MediaQuery.sizeOf(context).width;
    final compactDensity = cardDensity == VisualCardDensity.compact;
    final effectivePanelMode = activeTab == _VehicleBottomTab.chart
        ? _VehiclePanelMode.full
        : panelMode;
    final sidebarWidth = !sidebarVisible
        ? 0.0
        : (sidebarOpen
            ? (compactDensity ? 208.0 : 224.0)
            : (compactDensity ? 68.0 : 72.0));
    final height = switch (effectivePanelMode) {
      _VehiclePanelMode.collapsed => compactDensity ? 62.0 : 68.0,
      _VehiclePanelMode.summary   => compactDensity ? 218.0 : 240.0,
      _VehiclePanelMode.full      => compactDensity ? 218.0 : 240.0,
    };

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      left: width >= 980 ? (16.0 + sidebarWidth + 10.0) : 16,
      right: compactDensity ? 12 : 16,
      bottom: visible ? 14 : -height - 28,
      height: height,
      child: IgnorePointer(
        ignoring: !visible,
        child: _SurfaceGuard(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: visible ? 1 : 0,
            child: snapshot == null
                ? const SizedBox.shrink()
                : _LightVehiclePanel(
                    borderRadius: 18,
                    padding: EdgeInsets.zero,
                    child: _VehicleBottomContent(
                      snapshot: snapshot!,
                      replayAsync: replayAsync,
                      replayPoints: replayPoints,
                      replayIndex: replayIndex,
                      replayWindow: replayWindow,
                      replayPlaying: replayPlaying,
                      activeTab: activeTab,
                      onReplayWindowChanged: onReplayWindowChanged,
                      onReplayIndexChanged: onReplayIndexChanged,
                      onReplayToggle: onReplayToggle,
                      panelMode: effectivePanelMode,
                      onTabChanged: onTabChanged,
                      onModeChanged: onModeChanged,
                      onClose: onClose,
                      onAiTap: onAiTap,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _VehicleBottomContent extends StatelessWidget {
  const _VehicleBottomContent({
    required this.snapshot,
    required this.replayAsync,
    required this.replayPoints,
    required this.replayIndex,
    required this.replayWindow,
    required this.replayPlaying,
    required this.activeTab,
    required this.onReplayWindowChanged,
    required this.onReplayIndexChanged,
    required this.onReplayToggle,
    required this.panelMode,
    required this.onTabChanged,
    required this.onModeChanged,
    required this.onClose,
    this.onAiTap,
  });

  final _VehicleSnapshot snapshot;
  final AsyncValue<List<_ReplayPoint>> replayAsync;
  final List<_ReplayPoint> replayPoints;
  final int? replayIndex;
  final Duration replayWindow;
  final bool replayPlaying;
  final _VehicleBottomTab activeTab;
  final ValueChanged<Duration> onReplayWindowChanged;
  final ValueChanged<int> onReplayIndexChanged;
  final VoidCallback onReplayToggle;
  final _VehiclePanelMode panelMode;
  final ValueChanged<_VehicleBottomTab> onTabChanged;
  final ValueChanged<_VehiclePanelMode> onModeChanged;
  final VoidCallback onClose;
  final VoidCallback? onAiTap;

  @override
  Widget build(BuildContext context) {
    final isDriver = snapshot.isDriver;
    final statusColor =
        isDriver ? snapshot.driverStatusColor : snapshot.statusColor;
    final quickActions = [
      (
        icon: Icons.remove_red_eye_outlined,
        label: 'Ver detalhes',
        tab: _VehicleBottomTab.overview,
      ),
      (
        icon: Icons.history_rounded,
        label: 'Histórico',
        tab: _VehicleBottomTab.chart,
      ),
      (
        icon: Icons.send_rounded,
        label: 'Comando',
        tab: _VehicleBottomTab.commands,
      ),
      (
        icon: Icons.share_outlined,
        label: 'Compartilhar',
        tab: _VehicleBottomTab.info,
      ),
    ];

    void handleQuickAction(
      ({IconData icon, String label, _VehicleBottomTab tab}) action,
    ) {
      onTabChanged(action.tab);
      if (action.tab == _VehicleBottomTab.overview ||
          action.tab == _VehicleBottomTab.chart) {
        onModeChanged(_VehiclePanelMode.full);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1040;
        final summaryMetrics = isDriver
            ? <(IconData icon, String label, String value)>[
                (Icons.speed_rounded, 'Velocidade', snapshot.speedLabel),
                (
                  Icons.fiber_manual_record_rounded,
                  'Status',
                  snapshot.driverStatusLabel,
                ),
                (
                  Icons.access_time_rounded,
                  'Última posição',
                  snapshot.relativeLastPoint,
                ),
              ]
            : <(IconData icon, String label, String value)>[
                (Icons.speed_rounded, 'Velocidade', snapshot.speedLabel),
                (
                  Icons.power_settings_new_rounded,
                  'Ignição',
                  snapshot.ignitionLabel,
                ),
                (
                  Icons.battery_charging_full_rounded,
                  'Bateria',
                  snapshot.batteryLabel,
                ),
                (
                  Icons.network_cell_rounded,
                  'Sinal GSM',
                  snapshot.gsmSignalLabel,
                ),
              ];

        Widget modeButton({
          required IconData icon,
          required String tooltip,
          required _VehiclePanelMode mode,
        }) {
          final selected = panelMode == mode;
          return IconButton(
            tooltip: tooltip,
            onPressed: () => onModeChanged(mode),
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              backgroundColor: selected
                  ? const Color(0xFF176EEB).withValues(alpha: 0.12)
                  : const Color(0xFFF4F7FC),
              side: BorderSide(
                color: selected
                    ? const Color(0xFFBFD8FF)
                    : const Color(0xFFDDE5F0),
              ),
            ),
            icon: Icon(
              icon,
              color:
                  selected ? const Color(0xFF176EEB) : const Color(0xFF5A6D89),
              size: 18,
            ),
          );
        }

        final isCollapsed = panelMode == _VehiclePanelMode.collapsed;
        final iconColor =
            isDriver ? const Color(0xFF1A9E3F) : const Color(0xFF176EEB);
        final iconData = isDriver
            ? Icons.engineering_rounded
            : Icons.directions_car_filled_rounded;

        final photoUrl = snapshot.device.image ?? '';
        final hasPhoto = photoUrl.isNotEmpty;
        const headerH = 68.0;

        // Reusable name+badge+subtitle widget
        Widget nameBlock({double nameFontSize = 13.0}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    snapshot.device.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF1F2A44),
                      fontWeight: FontWeight.w900,
                      fontSize: nameFontSize,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: statusColor.withValues(alpha: 0.30)),
                  ),
                  child: Text(
                    isDriver ? snapshot.driverStatusLabel : snapshot.statusLabel,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 9.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${snapshot.identifierLabel} • ${snapshot.relativeLastPoint}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF52627C), fontWeight: FontWeight.w700, fontSize: 10.0),
            ),
          ],
        );

        // Reusable action buttons (IA + expand/collapse + close)
        Widget actionButtons() => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AiAssistButton(onTap: onAiTap),
            const SizedBox(width: 6),
            IconButton(
              tooltip: isCollapsed ? 'Expandir' : 'Recolher',
              onPressed: () => onModeChanged(isCollapsed ? _VehiclePanelMode.full : _VehiclePanelMode.collapsed),
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF4F7FC),
                side: const BorderSide(color: Color(0xFFDDE5F0)),
              ),
              icon: Icon(
                isCollapsed ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: const Color(0xFF5A6D89), size: 18,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Fechar',
              onPressed: onClose,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF4F7FC),
                side: const BorderSide(color: Color(0xFFDDE5F0)),
              ),
              icon: const Icon(Icons.close_rounded, color: Color(0xFF5A6D89), size: 18),
            ),
          ],
        );

        final header = SizedBox(
          height: headerH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Photo flush-left
              SizedBox(
                width: isCollapsed ? 68 : 100,
                child: hasPhoto
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _VehicleHeaderPhotoFallback(color: iconColor, icon: iconData),
                      )
                    : _VehicleHeaderPhotoFallback(color: iconColor, icon: iconData),
              ),
              // ── Header always identical regardless of collapsed/expanded ──
              SizedBox(
                width: 190,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                  child: nameBlock(nameFontSize: 12.4),
                ),
              ),
              const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFDDE5F0)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: _VehicleMapMetricCell(icon: Icons.speed_rounded, label: 'Velocidade', value: snapshot.speedLabel, accent: const Color(0xFF176EEB))),
                      const VerticalDivider(width: 18, color: Color(0xFFE2E8F0)),
                      Expanded(child: _VehicleMapMetricCell(icon: Icons.power_settings_new_rounded, label: 'Ignição', value: snapshot.ignitionLabel, accent: const Color(0xFF16A34A))),
                      const VerticalDivider(width: 18, color: Color(0xFFE2E8F0)),
                      Expanded(child: _VehicleMapMetricCell(icon: Icons.battery_charging_full_rounded, label: 'Bateria', value: snapshot.batteryLabel, accent: const Color(0xFF16A34A))),
                      const VerticalDivider(width: 18, color: Color(0xFFE2E8F0)),
                      Expanded(child: _VehicleMapMetricCell(icon: Icons.network_cell_rounded, label: 'Sinal GSM', value: snapshot.gsmSignalLabel, accent: const Color(0xFF16A34A))),
                      const VerticalDivider(width: 18, color: Color(0xFFE2E8F0)),
                      Expanded(child: _VehicleMapMetricCell(icon: Icons.schedule_rounded, label: 'Última atualização', value: snapshot.lastCommunicationLabel, subtitle: snapshot.relativeLastPoint, accent: const Color(0xFF334155))),
                      const VerticalDivider(width: 18, color: Color(0xFFE2E8F0)),
                      Expanded(child: _VehicleMapMetricCell(icon: Icons.place_outlined, label: 'Endereço', value: snapshot.address, accent: const Color(0xFF334155), maxLines: 2)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                child: actionButtons(),
              ),
            ],
          ),
        );

        final summaryBody = Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDDE5F0)),
            ),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: compact
                ? SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            for (final item in summaryMetrics)
                              _VehicleMapMetricCell(
                                icon: item.$1,
                                label: item.$2,
                                value: item.$3,
                                accent: const Color(0xFF334155),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF52627C),
                            fontWeight: FontWeight.w700,
                            fontSize: 10.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _AiAssistButton(onTap: onAiTap),
                      ],
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            for (var i = 0; i < summaryMetrics.length; i++) ...[
                              Expanded(
                                child: _VehicleMapMetricCell(
                                  icon: summaryMetrics[i].$1,
                                  label: summaryMetrics[i].$2,
                                  value: summaryMetrics[i].$3,
                                  accent: const Color(0xFF334155),
                                ),
                              ),
                              if (i != summaryMetrics.length - 1)
                                const VerticalDivider(
                                  width: 20,
                                  color: Color(0xFFE2E8F0),
                                ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _AiAssistButton(onTap: onAiTap),
                    ],
                  ),
          ),
        );

        final infoStrip = Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDDE5F0)),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _VehicleMapMetricCell(
                          icon: Icons.speed_rounded,
                          label: 'Velocidade',
                          value: snapshot.speedLabel,
                          accent: const Color(0xFF1F2A44),
                        ),
                        _VehicleMapMetricCell(
                          icon: Icons.power_settings_new_rounded,
                          label: 'Ignição',
                          value: snapshot.ignitionLabel,
                          accent: const Color(0xFF16A34A),
                        ),
                        _VehicleMapMetricCell(
                          icon: Icons.battery_charging_full_rounded,
                          label: 'Bateria',
                          value: snapshot.batteryLabel,
                          accent: const Color(0xFF16A34A),
                        ),
                        _VehicleMapMetricCell(
                          icon: Icons.network_cell_rounded,
                          label: 'Sinal GSM',
                          value: snapshot.gsmSignalLabel,
                          accent: const Color(0xFF16A34A),
                        ),
                        _VehicleMapMetricCell(
                          icon: Icons.schedule_rounded,
                          label: 'Última atualização',
                          value: snapshot.lastCommunicationLabel,
                          subtitle: snapshot.relativeLastPoint,
                          accent: const Color(0xFF334155),
                        ),
                        _VehicleMapMetricCell(
                          icon: Icons.place_outlined,
                          label: 'Endereço',
                          value: snapshot.address,
                          accent: const Color(0xFF334155),
                          maxLines: 2,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _AiAssistButton(onTap: onAiTap),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 8,
                      child: Row(
                        children: [
                          Expanded(
                            child: _VehicleMapMetricCell(
                              icon: Icons.speed_rounded,
                              label: 'Velocidade',
                              value: snapshot.speedLabel,
                              accent: const Color(0xFF1F2A44),
                            ),
                          ),
                          const VerticalDivider(
                              width: 22, color: Color(0xFFE2E8F0)),
                          Expanded(
                            child: _VehicleMapMetricCell(
                              icon: Icons.power_settings_new_rounded,
                              label: 'Ignição',
                              value: snapshot.ignitionLabel,
                              accent: const Color(0xFF16A34A),
                            ),
                          ),
                          const VerticalDivider(
                              width: 22, color: Color(0xFFE2E8F0)),
                          Expanded(
                            child: _VehicleMapMetricCell(
                              icon: Icons.battery_charging_full_rounded,
                              label: 'Bateria',
                              value: snapshot.batteryLabel,
                              accent: const Color(0xFF16A34A),
                            ),
                          ),
                          const VerticalDivider(
                              width: 22, color: Color(0xFFE2E8F0)),
                          Expanded(
                            child: _VehicleMapMetricCell(
                              icon: Icons.network_cell_rounded,
                              label: 'Sinal GSM',
                              value: snapshot.gsmSignalLabel,
                              accent: const Color(0xFF16A34A),
                            ),
                          ),
                          const VerticalDivider(
                              width: 22, color: Color(0xFFE2E8F0)),
                          Expanded(
                            child: _VehicleMapMetricCell(
                              icon: Icons.schedule_rounded,
                              label: 'Última atualização',
                              value: snapshot.lastCommunicationLabel,
                              subtitle: snapshot.relativeLastPoint,
                              accent: const Color(0xFF334155),
                            ),
                          ),
                          const VerticalDivider(
                              width: 22, color: Color(0xFFE2E8F0)),
                          Expanded(
                            child: _VehicleMapMetricCell(
                              icon: Icons.place_outlined,
                              label: 'Endereço',
                              value: snapshot.address,
                              accent: const Color(0xFF334155),
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _AiAssistButton(onTap: onAiTap),
                  ],
                ),
        );

        final overviewContent = compact
            ? ListView(
                padding: EdgeInsets.zero,
                children: [
                  SizedBox(
                    height: 120,
                    child: _VehicleTelemetryPanel(snapshot: snapshot),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 120,
                    child: _VehicleBottomEventsPanel(snapshot: snapshot),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 200,
                    child: _VehicleCommandsPanel(snapshot: snapshot),
                  ),
                  const VerticalDivider(width: 17, thickness: 1, color: Color(0xFFDDE5F0)),
                  SizedBox(
                    width: 200,
                    child: _VehicleTelemetryPanel(snapshot: snapshot),
                  ),
                  const VerticalDivider(width: 17, thickness: 1, color: Color(0xFFDDE5F0)),
                  Expanded(
                    child: _VehicleBottomEventsPanel(snapshot: snapshot),
                  ),
                ],
              );

        Widget activeFullContent() {
          switch (activeTab) {
            case _VehicleBottomTab.overview:
              return overviewContent;
            case _VehicleBottomTab.chart:
              return _VehicleReplayPanel(
                snapshot: snapshot,
                replayAsync: replayAsync,
                replayPoints: replayPoints,
                replayIndex: replayIndex,
                replayWindow: replayWindow,
                replayPlaying: replayPlaying,
                onReplayWindowChanged: onReplayWindowChanged,
                onReplayIndexChanged: onReplayIndexChanged,
                onReplayToggle: onReplayToggle,
              );
            case _VehicleBottomTab.commands:
              return _VehicleCommandsTab(snapshot: snapshot);
            case _VehicleBottomTab.info:
              return _VehicleInfoTab(snapshot: snapshot);
            case _VehicleBottomTab.photos:
              return _VehicleEmptyTab(
                icon: Icons.image_outlined,
                title: 'Fotos',
                detail:
                    'Espaco pronto para fotos, MDVR e evidencias do dispositivo.',
              );
          }
        }

        final fullBody = Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
          child: activeFullContent(),
        );

        return Column(
          children: [
            header,
            if (!isCollapsed) ...[
              const Divider(height: 1, color: Color(0xFFDDE5F0)),
              Expanded(child: fullBody),
            ],
          ],
        );
      },
    );
  }
}

// ── Vehicle header photo / fallback panel ────────────────────────────────────

class _VehicleHeaderPhotoFallback extends StatelessWidget {
  const _VehicleHeaderPhotoFallback({required this.color, required this.icon});
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.08),
          ],
        ),
        border: Border(right: BorderSide(color: color.withValues(alpha: 0.15))),
      ),
      child: Center(
        child: Icon(icon, color: color.withValues(alpha: 0.70), size: 32),
      ),
    );
  }
}

// ── Vehicle thumb (photo fallback) ────────────────────────────────────────────

class _VehicleIconThumb extends StatelessWidget {
  const _VehicleIconThumb({required this.size, required this.icon, required this.color, required this.isCollapsed});
  final double size;
  final IconData icon;
  final Color color;
  final bool isCollapsed;

  @override
  Widget build(BuildContext context) {
    final bg = Color.lerp(color, Colors.white, 0.88)!;
    final border = Color.lerp(color, Colors.white, 0.65)!;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(isCollapsed ? 9 : 12),
        border: Border.all(color: border),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

// ── AI assist button ───────────────────────────────────────────────────────────

class _AiAssistButton extends StatelessWidget {
  const _AiAssistButton({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF176EEB), Color(0xFF5B4EFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: const Color(0xFF176EEB).withValues(alpha: 0.30), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
            SizedBox(width: 6),
            Text('IA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _VehicleMapMetricCell extends StatelessWidget {
  const _VehicleMapMetricCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.subtitle,
    this.maxLines = 1,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Color accent;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, color: accent, size: 18),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF52627C),
                  fontWeight: FontWeight.w700,
                  fontSize: 10.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1F2A44),
                  fontWeight: FontWeight.w900,
                  fontSize: 14.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF60718D),
                    fontWeight: FontWeight.w700,
                    fontSize: 10.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _VehicleMapQuickActionButton extends StatelessWidget {
  const _VehicleMapQuickActionButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE8F1FF) : const Color(0xFFF8FAFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  selected ? const Color(0xFF9EC5FF) : const Color(0xFFDDE5F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected
                    ? const Color(0xFF176EEB)
                    : const Color(0xFF52627C),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF176EEB)
                      : const Color(0xFF334155),
                  fontWeight: FontWeight.w800,
                  fontSize: 11.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeedGauge extends StatelessWidget {
  const _SpeedGauge({required this.snapshot});
  final _VehicleSnapshot snapshot;

  static const _maxSpeed = 240.0;

  @override
  Widget build(BuildContext context) {
    final speed = (snapshot.speed ?? 0).toDouble().clamp(0.0, _maxSpeed);
    final Color arcColor = speed < 60
        ? const Color(0xFF22D3EE)
        : speed < 100
            ? const Color(0xFFFBBF24)
            : const Color(0xFFEF4444);

    return Row(
      children: [
        // ── Dial ──
        Expanded(
          flex: 3,
          child: Center(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: CustomPaint(
                painter: _SpeedGaugePainter(speed: speed, maxSpeed: _maxSpeed, color: arcColor),
                child: Align(
                  alignment: const Alignment(0, 0.62),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        speed > 0 ? speed.toInt().toString() : '--',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                          height: 1,
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        'km/h',
                        style: TextStyle(
                          color: arcColor.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w700,
                          fontSize: 8,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // ── Divider ──
        Container(
          width: 1,
          margin: const EdgeInsets.symmetric(vertical: 16),
          color: const Color(0xFFDDE5F0),
        ),
        // ── Info lateral ──
        SizedBox(
          width: 50,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('IGN',
                      style: TextStyle(
                          color: Color(0xFF8899B0),
                          fontSize: 7,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(snapshot.ignitionLabel,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: arcColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 6),
              const Divider(height: 1, color: Color(0xFFDDE5F0)),
              const SizedBox(height: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('BAT',
                      style: TextStyle(
                          color: Color(0xFF8899B0),
                          fontSize: 7,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(snapshot.batteryLabel,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFF22D3EE),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpeedGaugePainter extends CustomPainter {
  const _SpeedGaugePainter({required this.speed, required this.maxSpeed, required this.color});
  final double speed;
  final double maxSpeed;
  final Color color;

  static const _startAngle = math.pi * 0.75;
  static const _sweepAngle = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);
    final r = math.min(size.width, size.height) * 0.40;
    final fraction = (speed / maxSpeed).clamp(0.0, 1.0);

    // ── Background circles ─────────────────────────────────────────
    canvas.drawCircle(center, r + 6, Paint()..color = const Color(0xFF040A10));
    canvas.drawCircle(center, r + 3, Paint()..color = const Color(0xFF08111C));
    canvas.drawCircle(center, r,     Paint()..color = const Color(0xFF0A1825));

    // Inner ring stroke
    canvas.drawCircle(center, r + 1, Paint()
      ..color = const Color(0xFF1A3050)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);

    // ── Track arc ──────────────────────────────────────────────────
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r - 5),
      _startAngle, _sweepAngle, false,
      Paint()
        ..color = const Color(0xFF122030)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7,
    );

    // ── Speed arc glow + fill ──────────────────────────────────────
    if (fraction > 0.005) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r - 5),
        _startAngle, _sweepAngle * fraction, false,
        Paint()
          ..color = color.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r - 5),
        _startAngle, _sweepAngle * fraction, false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── Tick marks + labels ────────────────────────────────────────
    const steps = 24; // 0–240 at 10 km/h
    for (int i = 0; i <= steps; i++) {
      final pct = i / steps;
      final angle = _startAngle + _sweepAngle * pct;
      final isMajor = i % 2 == 0;
      final outerR = r - 11;
      final innerR = isMajor ? r - 24 : r - 17;

      canvas.drawLine(
        Offset(cx + outerR * math.cos(angle), cy + outerR * math.sin(angle)),
        Offset(cx + innerR * math.cos(angle), cy + innerR * math.sin(angle)),
        Paint()
          ..color = isMajor ? Colors.white.withValues(alpha: 0.52) : Colors.white.withValues(alpha: 0.18)
          ..strokeWidth = isMajor ? 1.4 : 0.7
          ..strokeCap = StrokeCap.round,
      );

      if (isMajor) {
        final labelR = r - 36;
        final lx = cx + labelR * math.cos(angle);
        final ly = cy + labelR * math.sin(angle);
        final tp = TextPainter(
          text: TextSpan(
            text: (i * 10).toString(),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.48), fontSize: (r * 0.115).clamp(8.0, 13.0), fontWeight: FontWeight.w600),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
      }
    }

    // ── Needle ─────────────────────────────────────────────────────
    final needleAngle = _startAngle + _sweepAngle * fraction;
    final needleLen = r - 18;
    final tipX = cx + needleLen * math.cos(needleAngle);
    final tipY = cy + needleLen * math.sin(needleAngle);
    final bw = r * 0.038;
    final b1 = Offset(cx + bw * math.cos(needleAngle + math.pi / 2), cy + bw * math.sin(needleAngle + math.pi / 2));
    final b2 = Offset(cx + bw * math.cos(needleAngle - math.pi / 2), cy + bw * math.sin(needleAngle - math.pi / 2));

    // Glow
    canvas.drawLine(center, Offset(tipX, tipY),
      Paint()
        ..color = color.withValues(alpha: 0.40)
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));

    // Body
    canvas.drawPath(
      Path()..moveTo(tipX, tipY)..lineTo(b1.dx, b1.dy)..lineTo(b2.dx, b2.dy)..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.90),
    );

    // Tip dot
    canvas.drawCircle(Offset(tipX, tipY), 2.5, Paint()..color = color);

    // ── Center hub ─────────────────────────────────────────────────
    canvas.drawCircle(center, r * 0.12, Paint()..color = const Color(0xFF08111C));
    canvas.drawCircle(center, r * 0.08, Paint()..color = color.withValues(alpha: 0.85));
    canvas.drawCircle(center, r * 0.04, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_SpeedGaugePainter old) => old.speed != speed || old.color != color;
}

// ignore: unused_element
class _VehicleBottomSpeedPanel extends StatelessWidget {
  const _VehicleBottomSpeedPanel({required this.snapshot});

  final _VehicleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    // kept for chart tab compatibility — overview now uses _SpeedGauge
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: const Text(
                  'Velocidade (últimas 2 horas)',
                  style: TextStyle(color: Color(0xFF1F2A44), fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                const Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('120', style: TextStyle(color: Color(0xFF70829A), fontSize: 11)),
                    Text('60',  style: TextStyle(color: Color(0xFF70829A), fontSize: 11)),
                    Text('0',   style: TextStyle(color: Color(0xFF70829A), fontSize: 11)),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: CustomPaint(
                          painter: _SpeedLinePainter(values: const [58,48,57,44,68,52,56,45,61,50,42,47,36,52,44,48]),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('08:30', style: TextStyle(color: Color(0xFF70829A), fontSize: 11)),
                          Text('09:00', style: TextStyle(color: Color(0xFF70829A), fontSize: 11)),
                          Text('09:30', style: TextStyle(color: Color(0xFF70829A), fontSize: 11)),
                          Text('10:00', style: TextStyle(color: Color(0xFF70829A), fontSize: 11)),
                          Text('10:30', style: TextStyle(color: Color(0xFF70829A), fontSize: 11)),
                        ],
                      ),
                    ],
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

class _VehicleReplayPanel extends StatelessWidget {
  const _VehicleReplayPanel({
    required this.snapshot,
    required this.replayAsync,
    required this.replayPoints,
    required this.replayIndex,
    required this.replayWindow,
    required this.replayPlaying,
    required this.onReplayWindowChanged,
    required this.onReplayIndexChanged,
    required this.onReplayToggle,
  });

  final _VehicleSnapshot snapshot;
  final AsyncValue<List<_ReplayPoint>> replayAsync;
  final List<_ReplayPoint> replayPoints;
  final int? replayIndex;
  final Duration replayWindow;
  final bool replayPlaying;
  final ValueChanged<Duration> onReplayWindowChanged;
  final ValueChanged<int> onReplayIndexChanged;
  final VoidCallback onReplayToggle;

  String _windowLabel(Duration duration) {
    if (duration.inHours >= 24) {
      return '${duration.inHours}h';
    }
    return '${duration.inHours}h';
  }

  String _distanceLabel() {
    if (replayPoints.length < 2) return '0 km';
    var totalKm = 0.0;
    for (var index = 1; index < replayPoints.length; index++) {
      totalKm += _distanceBetweenKm(
        replayPoints[index - 1],
        replayPoints[index],
      );
    }
    return '${totalKm.toStringAsFixed(1)} km';
  }

  double _distanceBetweenKm(_ReplayPoint a, _ReplayPoint b) {
    const earthRadiusKm = 6371.0;
    final dLat = (b.latitude - a.latitude) * (3.141592653589793 / 180);
    final dLng = (b.longitude - a.longitude) * (3.141592653589793 / 180);
    final lat1 = a.latitude * (3.141592653589793 / 180);
    final lat2 = b.latitude * (3.141592653589793 / 180);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return earthRadiusKm * c;
  }

  @override
  Widget build(BuildContext context) {
    final selectedPoint =
        replayIndex == null || replayIndex! >= replayPoints.length
            ? null
            : replayPoints[replayIndex!];
    final rangeOptions = [
      const Duration(hours: 6),
      const Duration(hours: 24),
      const Duration(hours: 48),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: replayAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Falha ao carregar replay real: $error',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFB42318),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        data: (_) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Replay visual da rota',
                      style: TextStyle(
                        color: Color(0xFF1F2A44),
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  for (final option in rangeOptions) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text(_windowLabel(option)),
                        selected: replayWindow == option,
                        onSelected: (_) => onReplayWindowChanged(option),
                        labelStyle: TextStyle(
                          color: replayWindow == option
                              ? const Color(0xFF176EEB)
                              : const Color(0xFF52627C),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _ReplayMetricPill(
                    label: 'Veiculo',
                    value: snapshot.device.name,
                  ),
                  _ReplayMetricPill(
                    label: 'Pontos',
                    value: '${replayPoints.length}',
                  ),
                  _ReplayMetricPill(
                    label: 'Distancia',
                    value: _distanceLabel(),
                  ),
                  _ReplayMetricPill(
                    label: 'Status',
                    value: replayPlaying ? 'Reproduzindo' : 'Pronto',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Anterior',
                    onPressed: replayIndex == null || replayIndex! <= 0
                        ? null
                        : () => onReplayIndexChanged(replayIndex! - 1),
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                  FilledButton.icon(
                    onPressed: replayPoints.length < 2 ? null : onReplayToggle,
                    icon: Icon(
                      replayPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                    ),
                    label: Text(replayPlaying ? 'Pausar' : 'Reproduzir'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Proximo',
                    onPressed: replayIndex == null ||
                            replayIndex! >= replayPoints.length - 1
                        ? null
                        : () => onReplayIndexChanged(replayIndex! + 1),
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                  const Spacer(),
                  Text(
                    selectedPoint == null
                        ? '--/--'
                        : '${(replayIndex ?? 0) + 1}/${replayPoints.length}',
                    style: const TextStyle(
                      color: Color(0xFF52627C),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 7),
                ),
                child: Slider(
                  value: (replayIndex ?? 0).toDouble(),
                  min: 0,
                  max: math.max(replayPoints.length - 1, 0).toDouble(),
                  divisions:
                      replayPoints.length > 1 ? replayPoints.length - 1 : null,
                  onChanged: replayPoints.isEmpty
                      ? null
                      : (value) => onReplayIndexChanged(value.round()),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: selectedPoint == null
                    ? const Center(
                        child: Text(
                          'Nenhum ponto real encontrado para o periodo selecionado.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF52627C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFDDE5F0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedPoint.timeLabel,
                                    style: const TextStyle(
                                      color: Color(0xFF1F2A44),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${selectedPoint.speedLabel} • '
                                    '${selectedPoint.latitude.toStringAsFixed(5)}, '
                                    '${selectedPoint.longitude.toStringAsFixed(5)}',
                                    style: const TextStyle(
                                      color: Color(0xFF52627C),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    selectedPoint.address,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF60718D),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F1FF),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                selectedPoint.course == null
                                    ? 'Sem rumo'
                                    : 'Rumo ${selectedPoint.course!.toStringAsFixed(0)}°',
                                style: const TextStyle(
                                  color: Color(0xFF176EEB),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              const Text(
                'A rota esta sincronizada com o mapa principal. O veiculo selecionado '
                'permanece em foco durante o replay, preparando a base para full screen '
                'e camera 3D depois.',
                style: TextStyle(
                  color: Color(0xFF52627C),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReplayMetricPill extends StatelessWidget {
  const _ReplayMetricPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF60718D),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1F2A44),
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleBottomEventItem {
  const _VehicleBottomEventItem({
    required this.time,
    required this.label,
    required this.color,
    required this.icon,
  });

  final String time;
  final String label;
  final Color color;
  final IconData icon;
}

class _VehicleBottomEventsPanel extends StatelessWidget {
  const _VehicleBottomEventsPanel({required this.snapshot});

  final _VehicleSnapshot snapshot;

  List<_VehicleBottomEventItem> _resolveEvents() {
    if (snapshot.recentEvents.isEmpty) {
      return const [
        _VehicleBottomEventItem(
          time: '10:24:32',
          label: 'Posi\u00E7\u00E3o atualizada',
          color: Color(0xFF1D80FF),
          icon: Icons.circle,
        ),
        _VehicleBottomEventItem(
          time: '10:23:45',
          label: 'Igni\u00E7\u00E3o ligada',
          color: Color(0xFF16A34A),
          icon: Icons.power_settings_new_rounded,
        ),
        _VehicleBottomEventItem(
          time: '10:22:18',
          label: 'Excesso de velocidade (85 km/h)',
          color: Color(0xFFEF4444),
          icon: Icons.warning_amber_rounded,
        ),
        _VehicleBottomEventItem(
          time: '10:18:05',
          label: 'Entrada na cerca: Base SP',
          color: Color(0xFF1D4ED8),
          icon: Icons.place_outlined,
        ),
      ];
    }

    return snapshot.recentEvents.take(4).map((event) {
      final rawType = '${event['type'] ?? ''}'.toLowerCase().trim();
      final rawTime = '${event['eventTime'] ?? event['serverTime'] ?? ''}';
      final parsed = DateTime.tryParse(rawTime);
      final time = parsed == null
          ? '--:--'
          : '${parsed.toLocal().hour.toString().padLeft(2, '0')}:'
              '${parsed.toLocal().minute.toString().padLeft(2, '0')}';

      if (rawType.contains('overspeed')) {
        return _VehicleBottomEventItem(
          time: time,
          label: _humanizeEventType(rawType),
          color: const Color(0xFFEF4444),
          icon: Icons.warning_amber_rounded,
        );
      }
      if (rawType.contains('ignition')) {
        return _VehicleBottomEventItem(
          time: time,
          label: _humanizeEventType(rawType),
          color: const Color(0xFF16A34A),
          icon: Icons.power_settings_new_rounded,
        );
      }
      if (rawType.contains('geofence')) {
        return _VehicleBottomEventItem(
          time: time,
          label: _humanizeEventType(rawType),
          color: const Color(0xFF1D4ED8),
          icon: Icons.place_outlined,
        );
      }
      return _VehicleBottomEventItem(
        time: time,
        label: _humanizeEventType(rawType.isEmpty ? 'event' : rawType),
        color: const Color(0xFF1D80FF),
        icon: Icons.circle,
      );
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final events = _resolveEvents();
    final visibleEvents = events.take(3).toList(growable: false);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '\u00DAltimos eventos',
            style: TextStyle(
              color: Color(0xFF1F2A44),
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    physics: const ClampingScrollPhysics(),
                    itemCount: visibleEvents.length,
                    itemBuilder: (context, index) {
                      final event = visibleEvents[index];
                      return Row(
                        children: [
                          Icon(event.icon, color: event.color, size: 14),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 58,
                            child: Text(
                              event.time,
                              style: const TextStyle(
                                color: Color(0xFF60718D),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              event.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF334155),
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Lista completa ainda depende da integracao deste painel com o modulo detalhado.',
                          ),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Ver todos',
                      style: TextStyle(
                        color: Color(0xFF176EEB),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
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

class _VehicleBottomIdentityPanel extends StatelessWidget {
  const _VehicleBottomIdentityPanel({required this.snapshot});

  final _VehicleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final imageUrl = snapshot.device.image?.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 1.6,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const _VehiclePhotoFallback(),
                      )
                    : const _VehiclePhotoFallback(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _VehicleInfoLine(label: 'Modelo', value: snapshot.modelLabel),
                const SizedBox(height: 4),
                _VehicleInfoLine(
                    label: 'IMEI', value: snapshot.identifierLabel),
                const SizedBox(height: 4),
                const _VehicleInfoLine(label: 'Firmware', value: '1.2.8'),
                const SizedBox(height: 4),
                const _VehicleInfoLine(label: 'Grupo', value: 'Frota SP'),
                const SizedBox(height: 4),
                _VehicleInfoLine(
                    label: 'Motorista', value: snapshot.driverName),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VehiclePhotoFallback extends StatelessWidget {
  const _VehiclePhotoFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF1F5F9),
            Color(0xFFE2E8F0),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.local_shipping_rounded,
          color: Color(0xFF176EEB),
          size: 56,
        ),
      ),
    );
  }
}

class _VehicleInfoLine extends StatelessWidget {
  const _VehicleInfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(
          color: Color(0xFF52627C),
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Color(0xFF1F2A44),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomTabContent extends StatelessWidget {
  const _BottomTabContent({
    required this.snapshot,
    required this.tab,
    required this.compact,
  });

  final _VehicleSnapshot snapshot;
  final _VehicleBottomTab tab;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    switch (tab) {
      case _VehicleBottomTab.overview:
        return _BottomOverviewDetails(snapshot: snapshot, compact: compact);
      case _VehicleBottomTab.photos:
        return _VehicleEmptyTab(
          icon: Icons.image_outlined,
          title: 'Fotos',
          detail:
              'Espa\u00E7o pronto para fotos, MDVR e evid\u00EAncias do dispositivo.',
        );
      case _VehicleBottomTab.commands:
        return _VehicleCommandsTab(snapshot: snapshot);
      case _VehicleBottomTab.chart:
        return _SpeedChartCard(snapshot: snapshot);
      case _VehicleBottomTab.info:
        return _VehicleInfoTab(snapshot: snapshot);
    }
  }
}

class _BottomOverviewDetails extends StatelessWidget {
  const _BottomOverviewDetails({
    required this.snapshot,
    required this.compact,
  });

  final _VehicleSnapshot snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _DetailCard(
        title: 'Localiza\u00E7\u00E3o atual',
        icon: Icons.place_outlined,
        body: snapshot.address,
        action: 'Ver no mapa',
      ),
      _DetailCard(
        title: '\u00DAltimos eventos',
        icon: Icons.timeline_outlined,
        body: snapshot.eventsSummary,
      ),
      _SpeedChartCard(snapshot: snapshot),
      _DetailCard(
        title: 'Informa\u00E7\u00F5es',
        icon: Icons.badge_outlined,
        body:
            'Modelo   ${snapshot.modelLabel}\nAno      2022\nGrupo    Frota SP - Vans',
      ),
    ];

    if (compact) {
      return Column(
        children: [
          for (final card in cards) ...[
            card,
            const SizedBox(height: 10),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 3, child: cards[0]),
        const SizedBox(width: 10),
        Expanded(flex: 3, child: cards[1]),
        const SizedBox(width: 10),
        Expanded(flex: 5, child: cards[2]),
        const SizedBox(width: 10),
        Expanded(flex: 3, child: cards[3]),
      ],
    );
  }
}

class _VehicleInfoTab extends StatelessWidget {
  const _VehicleInfoTab({required this.snapshot});

  final _VehicleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _DetailCard(
          title: 'Informa\u00E7\u00F5es do ve\u00EDculo',
          icon: Icons.badge_outlined,
          body:
              'Modelo   ${snapshot.modelLabel}\nMotorista ${snapshot.driverName}\nIgni\u00E7\u00E3o  ${snapshot.ignitionLabel}\nBateria interna  ${snapshot.batteryLabel}',
        ),
        const SizedBox(height: 10),
        _VehicleSensorsCard(snapshot: snapshot),
      ],
    );
  }
}

class _VehicleSensorsCard extends ConsumerWidget {
  const _VehicleSensorsCard({required this.snapshot});

  final _VehicleSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final includeTechnical = session.isAdministrator || kDebugMode;
    final sections =
        snapshot.sensorSections(includeTechnical: includeTechnical);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E7F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.sensors_outlined,
                color: Color(0xFF176EEB),
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sensores',
                  style: TextStyle(
                    color: Color(0xFF1F2A44),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (sections.isEmpty)
            const Text(
              'Sensores n\u00E3o recebidos',
              style: TextStyle(
                color: Color(0xFF526684),
                fontWeight: FontWeight.w600,
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
                      color: Color(0xFF1F2A44),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      for (final item in section.items)
                        SizedBox(
                          width: 250,
                          child: Row(
                            children: [
                              Icon(
                                item.icon,
                                size: 16,
                                color: const Color(0xFF60718D),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: const TextStyle(
                                    color: Color(0xFF1F2A44),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item.value,
                                style: const TextStyle(
                                  color: Color(0xFF334155),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _VehicleEmptyTab extends StatelessWidget {
  const _VehicleEmptyTab({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _DetailCard(
        title: title,
        icon: icon,
        body: detail,
      ),
    );
  }
}

// ── Compact commands panel (embedded in expanded bottom bar) ──────────────────

class _VehicleCommandsPanel extends ConsumerStatefulWidget {
  const _VehicleCommandsPanel({required this.snapshot});
  final _VehicleSnapshot snapshot;

  @override
  ConsumerState<_VehicleCommandsPanel> createState() =>
      _VehicleCommandsPanelState();
}

class _VehicleCommandsPanelState
    extends ConsumerState<_VehicleCommandsPanel> {
  bool _sending = false;
  String? _lastSent;

  Future<void> _send(String type, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar comando'),
        content: Text(
            'Enviar "$label" para ${widget.snapshot.device.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enviar')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _sending = true;
      _lastSent = null;
    });
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    try {
      await client.createEntity(
        path: '/commands/send',
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'deviceId': widget.snapshot.device.id,
          'type': type,
        },
      );
      if (mounted) setState(() => _lastSent = label);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const cmds = [
      ('engineStop',     Icons.lock_outline_rounded,           'Bloquear',    Color(0xFFEF4444)),
      ('engineResume',   Icons.lock_open_rounded,              'Desbloquear', Color(0xFF16A34A)),
      ('positionSingle', Icons.my_location_outlined,           'Localizar',   Color(0xFF176EEB)),
      ('alarm',          Icons.notifications_active_outlined,  'Alarme',      Color(0xFFF59E0B)),
      ('reboot',         Icons.restart_alt_rounded,            'Reiniciar',   Color(0xFF6366F1)),
      ('custom',         Icons.code_rounded,                   'Custom',      Color(0xFF64748B)),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.terminal_rounded, size: 13, color: Color(0xFF5A6D89)),
            const SizedBox(width: 5),
            const Text('Comandos Traccar',
                style: TextStyle(
                    color: Color(0xFF1F2A44),
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5)),
            if (_sending) ...[
              const SizedBox(width: 8),
              const SizedBox(
                  width: 10, height: 10,
                  child: CircularProgressIndicator(strokeWidth: 1.5)),
            ],
          ]),
          if (_lastSent != null) ...[
            const SizedBox(height: 2),
            Text('✓ $_lastSent enviado',
                style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 6),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 3.8,
              children: [
                for (final c in cmds)
                  _CommandButton(
                    icon: c.$2,
                    label: c.$3,
                    color: c.$4,
                    sending: _sending,
                    onTap: () => _send(c.$1, c.$3),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandButton extends StatelessWidget {
  const _CommandButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.sending,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool sending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: sending ? null : onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5)),
          ],
        ),
      ),
    );
  }
}

// ── Telemetry panel (overview expanded, center column) ────────────────────────

class _VehicleTelemetryPanel extends StatelessWidget {
  const _VehicleTelemetryPanel({required this.snapshot});
  final _VehicleSnapshot snapshot;

  String get _satLabel {
    final v = snapshot.position?.attributes?['sat'];
    if (v == null) return 'N/A';
    return '$v sat';
  }

  String get _altLabel {
    final v = snapshot.position?.attributes?['altitude'] ??
        snapshot.position?.attributes?['alt'];
    if (v == null) return 'N/A';
    final n = num.tryParse(v.toString());
    if (n == null) return 'N/A';
    return '${n.toStringAsFixed(0)} m';
  }

  String get _odomLabel {
    final v = snapshot.position?.attributes?['odometer'] ??
        snapshot.position?.attributes?['totalDistance'];
    if (v == null) return 'N/A';
    final n = num.tryParse(v.toString());
    if (n == null) return 'N/A';
    final km = n / 1000;
    return '${km.toStringAsFixed(0)} km';
  }

  String get _hoursLabel {
    final v = snapshot.position?.attributes?['totalHours'] ??
        snapshot.position?.attributes?['hours'];
    if (v == null) return 'N/A';
    final n = num.tryParse(v.toString());
    if (n == null) return 'N/A';
    return '${n.toStringAsFixed(0)} h';
  }

  String get _courseLabel {
    final c = snapshot.position?.course;
    if (c == null) return 'N/A';
    const dirs = ['N', 'NE', 'L', 'SE', 'S', 'SO', 'O', 'NO'];
    final idx = ((c + 22.5) / 45).floor() % 8;
    return '${c.toStringAsFixed(0)}° ${dirs[idx]}';
  }

  String get _motionLabel {
    final v = snapshot.position?.attributes?['motion'];
    if (v == null) return 'N/A';
    if (v is bool) return v ? 'Em movimento' : 'Parado';
    if (v is num) return v > 0 ? 'Em movimento' : 'Parado';
    return v.toString();
  }

  String get _coordLabel {
    final p = snapshot.position;
    if (p == null) return 'N/A';
    return '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TELEMETRIA',
          style: TextStyle(
            color: Color(0xFF8899B0),
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Row(children: [
                Expanded(child: _TelCell(icon: Icons.satellite_alt_rounded, label: 'Satélites', value: _satLabel, color: const Color(0xFF176EEB))),
                const SizedBox(width: 8),
                Expanded(child: _TelCell(icon: Icons.terrain_rounded, label: 'Altitude', value: _altLabel, color: const Color(0xFF334155))),
              ]),
              Row(children: [
                Expanded(child: _TelCell(icon: Icons.route_rounded, label: 'Odômetro', value: _odomLabel, color: const Color(0xFF0F766E))),
                const SizedBox(width: 8),
                Expanded(child: _TelCell(icon: Icons.timer_outlined, label: 'Horômetro', value: _hoursLabel, color: const Color(0xFF7C3AED))),
              ]),
              Row(children: [
                Expanded(child: _TelCell(icon: Icons.explore_rounded, label: 'Rumo', value: _courseLabel, color: const Color(0xFFF59E0B))),
                const SizedBox(width: 8),
                Expanded(child: _TelCell(icon: Icons.directions_car_outlined, label: 'Movimento', value: _motionLabel, color: const Color(0xFF16A34A))),
              ]),
              _TelCell(icon: Icons.my_location_rounded, label: 'Coordenadas', value: _coordLabel, color: const Color(0xFF52627C)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TelCell extends StatelessWidget {
  const _TelCell({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 13, color: color),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Color(0xFF8899B0), fontSize: 8.5, fontWeight: FontWeight.w700)),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF1F2A44), fontSize: 11.5, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Full commands tab (detail view) ───────────────────────────────────────────

class _VehicleCommandsTab extends ConsumerStatefulWidget {
  const _VehicleCommandsTab({required this.snapshot});

  final _VehicleSnapshot snapshot;

  @override
  ConsumerState<_VehicleCommandsTab> createState() =>
      _VehicleCommandsTabState();
}

class _VehicleCommandsTabState extends ConsumerState<_VehicleCommandsTab> {
  bool _sending = false;

  Future<void> _send(String type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar comando remoto'),
          content: Text(
            'Enviar "$type" para ${widget.snapshot.device.name}? '
            'Essa acao sera executada no servidor de rastreamento.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.send_outlined),
              label: const Text('Enviar'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    setState(() => _sending = true);
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    try {
      await client.createEntity(
        path: '/commands/send',
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'deviceId': widget.snapshot.device.id,
          'type': type,
        },
      );
      ref.invalidate(commandsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Comando $type enviado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao enviar comando: $error')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commands = [
      ('positionSingle', Icons.my_location_outlined, 'Posição'),
      ('engineStop', Icons.lock_outline_rounded, 'Bloquear'),
      ('engineResume', Icons.lock_open_rounded, 'Desbloquear'),
      ('alarm', Icons.notifications_active_outlined, 'Alarme'),
    ];

    return _DetailCard(
      title: 'Comandos remotos',
      icon: Icons.terminal_rounded,
      body: 'Envio real para ${widget.snapshot.device.name}.',
      trailing: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final command in commands)
            FilledButton.icon(
              onPressed: _sending ? null : () => _send(command.$1),
              icon: Icon(command.$2, size: 16),
              label: Text(command.$3),
            ),
        ],
      ),
    );
  }
}

String _humanizeEventType(String type) {
  final normalized = type.trim();
  final key = normalized.toLowerCase();
  switch (key) {
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

  switch (normalized) {
    case 'deviceOnline':
      return 'Online';
    case 'deviceOffline':
      return 'Offline';
    case 'deviceUnknown':
      return 'Status desconhecido';
    case 'ignitionOn':
      return 'Ignição ligada';
    case 'ignitionOff':
      return 'Ignição desligada';
    case 'deviceMoving':
      return 'Em movimento';
    case 'deviceStopped':
      return 'Parado';
    case 'alarm':
      return 'Alarme';
    case 'commandResult':
      return 'Resultado de comando';
    case 'geofenceEnter':
      return 'Entrou na cerca';
    case 'geofenceExit':
      return 'Saiu da cerca';
    case 'overspeed':
      return 'Excesso de velocidade';
    default:
      if (normalized.isEmpty) return 'Evento';
      return normalized
          .replaceAllMapped(
            RegExp(r'([a-z])([A-Z])'),
            (match) => '${match.group(1)} ${match.group(2)}',
          )
          .toLowerCase();
  }
}

class _BottomStatusCard extends StatelessWidget {
  const _BottomStatusCard({required this.snapshot});

  final _VehicleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusLine(snapshot: snapshot),
          const SizedBox(height: 10),
          Text(
            'Ultimo ponto: ${snapshot.relativeLastPoint}',
            style: const TextStyle(
              color: Color(0xFF526684),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleMetricPair extends StatelessWidget {
  const _VehicleMetricPair({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 110, maxWidth: 190),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF71819B),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1F2A44),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleTabChip extends StatelessWidget {
  const _VehicleTabChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF258DDF) : const Color(0xFFE9EDF5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  selected ? const Color(0xFF258DDF) : const Color(0xFFDDE5F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : const Color(0xFF526684),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF526684),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _VehicleBottomTab {
  overview('Visão geral', Icons.dashboard_customize_outlined),
  photos('Fotos', Icons.image_outlined),
  commands('Comandos', Icons.terminal_rounded),
  chart('Grafico', Icons.show_chart_outlined),
  info('Informações', Icons.info_outline_rounded);

  const _VehicleBottomTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

enum _VehiclePanelMode {
  collapsed,
  summary,
  full,
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.title,
    required this.icon,
    required this.body,
    this.action,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final String body;
  final String? action;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E7F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF176EEB), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1F2A44),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF526684),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 8),
            Text(
              action!,
              style: const TextStyle(
                color: Color(0xFF176EEB),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(height: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _SpeedChartCard extends StatelessWidget {
  const _SpeedChartCard({required this.snapshot});

  final _VehicleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E7F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Velocidade (ultimas 2 horas)',
                  style: TextStyle(
                    color: Color(0xFF1F2A44),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _SmallRangeChip(label: 'Hoje', selected: false),
              const SizedBox(width: 6),
              _SmallRangeChip(label: '24h', selected: true),
              const SizedBox(width: 6),
              _SmallRangeChip(label: '7d', selected: false),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: CustomPaint(
              painter: _SpeedLinePainter(
                values: [
                  20,
                  24,
                  42,
                  28,
                  30,
                  44,
                  38,
                  27,
                  snapshot.speed?.clamp(10, 95).toDouble() ?? 0,
                  52,
                  26,
                  47,
                  34,
                ],
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallRangeChip extends StatelessWidget {
  const _SmallRangeChip({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFDDEBFF) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF526684),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SpeedLinePainter extends CustomPainter {
  const _SpeedLinePainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.isEmpty) return;

    final gridPaint = Paint()
      ..color = const Color(0xFFE4EAF3)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final range = (maxValue - minValue).abs() < 0.001 ? 1 : maxValue - minValue;

    final line = Path();
    final fill = Path()..moveTo(0, size.height);

    for (var i = 0; i < values.length; i++) {
      final x = i * size.width / (values.length - 1);
      final y = size.height -
          ((values[i] - minValue) / range * size.height * 0.72 +
              size.height * 0.14);
      if (i == 0) {
        line.moveTo(x, y);
        fill.lineTo(x, y);
      } else {
        line.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x552C7BE5), Color(0x002C7BE5)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = const Color(0xFF176EEB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.3,
    );
  }

  @override
  bool shouldRepaint(covariant _SpeedLinePainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.snapshot});

  final _VehicleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(snapshot.statusIcon, color: snapshot.statusColor, size: 15),
        const SizedBox(width: 8),
        Text(
          snapshot.statusLabel,
          style: TextStyle(
            color: snapshot.statusColor,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _PopupTextLine extends StatelessWidget {
  const _PopupTextLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(
          color: Color(0xFF1F2A44),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        children: [
          TextSpan(text: '$label '),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Color(0xFF526684),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PopupAction extends StatelessWidget {
  const _PopupAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FD),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFFDDE5F0)),
            ),
            child: Icon(icon, color: const Color(0xFF25344A), size: 20),
          ),
        ),
      ),
    );
  }
}

class _PopupPrimaryAction extends StatelessWidget {
  const _PopupPrimaryAction({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Container(
            height: 43,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEDF5FF),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFFBFD8FF)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: const Color(0xFF176EEB), size: 19),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF176EEB),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VehicleAvatar extends StatelessWidget {
  const _VehicleAvatar({
    required this.snapshot,
    required this.size,
    required this.iconSize,
  });

  final _VehicleSnapshot snapshot;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final image = snapshot.device.image?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(size >= 70 ? 14 : 10),
      child: SizedBox(
        width: size,
        height: size,
        child: image != null && image.isNotEmpty
            ? Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _VehicleAvatarPlaceholder(
                  snapshot: snapshot,
                  iconSize: iconSize,
                ),
              )
            : _VehicleAvatarPlaceholder(
                snapshot: snapshot,
                iconSize: iconSize,
              ),
      ),
    );
  }
}

class _VehicleAvatarPlaceholder extends StatelessWidget {
  const _VehicleAvatarPlaceholder({
    required this.snapshot,
    required this.iconSize,
  });

  final _VehicleSnapshot snapshot;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            snapshot.statusColor.withValues(alpha: 0.22),
            const Color(0xFFE9EEF6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          _vehicleIconForSnapshot(snapshot),
          color: const Color(0xFF64748B),
          size: iconSize,
        ),
      ),
    );
  }
}

class _LightVehiclePanel extends StatelessWidget {
  const _LightVehiclePanel({
    required this.child,
    required this.borderRadius,
    required this.padding,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final visual = VisualSettingsScope.of(context);
    final baseAlpha = (visual.glassOpacity + 0.04).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: visual.glassBlur + 10,
          sigmaY: visual.glassBlur + 10,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FD).withValues(alpha: baseAlpha),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF183153).withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassSurface extends StatelessWidget {
  const _GlassSurface({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.width,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final double? width;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final visual = VisualSettingsScope.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: visual.glassBlur,
          sigmaY: visual.glassBlur,
        ),
        child: Container(
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: visual.glassOpacity),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor ?? const Color(0xFFE2E8F3),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF183153).withValues(alpha: 0.07),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: _GlassSurface(
            padding: EdgeInsets.zero,
            borderColor:
                selected ? const Color(0xFFBFD8FF) : const Color(0xFFE2E8F3),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                icon,
                color: selected
                    ? const Color(0xFF176EEB)
                    : const Color(0xFF25344A),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapLayersButton extends StatelessWidget {
  const _MapLayersButton({
    this.mapType,
    this.trafficEnabled,
    this.onMapTypeChanged,
    this.onTrafficToggle,
    this.onRecenter,
  });

  final gmaps.MapType? mapType;
  final bool? trafficEnabled;
  final ValueChanged<gmaps.MapType>? onMapTypeChanged;
  final VoidCallback? onTrafficToggle;
  final VoidCallback? onRecenter;

  @override
  Widget build(BuildContext context) {
    final isNormal = mapType == null || mapType == gmaps.MapType.normal;
    final isSatellite = mapType == gmaps.MapType.satellite;
    final isHybrid = mapType == gmaps.MapType.hybrid;
    final trafficOn = trafficEnabled == true;
    final active = !isNormal || trafficOn;

    return PopupMenuButton<String>(
      tooltip: 'Camadas do mapa',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      color: const Color(0xFFFDFEFF),
      elevation: 14,
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 220),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFD8E3F2)),
      ),
      onSelected: (value) {
        switch (value) {
          case 'normal':
            onMapTypeChanged?.call(gmaps.MapType.normal);
          case 'satellite':
            onMapTypeChanged?.call(gmaps.MapType.satellite);
          case 'hybrid':
            onMapTypeChanged?.call(gmaps.MapType.hybrid);
          case 'traffic':
            onTrafficToggle?.call();
          case 'recenter':
            onRecenter?.call();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem<String>(
          enabled: false,
          height: 28,
          child: Text(
            'Visualização',
            style: TextStyle(
              color: Color(0xFF60718D),
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ),
        PopupMenuItem<String>(
          value: 'normal',
          child: Row(children: [
            Icon(isNormal ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 16, color: const Color(0xFF176EEB)),
            const SizedBox(width: 10),
            const Text('Padrão'),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'satellite',
          child: Row(children: [
            Icon(isSatellite ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 16, color: const Color(0xFF176EEB)),
            const SizedBox(width: 10),
            const Text('Satélite'),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'hybrid',
          child: Row(children: [
            Icon(isHybrid ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 16, color: const Color(0xFF176EEB)),
            const SizedBox(width: 10),
            const Text('Híbrido'),
          ]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'traffic',
          child: Row(children: [
            Icon(
              trafficOn ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              size: 16,
              color: const Color(0xFF176EEB),
            ),
            const SizedBox(width: 10),
            const Text('Tráfego'),
          ]),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'recenter',
          child: Row(children: [
            Icon(Icons.my_location_rounded, size: 16, color: Color(0xFF52627C)),
            SizedBox(width: 10),
            Text('Centralizar frota'),
          ]),
        ),
      ],
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFEAF3FF)
              : Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? const Color(0xFFBFD8FF) : const Color(0xFFE1E8F2),
          ),
        ),
        child: Icon(
          Icons.layers_rounded,
          color: active ? const Color(0xFF176EEB) : const Color(0xFF526684),
          size: 20,
        ),
      ),
    );
  }
}

class _TopIcon extends StatelessWidget {
  const _TopIcon({
    required this.icon,
    required this.count,
    this.onTap,
    this.tooltip,
    this.selected = false,
  });

  final IconData icon;
  final int? count;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFEAF3FF)
                    : Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFBFD8FF)
                      : const Color(0xFFE1E8F2),
                ),
              ),
              child: Icon(
                icon,
                color: selected
                    ? const Color(0xFF176EEB)
                    : const Color(0xFF526684),
                size: 20,
              ),
            ),
            if (count != null)
              Positioned(
                right: -8,
                top: -6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8C530),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white),
                  ),
                  child: Text(
                    count! > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Color(0xFF1F2A44),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (tooltip == null || tooltip!.isEmpty) {
      return button;
    }
    return Tooltip(message: tooltip!, child: button);
  }
}

class _VisualDiagnosis {
  const _VisualDiagnosis({
    required this.screenName,
    required this.probableIssue,
    required this.adjustmentSuggestion,
    required this.technicalPrompt,
  });

  final String screenName;
  final String probableIssue;
  final String adjustmentSuggestion;
  final String technicalPrompt;
}

class _CopilotFloatingButton extends StatelessWidget {
  const _CopilotFloatingButton({
    required this.open,
    required this.onTap,
  });

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 20,
      bottom: 20,
      child: _SurfaceGuard(
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xE8172235),
                    Color(0xD2121D2D),
                  ],
                ),
                border: Border.all(color: const Color(0xFF35537D)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0B1220).withValues(alpha: 0.44),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A4D82).withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    open ? 'Fechar IA' : 'IA',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CopilotOption<T> {
  const _CopilotOption({
    required this.value,
    required this.label,
  });

  final T value;
  final String label;
}

class _CopilotOperationalPanel extends StatelessWidget {
  const _CopilotOperationalPanel({
    required this.open,
    required this.settings,
    required this.diagnosis,
    required this.onClose,
    required this.onDiagnose,
    required this.onReset,
    required this.onBalloonSize,
    required this.onLogoMode,
    required this.onCardDensity,
    required this.onTransparency,
    required this.onFontSize,
    required this.onMapMode,
  });

  final bool open;
  final VisualSettings settings;
  final _VisualDiagnosis? diagnosis;
  final VoidCallback onClose;
  final VoidCallback onDiagnose;
  final VoidCallback onReset;
  final ValueChanged<VisualBalloonSize> onBalloonSize;
  final ValueChanged<VisualLogoMode> onLogoMode;
  final ValueChanged<VisualCardDensity> onCardDensity;
  final ValueChanged<VisualTransparency> onTransparency;
  final ValueChanged<VisualFontSize> onFontSize;
  final ValueChanged<VisualMapMode> onMapMode;

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      top: 92,
      bottom: 24,
      right: open ? 16 : -410,
      width: 390,
      child: IgnorePointer(
        ignoring: !open,
        child: _SurfaceGuard(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: open ? 1 : 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF35537D)),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xED101B2B),
                        Color(0xDD0D1623),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.36),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.tune_rounded,
                              color: Color(0xFF9FC3FF),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Copiloto Operacional',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Resetar visual',
                              onPressed: onReset,
                              icon: const Icon(
                                Icons.restart_alt_rounded,
                                color: Color(0xFFB7C9E8),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Fechar',
                              onPressed: onClose,
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFFB7C9E8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0x27486688)),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                          children: [
                            _CopilotInlineChat(
                              settings: settings,
                              diagnosis: diagnosis,
                              onDiagnose: onDiagnose,
                            ),
                            const SizedBox(height: 12),
                            _CopilotChoiceGroup<VisualBalloonSize>(
                              title: 'Tamanho dos balões',
                              selected: settings.balloonSize,
                              options: const [
                                _CopilotOption(
                                  value: VisualBalloonSize.small,
                                  label: 'Pequeno',
                                ),
                                _CopilotOption(
                                  value: VisualBalloonSize.medium,
                                  label: 'Médio',
                                ),
                                _CopilotOption(
                                  value: VisualBalloonSize.large,
                                  label: 'Grande',
                                ),
                              ],
                              onChanged: onBalloonSize,
                            ),
                            _CopilotChoiceGroup<VisualLogoMode>(
                              title: 'Logo',
                              selected: settings.logoMode,
                              options: const [
                                _CopilotOption(
                                  value: VisualLogoMode.normal,
                                  label: 'Normal',
                                ),
                                _CopilotOption(
                                  value: VisualLogoMode.compact,
                                  label: 'Compacto',
                                ),
                                _CopilotOption(
                                  value: VisualLogoMode.hideOnFullMap,
                                  label: 'Ocultar mapa cheio',
                                ),
                              ],
                              onChanged: onLogoMode,
                            ),
                            _CopilotChoiceGroup<VisualCardDensity>(
                              title: 'Cards',
                              selected: settings.cardDensity,
                              options: const [
                                _CopilotOption(
                                  value: VisualCardDensity.compact,
                                  label: 'Compacto',
                                ),
                                _CopilotOption(
                                  value: VisualCardDensity.comfortable,
                                  label: 'Confortavel',
                                ),
                              ],
                              onChanged: onCardDensity,
                            ),
                            _CopilotChoiceGroup<VisualTransparency>(
                              title: 'Transparencia',
                              selected: settings.transparency,
                              options: const [
                                _CopilotOption(
                                  value: VisualTransparency.low,
                                  label: 'Baixa',
                                ),
                                _CopilotOption(
                                  value: VisualTransparency.medium,
                                  label: 'Media',
                                ),
                                _CopilotOption(
                                  value: VisualTransparency.high,
                                  label: 'Alta',
                                ),
                              ],
                              onChanged: onTransparency,
                            ),
                            _CopilotChoiceGroup<VisualFontSize>(
                              title: 'Fonte',
                              selected: settings.fontSize,
                              options: const [
                                _CopilotOption(
                                  value: VisualFontSize.normal,
                                  label: 'Normal',
                                ),
                                _CopilotOption(
                                  value: VisualFontSize.large,
                                  label: 'Grande',
                                ),
                              ],
                              onChanged: onFontSize,
                            ),
                            _CopilotChoiceGroup<VisualMapMode>(
                              title: 'Mapa',
                              selected: settings.mapMode,
                              options: const [
                                _CopilotOption(
                                  value: VisualMapMode.normal,
                                  label: 'Normal',
                                ),
                                _CopilotOption(
                                  value: VisualMapMode.premium,
                                  label: 'Premium',
                                ),
                                _CopilotOption(
                                  value: VisualMapMode.dark,
                                  label: 'Escuro',
                                ),
                              ],
                              onChanged: onMapMode,
                            ),
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              onPressed: onDiagnose,
                              icon: const Icon(Icons.auto_fix_high_rounded),
                              label:
                                  const Text('Diagnosticar visual desta tela'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF176EEB),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            if (diagnosis != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F2238),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF264970),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _CopilotDiagnosisRow(
                                      label: 'Tela atual',
                                      value: diagnosis!.screenName,
                                    ),
                                    const SizedBox(height: 8),
                                    _CopilotDiagnosisRow(
                                      label: 'Problema visual provavel',
                                      value: diagnosis!.probableIssue,
                                    ),
                                    const SizedBox(height: 8),
                                    _CopilotDiagnosisRow(
                                      label: 'SuGestão de ajuste',
                                      value: diagnosis!.adjustmentSuggestion,
                                    ),
                                    const SizedBox(height: 8),
                                    _CopilotDiagnosisRow(
                                      label: 'Prompt tecnico',
                                      value: diagnosis!.technicalPrompt,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CopilotChoiceGroup<T> extends StatelessWidget {
  const _CopilotChoiceGroup({
    required this.title,
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final T selected;
  final List<_CopilotOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFB7C9E8),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                ChoiceChip(
                  label: Text(option.label),
                  selected: option.value == selected,
                  showCheckmark: false,
                  onSelected: (_) => onChanged(option.value),
                  labelStyle: TextStyle(
                    color: option.value == selected
                        ? Colors.white
                        : const Color(0xFFCED9EA),
                    fontWeight: option.value == selected
                        ? FontWeight.w700
                        : FontWeight.w600,
                    fontSize: 12,
                  ),
                  backgroundColor: const Color(0xFF13253B),
                  selectedColor: const Color(0xFF176EEB),
                  side: BorderSide(
                    color: option.value == selected
                        ? const Color(0xFF5F9BFF)
                        : const Color(0xFF2D4562),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CopilotDiagnosisRow extends StatelessWidget {
  const _CopilotDiagnosisRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF7FA5D2),
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
            height: 1.32,
          ),
        ),
      ],
    );
  }
}

class _CopilotChatMessage {
  const _CopilotChatMessage({
    required this.fromAssistant,
    required this.text,
  });

  final bool fromAssistant;
  final String text;
}

class _CopilotInlineChat extends StatefulWidget {
  const _CopilotInlineChat({
    required this.settings,
    required this.diagnosis,
    required this.onDiagnose,
  });

  final VisualSettings settings;
  final _VisualDiagnosis? diagnosis;
  final VoidCallback onDiagnose;

  @override
  State<_CopilotInlineChat> createState() => _CopilotInlineChatState();
}

class _CopilotInlineChatState extends State<_CopilotInlineChat> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_CopilotChatMessage> _messages = <_CopilotChatMessage>[
    const _CopilotChatMessage(
      fromAssistant: true,
      text:
          'Copiloto pronto. Me diga o ajuste visual desejado e eu te respondo com acao objetiva.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendCurrent() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;
    _controller.clear();
    _appendConversation(raw);
  }

  void _sendQuick(String text) {
    _appendConversation(text);
  }

  void _appendConversation(String userText) {
    final reply = _buildAssistantReply(userText);
    setState(() {
      _messages.add(_CopilotChatMessage(fromAssistant: false, text: userText));
      _messages.add(_CopilotChatMessage(fromAssistant: true, text: reply));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _buildAssistantReply(String input) {
    final text = input.toLowerCase();
    final settings = widget.settings;

    String summary() {
      return 'Resumo atual: baloes ${settings.balloonSize.name}, '
          'logo ${settings.logoMode.name}, cards ${settings.cardDensity.name}, '
          'transparencia ${settings.transparency.name}, '
          'fonte ${settings.fontSize.name}, mapa ${settings.mapMode.name}.';
    }

    if (text.contains('diagnost')) {
      widget.onDiagnose();
      return widget.diagnosis == null
          ? 'Diagnostico acionado. Veja o bloco acima com problema provavel e prompt tecnico.'
          : 'Diagnostico atualizado para a tela ${widget.diagnosis!.screenName}.';
    }
    if (text.contains('mapa')) {
      return 'Use o seletor de mapa para alternar entre normal, premium e escuro. '
          'Se precisar de contraste maior, combine mapa escuro com transparencia baixa.';
    }
    if (text.contains('logo')) {
      return 'Você pode manter o logo normal, compacto ou ocultar no mapa cheio. '
          'Para foco operacional, recomendo ocultar no mapa cheio.';
    }
    if (text.contains('fonte') || text.contains('texto')) {
      return 'Ative fonte grande para leitura em operação. '
          'Se a tela ficar densa, combine com cards confortáveis.';
    }
    if (text.contains('transparen') || text.contains('vidro')) {
      return 'Transparencia baixa melhora leitura; alta destaca mapa. '
          'Para uso diário, médio costuma equilibrar visual e legibilidade.';
    }
    if (text.contains('card') || text.contains('compact')) {
      return 'Cards compactos aumentam área útil; confortável melhora leitura. '
          'Você pode alternar instantaneamente para comparar.';
    }
    if (text.contains('resumo') || text.contains('status')) {
      return summary();
    }
    if (text.contains('balao') || text.contains('popup')) {
      return 'Tamanho dos balões ajusta o popup rápido do veículo no mapa. '
          'Grande favorece toque, pequeno reduz obstrução.';
    }

    return 'Entendi. Posso te guiar em ajustes de mapa, cards, transparência, fonte e logo. ${summary()}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1C2F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF244566)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.forum_outlined,
                color: Color(0xFF9FC3FF),
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Chat do Copiloto',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 168,
            child: ListView.separated(
              controller: _scrollController,
              itemCount: _messages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 7),
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg.fromAssistant
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 290),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: msg.fromAssistant
                          ? const Color(0xFF122A43)
                          : const Color(0xFF176EEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: msg.fromAssistant
                            ? const Color(0xFF315C85)
                            : const Color(0xFF7CB2FF),
                      ),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        color: msg.fromAssistant
                            ? const Color(0xFFE5F0FF)
                            : Colors.white,
                        fontSize: 12.3,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _CopilotQuickActionChip(
                label: 'Resumo visual',
                onTap: () => _sendQuick('resumo visual'),
              ),
              _CopilotQuickActionChip(
                label: 'Diagnosticar',
                onTap: () => _sendQuick('diagnosticar'),
              ),
              _CopilotQuickActionChip(
                label: 'Melhorar legibilidade',
                onTap: () => _sendQuick('melhorar legibilidade'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _sendCurrent(),
                  style: const TextStyle(color: Colors.white, fontSize: 12.8),
                  decoration: InputDecoration(
                    hintText: 'Escreva um ajuste visual...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF9EB4CF),
                      fontSize: 12.5,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFF102338),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF2B4C6D)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF2B4C6D)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF5D9DFF)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: FilledButton(
                  onPressed: _sendCurrent,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF176EEB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Icon(Icons.send_rounded, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CopilotQuickActionChip extends StatelessWidget {
  const _CopilotQuickActionChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      labelStyle: const TextStyle(
        color: Color(0xFFE5F0FF),
        fontWeight: FontWeight.w700,
        fontSize: 11.5,
      ),
      backgroundColor: const Color(0xFF163250),
      side: const BorderSide(color: Color(0xFF2F567D)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
      ),
    );
  }
}

class _PanelToolEntry {
  const _PanelToolEntry({
    required this.label,
    required this.icon,
    required this.child,
    this.detail,
  });

  final String label;
  final IconData icon;
  final Widget child;
  final String? detail;
}

class _ModulePlaceholderScreen extends StatelessWidget {
  const _ModulePlaceholderScreen({
    required this.moduleTitle,
    required this.submenuTitle,
    required this.description,
    this.cards = const [],
  });

  final String moduleTitle;
  final String submenuTitle;
  final String description;
  final List<String> cards;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _GlassSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                moduleTitle,
                style: const TextStyle(
                  color: Color(0xFF1F2A44),
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                submenuTitle,
                style: const TextStyle(
                  color: Color(0xFF176EEB),
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  color: Color(0xFF526684),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _GlassSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _PlaceholderInfoLine(
                icon: Icons.check_circle_outline,
                title: 'Status',
                value: 'estrutura criada',
              ),
              SizedBox(height: 8),
              _PlaceholderInfoLine(
                icon: Icons.link_outlined,
                title: 'Aviso',
                value: 'integracao sera plugada em etapa futura',
              ),
            ],
          ),
        ),
        if (cards.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final card in cards)
                Container(
                  width: 240,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDDE5F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.widgets_outlined,
                        size: 18,
                        color: Color(0xFF176EEB),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          card,
                          style: const TextStyle(
                            color: Color(0xFF1F2A44),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AiOperationAssistantScreen extends StatefulWidget {
  const _AiOperationAssistantScreen({
    required this.operationId,
    required this.title,
    required this.description,
  });

  final String operationId;
  final String title;
  final String description;

  @override
  State<_AiOperationAssistantScreen> createState() =>
      _AiOperationAssistantScreenState();
}

class _AiOperationAssistantScreenState
    extends State<_AiOperationAssistantScreen> {
  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  final BridgeClient _bridgeClient = const BridgeClient();
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _contextController = TextEditingController();

  bool _isSubmitting = false;
  String? _error;
  Map<String, dynamic>? _response;

  @override
  void initState() {
    super.initState();
    _contextController.text = 'Operação monitorada pelo painel SouTracking';
  }

  @override
  void dispose() {
    _targetController.dispose();
    _promptController.dispose();
    _contextController.dispose();
    super.dispose();
  }

  Future<void> _execute() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      setState(() {
        _error = 'Descreva o objetivo para executar a assistencia de IA.';
      });
      return;
    }

    final payload = <String, dynamic>{
      'origem': 'SouTracking',
      'modulo': 'ia_operacional',
      'Operação': widget.operationId,
      'alvo': _targetController.text.trim(),
      'prompt': prompt,
      'contexto': _contextController.text.trim(),
      'executadoEm': DateTime.now().toIso8601String(),
    };

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      late final Map<String, dynamic> result;
      switch (widget.operationId) {
        case 'alerta':
          result = await _bridgeClient.criarAlerta(payload);
          break;
        case 'cerca':
          result = await _bridgeClient.criarCerca(payload);
          break;
        case 'relatorio':
          result = await _bridgeClient.gerarRelatorio(payload);
          break;
        case 'acao':
          result = await _bridgeClient.registrarEvento({
            ...payload,
            'tipo': 'ia_recomendacao',
          });
          break;
        default:
          result = await _bridgeClient.registrarEvento(payload);
      }

      if (!mounted) return;
      setState(() {
        _response = result;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Falha ao executar a assistencia de IA em modo controlado.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _GlassSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: Color(0xFF1F2A44),
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.description,
                style: const TextStyle(
                  color: Color(0xFF526684),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _targetController,
                decoration: const InputDecoration(
                  labelText: 'Alvo (veículo, grupo ou regra)',
                  hintText: 'Ex.: AB12, Frota Escolar, Regra de risco',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _promptController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Prompt operacional',
                  hintText: 'Descreva o que a IA deve gerar para a Operação.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _contextController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Contexto',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _execute,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_outlined),
                label: Text(
                  _isSubmitting ? 'Executando...' : 'Executar assistencia',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFB42318),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_response != null) ...[
          const SizedBox(height: 10),
          _GlassSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PlaceholderInfoLine(
                  icon: Icons.check_circle_outline,
                  title: 'Status',
                  value: 'acao executada com sucesso no modo controlado',
                ),
                const SizedBox(height: 10),
                SelectableText(
                  _encoder.convert(_response),
                  style: const TextStyle(
                    color: Color(0xFF25344A),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _AutomationWorkbenchScreen extends StatefulWidget {
  const _AutomationWorkbenchScreen({
    required this.title,
    required this.description,
    required this.scope,
    required this.actionType,
  });

  final String title;
  final String description;
  final String scope;
  final String actionType;

  @override
  State<_AutomationWorkbenchScreen> createState() =>
      _AutomationWorkbenchScreenState();
}

class _AutomationWorkbenchScreenState
    extends State<_AutomationWorkbenchScreen> {
  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  final BridgeClient _bridgeClient = const BridgeClient();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _triggerController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  bool _isSaving = false;
  bool _isTesting = false;
  String? _error;
  Map<String, dynamic>? _lastSaved;
  Map<String, dynamic>? _lastTest;

  @override
  void initState() {
    super.initState();
    _nameController.text = '${widget.title} - Regra 01';
    _triggerController.text = 'evento_critico';
    _messageController.text =
        'Acao automatica disparada pelo modulo ${widget.scope}.';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _triggerController.dispose();
    _targetController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _saveRule() async {
    final ruleName = _nameController.text.trim();
    final trigger = _triggerController.text.trim();
    if (ruleName.isEmpty || trigger.isEmpty) {
      setState(() {
        _error = 'Preencha nome da regra e gatilho para salvar.';
      });
      return;
    }

    final payload = <String, dynamic>{
      'origem': 'SouTracking',
      'tipo': 'automation_rule',
      'scope': widget.scope,
      'ruleName': ruleName,
      'trigger': trigger,
      'actionType': widget.actionType,
      'target': _targetController.text.trim(),
      'message': _messageController.text.trim(),
      'savedAt': DateTime.now().toIso8601String(),
    };

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final result = await _bridgeClient.registrarEvento(payload);
      if (!mounted) return;
      setState(() {
        _lastSaved = result;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Falha ao salvar automacao em modo controlado.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _testRule() async {
    final payload = <String, dynamic>{
      'origem': 'SouTracking',
      'scope': widget.scope,
      'ruleName': _nameController.text.trim(),
      'trigger': _triggerController.text.trim(),
      'target': _targetController.text.trim(),
      'message': _messageController.text.trim(),
      'testedAt': DateTime.now().toIso8601String(),
    };

    setState(() {
      _isTesting = true;
      _error = null;
    });

    try {
      late final Map<String, dynamic> result;
      switch (widget.actionType) {
        case 'alerta':
          result = await _bridgeClient.criarAlerta(payload);
          break;
        case 'whatsapp':
          result = await _bridgeClient.enviarWhatsapp(payload);
          break;
        case 'ticket':
          result = await _bridgeClient.criarChamado(payload);
          break;
        case 'relatorio':
          result = await _bridgeClient.gerarRelatorio(payload);
          break;
        case 'webhook':
          result = await _bridgeClient.registrarEvento({
            ...payload,
            'tipo': 'webhook_test',
          });
          break;
        default:
          result = await _bridgeClient.registrarEvento(payload);
      }

      if (!mounted) return;
      setState(() {
        _lastTest = result;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Falha ao executar teste de automacao.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _GlassSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: Color(0xFF1F2A44),
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.description,
                style: const TextStyle(
                  color: Color(0xFF526684),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              const _PlaceholderInfoLine(
                icon: Icons.settings_backup_restore_outlined,
                title: 'Modo',
                value: 'controle operacional ativo',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome da regra',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _triggerController,
                decoration: const InputDecoration(
                  labelText: 'Gatilho',
                  hintText: 'Ex.: ignicao_on, excesso_velocidade, cerca_saida',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _targetController,
                decoration: const InputDecoration(
                  labelText: 'Destino/Alvo',
                  hintText: 'Ex.: grupo_frota, operador_plantao, webhook_url',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _messageController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Mensagem/Acao',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _saveRule,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_isSaving ? 'Salvando...' : 'Salvar automacao'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _isTesting ? null : _testRule,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_outlined),
                    label: Text(_isTesting ? 'Testando...' : 'Executar teste'),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFB42318),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_lastSaved != null) ...[
          const SizedBox(height: 10),
          _GlassSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PlaceholderInfoLine(
                  icon: Icons.check_circle_outline,
                  title: 'Regra',
                  value: 'salva no modo controlado',
                ),
                const SizedBox(height: 10),
                SelectableText(
                  _encoder.convert(_lastSaved),
                  style: const TextStyle(
                    color: Color(0xFF25344A),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_lastTest != null) ...[
          const SizedBox(height: 10),
          _GlassSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PlaceholderInfoLine(
                  icon: Icons.bolt_outlined,
                  title: 'Teste',
                  value: 'executado no modo controlado',
                ),
                const SizedBox(height: 10),
                SelectableText(
                  _encoder.convert(_lastTest),
                  style: const TextStyle(
                    color: Color(0xFF25344A),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BridgeTicketCreateScreen extends StatefulWidget {
  const _BridgeTicketCreateScreen();

  @override
  State<_BridgeTicketCreateScreen> createState() =>
      _BridgeTicketCreateScreenState();
}

class _BridgeTicketCreateScreenState extends State<_BridgeTicketCreateScreen> {
  static const List<String> _tipos = [
    'Suporte técnico',
    'Sem comunica\u00E7\u00E3o',
    'Instalacao',
    'Manutenção',
    'Guincho',
    'Vistoria',
    'Sinistro',
  ];

  static const List<String> _prioridades = [
    'Baixa',
    'Media',
    'Alta',
    'Critica',
  ];

  final BridgeClient _bridgeClient = const BridgeClient();
  final TextEditingController _vehicleIdController = TextEditingController();
  final TextEditingController _descricaoController = TextEditingController();
  final TextEditingController _souCallDestinoController =
      TextEditingController();
  final TextEditingController _souCallMensagemController =
      TextEditingController();

  String _tipoSelecionado = _tipos.first;
  String _prioridadeSelecionada = _prioridades[1];
  bool _isSubmitting = false;
  bool _isSendingSouCall = false;
  String? _erro;
  String? _souCallErro;
  String? _protocolo;
  Map<String, dynamic>? _ultimoPayload;
  Map<String, dynamic>? _ultimoSouCallPayload;

  @override
  void dispose() {
    _vehicleIdController.dispose();
    _descricaoController.dispose();
    _souCallDestinoController.dispose();
    _souCallMensagemController.dispose();
    super.dispose();
  }

  String _mensagemSugerida({
    required String tipo,
    required String prioridade,
    required String vehicleId,
  }) {
    return 'Chamado criado no SouTracking.\n'
        'Tipo: $tipo\n'
        'Prioridade: $prioridade\n'
        'veículo: $vehicleId\n'
        'Status: aguardando envio para SouFind.';
  }

  Future<void> _criarChamado() async {
    final vehicleId = _vehicleIdController.text.trim();
    final descricao = _descricaoController.text.trim();
    if (vehicleId.isEmpty || descricao.isEmpty) {
      setState(() {
        _erro = 'Preencha veículo e descricao para criar o chamado.';
      });
      return;
    }

    final payload = <String, dynamic>{
      'origem': 'SouTracking',
      'tipo': _tipoSelecionado,
      'vehicleId': vehicleId,
      'descricao': descricao,
      'prioridade': _prioridadeSelecionada,
      'destinoFuturo': 'SouFind',
    };

    setState(() {
      _isSubmitting = true;
      _erro = null;
    });

    try {
      await _bridgeClient.criarChamado(payload);
      final protocolo = 'ST-${DateTime.now().millisecondsSinceEpoch}';
      final mensagem = _mensagemSugerida(
        tipo: _tipoSelecionado,
        prioridade: _prioridadeSelecionada,
        vehicleId: vehicleId,
      );
      if (!mounted) return;
      setState(() {
        _protocolo = protocolo;
        _ultimoPayload = payload;
        _souCallMensagemController.text = mensagem;
        _souCallErro = null;
        _ultimoSouCallPayload = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erro = 'Falha ao criar chamado no modo controlado.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _enviarAvisoSouCall() async {
    final origemPayload = _ultimoPayload;
    if (origemPayload == null) {
      setState(() {
        _souCallErro = 'Crie o chamado antes de enviar aviso.';
      });
      return;
    }

    final destino = _souCallDestinoController.text.trim();
    final mensagem = _souCallMensagemController.text.trim();
    if (destino.isEmpty || mensagem.isEmpty) {
      setState(() {
        _souCallErro = 'Preencha destinatario e mensagem para enviar aviso.';
      });
      return;
    }

    final payload = <String, dynamic>{
      'destino': destino,
      'mensagem': mensagem,
      'vehicleId': '${origemPayload['vehicleId'] ?? ''}',
      'payload': {
        'origem': 'SouTracking',
        'tipo': '${origemPayload['tipo'] ?? ''}',
        'prioridade': '${origemPayload['prioridade'] ?? ''}',
        'destinoFuturo': 'SouFind',
      },
    };

    setState(() {
      _isSendingSouCall = true;
      _souCallErro = null;
    });

    try {
      await _bridgeClient.enviarWhatsapp(payload);
      if (!mounted) return;
      setState(() {
        _ultimoSouCallPayload = payload;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _souCallErro = 'Falha ao enviar aviso em modo controlado.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSendingSouCall = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _GlassSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Abrir chamado',
                style: TextStyle(
                  color: Color(0xFF1F2A44),
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 10),
              const _PlaceholderInfoLine(
                icon: Icons.account_tree_outlined,
                title: 'Origem',
                value: 'SouTracking',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _tipoSelecionado,
                decoration: const InputDecoration(
                  labelText: 'Tipo do chamado',
                  border: OutlineInputBorder(),
                ),
                items: _tipos
                    .map(
                      (tipo) => DropdownMenuItem<String>(
                        value: tipo,
                        child: Text(tipo),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _tipoSelecionado = value);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _vehicleIdController,
                decoration: const InputDecoration(
                  labelText: 'veículo',
                  hintText: 'Ex.: ABC-1234 ou ID do veículo',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descricaoController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Descricao',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _prioridadeSelecionada,
                decoration: const InputDecoration(
                  labelText: 'Prioridade',
                  border: OutlineInputBorder(),
                ),
                items: _prioridades
                    .map(
                      (prioridade) => DropdownMenuItem<String>(
                        value: prioridade,
                        child: Text(prioridade),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _prioridadeSelecionada = value);
                },
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _criarChamado,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(
                  _isSubmitting ? 'Criando...' : 'Criar chamado',
                ),
              ),
              if (_erro != null) ...[
                const SizedBox(height: 10),
                Text(
                  _erro!,
                  style: const TextStyle(
                    color: Color(0xFFB42318),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_protocolo != null && _ultimoPayload != null) ...[
          const SizedBox(height: 10),
          _GlassSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resultado',
                  style: TextStyle(
                    color: Color(0xFF1F2A44),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'chamado criado em modo mock',
                  style: TextStyle(
                    color: Color(0xFF047857),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'protocolo simulado: $_protocolo',
                  style: const TextStyle(
                    color: Color(0xFF1F2A44),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'status: aguardando envio para SouFind',
                  style: TextStyle(
                    color: Color(0xFF1F2A44),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'proximo passo: aviso via SouCall em etapa futura',
                  style: TextStyle(
                    color: Color(0xFF1F2A44),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Payload enviado:',
                  style: TextStyle(
                    color: Color(0xFF526684),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _ultimoPayload.toString(),
                  style: const TextStyle(
                    color: Color(0xFF1F2A44),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _GlassSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aviso via SouCall',
                  style: TextStyle(
                    color: Color(0xFF1F2A44),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _souCallDestinoController,
                  decoration: const InputDecoration(
                    labelText: 'Destinatario WhatsApp',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _souCallMensagemController,
                  minLines: 4,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Mensagem sugerida',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isSendingSouCall ? null : _enviarAvisoSouCall,
                  icon: _isSendingSouCall
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.campaign_outlined),
                  label: Text(
                    _isSendingSouCall
                        ? 'Enviando...'
                        : 'Enviar aviso via SouCall',
                  ),
                ),
                if (_souCallErro != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _souCallErro!,
                    style: const TextStyle(
                      color: Color(0xFFB42318),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (_ultimoSouCallPayload != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'aviso enviado em modo mock',
                    style: TextStyle(
                      color: Color(0xFF047857),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'destino: ${_ultimoSouCallPayload!['destino']}',
                    style: const TextStyle(
                      color: Color(0xFF1F2A44),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'status: aguardando integracao real SouCall',
                    style: TextStyle(
                      color: Color(0xFF1F2A44),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'payload enviado:',
                    style: TextStyle(
                      color: Color(0xFF526684),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _ultimoSouCallPayload.toString(),
                    style: const TextStyle(
                      color: Color(0xFF1F2A44),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _InventoryDemoScreen extends StatelessWidget {
  const _InventoryDemoScreen();

  static const _summary = <_InventorySummaryData>[
    _InventorySummaryData(
      title: 'Rastreadores disponiveis',
      value: '24',
      icon: Icons.gps_fixed_outlined,
      color: Color(0xFF176EEB),
    ),
    _InventorySummaryData(
      title: 'Chips disponiveis',
      value: '38',
      icon: Icons.sim_card_outlined,
      color: Color(0xFF0891B2),
    ),
    _InventorySummaryData(
      title: 'Instalados',
      value: '112',
      icon: Icons.check_circle_outline,
      color: Color(0xFF047857),
    ),
    _InventorySummaryData(
      title:
          'Em manutenção',
      value: '6',
      icon: Icons.build_circle_outlined,
      color: Color(0xFFD97706),
    ),
    _InventorySummaryData(
      title: 'Estoque baixo',
      value: '3',
      icon: Icons.warning_amber_outlined,
      color: Color(0xFFB42318),
    ),
  ];

  static const _items = <_InventoryItemData>[
    _InventoryItemData(
      type: 'Rastreador 4G',
      model: 'ST-4G01',
      idNumber: 'IMEI 865000000001',
      carrier: '-',
      status: 'Disponivel',
      technician: 'Estoque',
      vehicle: '-',
      movement: 'Entrada hoje',
    ),
    _InventoryItemData(
      type: 'Chip Vivo',
      model: 'SIM-VIVO',
      idNumber: 'ICCID 895500000001',
      carrier: 'Vivo',
      status: 'Disponivel',
      technician: 'Estoque',
      vehicle: '-',
      movement: 'Entrada hoje',
    ),
    _InventoryItemData(
      type: 'Rastreador 2G',
      model: 'TK-303',
      idNumber: 'IMEI 359000000002',
      carrier: '-',
      status: 'Instalado',
      technician: 'Joao Tecnico',
      vehicle: 'ABC-1234',
      movement: 'Instalado ontem',
    ),
    _InventoryItemData(
      type: 'Chip Claro',
      model: 'SIM-CLARO',
      idNumber: 'ICCID 895500000002',
      carrier: 'Claro',
      status: 'Instalado',
      technician: 'Joao Tecnico',
      vehicle: 'ABC-1234',
      movement: 'Instalado ontem',
    ),
    _InventoryItemData(
      type: 'Rele bloqueio',
      model: 'RELE-12V',
      idNumber: '-',
      carrier: '-',
      status:
          'Manutenção',
      technician: 'Carlos Tecnico',
      vehicle: 'XYZ-9876',
      movement: 'Retorno tecnico',
    ),
  ];

  static const _history = <String>[
    '23:10 Entrada de rastreador 4G',
    '22:45 Saida de chip Vivo para tecnico',
    '21:30 Instalacao no veículo ABC-1234',
    '20:10 Relé enviado para manutenção',
  ];

  static const _actions = <String>[
    'Entrada',
    'Saida para tecnico',
    'Instalar no veículo',
    'Trocar chip',
    'Enviar para manutenção',
    'Devolver ao estoque',
    'Dar baixa',
    'Ver histórico',
  ];

  void _showAction(BuildContext context, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Acao visual: $action (modo demonstracao)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const _GlassSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estoque',
                style: TextStyle(
                  color: Color(0xFF1F2A44),
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Controle de rastreadores, chips, acessorios e movimentações operacionais.',
                style: TextStyle(
                  color: Color(0xFF526684),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _GlassSurface(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF25344A)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Color(0xFF60A5FA),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Modo demonstracao',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'Futura integracao com Google Sheets via MackFlow/Bridge.',
                  style: TextStyle(
                    color: Color(0xFFBFDBFE),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final summary in _summary)
              _InventorySummaryCard(data: summary, width: 178),
          ],
        ),
        const SizedBox(height: 10),
        _GlassSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Itens (simulado)',
                style: TextStyle(
                  color: Color(0xFF1F2A44),
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 980),
                  child: DataTable(
                    headingRowHeight: 42,
                    dataRowMinHeight: 42,
                    dataRowMaxHeight: 56,
                    headingTextStyle: const TextStyle(
                      color: Color(0xFF1F2A44),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                    dataTextStyle: const TextStyle(
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    dividerThickness: 0.6,
                    columns: const [
                      DataColumn(label: Text('Tipo')),
                      DataColumn(label: Text('Modelo')),
                      DataColumn(label: Text('IMEI / ICCID')),
                      DataColumn(label: Text('Operadora')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Tecnico')),
                      DataColumn(label: Text('veículo')),
                      DataColumn(label: Text('Ultima movimentacao')),
                    ],
                    rows: [
                      for (final item in _items)
                        DataRow(
                          cells: [
                            DataCell(Text(item.type)),
                            DataCell(Text(item.model)),
                            DataCell(Text(item.idNumber)),
                            DataCell(Text(item.carrier)),
                            DataCell(_InventoryStatusChip(status: item.status)),
                            DataCell(Text(item.technician)),
                            DataCell(Text(item.vehicle)),
                            DataCell(Text(item.movement)),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _GlassSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Movimentações (demo)',
                style: TextStyle(
                  color: Color(0xFF1F2A44),
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final action in _actions)
                    OutlinedButton.icon(
                      onPressed: () => _showAction(context, action),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                      label: Text(action),
                      style: OutlinedButton.styleFrom(
                        visualDensity:
                            const VisualDensity(horizontal: -2, vertical: -2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 7,
                        ),
                        foregroundColor: const Color(0xFF1F2A44),
                        side: const BorderSide(color: Color(0xFFD3DDEA)),
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _GlassSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Histórico simulado',
                style: TextStyle(
                  color: Color(0xFF1F2A44),
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              for (final item in _history) ...[
                _InventoryHistoryLine(text: item),
                if (item != _history.last)
                  const Divider(color: Color(0xFFDDE5F0), height: 14),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        const _GlassSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fluxo de integracao (demo)',
                style: TextStyle(
                  color: Color(0xFF1F2A44),
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 8),
              _InventoryFlowLine(text: 'SouTracking'),
              _InventoryFlowLine(text: 'Bridge'),
              _InventoryFlowLine(text: 'Google Sheets'),
              _InventoryFlowLine(text: 'Aba Itens atualiza status'),
              _InventoryFlowLine(
                  text: 'Aba Movimentações registra Histórico'),
            ],
          ),
        ),
      ],
    );
  }
}

class _InventorySummaryData {
  const _InventorySummaryData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
}

class _InventorySummaryCard extends StatelessWidget {
  const _InventorySummaryCard({required this.data, required this.width});

  final _InventorySummaryData data;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: _GlassSurface(
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(data.icon, color: data.color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF526684),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.value,
                    style: const TextStyle(
                      color: Color(0xFF1F2A44),
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
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

class _InventoryItemData {
  const _InventoryItemData({
    required this.type,
    required this.model,
    required this.idNumber,
    required this.carrier,
    required this.status,
    required this.technician,
    required this.vehicle,
    required this.movement,
  });

  final String type;
  final String model;
  final String idNumber;
  final String carrier;
  final String status;
  final String technician;
  final String vehicle;
  final String movement;
}

class _InventoryStatusChip extends StatelessWidget {
  const _InventoryStatusChip({required this.status});

  final String status;

  ({Color fg, Color bg, Color border}) _style() {
    switch (status.toLowerCase()) {
      case 'instalado':
        return (
          fg: const Color(0xFF047857),
          bg: const Color(0xFFECFDF3),
          border: const Color(0xFFBBF7D0),
        );
      case 'Manutenção':
        return (
          fg: const Color(0xFFD97706),
          bg: const Color(0xFFFFF7ED),
          border: const Color(0xFFFED7AA),
        );
      default:
        return (
          fg: const Color(0xFF176EEB),
          bg: const Color(0xFFEFF6FF),
          border: const Color(0xFFBFDBFE),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _style();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.border),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: style.fg,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _InventoryHistoryLine extends StatelessWidget {
  const _InventoryHistoryLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.history, size: 16, color: Color(0xFF176EEB)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _InventoryFlowLine extends StatelessWidget {
  const _InventoryFlowLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(
            Icons.arrow_right_alt_rounded,
            color: Color(0xFF176EEB),
            size: 18,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF526684),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MdvrDemoScreen extends StatelessWidget {
  const _MdvrDemoScreen();

  static const _cameras = <_MdvrCameraData>[
    _MdvrCameraData(name: 'Camera frontal', icon: Icons.videocam_outlined),
    _MdvrCameraData(name: 'Camera cabine', icon: Icons.videocam_outlined),
    _MdvrCameraData(name: 'Camera traseira', icon: Icons.videocam_outlined),
    _MdvrCameraData(name: 'Camera lateral', icon: Icons.videocam_outlined),
  ];

  static const _events = <_MdvrEventData>[
    _MdvrEventData(
      title: 'Frenagem brusca',
      time: '08:41',
      severity: 'Alta',
      vehicle: 'ABC-1234',
      camera: 'Camera frontal',
    ),
    _MdvrEventData(
      title: 'Excesso de velocidade',
      time: '08:55',
      severity: 'Media',
      vehicle: 'ABC-1234',
      camera: 'Camera cabine',
    ),
    _MdvrEventData(
      title: 'Porta aberta',
      time: '09:03',
      severity: 'Media',
      vehicle: 'ABC-1234',
      camera: 'Camera traseira',
    ),
    _MdvrEventData(
      title: 'Botao de panico',
      time: '09:14',
      severity: 'Critica',
      vehicle: 'ABC-1234',
      camera: 'Camera lateral',
    ),
    _MdvrEventData(
      title: 'Sem comunica\u00E7\u00E3o',
      time: '09:30',
      severity: 'Alta',
      vehicle: 'ABC-1234',
      camera: 'Camera frontal',
    ),
  ];

  String _clockNow() {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  void _showAction(BuildContext context, String action, String cameraName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Acao visual: $action - $cameraName (modo demonstracao)'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visualTime = _clockNow();

    return ListView(
      children: [
        const _GlassSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MDVR / Câmeras',
                style: TextStyle(
                  color: Color(0xFF1F2A44),
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Monitoramento visual vinculado ao rastreamento, alertas e chamados.',
                style: TextStyle(
                  color: Color(0xFF526684),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _GlassSurface(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF25344A)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Color(0xFF60A5FA),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Modo demonstracao',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'Integracao real com DVR/CMS/VMS sera plugada em etapa futura.',
                  style: TextStyle(
                    color: Color(0xFFBFDBFE),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.93,
          ),
          itemCount: _cameras.length,
          itemBuilder: (context, index) {
            final camera = _cameras[index];
            return _MdvrCameraCard(
              data: camera,
              visualTime: visualTime,
              onAction: (action) => _showAction(context, action, camera.name),
            );
          },
        ),
        const SizedBox(height: 10),
        _GlassSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Eventos com video (simulado)',
                style: TextStyle(
                  color: Color(0xFF1F2A44),
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              for (final event in _events) ...[
                _MdvrEventRow(event: event),
                if (event != _events.last)
                  const Divider(color: Color(0xFFDDE5F0), height: 14),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        const _GlassSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fluxo de atendimento (demo)',
                style: TextStyle(
                  color: Color(0xFF1F2A44),
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 8),
              _MdvrFlowLine(text: 'Alerta no rastreamento'),
              _MdvrFlowLine(text: 'abre camera relacionada'),
              _MdvrFlowLine(text: 'salva evidencia'),
              _MdvrFlowLine(text: 'cria chamado via Bridge futuramente'),
              _MdvrFlowLine(text: 'envia WhatsApp via SouCall futuramente'),
            ],
          ),
        ),
      ],
    );
  }
}

class _MdvrCameraData {
  const _MdvrCameraData({required this.name, required this.icon});

  final String name;
  final IconData icon;
}

class _MdvrCameraCard extends StatelessWidget {
  const _MdvrCameraCard({
    required this.data,
    required this.visualTime,
    required this.onAction,
  });

  final _MdvrCameraData data;
  final String visualTime;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(data.icon, color: const Color(0xFF176EEB), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1F2A44),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Text(
                  'REC',
                  style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'veículo vinculado: ABC-1234',
            style: TextStyle(
              color: Color(0xFF60718D),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.circle, color: Color(0xFF10B981), size: 10),
              const SizedBox(width: 6),
              const Text(
                'Ao vivo',
                style: TextStyle(
                  color: Color(0xFF047857),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                visualTime,
                style: const TextStyle(
                  color: Color(0xFF60718D),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_circle_fill_outlined,
                    color: Color(0xFF93C5FD),
                    size: 34,
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Feed visual simulado',
                    style: TextStyle(
                      color: Color(0xFFBFDBFE),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MdvrActionButton(
                icon: Icons.map_outlined,
                label: 'Ver no mapa',
                onTap: () => onAction('Ver no mapa'),
              ),
              _MdvrActionButton(
                icon: Icons.support_agent_outlined,
                label: 'Criar chamado',
                onTap: () => onAction('Criar chamado'),
              ),
              _MdvrActionButton(
                icon: Icons.forum_outlined,
                label: 'Enviar WhatsApp',
                onTap: () => onAction('Enviar WhatsApp'),
              ),
              _MdvrActionButton(
                icon: Icons.save_outlined,
                label: 'Salvar evidencia',
                onTap: () => onAction('Salvar evidencia'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MdvrActionButton extends StatelessWidget {
  const _MdvrActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        foregroundColor: const Color(0xFF1F2A44),
        side: const BorderSide(color: Color(0xFFD3DDEA)),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MdvrEventData {
  const _MdvrEventData({
    required this.title,
    required this.time,
    required this.severity,
    required this.vehicle,
    required this.camera,
  });

  final String title;
  final String time;
  final String severity;
  final String vehicle;
  final String camera;
}

class _MdvrEventRow extends StatelessWidget {
  const _MdvrEventRow({required this.event});

  final _MdvrEventData event;

  Color _severityColor() {
    switch (event.severity.toLowerCase()) {
      case 'critica':
        return const Color(0xFFB42318);
      case 'alta':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF176EEB);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _severityColor();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: const TextStyle(
                  color: Color(0xFF1F2A44),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${event.time} - ${event.severity} - ${event.vehicle} - ${event.camera}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MdvrFlowLine extends StatelessWidget {
  const _MdvrFlowLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(
            Icons.arrow_right_alt_rounded,
            color: Color(0xFF176EEB),
            size: 18,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF526684),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetryRaceShowcaseScreen extends StatefulWidget {
  const _TelemetryRaceShowcaseScreen();

  @override
  State<_TelemetryRaceShowcaseScreen> createState() =>
      _TelemetryRaceShowcaseScreenState();
}

class _TelemetryRaceShowcaseScreenState
    extends State<_TelemetryRaceShowcaseScreen> {
  static const _seasonOptions = ['Temporada atual demo'];
  static const _raceOptions = [
    'Austrália',
    'China',
    'Japão',
    'Bahrein'
  ];
  static const _sessionOptions = [
    'Treino',
    'Classificação',
    'Corrida'
  ];
  static const _driverOptions = [
    'Bortoleto',
    'Verstappen',
    'Norris',
    'Leclerc'
  ];
  static const _compareOptions = [
    'Nenhum',
    'Verstappen',
    'Norris',
    'Leclerc',
    'Bortoleto',
  ];

  final Map<String, _RaceTelemetryCircuit> _circuits = {
    'Austrália':
        _RaceTelemetryCircuit(
      raceName:
          'Austrália',
      trackSubtitle:
          'Albert Park • Setores 1/2/3',
      pathPoints: const [
        Offset(0.13, 0.62),
        Offset(0.22, 0.79),
        Offset(0.41, 0.84),
        Offset(0.64, 0.75),
        Offset(0.82, 0.58),
        Offset(0.77, 0.33),
        Offset(0.57, 0.20),
        Offset(0.34, 0.23),
        Offset(0.19, 0.38),
      ],
      events: const [
        _RaceTelemetryEvent(
          id: 'aus-1',
          label: 'Frenagem forte',
          sector: 'Setor 1',
          position: Offset(0.24, 0.78),
          accent: Color(0xFFEF4444),
        ),
        _RaceTelemetryEvent(
          id: 'aus-2',
          label: 'Troca de pneus',
          sector: 'Setor 2',
          position: Offset(0.57, 0.71),
          accent: Color(0xFFF59E0B),
        ),
        _RaceTelemetryEvent(
          id: 'aus-3',
          label:
              'Aceleração máxima',
          sector: 'Setor 3',
          position: Offset(0.76, 0.43),
          accent: Color(0xFF22C55E),
        ),
        _RaceTelemetryEvent(
          id: 'aus-4',
          label:
              'Perda de aderência',
          sector: 'Setor 1',
          position: Offset(0.34, 0.24),
          accent: Color(0xFFA855F7),
        ),
        _RaceTelemetryEvent(
          id: 'aus-5',
          label:
              'Volta rápida',
          sector: 'Setor 2',
          position: Offset(0.63, 0.30),
          accent: Color(0xFF3B82F6),
        ),
      ],
    ),
    'China': _RaceTelemetryCircuit(
      raceName: 'China',
      trackSubtitle:
          'Shanghai • Setores 1/2/3',
      pathPoints: const [
        Offset(0.15, 0.70),
        Offset(0.25, 0.82),
        Offset(0.47, 0.80),
        Offset(0.69, 0.69),
        Offset(0.84, 0.52),
        Offset(0.80, 0.28),
        Offset(0.60, 0.19),
        Offset(0.43, 0.27),
        Offset(0.31, 0.40),
      ],
      events: const [
        _RaceTelemetryEvent(
          id: 'chi-1',
          label: 'Entrada no box',
          sector: 'Setor 1',
          position: Offset(0.28, 0.81),
          accent: Color(0xFFEF4444),
        ),
        _RaceTelemetryEvent(
          id: 'chi-2',
          label: 'Frenagem forte',
          sector: 'Setor 2',
          position: Offset(0.49, 0.74),
          accent: Color(0xFFF59E0B),
        ),
        _RaceTelemetryEvent(
          id: 'chi-3',
          label: 'Temperatura alta',
          sector: 'Setor 3',
          position: Offset(0.77, 0.52),
          accent: Color(0xFF22C55E),
        ),
        _RaceTelemetryEvent(
          id: 'chi-4',
          label:
              'Aceleração máxima',
          sector: 'Setor 3',
          position: Offset(0.69, 0.27),
          accent: Color(0xFF3B82F6),
        ),
      ],
    ),
    'Japão':
        _RaceTelemetryCircuit(
      raceName:
          'Japão',
      trackSubtitle:
          'Suzuka • Setores 1/2/3',
      pathPoints: const [
        Offset(0.16, 0.67),
        Offset(0.23, 0.82),
        Offset(0.46, 0.84),
        Offset(0.67, 0.74),
        Offset(0.79, 0.57),
        Offset(0.72, 0.40),
        Offset(0.52, 0.34),
        Offset(0.41, 0.19),
        Offset(0.24, 0.31),
      ],
      events: const [
        _RaceTelemetryEvent(
          id: 'jpn-1',
          label:
              'Perda de aderência',
          sector: 'Setor 1',
          position: Offset(0.25, 0.81),
          accent: Color(0xFFEF4444),
        ),
        _RaceTelemetryEvent(
          id: 'jpn-2',
          label: 'Frenagem forte',
          sector: 'Setor 2',
          position: Offset(0.51, 0.78),
          accent: Color(0xFFF59E0B),
        ),
        _RaceTelemetryEvent(
          id: 'jpn-3',
          label: 'Entrada no box',
          sector: 'Setor 3',
          position: Offset(0.74, 0.54),
          accent: Color(0xFF22C55E),
        ),
        _RaceTelemetryEvent(
          id: 'jpn-4',
          label:
              'Volta rápida',
          sector: 'Setor 2',
          position: Offset(0.46, 0.22),
          accent: Color(0xFF3B82F6),
        ),
      ],
    ),
    'Bahrein': _RaceTelemetryCircuit(
      raceName: 'Bahrein',
      trackSubtitle:
          'Sakhir • Setores 1/2/3',
      pathPoints: const [
        Offset(0.14, 0.72),
        Offset(0.29, 0.83),
        Offset(0.50, 0.82),
        Offset(0.70, 0.72),
        Offset(0.82, 0.55),
        Offset(0.77, 0.30),
        Offset(0.57, 0.19),
        Offset(0.35, 0.23),
        Offset(0.21, 0.42),
      ],
      events: const [
        _RaceTelemetryEvent(
          id: 'bah-1',
          label: 'Frenagem forte',
          sector: 'Setor 1',
          position: Offset(0.30, 0.82),
          accent: Color(0xFFEF4444),
        ),
        _RaceTelemetryEvent(
          id: 'bah-2',
          label: 'Temperatura alta',
          sector: 'Setor 2',
          position: Offset(0.53, 0.79),
          accent: Color(0xFFF59E0B),
        ),
        _RaceTelemetryEvent(
          id: 'bah-3',
          label: 'Troca de pneus',
          sector: 'Setor 3',
          position: Offset(0.75, 0.50),
          accent: Color(0xFF22C55E),
        ),
        _RaceTelemetryEvent(
          id: 'bah-4',
          label:
              'Aceleração máxima',
          sector: 'Setor 3',
          position: Offset(0.63, 0.24),
          accent: Color(0xFF3B82F6),
        ),
        _RaceTelemetryEvent(
          id: 'bah-5',
          label:
              'Volta rápida',
          sector: 'Setor 2',
          position: Offset(0.36, 0.25),
          accent: Color(0xFFA855F7),
        ),
      ],
    ),
  };

  final Map<String, _RaceTelemetryDriverSnapshot> _baseDriverSnapshots = {
    'Bortoleto': const _RaceTelemetryDriverSnapshot(
      tireCompound: 'Macio',
      tireLife: 62,
      speedKmh: 298,
      rpm: 11820,
      gear: 8,
      throttle: 92,
      brake: 17,
      tireTempC: 96,
      engineTempC: 104,
      trackerBattery: 87,
      ignitionOn: true,
      gpsSignal: 92,
      gsmSignal: 88,
      lastCommunication:
          'há 9 s',
      fuelOrLoad: 54,
      trackerTemperature: 39,
      behavior: 'normal',
    ),
    'Verstappen': const _RaceTelemetryDriverSnapshot(
      tireCompound: 'Duro',
      tireLife: 58,
      speedKmh: 304,
      rpm: 12010,
      gear: 8,
      throttle: 95,
      brake: 14,
      tireTempC: 98,
      engineTempC: 106,
      trackerBattery: 90,
      ignitionOn: true,
      gpsSignal: 94,
      gsmSignal: 86,
      lastCommunication:
          'há 7 s',
      fuelOrLoad: 49,
      trackerTemperature: 40,
      behavior:
          'atenção',
    ),
    'Norris': const _RaceTelemetryDriverSnapshot(
      tireCompound:
          'Médio',
      tireLife: 66,
      speedKmh: 301,
      rpm: 11910,
      gear: 8,
      throttle: 90,
      brake: 18,
      tireTempC: 95,
      engineTempC: 103,
      trackerBattery: 84,
      ignitionOn: true,
      gpsSignal: 89,
      gsmSignal: 85,
      lastCommunication:
          'há 11 s',
      fuelOrLoad: 56,
      trackerTemperature: 38,
      behavior: 'normal',
    ),
    'Leclerc': const _RaceTelemetryDriverSnapshot(
      tireCompound:
          'Intermediário',
      tireLife: 60,
      speedKmh: 300,
      rpm: 11760,
      gear: 7,
      throttle: 88,
      brake: 21,
      tireTempC: 97,
      engineTempC: 105,
      trackerBattery: 79,
      ignitionOn: true,
      gpsSignal: 87,
      gsmSignal: 82,
      lastCommunication:
          'há 13 s',
      fuelOrLoad: 52,
      trackerTemperature: 41,
      behavior: 'risco',
    ),
  };

  String _selectedSeason = _seasonOptions.first;
  String _selectedRace = _raceOptions.first;
  String _selectedSession = _sessionOptions.first;
  String _selectedDriver = _driverOptions.first;
  String _selectedCompare = _compareOptions.first;
  int _selectedEventIndex = 0;

  _RaceTelemetryCircuit get _activeCircuit => _circuits[_selectedRace]!;

  int _sessionSpeedAdjust() {
    switch (_selectedSession) {
      case 'Treino':
        return -9;
      case 'Classificação':
        return 6;
      case 'Corrida':
        return 0;
    }
    return 0;
  }

  int _sessionRpmAdjust() {
    switch (_selectedSession) {
      case 'Treino':
        return -300;
      case 'Classificação':
        return 210;
      case 'Corrida':
        return 0;
    }
    return 0;
  }

  int _raceAdjust(String race) {
    switch (race) {
      case 'Austrália':
        return 2;
      case 'China':
        return -1;
      case 'Japão':
        return 4;
      case 'Bahrein':
        return 1;
    }
    return 0;
  }

  _RaceTelemetryDriverSnapshot _snapshotForDriver(String driver) {
    final base =
        _baseDriverSnapshots[driver] ?? _baseDriverSnapshots.values.first;
    final speedAdjust = _sessionSpeedAdjust() + _raceAdjust(_selectedRace);
    final rpmAdjust = _sessionRpmAdjust() + (_raceAdjust(_selectedRace) * 35);

    final tireLifeShift = _selectedSession == 'Corrida'
        ? -5
        : (_selectedSession ==
                'Classificação'
            ? -2
            : 4);

    return base.copyWith(
      speedKmh: (base.speedKmh + speedAdjust).clamp(120, 360),
      rpm: (base.rpm + rpmAdjust).clamp(5000, 14000),
      tireLife: (base.tireLife + tireLifeShift).clamp(18, 100),
      fuelOrLoad: (base.fuelOrLoad + (_selectedSession == 'Corrida' ? -4 : 3))
          .clamp(10, 100),
      trackerBattery:
          (base.trackerBattery + (_selectedSession == 'Treino' ? 3 : -2))
              .clamp(15, 100),
      behavior: _selectedSession == 'Corrida' && driver == 'Leclerc'
          ? 'risco'
          : (_selectedSession ==
                  'Classificação'
              ? 'atenção'
              : 'normal'),
    );
  }

  _RaceTelemetryComparison? _buildComparison(
    _RaceTelemetryDriverSnapshot principal,
  ) {
    if (_selectedCompare == 'Nenhum' || _selectedCompare == _selectedDriver) {
      return null;
    }

    final compared = _snapshotForDriver(_selectedCompare);
    return _RaceTelemetryComparison(
      mainDriver: _selectedDriver,
      comparedDriver: _selectedCompare,
      speedDelta: principal.speedKmh - compared.speedKmh,
      brakingDelta: principal.brake - compared.brake,
      throttleDelta: principal.throttle - compared.throttle,
      tireWearDelta: principal.tireWear - compared.tireWear,
    );
  }

  void _selectEventByIndex(int index) {
    setState(() {
      _selectedEventIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeCircuit = _activeCircuit;
    final safeSelectedIndex =
        _selectedEventIndex.clamp(0, activeCircuit.events.length - 1);
    final selectedEvent = activeCircuit.events[safeSelectedIndex];
    final driverSnapshot = _snapshotForDriver(_selectedDriver);
    final comparison = _buildComparison(driverSnapshot);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1120;

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF051428),
                    Color(0xFF0A1E3A),
                    Color(0xFF071528),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: const Color(0xFF1A3C66)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Demo Telemetria de Corrida',
                          style: TextStyle(
                            color: Color(0xFFEAF1FF),
                            fontWeight: FontWeight.w900,
                            fontSize: 26,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F2B4C),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFF2B568A)),
                        ),
                        child: const Text(
                          'Snapshot demo',
                          style: TextStyle(
                            color: Color(0xFFD6E7FF),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Demonstração técnica com dados públicos/simulados. Sem uso de marca oficial.',
                    style: TextStyle(
                      color: Color(0xFF9DB6D8),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0B2039),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1A3D66)),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _RaceTelemetryFilterDropdown(
                    label: 'Temporada',
                    value: _selectedSeason,
                    options: _seasonOptions,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedSeason = value);
                    },
                  ),
                  _RaceTelemetryFilterDropdown(
                    label: 'Prova',
                    value: _selectedRace,
                    options: _raceOptions,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedRace = value;
                        _selectedEventIndex = 0;
                      });
                    },
                  ),
                  _RaceTelemetryFilterDropdown(
                    label:
                        'Sessão',
                    value: _selectedSession,
                    options: _sessionOptions,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedSession = value);
                    },
                  ),
                  _RaceTelemetryFilterDropdown(
                    label: 'Piloto',
                    value: _selectedDriver,
                    options: _driverOptions,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedDriver = value);
                    },
                  ),
                  _RaceTelemetryFilterDropdown(
                    label: 'Comparar com',
                    value: _selectedCompare,
                    options: _compareOptions,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedCompare = value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      children: [
                        _buildCircuitCard(activeCircuit, selectedEvent),
                        const SizedBox(height: 12),
                        _buildEventSelector(activeCircuit, safeSelectedIndex),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        _buildRaceMetricsCard(
                          driverSnapshot,
                          comparison,
                        ),
                        const SizedBox(height: 12),
                        _buildFleetMetricsCard(driverSnapshot),
                        const SizedBox(height: 12),
                        _buildTranslationCard(theme),
                        if (comparison != null) ...[
                          const SizedBox(height: 12),
                          _buildComparisonCard(comparison),
                        ],
                      ],
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  _buildCircuitCard(activeCircuit, selectedEvent),
                  const SizedBox(height: 12),
                  _buildEventSelector(activeCircuit, safeSelectedIndex),
                  const SizedBox(height: 12),
                  _buildRaceMetricsCard(driverSnapshot, comparison),
                  const SizedBox(height: 12),
                  _buildFleetMetricsCard(driverSnapshot),
                  const SizedBox(height: 12),
                  _buildTranslationCard(theme),
                  if (comparison != null) ...[
                    const SizedBox(height: 12),
                    _buildComparisonCard(comparison),
                  ],
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildCircuitCard(
    _RaceTelemetryCircuit circuit,
    _RaceTelemetryEvent selectedEvent,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF091A2F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1B3A61)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Mapinha da pista',
                  style: TextStyle(
                    color: Color(0xFFEAF1FF),
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
              Text(
                circuit.raceName,
                style: const TextStyle(
                  color: Color(0xFF93C5FD),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            circuit.trackSubtitle,
            style: const TextStyle(
              color: Color(0xFFA6BDD8),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              _RaceTelemetrySectorBadge(
                color: Color(0xFF3B82F6),
                label: 'Setor 1',
              ),
              SizedBox(width: 8),
              _RaceTelemetrySectorBadge(
                color: Color(0xFFF59E0B),
                label: 'Setor 2',
              ),
              SizedBox(width: 8),
              _RaceTelemetrySectorBadge(
                color: Color(0xFF22C55E),
                label: 'Setor 3',
              ),
            ],
          ),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 1.85,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;

                return Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CustomPaint(
                          painter: _RaceTelemetryCircuitPainter(
                            pathPoints: circuit.pathPoints,
                          ),
                        ),
                      ),
                    ),
                    for (var i = 0; i < circuit.events.length; i++)
                      Positioned(
                        left: (circuit.events[i].position.dx * width) - 16,
                        top: (circuit.events[i].position.dy * height) - 16,
                        child: Tooltip(
                          message: 'Esse evento foi aqui',
                          child: GestureDetector(
                            onTap: () => _selectEventByIndex(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: circuit.events[i].accent
                                    .withValues(alpha: 0.90),
                                border: Border.all(
                                  color: i == _selectedEventIndex
                                      ? const Color(0xFFFFF7ED)
                                      : const Color(0xFFDDE8F8),
                                  width: i == _selectedEventIndex ? 2 : 1.2,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: Container(
                        width: width * 0.52,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF0C213A).withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF2A4D76)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedEvent.label,
                              style: TextStyle(
                                color: selectedEvent.accent,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Esse evento foi aqui',
                              style: TextStyle(
                                color: Color(0xFFCFE2FF),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              selectedEvent.sector,
                              style: const TextStyle(
                                color: Color(0xFF93B7E7),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventSelector(
      _RaceTelemetryCircuit circuit, int safeSelectedIndex) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1D33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1A3C62)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < circuit.events.length; i++)
            ChoiceChip(
              selected: i == safeSelectedIndex,
              onSelected: (_) => _selectEventByIndex(i),
              label: Text(
                circuit.events[i].label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              selectedColor: const Color(0xFF1D4E89),
              labelStyle: TextStyle(
                color: i == safeSelectedIndex
                    ? const Color(0xFFEAF1FF)
                    : const Color(0xFFD8E8FF),
              ),
              backgroundColor: const Color(0xFF102A48),
            ),
        ],
      ),
    );
  }

  Widget _buildRaceMetricsCard(
    _RaceTelemetryDriverSnapshot snapshot,
    _RaceTelemetryComparison? comparison,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF091A2F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1B3A61)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Métricas de corrida',
            style: TextStyle(
              color: Color(0xFFEAF1FF),
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          _RaceTelemetryInfoLine(label: 'Piloto', value: _selectedDriver),
          _RaceTelemetryInfoLine(label: 'Prova', value: _selectedRace),
          _RaceTelemetryInfoLine(
              label:
                  'Sessão',
              value: _selectedSession),
          _RaceTelemetryInfoLine(label: 'Pneu', value: snapshot.tireCompound),
          _RaceTelemetryInfoLine(
            label: 'Vida do pneu',
            value: '${snapshot.tireLife}%',
          ),
          _RaceTelemetryInfoLine(
            label: 'Velocidade',
            value: '${snapshot.speedKmh} km/h',
          ),
          _RaceTelemetryInfoLine(label: 'RPM', value: '${snapshot.rpm}'),
          _RaceTelemetryInfoLine(label: 'Marcha', value: '${snapshot.gear}'),
          _RaceTelemetryInfoLine(
            label: 'Acelerador',
            value: '${snapshot.throttle}%',
          ),
          _RaceTelemetryInfoLine(label: 'Freio', value: '${snapshot.brake}%'),
          _RaceTelemetryInfoLine(
            label: 'Temperatura do pneu',
            value:
                '${snapshot.tireTempC}Â°C',
          ),
          _RaceTelemetryInfoLine(
            label: 'Temperatura do motor',
            value:
                '${snapshot.engineTempC}Â°C',
          ),
          _RaceTelemetryInfoLine(
            label:
                'Gap para comparação',
            value: comparison == null
                ? 'n/a'
                : '${comparison.speedDelta >= 0 ? '+' : ''}${comparison.speedDelta} km/h',
          ),
        ],
      ),
    );
  }

  Widget _buildFleetMetricsCard(_RaceTelemetryDriverSnapshot snapshot) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF091A2F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1B3A61)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Equivalente em frota',
            style: TextStyle(
              color: Color(0xFFEAF1FF),
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          _RaceTelemetryInfoLine(
            label: 'Bateria do rastreador',
            value: '${snapshot.trackerBattery}%',
          ),
          _RaceTelemetryInfoLine(
            label:
                'Ignição',
            value: snapshot.ignitionOn ? 'Ligada' : 'Desligada',
          ),
          _RaceTelemetryInfoLine(
            label: 'Sinal GPS',
            value: '${snapshot.gpsSignal}%',
          ),
          _RaceTelemetryInfoLine(
            label: 'Sinal GSM',
            value: '${snapshot.gsmSignal}%',
          ),
          _RaceTelemetryInfoLine(
            label:
                'Última comunicação',
            value: snapshot.lastCommunication,
          ),
          _RaceTelemetryInfoLine(
            label:
                'Temperatura do baú/motor',
            value:
                '${snapshot.trackerTemperature}Â°C',
          ),
          _RaceTelemetryInfoLine(
            label:
                'Nível de combustível/carga',
            value: '${snapshot.fuelOrLoad}%',
          ),
          _RaceTelemetryInfoLine(
            label: 'Comportamento',
            value: snapshot.behavior,
          ),
        ],
      ),
    );
  }

  Widget _buildTranslationCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1D33),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F446F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Como isso vira valor na frota',
            style: theme.textTheme.titleMedium?.copyWith(
              color: const Color(0xFFEAF1FF),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'A mesma lógica usada para analisar velocidade, pneus, temperatura e comportamento em uma corrida pode ser aplicada em veículos de frota, guinchos, caminhões, máquinas e operações críticas.',
            style: TextStyle(
              color: Color(0xFFBCD3F3),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const _RaceTelemetryBullet(
              text:
                  'detectar condução agressiva;'),
          const _RaceTelemetryBullet(
              text:
                  'prever manutenção;'),
          const _RaceTelemetryBullet(
              text:
                  'monitorar bateria e comunicação;'),
          const _RaceTelemetryBullet(text: 'identificar perda de sinal;'),
          const _RaceTelemetryBullet(text: 'cruzar evento com mapa;'),
          const _RaceTelemetryBullet(text: 'gerar alerta ou chamado;'),
          const _RaceTelemetryBullet(text: 'enviar aviso via SouCall;'),
          const _RaceTelemetryBullet(text: 'abrir OS via SouFind futuramente.'),
        ],
      ),
    );
  }

  Widget _buildComparisonCard(_RaceTelemetryComparison comparison) {
    String formatDelta(int value, String suffix) {
      final signal = value >= 0 ? '+' : '';
      return '$signal$value$suffix';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF091A2F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1B3A61)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comparação',
            style: TextStyle(
              color: Color(0xFFEAF1FF),
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          _RaceTelemetryInfoLine(
            label: 'Piloto principal',
            value: comparison.mainDriver,
          ),
          _RaceTelemetryInfoLine(
            label: 'Piloto comparado',
            value: comparison.comparedDriver,
          ),
          _RaceTelemetryInfoLine(
            label:
                'Diferença de velocidade',
            value: formatDelta(comparison.speedDelta, ' km/h'),
          ),
          _RaceTelemetryInfoLine(
            label:
                'Diferença de frenagem',
            value: formatDelta(comparison.brakingDelta, '%'),
          ),
          _RaceTelemetryInfoLine(
            label:
                'Diferença de aceleração',
            value: formatDelta(comparison.throttleDelta, '%'),
          ),
          _RaceTelemetryInfoLine(
            label:
                'Diferença de desgaste de pneu',
            value: formatDelta(comparison.tireWearDelta, '%'),
          ),
        ],
      ),
    );
  }
}

class _RaceTelemetryFilterDropdown extends StatelessWidget {
  const _RaceTelemetryFilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isDense: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFF122C4D),
          labelStyle: const TextStyle(
            color: Color(0xFFA8C4E9),
            fontWeight: FontWeight.w700,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF2D588A)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF2D588A)),
          ),
        ),
        dropdownColor: const Color(0xFF0D2440),
        style: const TextStyle(
          color: Color(0xFFEAF1FF),
          fontWeight: FontWeight.w700,
        ),
        items: [
          for (final option in options)
            DropdownMenuItem<String>(
              value: option,
              child: Text(option),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _RaceTelemetrySectorBadge extends StatelessWidget {
  const _RaceTelemetrySectorBadge({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.62)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _RaceTelemetryInfoLine extends StatelessWidget {
  const _RaceTelemetryInfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFA9C3E8),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFFEAF1FF),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RaceTelemetryBullet extends StatelessWidget {
  const _RaceTelemetryBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(
              Icons.circle,
              size: 8,
              color: Color(0xFF60A5FA),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFD5E6FF),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RaceTelemetryCircuitPainter extends CustomPainter {
  const _RaceTelemetryCircuitPainter({required this.pathPoints});

  final List<Offset> pathPoints;

  @override
  void paint(Canvas canvas, Size size) {
    if (pathPoints.length < 2) {
      return;
    }

    final backgroundPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF061426), Color(0xFF10233A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    final points = [
      for (final point in pathPoints)
        Offset(point.dx * size.width, point.dy * size.height),
    ];

    final sectorColors = const [
      Color(0xFF3B82F6),
      Color(0xFFF59E0B),
      Color(0xFF22C55E),
    ];
    final segmentCount = points.length;

    for (var i = 0; i < segmentCount; i++) {
      final current = points[i];
      final next = points[(i + 1) % segmentCount];
      final ratio = i / segmentCount;
      final sectorIndex = ratio < 0.34 ? 0 : (ratio < 0.67 ? 1 : 2);

      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 15
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14)
        ..color = sectorColors[sectorIndex].withValues(alpha: 0.20);
      canvas.drawLine(current, next, glow);

      final track = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 9
        ..color = sectorColors[sectorIndex].withValues(alpha: 0.88);
      canvas.drawLine(current, next, track);

      final center = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.4
        ..color = const Color(0xFFE2E8F0).withValues(alpha: 0.46);
      canvas.drawLine(current, next, center);
    }

    final start = points.first;
    final finishPaint = Paint()
      ..color = const Color(0xFFEAF1FF)
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(start.dx - 9, start.dy - 7),
      Offset(start.dx + 9, start.dy + 7),
      finishPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RaceTelemetryCircuitPainter oldDelegate) {
    return oldDelegate.pathPoints != pathPoints;
  }
}

class _RaceTelemetryCircuit {
  const _RaceTelemetryCircuit({
    required this.raceName,
    required this.trackSubtitle,
    required this.pathPoints,
    required this.events,
  });

  final String raceName;
  final String trackSubtitle;
  final List<Offset> pathPoints;
  final List<_RaceTelemetryEvent> events;
}

class _RaceTelemetryEvent {
  const _RaceTelemetryEvent({
    required this.id,
    required this.label,
    required this.sector,
    required this.position,
    required this.accent,
  });

  final String id;
  final String label;
  final String sector;
  final Offset position;
  final Color accent;
}

class _RaceTelemetryDriverSnapshot {
  const _RaceTelemetryDriverSnapshot({
    required this.tireCompound,
    required this.tireLife,
    required this.speedKmh,
    required this.rpm,
    required this.gear,
    required this.throttle,
    required this.brake,
    required this.tireTempC,
    required this.engineTempC,
    required this.trackerBattery,
    required this.ignitionOn,
    required this.gpsSignal,
    required this.gsmSignal,
    required this.lastCommunication,
    required this.fuelOrLoad,
    required this.trackerTemperature,
    required this.behavior,
  });

  final String tireCompound;
  final int tireLife;
  final int speedKmh;
  final int rpm;
  final int gear;
  final int throttle;
  final int brake;
  final int tireTempC;
  final int engineTempC;
  final int trackerBattery;
  final bool ignitionOn;
  final int gpsSignal;
  final int gsmSignal;
  final String lastCommunication;
  final int fuelOrLoad;
  final int trackerTemperature;
  final String behavior;

  int get tireWear => 100 - tireLife;

  _RaceTelemetryDriverSnapshot copyWith({
    String? tireCompound,
    int? tireLife,
    int? speedKmh,
    int? rpm,
    int? gear,
    int? throttle,
    int? brake,
    int? tireTempC,
    int? engineTempC,
    int? trackerBattery,
    bool? ignitionOn,
    int? gpsSignal,
    int? gsmSignal,
    String? lastCommunication,
    int? fuelOrLoad,
    int? trackerTemperature,
    String? behavior,
  }) {
    return _RaceTelemetryDriverSnapshot(
      tireCompound: tireCompound ?? this.tireCompound,
      tireLife: tireLife ?? this.tireLife,
      speedKmh: speedKmh ?? this.speedKmh,
      rpm: rpm ?? this.rpm,
      gear: gear ?? this.gear,
      throttle: throttle ?? this.throttle,
      brake: brake ?? this.brake,
      tireTempC: tireTempC ?? this.tireTempC,
      engineTempC: engineTempC ?? this.engineTempC,
      trackerBattery: trackerBattery ?? this.trackerBattery,
      ignitionOn: ignitionOn ?? this.ignitionOn,
      gpsSignal: gpsSignal ?? this.gpsSignal,
      gsmSignal: gsmSignal ?? this.gsmSignal,
      lastCommunication: lastCommunication ?? this.lastCommunication,
      fuelOrLoad: fuelOrLoad ?? this.fuelOrLoad,
      trackerTemperature: trackerTemperature ?? this.trackerTemperature,
      behavior: behavior ?? this.behavior,
    );
  }
}

class _RaceTelemetryComparison {
  const _RaceTelemetryComparison({
    required this.mainDriver,
    required this.comparedDriver,
    required this.speedDelta,
    required this.brakingDelta,
    required this.throttleDelta,
    required this.tireWearDelta,
  });

  final String mainDriver;
  final String comparedDriver;
  final int speedDelta;
  final int brakingDelta;
  final int throttleDelta;
  final int tireWearDelta;
}

class _TelemetryDemoScreen extends StatefulWidget {
  const _TelemetryDemoScreen();

  @override
  State<_TelemetryDemoScreen> createState() => _TelemetryDemoScreenState();
}

class _TelemetryDemoScreenState extends State<_TelemetryDemoScreen> {
  static const _fallbackEvents = <_TelemetryDemoEvent>[
    _TelemetryDemoEvent(
      id: '01',
      markerLabel: '01',
      cornerLabel: 'Curva 1',
      eventLabel: 'Frenagem forte',
      sectorLabel: 'Setor 1',
      speedKmh: 287,
      rpm: 11580,
      gear: 7,
      throttle: 78,
      brake: 24,
      temperatureC: 98,
      eventTime: '14:22:18',
      markerX: 0.28,
      markerY: 0.76,
      markerColor: Color(0xFFEF4444),
      severityLabel: 'Alto',
      severityColor: Color(0xFFEF4444),
      lapDelta: '+0.352',
    ),
    _TelemetryDemoEvent(
      id: '02',
      markerLabel: '02',
      cornerLabel: 'Curva 4',
      eventLabel: 'Reducao brusca',
      sectorLabel: 'Setor 2',
      speedKmh: 173,
      rpm: 9410,
      gear: 5,
      throttle: 35,
      brake: 61,
      temperatureC: 101,
      eventTime: '14:24:12',
      markerX: 0.72,
      markerY: 0.70,
      markerColor: Color(0xFFF59E0B),
      severityLabel: 'Médio',
      severityColor: Color(0xFFF59E0B),
      lapDelta: '+0.128',
    ),
    _TelemetryDemoEvent(
      id: '03',
      markerLabel: '03',
      cornerLabel: 'Reta principal',
      eventLabel: 'Aceleracao maxima',
      sectorLabel: 'Setor 3',
      speedKmh: 301,
      rpm: 12090,
      gear: 8,
      throttle: 100,
      brake: 0,
      temperatureC: 96,
      eventTime: '14:23:05',
      markerX: 0.80,
      markerY: 0.31,
      markerColor: Color(0xFF22C55E),
      severityLabel: 'Médio',
      severityColor: Color(0xFFF59E0B),
      lapDelta: '+0.082',
    ),
    _TelemetryDemoEvent(
      id: '04',
      markerLabel: '04',
      cornerLabel: 'Setor 2',
      eventLabel: 'Setor mais rapido',
      sectorLabel: 'Setor 2',
      speedKmh: 278,
      rpm: 11210,
      gear: 7,
      throttle: 84,
      brake: 11,
      temperatureC: 97,
      eventTime: '14:25:33',
      markerX: 0.36,
      markerY: 0.18,
      markerColor: Color(0xFF3B82F6),
      severityLabel: 'Baixo',
      severityColor: Color(0xFF22C55E),
      lapDelta: '-0.041',
    ),
    _TelemetryDemoEvent(
      id: '05',
      markerLabel: '05',
      cornerLabel: 'Chicane',
      eventLabel: 'Instabilidade traseira',
      sectorLabel: 'Setor 1',
      speedKmh: 232,
      rpm: 10520,
      gear: 6,
      throttle: 67,
      brake: 28,
      temperatureC: 99,
      eventTime: '14:26:40',
      markerX: 0.15,
      markerY: 0.48,
      markerColor: Color(0xFFA855F7),
      severityLabel: 'Médio',
      severityColor: Color(0xFFF59E0B),
      lapDelta: '+0.214',
    ),
  ];

  static const _fallbackRecentEvents = <_TelemetryRecentEvent>[
    _TelemetryRecentEvent(
      time: '14:22:18',
      section: 'Curva 1',
      event: 'Frenagem forte',
      value: '287 km/h',
      severity: 'Alto',
      accent: Color(0xFFEF4444),
    ),
    _TelemetryRecentEvent(
      time: '14:23:05',
      section: 'Reta principal',
      event: 'Aceleracao maxima',
      value: '301 km/h',
      severity: 'Médio',
      accent: Color(0xFF22C55E),
    ),
    _TelemetryRecentEvent(
      time: '14:24:12',
      section: 'Curva 4',
      event: 'Reducao brusca',
      value: '173 km/h',
      severity: 'Médio',
      accent: Color(0xFFF59E0B),
    ),
    _TelemetryRecentEvent(
      time: '14:25:33',
      section: 'Setor 2',
      event: 'Setor mais rapido',
      value: '27.842 s',
      severity: 'Baixo',
      accent: Color(0xFF3B82F6),
    ),
  ];

  final OpenF1Client _openF1Client = OpenF1Client();

  var _selectedIndex = 0;
  var _isLoadingOpenF1 = true;
  var _usingOpenF1 = false;
  var _dataStatus = 'snapshot demo';
  var _sessionSubtitle = 'Treino - snapshot';
  var _driverSubtitle = 'Carro demo';
  var _elapsedSubtitle = '--:--:--';

  List<_TelemetryDemoEvent> _eventsData = _fallbackEvents;
  List<_TelemetryRecentEvent> _recentEventsData = _fallbackRecentEvents;

  void _runAction(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Acao visual: $label (demo)')),
    );
  }

  double _normalize(num value, num max) {
    if (max <= 0) return 0;
    final result = value / max;
    if (result < 0) return 0;
    if (result > 1) return 1;
    return result.toDouble();
  }

  @override
  void initState() {
    super.initState();
    _carregarDadosOpenF1();
  }

  List<OpenF1RaceControlEvent> _buildOpenF1FallbackEvents() {
    return _fallbackRecentEvents
        .map(
          (event) => OpenF1RaceControlEvent(
            timeLabel: event.time,
            sectionLabel: event.section,
            title: event.event,
            detail: event.value,
            severity: event.severity,
            isSnapshot: true,
          ),
        )
        .toList(growable: false);
  }

  Color _mapSeverityColor(String severity, Color fallback) {
    final normalized = severity.toLowerCase();
    if (normalized.contains('alto') ||
        normalized.contains('high') ||
        normalized.contains('red')) {
      return const Color(0xFFEF4444);
    }
    if (normalized.contains('baixo') ||
        normalized.contains('low') ||
        normalized.contains('green')) {
      return const Color(0xFF22C55E);
    }
    if (normalized.contains('medio') ||
        normalized.contains('medium') ||
        normalized.contains('yellow')) {
      return const Color(0xFFF59E0B);
    }
    return fallback;
  }

  List<_TelemetryDemoEvent> _mapOpenF1EventsToTrack({
    required List<OpenF1RaceControlEvent> events,
    OpenF1CarSnapshot? carData,
  }) {
    final source = events.isEmpty ? _buildOpenF1FallbackEvents() : events;
    if (source.isEmpty) {
      return _fallbackEvents;
    }

    final mapped = <_TelemetryDemoEvent>[];
    for (var i = 0; i < _fallbackEvents.length; i++) {
      final base = _fallbackEvents[i];
      final event = source[i % source.length];
      final severityColor =
          _mapSeverityColor(event.severity, base.severityColor);

      mapped.add(
        _TelemetryDemoEvent(
          id: base.id,
          markerLabel: base.markerLabel,
          cornerLabel: base.cornerLabel,
          eventLabel: event.title,
          sectorLabel: base.sectorLabel,
          speedKmh: carData?.speedKmh ?? base.speedKmh,
          rpm: carData?.rpm ?? base.rpm,
          gear: carData?.gear ?? base.gear,
          throttle: carData?.throttle ?? base.throttle,
          brake: carData?.brake ?? base.brake,
          temperatureC: base.temperatureC,
          eventTime: event.timeLabel,
          markerX: base.markerX,
          markerY: base.markerY,
          markerColor: base.markerColor,
          severityLabel: event.severity,
          severityColor: severityColor,
          lapDelta: base.lapDelta,
          dataStatus: event.isSnapshot ? 'snapshot demo' : 'dados reais',
        ),
      );
    }

    return mapped;
  }

  List<_TelemetryRecentEvent> _mapOpenF1RecentEvents(
    List<OpenF1RaceControlEvent> events,
  ) {
    if (events.isEmpty) {
      return _fallbackRecentEvents;
    }

    return events.take(6).map((event) {
      final accent = _mapSeverityColor(event.severity, const Color(0xFF3B82F6));
      return _TelemetryRecentEvent(
        time: event.timeLabel,
        section: event.sectionLabel,
        event: event.title,
        value: event.isSnapshot ? 'snapshot demo' : event.detail,
        severity: event.severity,
        accent: accent,
      );
    }).toList(growable: false);
  }

  Future<void> _carregarDadosOpenF1() async {
    OpenF1SessionSnapshot? session;
    OpenF1DriverSnapshot? driver;
    OpenF1CarSnapshot? carData;
    var usingOpenF1 = false;
    var dataStatus = 'snapshot demo';
    var mappedEvents = _fallbackEvents;
    var mappedRecent = _fallbackRecentEvents;

    try {
      session = await _openF1Client.buscarSessaoAtualOuUltima();
      if (session != null && session.sessionKey > 0) {
        final drivers = await _openF1Client.buscarPilotosDaSessao(
          sessionKey: session.sessionKey,
        );
        if (drivers.isNotEmpty) {
          driver = drivers.first;
        }

        if (driver != null) {
          carData = await _openF1Client.buscarCarData(
            sessionKey: session.sessionKey,
            driverNumber: driver.driverNumber,
          );
        }

        final events = await _openF1Client.buscarEventosOuMontarEventosDemo(
          sessionKey: session.sessionKey,
          fallbackSnapshot: _buildOpenF1FallbackEvents(),
        );

        mappedEvents = _mapOpenF1EventsToTrack(
          events: events,
          carData: carData,
        );
        mappedRecent = _mapOpenF1RecentEvents(events);

        usingOpenF1 = carData != null || events.any((it) => !it.isSnapshot);
        dataStatus = usingOpenF1 ? 'dados reais' : 'snapshot demo';
      }
    } catch (_) {
      mappedEvents = _fallbackEvents;
      mappedRecent = _fallbackRecentEvents;
      usingOpenF1 = false;
      dataStatus = 'snapshot demo';
    }

    if (!mounted) return;

    setState(() {
      _eventsData = mappedEvents;
      _recentEventsData = mappedRecent;
      _selectedIndex = 0;
      _usingOpenF1 = usingOpenF1;
      _dataStatus = dataStatus;
      _isLoadingOpenF1 = false;
      _sessionSubtitle = session?.label ?? 'Treino - snapshot';
      if (driver != null) {
        final currentDriver = driver;
        final name = currentDriver.displayName.isNotEmpty
            ? currentDriver.displayName
            : 'Piloto ${currentDriver.driverNumber}';
        _driverSubtitle = '#${currentDriver.driverNumber} $name';
      } else {
        _driverSubtitle = 'Piloto indisponivel';
      }
      _elapsedSubtitle = carData?.sampleTime ?? 'snapshot demo';
    });
  }

  @override
  Widget build(BuildContext context) {
    final safeEvents = _eventsData.isEmpty ? _fallbackEvents : _eventsData;
    final safeIndex = _selectedIndex >= safeEvents.length ? 0 : _selectedIndex;
    final selectedEvent = safeEvents[safeIndex];

    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF061428), Color(0xFF0B1D36), Color(0xFF091527)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFF16365F)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Demo Telemetria',
                      style: TextStyle(
                        color: Color(0xFFEAF1FF),
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E2B4D),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFF24517F)),
                    ),
                    child: const Text(
                      'Dados via OpenF1',
                      style: TextStyle(
                        color: Color(0xFFD7E7FF),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Sessao: $_sessionSubtitle',
                style: const TextStyle(
                  color: Color(0xFF9DB6D8),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Piloto: $_driverSubtitle',
                style: const TextStyle(
                  color: Color(0xFF9DB6D8),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Tempo decorrido: $_elapsedSubtitle',
                style: const TextStyle(
                  color: Color(0xFF9DB6D8),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < safeEvents.length; i++)
                    ChoiceChip(
                      selected: i == safeIndex,
                      onSelected: (_) => setState(() => _selectedIndex = i),
                      label: Text(
                        '${safeEvents[i].cornerLabel} • ${safeEvents[i].eventLabel}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C223C),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1B3A61)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${selectedEvent.cornerLabel} • ${selectedEvent.eventTime}',
                      style: const TextStyle(
                        color: Color(0xFFEAF1FF),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedEvent.eventLabel,
                      style: TextStyle(
                        color: selectedEvent.markerColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Velocidade ${selectedEvent.speedKmh} km/h • RPM ${selectedEvent.rpm} • Marcha ${selectedEvent.gear}',
                      style: const TextStyle(
                        color: Color(0xFFDCEAFE),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Acelerador ${selectedEvent.throttle}% • Freio ${selectedEvent.brake}% • Temp ${selectedEvent.temperatureC}Â°C',
                      style: const TextStyle(
                        color: Color(0xFFDCEAFE),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Status: ${selectedEvent.dataStatus}',
                      style: const TextStyle(
                        color: Color(0xFF9BB8DD),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Eventos recentes',
                style: TextStyle(
                  color: Color(0xFFEAF1FF),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              for (final event in _recentEventsData.take(4)) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C223C),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1B3A61)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: event.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${event.time} • ${event.section} • ${event.event}',
                          style: const TextStyle(
                            color: Color(0xFFDCEAFE),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        event.value,
                        style: const TextStyle(
                          color: Color(0xFF9BB8DD),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Row(
                children: [
                  Icon(
                    Icons.wifi_tethering,
                    size: 14,
                    color: _usingOpenF1
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isLoadingOpenF1
                        ? 'carregando...'
                        : (_usingOpenF1 ? 'dados reais' : 'snapshot demo'),
                    style: const TextStyle(
                      color: Color(0xFF93C5FD),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Fonte: OpenF1',
                    style: TextStyle(
                      color: Color(0xFF7FA5D6),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Status: $_dataStatus',
                    style: const TextStyle(
                      color: Color(0xFF7FA5D6),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Demonstração técnica com dados públicos/snapshot. Sem uso de marca oficial.',
                style: TextStyle(
                  color: Color(0xFF8FAED6),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TelemetryDemoEvent {
  const _TelemetryDemoEvent({
    required this.id,
    required this.markerLabel,
    required this.cornerLabel,
    required this.eventLabel,
    required this.sectorLabel,
    required this.speedKmh,
    required this.rpm,
    required this.gear,
    required this.throttle,
    required this.brake,
    required this.temperatureC,
    required this.eventTime,
    required this.markerX,
    required this.markerY,
    required this.markerColor,
    required this.severityLabel,
    required this.severityColor,
    required this.lapDelta,
    this.dataStatus = 'snapshot demo',
  });

  final String id;
  final String markerLabel;
  final String cornerLabel;
  final String eventLabel;
  final String sectorLabel;
  final int speedKmh;
  final int rpm;
  final int gear;
  final int throttle;
  final int brake;
  final int temperatureC;
  final String eventTime;
  final double markerX;
  final double markerY;
  final Color markerColor;
  final String severityLabel;
  final Color severityColor;
  final String lapDelta;
  final String dataStatus;
}

class _TelemetryRecentEvent {
  const _TelemetryRecentEvent({
    required this.time,
    required this.section,
    required this.event,
    required this.value,
    required this.severity,
    required this.accent,
  });

  final String time;
  final String section;
  final String event;
  final String value;
  final String severity;
  final Color accent;
}

class _TelemetryTopHeader extends StatelessWidget {
  const _TelemetryTopHeader({
    required this.compact,
    required this.onAction,
    required this.sessionSubtitle,
    required this.driverSubtitle,
    required this.elapsedSubtitle,
    required this.usingOpenF1,
    required this.isLoading,
    required this.dataStatus,
  });

  final bool compact;
  final ValueChanged<String> onAction;
  final String sessionSubtitle;
  final String driverSubtitle;
  final String elapsedSubtitle;
  final bool usingOpenF1;
  final bool isLoading;
  final String dataStatus;

  @override
  Widget build(BuildContext context) {
    final infoCards = <_TelemetryTopInfoData>[
      _TelemetryTopInfoData(
        title: 'Carro/piloto',
        subtitle: driverSubtitle,
        icon: Icons.directions_car_filled_outlined,
        status:
            isLoading ? 'Carregando' : (usingOpenF1 ? 'Ao vivo' : 'Snapshot'),
        statusColor: isLoading
            ? const Color(0xFFF59E0B)
            : (usingOpenF1 ? const Color(0xFF22C55E) : const Color(0xFFF59E0B)),
      ),
      _TelemetryTopInfoData(
        title: 'Sessao',
        subtitle: sessionSubtitle,
        icon: Icons.flag_circle_outlined,
      ),
      _TelemetryTopInfoData(
        title: 'Tempo decorrido',
        subtitle: elapsedSubtitle,
        icon: Icons.schedule,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compact) ...[
          const Text(
            'Operação > Demo Telemetria',
            style: TextStyle(
              color: Color(0xFF6F8CB5),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Demo Telemetria',
            style: TextStyle(
              color: Color(0xFFEAF1FF),
              fontWeight: FontWeight.w900,
              fontSize: 30,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Telemetria em tempo real e analise de eventos.',
            style: TextStyle(
              color: Color(0xFF9DB6D8),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < infoCards.length; i++) ...[
                  _TelemetryTopInfoCard(data: infoCards[i]),
                  if (i != infoCards.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operação > Demo Telemetria',
                      style: TextStyle(
                        color: Color(0xFF6F8CB5),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Demo Telemetria',
                      style: TextStyle(
                        color: Color(0xFFEAF1FF),
                        fontWeight: FontWeight.w900,
                        fontSize: 34,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Telemetria em tempo real e analise de eventos.',
                      style: TextStyle(
                        color: Color(0xFF9DB6D8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final card in infoCards)
                    _TelemetryTopInfoCard(data: card)
                ],
              ),
            ],
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0E2B4D),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF24517F)),
              ),
              child: const Text(
                'Dados via OpenF1',
                style: TextStyle(
                  color: Color(0xFFD7E7FF),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0E2B4D),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF24517F)),
              ),
              child: Text(
                isLoading ? 'carregando...' : dataStatus,
                style: const TextStyle(
                  color: Color(0xFF9DB6D8),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _TelemetryActionChip(
              icon: Icons.play_circle_outline,
              label: 'Replay',
              onTap: () => onAction('Replay'),
            ),
            _TelemetryActionChip(
              icon: Icons.compare_arrows,
              label: 'Comparar',
              onTap: () => onAction('Comparar'),
            ),
            _TelemetryActionChip(
              icon: Icons.more_horiz,
              label: 'Mais',
              onTap: () => onAction('Mais ações'),
            ),
          ],
        ),
      ],
    );
  }
}

class _TelemetryTopInfoData {
  const _TelemetryTopInfoData({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.status,
    this.statusColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? status;
  final Color? statusColor;
}

class _TelemetryTopInfoCard extends StatelessWidget {
  const _TelemetryTopInfoCard({required this.data});

  final _TelemetryTopInfoData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C203B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1D3A61)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: 16, color: const Color(0xFF8CB8FF)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    color: Color(0xFFCCE0FF),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.subtitle,
                  style: const TextStyle(
                    color: Color(0xFFEAF1FF),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (data.status != null)
            Row(
              children: [
                Icon(Icons.circle,
                    size: 9,
                    color: data.statusColor ?? const Color(0xFF22C55E)),
                const SizedBox(width: 5),
                Text(
                  data.status!,
                  style: TextStyle(
                    color: data.statusColor ?? const Color(0xFF22C55E),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TelemetryActionChip extends StatelessWidget {
  const _TelemetryActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D233F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E3C66)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: const Color(0xFFA4C6F8)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFDCEAFE),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TelemetryTrackPanel extends StatelessWidget {
  const _TelemetryTrackPanel({
    required this.events,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<_TelemetryDemoEvent> events;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final selected = events[selectedIndex];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF071727),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF163656)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timeline, size: 16, color: Color(0xFF8CB8FF)),
              SizedBox(width: 8),
              Text(
                'Circuito ao vivo',
                style: TextStyle(
                  color: Color(0xFFDCEAFE),
                  fontWeight: FontWeight.w800,
                ),
              ),
              Spacer(),
              Text(
                'Setor 1  +0.352',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          AspectRatio(
            aspectRatio: 1.78,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                final markerSize = width < 520 ? 30.0 : 36.0;
                final bubbleWidth = width < 560 ? 220.0 : 260.0;

                final rawLeft = selected.markerX * width + 14;
                final maxLeft = width - bubbleWidth - 8;
                final bubbleLeft =
                    rawLeft < 8 ? 8.0 : (rawLeft > maxLeft ? maxLeft : rawLeft);

                final rawTop = selected.markerY * height - 80;
                final maxTop = height - 158;
                final bubbleTop =
                    rawTop < 8 ? 8.0 : (rawTop > maxTop ? maxTop : rawTop);

                return Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF071426), Color(0xFF102540)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CustomPaint(painter: _TelemetryTrackPainter()),
                      ),
                    ),
                    for (var i = 0; i < events.length; i++)
                      Positioned(
                        left: (events[i].markerX * width) - (markerSize / 2),
                        top: (events[i].markerY * height) - (markerSize / 2),
                        child: _TelemetryTrackMarker(
                          label: events[i].markerLabel,
                          color: events[i].markerColor,
                          selected: i == selectedIndex,
                          size: markerSize,
                          onTap: () => onSelect(i),
                        ),
                      ),
                    Positioned(
                      left: bubbleLeft,
                      top: bubbleTop,
                      child: _TelemetryEventBubble(
                        event: selected,
                        width: bubbleWidth,
                      ),
                    ),
                    const Positioned(
                      right: 10,
                      bottom: 10,
                      child: _TelemetrySectorLegend(),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetryTrackMarker extends StatelessWidget {
  const _TelemetryTrackMarker({
    required this.label,
    required this.color,
    required this.selected,
    required this.size,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: selected ? 0.95 : 0.80),
            border: Border.all(
              color:
                  selected ? const Color(0xFFFFF7ED) : const Color(0xFFDDE7F7),
              width: selected ? 2.2 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: selected ? 0.72 : 0.38),
                blurRadius: selected ? 20 : 10,
                spreadRadius: selected ? 2 : 1,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _TelemetryEventBubble extends StatelessWidget {
  const _TelemetryEventBubble({required this.event, required this.width});

  final _TelemetryDemoEvent event;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1D33).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E517A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Evento detectado',
                  style: TextStyle(
                    color: Color(0xFFDCEAFE),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const Icon(Icons.close, size: 16, color: Color(0xFF93B7E7)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Este evento foi aqui',
            style: TextStyle(
              color: Color(0xFF9BB8DD),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            event.cornerLabel,
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontWeight: FontWeight.w900,
              fontSize: 30,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            event.eventLabel,
            style: TextStyle(
              color: event.markerColor,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Velocidade: ${event.speedKmh} km/h',
            style: const TextStyle(
              color: Color(0xFFDCEAFE),
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Horario: ${event.eventTime}',
            style: const TextStyle(
              color: Color(0xFFDCEAFE),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Status: ${event.dataStatus}',
            style: const TextStyle(
              color: Color(0xFF9BB8DD),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetrySectorLegend extends StatelessWidget {
  const _TelemetrySectorLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1B2F).withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E3E66)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TelemetryLegendDot(color: Color(0xFF3B82F6), label: 'Setor 1'),
          SizedBox(width: 12),
          _TelemetryLegendDot(color: Color(0xFFF59E0B), label: 'Setor 2'),
          SizedBox(width: 12),
          _TelemetryLegendDot(color: Color(0xFF22C55E), label: 'Setor 3'),
        ],
      ),
    );
  }
}

class _TelemetryLegendDot extends StatelessWidget {
  const _TelemetryLegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFCFE2FF),
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _TelemetryLiveMetric {
  const _TelemetryLiveMetric({
    required this.label,
    required this.value,
    required this.unit,
    required this.progress,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final String unit;
  final double progress;
  final Color color;
  final IconData icon;
}

class _TelemetryLivePanel extends StatelessWidget {
  const _TelemetryLivePanel({
    required this.metrics,
    required this.usingOpenF1,
    required this.dataStatus,
  });

  final List<_TelemetryLiveMetric> metrics;
  final bool usingOpenF1;
  final String dataStatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF091A2F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1B3A61)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Telemetria ao vivo',
                  style: TextStyle(
                    color: Color(0xFFEAF1FF),
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
              Icon(
                Icons.circle,
                size: 10,
                color: usingOpenF1
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 6),
              Text(
                usingOpenF1 ? 'Ao vivo' : 'snapshot demo',
                style: TextStyle(
                  color: usingOpenF1
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFF59E0B),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final metric in metrics) ...[
            _TelemetryLiveMetricRow(metric: metric),
            if (metric != metrics.last) const SizedBox(height: 8),
          ],
          const SizedBox(height: 10),
          const Divider(color: Color(0xFF214266), height: 12),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 16, color: Color(0xFF60A5FA)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'GPS 23Â°42\'45.8"S   46Â°41\'19.6"W',
                  style: TextStyle(
                    color: Color(0xFFD3E4FF),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                dataStatus,
                style: TextStyle(
                  color: usingOpenF1
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFF59E0B),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TelemetryLiveMetricRow extends StatelessWidget {
  const _TelemetryLiveMetricRow({required this.metric});

  final _TelemetryLiveMetric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0C223C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1B3A61)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(metric.icon, size: 14, color: metric.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  metric.label,
                  style: const TextStyle(
                    color: Color(0xFFC7DBF9),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              Text(
                '${metric.value} ${metric.unit}',
                style: const TextStyle(
                  color: Color(0xFFEAF1FF),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: metric.progress,
              minHeight: 6,
              backgroundColor: const Color(0xFF284263),
              valueColor: AlwaysStoppedAnimation<Color>(metric.color),
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetrySummaryWrap extends StatelessWidget {
  const _TelemetrySummaryWrap({required this.event});

  final _TelemetryDemoEvent event;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        const _TelemetrySummaryCard(
          icon: Icons.event,
          title: 'Eventos',
          value: '12',
          detail: 'Hoje',
          accent: Color(0xFF3B82F6),
        ),
        const _TelemetrySummaryCard(
          icon: Icons.speed,
          title: 'Velocidade maxima',
          value: '312 km/h',
          detail: 'Reta principal',
          accent: Color(0xFF22C55E),
        ),
        const _TelemetrySummaryCard(
          icon: Icons.timer_outlined,
          title: 'Tempo de volta',
          value: '1:28.456',
          detail: 'Melhor volta',
          accent: Color(0xFFF59E0B),
        ),
        _TelemetrySummaryCard(
          icon: Icons.report_problem_outlined,
          title: 'Setor critico',
          value: event.sectorLabel,
          detail: 'Delta ${event.lapDelta}',
          accent: event.severityColor,
        ),
      ],
    );
  }
}

class _TelemetrySummaryCard extends StatelessWidget {
  const _TelemetrySummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1D33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.62)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF9DB6D8),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w900,
              fontSize: 31,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: const TextStyle(
              color: Color(0xFF9DB6D8),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetryRecentEventsPanel extends StatelessWidget {
  const _TelemetryRecentEventsPanel({required this.events});

  final List<_TelemetryRecentEvent> events;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1D33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1A3B61)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Eventos recentes',
                  style: TextStyle(
                    color: Color(0xFFEAF1FF),
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
              _TelemetryDropdownStub(label: 'Todos os eventos'),
            ],
          ),
          const SizedBox(height: 8),
          for (final event in events) ...[
            Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    event.time,
                    style: const TextStyle(
                      color: Color(0xFFA5BFDE),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${event.section}  ${event.event}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: event.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  event.value,
                  style: const TextStyle(
                    color: Color(0xFFDCEAFE),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                _TelemetrySeverityChip(
                  label: event.severity,
                  color: event.accent,
                ),
              ],
            ),
            if (event != events.last)
              const Divider(color: Color(0xFF1E3F64), height: 12),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Abertura completa de eventos desta visao ainda segue em implantacao.',
                    ),
                  ),
                );
              },
              icon: const Icon(
                Icons.open_in_new,
                size: 14,
                color: Color(0xFF60A5FA),
              ),
              label: const Text(
                'Ver todos os eventos',
                style: TextStyle(
                  color: Color(0xFF60A5FA),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetryDropdownStub extends StatelessWidget {
  const _TelemetryDropdownStub({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0C223C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E3E66)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFCFE2FF),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.keyboard_arrow_down,
              size: 15, color: Color(0xFF9EBCE4)),
        ],
      ),
    );
  }
}

class _TelemetrySeverityChip extends StatelessWidget {
  const _TelemetrySeverityChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.62)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _TelemetryTrackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 0.28, h * 0.76)
      ..cubicTo(w * 0.12, h * 0.76, w * 0.08, h * 0.60, w * 0.16, h * 0.50)
      ..cubicTo(w * 0.25, h * 0.37, w * 0.22, h * 0.24, w * 0.34, h * 0.20)
      ..cubicTo(w * 0.48, h * 0.16, w * 0.64, h * 0.24, w * 0.79, h * 0.26)
      ..cubicTo(w * 0.89, h * 0.28, w * 0.91, h * 0.43, w * 0.84, h * 0.52)
      ..cubicTo(w * 0.79, h * 0.59, w * 0.71, h * 0.56, w * 0.67, h * 0.64)
      ..cubicTo(w * 0.63, h * 0.73, w * 0.57, h * 0.75, w * 0.49, h * 0.74)
      ..cubicTo(w * 0.43, h * 0.73, w * 0.35, h * 0.76, w * 0.28, h * 0.76)
      ..close();

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.14
      ..color = const Color(0xFF0EA5E9).withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas.drawPath(path, glowPaint);

    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.092
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = const LinearGradient(
        colors: [Color(0xFF3B82F6), Color(0xFFF59E0B), Color(0xFF22C55E)],
        stops: [0.08, 0.55, 0.92],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, outerPaint);

    final innerTrackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.058
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFBFD2F0).withValues(alpha: 0.28);
    canvas.drawPath(path, innerTrackPaint);

    final centerLinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFE2E8F0).withValues(alpha: 0.48);
    canvas.drawPath(path, centerLinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PlaceholderInfoLine extends StatelessWidget {
  const _PlaceholderInfoLine({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF176EEB)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                color: Color(0xFF526684),
                fontWeight: FontWeight.w600,
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(
                    color: Color(0xFF1F2A44),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TraccarToolsPanel extends StatefulWidget {
  const _TraccarToolsPanel({
    super.key,
    required this.title,
    required this.entries,
  });

  final String title;
  final List<_PanelToolEntry> entries;

  @override
  State<_TraccarToolsPanel> createState() => _TraccarToolsPanelState();
}

class _TraccarToolsPanelState extends State<_TraccarToolsPanel> {
  int _selectedIndex = 0;

  @override
  void didUpdateWidget(covariant _TraccarToolsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedIndex >= widget.entries.length) {
      _selectedIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return _EmptyToolState(
        icon: Icons.inbox_outlined,
        title: 'Nenhum registro encontrado',
        detail: 'Atualize os filtros ou aguarde novos dados.',
        actionLabel: 'Atualizar tela',
        onAction: () => setState(() {}),
      );
    }
    final selected = widget.entries[_selectedIndex];

    return Column(
      children: [
        _GlassSurface(
          padding: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < widget.entries.length; i++) ...[
                  _ToolSelectorChip(
                    entry: widget.entries[i],
                    selected: i == _selectedIndex,
                    onTap: () => setState(() => _selectedIndex = i),
                  ),
                  if (i != widget.entries.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ColoredBox(
              color: Colors.white.withValues(alpha: 0.70),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: ClipRect(
                  child: SizedBox.expand(
                    child: selected.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToolSelectorChip extends StatelessWidget {
  const _ToolSelectorChip({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final _PanelToolEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF176EEB) : const Color(0xFF25344A);
    return Material(
      color: selected
          ? const Color(0xFF176EEB).withValues(alpha: 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 42, minWidth: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected
                  ? const Color(0xFF176EEB).withValues(alpha: 0.28)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(entry.icon, color: color, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    if (entry.detail != null)
                      Text(
                        entry.detail!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF71819B),
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationTypesPanel extends ConsumerWidget {
  const _NotificationTypesPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typesAsync = ref.watch(notificationTypesProvider);
    return typesAsync.when(
      data: (types) => ListView.separated(
        itemCount: types.isEmpty ? 1 : types.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (types.isEmpty) {
            return const _EmptyToolState(
              icon: Icons.notifications_none_outlined,
              title: 'Nenhum tipo retornado',
              detail:
                  'O servidor de rastreamento nao retornou tipos de notificacao agora.',
            );
          }
          final type = '${types[index]['type'] ?? 'notificacao'}';
          return _SimpleToolRow(
            icon: Icons.notifications_active_outlined,
            title: _humanizeEventType(type),
            detail: type,
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }
}

enum _ServerPanelState {
  online,
  noPermission,
  unavailable,
  error,
}

class _ServerPanelSnapshot {
  const _ServerPanelSnapshot({
    required this.state,
    required this.apiStatus,
    required this.lastReadAt,
    required this.environment,
    required this.userLabel,
    required this.timezone,
    required this.serviceVersion,
    required this.operationalConfig,
    required this.communicationLevel,
    required this.defaultCoordinates,
    this.message,
  });

  final _ServerPanelState state;
  final String apiStatus;
  final DateTime lastReadAt;
  final String environment;
  final String userLabel;
  final String timezone;
  final String serviceVersion;
  final String operationalConfig;
  final String communicationLevel;
  final String defaultCoordinates;
  final String? message;
}

final _serverPanelSnapshotProvider = FutureProvider<_ServerPanelSnapshot>((
  ref,
) async {
  final currentSession = ref.watch(sessionProvider);
  final now = DateTime.now();

  if (presentationMode || !currentSession.isAuthenticated) {
    return _ServerPanelSnapshot(
      state: _ServerPanelState.unavailable,
      apiStatus: 'Indisponivel',
      lastReadAt: now,
      environment: _resolveEnvironmentLabel(kTraccarBaseUrl),
      userLabel: 'Nao autenticado',
      timezone: 'Não informado',
      serviceVersion: 'Não informado',
      operationalConfig: 'Não informado',
      communicationLevel: 'Não informado',
      defaultCoordinates: 'Não informado',
      message: 'Faca login para consultar o status do servidor.',
    );
  }

  final client = ref.watch(traccarClientProvider);
  try {
    final sessionList = await client.getList(
      path: '/session',
      cookie: currentSession.cookie,
      authHeader: currentSession.authHeader,
    );
    final server = await client.getServer(
      cookie: currentSession.cookie,
      authHeader: currentSession.authHeader,
    );

    List<String> timezones = const <String>[];
    try {
      timezones = await client.getTimezones(
        cookie: currentSession.cookie,
        authHeader: currentSession.authHeader,
      );
    } catch (_) {
      // Timezone is complementary and should not block server status.
    }

    final sessionData =
        sessionList.isNotEmpty ? sessionList.first : <String, dynamic>{};
    final userName = _cleanText(sessionData['name'], fallback: 'Usuario atual');
    final userEmail = _cleanText(sessionData['email']);
    final userLabel = userEmail == '-' ? userName : '$userName <$userEmail>';

    return _ServerPanelSnapshot(
      state: _ServerPanelState.online,
      apiStatus: 'Operacional',
      lastReadAt: now,
      environment: _resolveEnvironmentLabel(kTraccarBaseUrl),
      userLabel: userLabel,
      timezone: _resolveTimezone(server, sessionData, timezones),
      serviceVersion: _cleanText(server['version']),
      operationalConfig: _resolveOperationalConfig(server),
      communicationLevel: _resolveCommunicationLevel(server),
      defaultCoordinates: _resolveCoordinates(server),
    );
  } catch (error) {
    final code = _extractHttpStatusCode(error);
    if (code == 401 || code == 403) {
      return _ServerPanelSnapshot(
        state: _ServerPanelState.noPermission,
        apiStatus: 'Sem permissao',
        lastReadAt: now,
        environment: _resolveEnvironmentLabel(kTraccarBaseUrl),
        userLabel: _cleanText(currentSession.email, fallback: 'Usuario atual'),
        timezone: 'Não informado',
        serviceVersion: 'Não informado',
        operationalConfig: 'Não informado',
        communicationLevel: 'Não informado',
        defaultCoordinates: 'Não informado',
        message:
            'Seu usuario nao tem permissao para consultar essas configurações.',
      );
    }
    if (code != null && code >= 500) {
      return _ServerPanelSnapshot(
        state: _ServerPanelState.unavailable,
        apiStatus: 'Indisponivel',
        lastReadAt: now,
        environment: _resolveEnvironmentLabel(kTraccarBaseUrl),
        userLabel: _cleanText(currentSession.email, fallback: 'Usuario atual'),
        timezone: 'Não informado',
        serviceVersion: 'Não informado',
        operationalConfig: 'Não informado',
        communicationLevel: 'Não informado',
        defaultCoordinates: 'Não informado',
        message:
            'Servico temporariamente indisponivel. Tente novamente em instantes.',
      );
    }

    return _ServerPanelSnapshot(
      state: _ServerPanelState.error,
      apiStatus: code == null ? 'Erro controlado' : 'Erro controlado ($code)',
      lastReadAt: now,
      environment: _resolveEnvironmentLabel(kTraccarBaseUrl),
      userLabel: _cleanText(currentSession.email, fallback: 'Usuario atual'),
      timezone: 'Não informado',
      serviceVersion: 'Não informado',
      operationalConfig: 'Não informado',
      communicationLevel: 'Não informado',
      defaultCoordinates: 'Não informado',
      message:
          'Nao foi possivel concluir a leitura agora. Verifique a sessao e tente atualizar.',
    );
  }
});

String _cleanText(dynamic value, {String fallback = '-'}) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? fallback : text;
}

int? _extractHttpStatusCode(Object error) {
  final raw = error.toString();
  final match =
      RegExp(r'(?:^|[^0-9])([1-5][0-9]{2})(?:[^0-9]|$)').firstMatch(raw);
  if (match == null) return null;
  return int.tryParse(match.group(1) ?? '');
}

String _resolveEnvironmentLabel(String baseUrl) {
  final uri = Uri.tryParse(baseUrl);
  if (uri == null || uri.host.trim().isEmpty) {
    return 'Nao identificado';
  }
  final host = uri.host.toLowerCase();
  final isPrivateIp = RegExp(
    r'^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[0-1])\.)',
  ).hasMatch(host);
  if (host == 'localhost' || host == '127.0.0.1' || isPrivateIp) {
    return 'Interno';
  }
  if (host.contains('homolog') ||
      host.contains('staging') ||
      host.contains('dev')) {
    return 'Homologacao';
  }
  return 'Producao';
}

String _resolveTimezone(
  Map<String, dynamic> server,
  Map<String, dynamic> sessionData,
  List<String> timezones,
) {
  final candidates = <dynamic>[
    sessionData['timezone'],
    server['timezone'],
    (sessionData['attributes'] is Map)
        ? (sessionData['attributes'] as Map)['timezone']
        : null,
  ];
  for (final value in candidates) {
    final text = _cleanText(value, fallback: '');
    if (text.isNotEmpty) {
      return text;
    }
  }

  if (timezones.contains('America/Sao_Paulo')) {
    return 'America/Sao_Paulo';
  }
  return 'Não informado';
}

String _resolveCommunicationLevel(Map<String, dynamic> server) {
  var level = 0;
  if (server['emailEnabled'] == true) level++;
  if (server['textEnabled'] == true) level++;
  if (server['geocoderEnabled'] == true) level++;

  if (level >= 3) return 'Alto';
  if (level == 2) return 'Médio';
  if (level == 1) return 'Basico';
  return 'Essencial';
}

String _resolveOperationalConfig(Map<String, dynamic> server) {
  final systemMode =
      server['readonly'] == true ? 'Sistema em leitura' : 'Sistema operacional';
  final deviceMode = server['deviceReadonly'] == true
      ? 'Dispositivos protegidos'
      : 'Dispositivos operacionais';
  final registration = server['registration'] == true
      ? 'Cadastro externo ativo'
      : 'Cadastro externo inativo';
  return '$systemMode | $deviceMode | $registration';
}

String _resolveCoordinates(Map<String, dynamic> server) {
  final lat = server['latitude'];
  final lon = server['longitude'];
  if (lat is num && lon is num) {
    return '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}';
  }
  return 'Não informado';
}

String _formatReadTime(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} '
      '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
}

String _serverStateLabel(_ServerPanelState state) {
  switch (state) {
    case _ServerPanelState.online:
      return 'Online';
    case _ServerPanelState.noPermission:
      return 'Sem permissao';
    case _ServerPanelState.unavailable:
      return 'Indisponivel';
    case _ServerPanelState.error:
      return 'Erro controlado';
  }
}

IconData _serverStateIcon(_ServerPanelState state) {
  switch (state) {
    case _ServerPanelState.online:
      return Icons.cloud_done_outlined;
    case _ServerPanelState.noPermission:
      return Icons.lock_outline;
    case _ServerPanelState.unavailable:
      return Icons.cloud_off_outlined;
    case _ServerPanelState.error:
      return Icons.error_outline;
  }
}

class _ServerStatusPanel extends ConsumerWidget {
  const _ServerStatusPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(_serverPanelSnapshotProvider);
    return statusAsync.when(
      data: (status) {
        return ListView(
          children: [
            _SimpleToolRow(
              icon: _serverStateIcon(status.state),
              title: 'Status do Servidor',
              detail: _serverStateLabel(status.state),
            ),
            const SizedBox(height: 8),
            _SimpleToolRow(
              icon: Icons.person_outline,
              title: 'Usuario atual',
              detail: status.userLabel,
            ),
            const SizedBox(height: 8),
            _SimpleToolRow(
              icon: Icons.public_outlined,
              title: 'Ambiente',
              detail: status.environment,
            ),
            const SizedBox(height: 8),
            _SimpleToolRow(
              icon: Icons.schedule_outlined,
              title: 'Timezone',
              detail: status.timezone,
            ),
            const SizedBox(height: 8),
            _SimpleToolRow(
              icon: Icons.verified_outlined,
              title: 'Versao do servico',
              detail: status.serviceVersion,
            ),
            const SizedBox(height: 8),
            _SimpleToolRow(
              icon: Icons.settings_suggest_outlined,
              title: 'Configurações operacionais',
              detail: status.operationalConfig,
            ),
            const SizedBox(height: 8),
            _SimpleToolRow(
              icon: Icons.wifi_tethering_outlined,
              title: 'Nivel de comunicação',
              detail: status.communicationLevel,
            ),
            const SizedBox(height: 8),
            _SimpleToolRow(
              icon: Icons.pin_drop_outlined,
              title: 'Coordenadas padrao',
              detail: status.defaultCoordinates,
            ),
            const SizedBox(height: 8),
            _SimpleToolRow(
              icon: Icons.network_check_outlined,
              title: 'Status da API',
              detail: status.apiStatus,
            ),
            const SizedBox(height: 8),
            _SimpleToolRow(
              icon: Icons.schedule_outlined,
              title: 'Ultima leitura',
              detail: _formatReadTime(status.lastReadAt),
            ),
            if ((status.message ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              _SimpleToolRow(
                icon: Icons.info_outline,
                title: 'Observacao',
                detail: status.message!,
              ),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => ListView(
        children: const [
          _SimpleToolRow(
            icon: Icons.error_outline,
            title: 'Status do Servidor',
            detail:
                'Erro controlado ao carregar os dados. Atualize o painel e tente novamente.',
          ),
        ],
      ),
    );
  }
}

class _SimpleToolRow extends StatelessWidget {
  const _SimpleToolRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF176EEB)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1F2A44),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: const TextStyle(
                    color: Color(0xFF60718D),
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

class _EmptyToolState extends StatelessWidget {
  const _EmptyToolState({
    required this.icon,
    required this.title,
    required this.detail,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _GlassSurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF176EEB), size: 36),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF1F2A44),
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF60718D),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(actionLabel!),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF176EEB),
                  side: const BorderSide(color: Color(0xFFB7D5FF)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FallbackOperationalPanel extends StatelessWidget {
  const _FallbackOperationalPanel({
    required this.title,
    required this.icon,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final List<String> rows;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _GlassSurface(
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF176EEB)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1F2A44),
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _GlassSurface(
              padding: const EdgeInsets.all(12),
              child: Text(
                row,
                style: const TextStyle(
                  color: Color(0xFF526684),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FallbackTenantConfigNotice extends StatelessWidget {
  const _FallbackTenantConfigNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: _GlassSurface(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF9A6700),
              size: 18,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF7A5C00),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge();

  @override
  Widget build(BuildContext context) {
    return const _GlassSurface(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text(
            'Sincronizando',
            style: TextStyle(
              color: Color(0xFF526684),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

enum _KpiFilter {
  online('Online', Icons.wifi_tethering_rounded, Color(0xFF10B981)),
  offline('Offline', Icons.wifi_off_rounded, Color(0xFF94A3B8)),
  moving('Em movimento', Icons.near_me_outlined, Color(0xFFF59E0B)),
  alerts('Alertas', Icons.warning_amber_rounded, Color(0xFFEF4444)),
  noCommunication('Sem comunicação', Icons.signal_wifi_off_rounded, Color(0xFF64748B));

  const _KpiFilter(this.title, this.icon, this.color);

  final String title;
  final IconData icon;
  final Color color;
}

class _FleetKpis {
  const _FleetKpis({
    required this.online,
    required this.offline,
    required this.moving,
    required this.alerts,
    required this.noCommunication,
  });

  final int online;
  final int offline;
  final int moving;
  final int alerts;
  final int noCommunication;

  _FleetKpis copyWith({
    int? online,
    int? offline,
    int? moving,
    int? alerts,
    int? noCommunication,
  }) {
    return _FleetKpis(
      online: online ?? this.online,
      offline: offline ?? this.offline,
      moving: moving ?? this.moving,
      alerts: alerts ?? this.alerts,
      noCommunication: noCommunication ?? this.noCommunication,
    );
  }

  factory _FleetKpis.fromSnapshots(List<_VehicleSnapshot> snapshots) {
    if (snapshots.isEmpty) {
      return const _FleetKpis(
        online: 0,
        offline: 0,
        moving: 0,
        alerts: 0,
        noCommunication: 0,
      );
    }

    var online = 0;
    var offline = 0;
    var moving = 0;
    var noCommunication = 0;

    for (final snapshot in snapshots) {
      if (snapshot.hasNoCommunication) {
        noCommunication++;
      }

      if (snapshot.isOperationalOnline) {
        online++;
      } else {
        // Status offline/unknown ou atualização antiga entram no offline operacional.
        offline++;
      }

      if (snapshot.isOperationalMoving) {
        moving++;
      }
    }

    if (online == 0 && offline == 0 && moving == 0) {
      offline = snapshots.length;
    }

    return _FleetKpis(
      online: online,
      offline: offline,
      moving: moving,
      alerts: snapshots.where((it) => it.hasAlert).length,
      noCommunication: noCommunication,
    );
  }

  int valueFor(_KpiFilter filter) {
    switch (filter) {
      case _KpiFilter.online:
        return online;
      case _KpiFilter.offline:
        return offline;
      case _KpiFilter.moving:
        return moving;
      case _KpiFilter.alerts:
        return alerts;
      case _KpiFilter.noCommunication:
        return noCommunication;
    }
  }
}

enum _VehicleOperationalStatus {
  online,
  moving,
  alert,
  offline,
  noCommunication,
}

enum _VehicleMarkerType {
  animal('animal.png'),
  car('car.png'),
  motorcycle('motorcycle.png'),
  truck('truck.png'),
  bus('bus.png'),
  camper('camper.png'),
  person('person.png'),
  generic('default.png'),
  pickup('pickup.png'),
  van('van.png'),
  tractor('tractor.png'),
  crane('crane.png'),
  helicopter('helicopter.png'),
  offroad('offroad.png'),
  bicycle('bicycle.png'),
  boat('boat.png'),
  plane('plane.png'),
  ship('ship.png'),
  scooter('scooter.png'),
  train('train.png'),
  tram('tram.png'),
  trolleybus('trolleybus.png');

  const _VehicleMarkerType(this.fileName);

  final String fileName;
  String get assetPath => 'assets/icons/map/$fileName';

  static _VehicleMarkerType? fromStoredKey(String? raw) {
    final value = raw?.trim().toLowerCase() ?? '';
    if (value.isEmpty) return null;
    switch (value) {
      case 'animal':
        return _VehicleMarkerType.animal;
      case 'car':
        return _VehicleMarkerType.car;
      case 'motorcycle':
        return _VehicleMarkerType.motorcycle;
      case 'truck':
        return _VehicleMarkerType.truck;
      case 'bus':
        return _VehicleMarkerType.bus;
      case 'camper':
        return _VehicleMarkerType.camper;
      case 'person':
        return _VehicleMarkerType.person;
      case 'pickup':
        return _VehicleMarkerType.pickup;
      case 'van':
        return _VehicleMarkerType.van;
      case 'tractor':
        return _VehicleMarkerType.tractor;
      case 'crane':
        return _VehicleMarkerType.crane;
      case 'helicopter':
        return _VehicleMarkerType.helicopter;
      case 'offroad':
        return _VehicleMarkerType.offroad;
      case 'bicycle':
        return _VehicleMarkerType.bicycle;
      case 'boat':
        return _VehicleMarkerType.boat;
      case 'plane':
        return _VehicleMarkerType.plane;
      case 'ship':
        return _VehicleMarkerType.ship;
      case 'scooter':
        return _VehicleMarkerType.scooter;
      case 'train':
        return _VehicleMarkerType.train;
      case 'tram':
        return _VehicleMarkerType.tram;
      case 'trolleybus':
        return _VehicleMarkerType.trolleybus;
      case 'default':
      case 'generic':
        return _VehicleMarkerType.generic;
      default:
        return _VehicleMarkerType.generic;
    }
  }
}

class _VehicleMarkerIconKey {
  const _VehicleMarkerIconKey(this.type, this.status, [this.bearing8 = 0]);

  final _VehicleMarkerType type;
  final _VehicleOperationalStatus status;
  // 0-7: N, NE, E, SE, S, SW, W, NW (buckets de 45°)
  final int bearing8;

  @override
  bool operator ==(Object other) {
    return other is _VehicleMarkerIconKey &&
        other.type == type &&
        other.status == status &&
        other.bearing8 == bearing8;
  }

  @override
  int get hashCode => Object.hash(type, status, bearing8);
}

class TireReading {
  const TireReading({
    required this.index,
    required this.rawId,
    required this.batteryVolts,
    required this.temperatureC,
    required this.pressureRaw,
  });

  final int index;
  final String rawId;
  final double? batteryVolts;
  final int? temperatureC;
  final int? pressureRaw;

  bool get isLowBattery => batteryVolts != null && batteryVolts! < 2.8;
}

class _VehicleSnapshot {
  static const Duration _offlineStaleThreshold = Duration(minutes: 30);
  static const List<String> _defaultSensorKeys = [
    'ignition',
    'motion',
    'door',
    'blocked',
    'gpsTracking',
    'power',
    'batteryLevel',
    'battery',
    'charge',
    'gsm',
    'rssi',
    'sat',
    'mcc',
    'mnc',
    'lac',
    'cid',
    'odometer',
    'totalHours',
  ];

  const _VehicleSnapshot({
    required this.device,
    required this.position,
    required this.index,
    this.resolvedAddress,
    this.recentEvents = const [],
    this.tireAttributes = const {},
  });

  final TraccarDevice device;
  final TraccarPosition? position;
  final int index;
  final String? resolvedAddress;
  final List<Map<String, dynamic>> recentEvents;
  final Map<String, dynamic> tireAttributes;

  _VehicleSnapshot copyWith({
    String? resolvedAddress,
    List<Map<String, dynamic>>? recentEvents,
  }) {
    return _VehicleSnapshot(
      device: device,
      position: position,
      index: index,
      resolvedAddress: resolvedAddress ?? this.resolvedAddress,
      recentEvents: recentEvents ?? this.recentEvents,
      tireAttributes: tireAttributes,
    );
  }

  // IDs vêm crus do sensor (ex: "11", "21", "14", "24" — eixo+posição, não
  // documentado pelo fabricante ainda). Por enquanto só numeramos 1..N na
  // ordem crescente do ID pra dar uma posição visual estável no desenho.
  List<TireReading> get tireReadings {
    final ids = <String>{
      for (final key in tireAttributes.keys)
        if (key.startsWith('tire') && key.length >= 6) key.substring(4, 6),
    }.toList()
      ..sort();
    return [
      for (var i = 0; i < ids.length; i++)
        TireReading(
          index: i + 1,
          rawId: ids[i],
          batteryVolts: (tireAttributes['tire${ids[i]}Battery'] as num?)
              ?.toDouble(),
          temperatureC: (tireAttributes['tire${ids[i]}Temp'] as num?)
              ?.toInt(),
          pressureRaw: (tireAttributes['tire${ids[i]}Pressure'] as num?)
              ?.toInt(),
        ),
    ];
  }

  gmaps.LatLng? get latLngOrNull {
    final current = position;
    if (current == null) return null;
    if (!hasValidGps) return null;
    return gmaps.LatLng(current.latitude, current.longitude);
  }

  gmaps.LatLng get latLng {
    return latLngOrNull ?? const gmaps.LatLng(-23.55052, -46.633308);
  }

  String get normalizedStatus => device.status.toLowerCase().trim();

  bool get hasPosition => position != null;
  Map<String, dynamic> get _mergedAttributes => {
        ...?device.attributes,
        ...?position?.attributes,
      };

  bool get hasValidGps {
    final lat = position?.latitude;
    final lng = position?.longitude;
    if (lat == null || lng == null) return false;
    if (lat == 0 || lng == 0) return false;
    return hasValidGpsPosition(
      latitude: lat,
      longitude: lng,
      attributes: _mergedAttributes,
    );
  }

  bool get hasGpsInvalidPacket => hasPosition && !hasValidGps;

  bool get isStatusUnknownOrUninformed {
    if (normalizedStatus.isEmpty) return true;
    return normalizedStatus == 'unknown' ||
        normalizedStatus == 'nao informado' ||
        normalizedStatus == 'não informado' ||
        normalizedStatus == 'n/a';
  }

  DateTime? get lastCommunicationAt {
    final source = device.lastUpdate ?? position?.fixTime;
    if (source == null || source.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(source);
    if (parsed == null) return null;
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  bool get hasStaleLastUpdate {
    final timestamp = lastCommunicationAt;
    if (timestamp == null) return true;
    return DateTime.now().difference(timestamp) > _offlineStaleThreshold;
  }

  bool get hasRecentCommunication {
    final timestamp = lastCommunicationAt;
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) <= const Duration(minutes: 5);
  }

  bool get hasNoCommunication =>
      !hasValidGps || hasStaleLastUpdate || isStatusUnknownOrUninformed;

  bool get isOperationalOnline =>
      normalizedStatus == 'online' && !hasNoCommunication;

  bool get isOperationalOffline =>
      normalizedStatus == 'offline' && !hasNoCommunication;

  bool get isOperationalMoving =>
      hasPosition && !hasNoCommunication && (speedKmh ?? 0) > 1;

  bool get isOperationalStopped => hasPosition && !isOperationalMoving;

  bool get isOnline => isOperationalOnline;

  bool get isOffline => isOperationalOffline;

  double? get speedKnots {
    final value = position?.speed;
    if (value == null) return null;
    if (!value.isFinite) return null;
    return value;
  }

  double? get speedKmh {
    final value = speedKnots;
    if (value == null) return null;
    return value * 1.852;
  }

  double? get speed => speedKmh;

  bool get isMoving => (speedKmh ?? 0) > 1;

  bool? get ignition {
    final value = position?.attributes?['ignition'] ??
        device.attributes?['ignition'] ??
        device.attributes?['ignitionOn'];
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value > 0;
    if (value is String) {
      final normalized = value.toLowerCase().trim();
      return normalized == 'true' ||
              normalized == 'on' ||
              normalized == 'ligada' ||
              normalized == '1'
          ? true
          : (normalized == 'false' ||
                  normalized == 'off' ||
                  normalized == 'desligada' ||
                  normalized == '0')
              ? false
              : null;
    }
    return null;
  }

  // Alerta é só o que o usuário decide que é — não um número fixo no código.
  // Por isso só contam aqui os alarmes realmente graves/acionáveis (pânico,
  // SOS, jammer, colisão/choque, corte de energia, excesso de velocidade
  // reportado pelo próprio Traccar). Estados técnicos/informativos (ex:
  // "gpsAntennaCut" — só significa "sem satélite agora", não é emergência)
  // são ignorados aqui de propósito, pra não poluir o painel com ruído.
  static const _seriousAlarmKeywords = [
    'sos',
    'panic',
    'jamming',
    'jammer',
    'shock',
    'vibration',
    'accident',
    'overspeed',
    'powercut',
    'powerdisconnect',
    'tow',
    'removing',
  ];

  bool get _hasAlarmFlag {
    final raw = _mergedAttributes['alarm'] ?? _mergedAttributes['alarmType'];
    if (raw == null) return false;
    final text = raw.toString().trim().toLowerCase();
    if (text.isEmpty) return false;
    return _seriousAlarmKeywords.any(text.contains);
  }

  bool get hasAlert => !hasNoCommunication && _hasAlarmFlag;

  bool get isDriver =>
      (device.uniqueId ?? '').toLowerCase().startsWith('driver_');

  int get driverStatus {
    final raw = _mergedAttributes['status'];
    if (raw == null) return 1;
    if (raw is int) return raw;
    return int.tryParse(raw.toString()) ?? 1;
  }

  String get driverStatusLabel {
    switch (driverStatus) {
      case 0:
        return 'Offline';
      case 2:
        return 'A caminho';
      case 3:
        return 'Em Atendimento';
      default:
        return 'Disponível';
    }
  }

  Color get driverStatusColor {
    switch (driverStatus) {
      case 0:
        return const Color(0xFF9CA3AF);
      case 2:
        return const Color(0xFFF59E0B);
      case 3:
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF22C55E);
    }
  }

  String get identifierLabel {
    final value = device.uniqueId ??
        device.attributes?['plate'] ??
        device.attributes?['plateNumber'] ??
        device.attributes?['licensePlate'] ??
        device.attributes?['registration'] ??
        device.attributes?['identifier'];
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'Não informado' : text;
  }

  _VehicleOperationalStatus get operationalStatus {
    if (hasNoCommunication) return _VehicleOperationalStatus.noCommunication;
    if (hasAlert) return _VehicleOperationalStatus.alert;
    if (isOperationalMoving) return _VehicleOperationalStatus.moving;
    if (isOperationalOnline) return _VehicleOperationalStatus.online;
    return _VehicleOperationalStatus.offline;
  }

  String get connectionStatusLabel => statusLabel;

  String get statusLabel {
    switch (operationalStatus) {
      case _VehicleOperationalStatus.online:
        return 'Online';
      case _VehicleOperationalStatus.moving:
        return 'Em movimento';
      case _VehicleOperationalStatus.alert:
        return 'Alerta';
      case _VehicleOperationalStatus.offline:
        return 'Offline';
      case _VehicleOperationalStatus.noCommunication:
        return 'Sem comunica\u00E7\u00E3o';
    }
  }

  String get operationalPanelStatusLabel {
    if (hasGpsInvalidPacket) return 'GPS inválido';
    if (lastCommunicationAt == null) return 'Sem comunicação';
    if (hasStaleLastUpdate) return 'Desatualizado';
    if (hasRecentCommunication && !isMoving) return 'Standby';
    if (hasRecentCommunication && hasValidGps) return 'Tempo real';
    return 'Sem comunicação';
  }

  Color get operationalPanelStatusColor {
    switch (operationalPanelStatusLabel) {
      case 'Tempo real':
        return const Color(0xFF16A34A);
      case 'Standby':
        return const Color(0xFF2563EB);
      case 'Desatualizado':
        return const Color(0xFFF59E0B);
      case 'GPS inválido':
        return const Color(0xFFEF4444);
      case 'Sem comunicação':
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  IconData get operationalPanelStatusIcon {
    switch (operationalPanelStatusLabel) {
      case 'Tempo real':
        return Icons.radio_button_checked_rounded;
      case 'Standby':
        return Icons.pause_circle_filled_rounded;
      case 'Desatualizado':
        return Icons.schedule_rounded;
      case 'GPS inválido':
        return Icons.gps_off_rounded;
      case 'Sem comunicação':
      default:
        return Icons.signal_wifi_off_rounded;
    }
  }

  Color get statusColor {
    switch (operationalStatus) {
      case _VehicleOperationalStatus.online:
        return const Color(0xFF22C55E);
      case _VehicleOperationalStatus.moving:
        return const Color(0xFF22C55E);
      case _VehicleOperationalStatus.alert:
        return const Color(0xFFEF4444);
      case _VehicleOperationalStatus.offline:
        return const Color(0xFF9CA3AF);
      case _VehicleOperationalStatus.noCommunication:
        return const Color(0xFFF59E0B);
    }
  }

  IconData get statusIcon {
    switch (operationalStatus) {
      case _VehicleOperationalStatus.online:
        return Icons.check_circle_rounded;
      case _VehicleOperationalStatus.moving:
        return Icons.directions_car_filled_rounded;
      case _VehicleOperationalStatus.alert:
        return Icons.warning_rounded;
      case _VehicleOperationalStatus.offline:
        return Icons.remove_circle_rounded;
      case _VehicleOperationalStatus.noCommunication:
        return Icons.signal_cellular_connected_no_internet_4_bar_rounded;
    }
  }

  double get markerHue {
    switch (operationalStatus) {
      case _VehicleOperationalStatus.online:
        return gmaps.BitmapDescriptor.hueGreen;
      case _VehicleOperationalStatus.moving:
        return gmaps.BitmapDescriptor.hueGreen;
      case _VehicleOperationalStatus.alert:
        return gmaps.BitmapDescriptor.hueRed;
      case _VehicleOperationalStatus.offline:
        return gmaps.BitmapDescriptor.hueBlue;
      case _VehicleOperationalStatus.noCommunication:
        return gmaps.BitmapDescriptor.hueOrange;
    }
  }

  _VehicleMarkerType get markerType {
    final storedIcon = device.attributes?['souMapIcon']?.toString();
    final hasStoredIcon = storedIcon != null && storedIcon.trim().isNotEmpty;
    if (hasStoredIcon) {
      return _VehicleMarkerType.fromStoredKey(storedIcon) ??
          _VehicleMarkerType.generic;
    }

    final raw = [
      device.category,
      device.attributes?['category'],
      device.attributes?['type'],
      device.attributes?['vehicleType'],
      device.attributes?['model'],
      device.attributes?['vehicleModel'],
      device.name,
    ].whereType<Object>().join(' ').toLowerCase();

    if (raw.contains('scooter')) return _VehicleMarkerType.scooter;
    if (raw.contains('moto') || raw.contains('motorcycle')) {
      return _VehicleMarkerType.motorcycle;
    }
    if (raw.contains('caminh') || raw.contains('truck')) {
      return _VehicleMarkerType.truck;
    }
    if (raw.contains('onibus') ||
        raw.contains('\u00F4nibus') ||
        raw.contains('bus')) {
      return _VehicleMarkerType.bus;
    }
    if (raw.contains('pickup') || raw.contains('pick-up')) {
      return _VehicleMarkerType.pickup;
    }
    if (raw.contains('van')) return _VehicleMarkerType.van;
    if (raw.contains('pessoa') ||
        raw.contains('person') ||
        raw.contains('motorista')) {
      return _VehicleMarkerType.person;
    }
    if (raw.contains('bike') || raw.contains('bicic')) {
      return _VehicleMarkerType.bicycle;
    }
    if (raw.contains('barco') || raw.contains('boat')) {
      return _VehicleMarkerType.boat;
    }
    if (raw.contains('navio') || raw.contains('ship')) {
      return _VehicleMarkerType.ship;
    }
    if (raw.contains('guindaste') || raw.contains('crane')) {
      return _VehicleMarkerType.crane;
    }
    if (raw.contains('trator') ||
        raw.contains('tractor') ||
        raw.contains('maquina') ||
        raw.contains('m\u00E1quina')) {
      return _VehicleMarkerType.tractor;
    }
    if (raw.contains('offroad') ||
        raw.contains('4x4') ||
        raw.contains('fora de estrada')) {
      return _VehicleMarkerType.offroad;
    }
    if (raw.contains('carro') ||
        raw.contains('car') ||
        raw.contains('auto') ||
        raw.contains('veiculo') ||
        raw.contains('ve\u00EDculo')) {
      return _VehicleMarkerType.car;
    }
    return _VehicleMarkerType.generic;
  }

  _VehicleMarkerIconKey get markerIconKey {
    return _VehicleMarkerIconKey(markerType, operationalStatus);
  }

  double? get markerRotation {
    return _normalizeDirection(
      position?.course ??
          _mergedAttributes['course'] ??
          _mergedAttributes['heading'] ??
          _mergedAttributes['bearing'],
    );
  }

  static double? _normalizeDirection(Object? raw) {
    if (raw == null) return null;
    double? value;
    if (raw is num) {
      value = raw.toDouble();
    } else if (raw is String) {
      final normalized = raw.trim().replaceAll(',', '.');
      if (normalized.isEmpty) return null;
      value = double.tryParse(normalized);
    }
    if (value == null || !value.isFinite) return null;
    var angle = value % 360;
    if (angle < 0) angle += 360;
    return angle.toDouble();
  }

  double get mapBearing => (index * 34) % 360;

  String get speedLabel {
    final current = speed;
    if (current == null) return 'Não informado';
    return '${current.toStringAsFixed(0)} km/h';
  }

  String get latLngLabel {
    if (!hasValidGps) return 'Não informado';
    return formatGpsCoordinateLabel(
      latitude: position?.latitude,
      longitude: position?.longitude,
      attributes: _mergedAttributes,
    );
  }

  String get locationSummaryLabel {
    if (hasGpsInvalidPacket) return 'GPS inválido no último pacote';
    if (hasValidGps && address != 'Não informado') return address;
    if (hasValidGps) return latLngLabel;
    return 'Não informado';
  }

  String get lastCommunicationLabel {
    final parsed = lastCommunicationAt;
    if (parsed == null) return 'Não informado';
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final year = parsed.year.toString().padLeft(4, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  String get ignitionLabel {
    final value = ignition;
    if (value == null) return 'Não informado';
    return value ? 'Ligada' : 'Desligada';
  }

  String get batteryLabel {
    final value = position?.attributes?['battery'] ??
        position?.attributes?['power'] ??
        device.attributes?['battery'] ??
        device.attributes?['power'];
    if (value is num) {
      return value > 30
          ? '${value.toStringAsFixed(0)}%'
          : '${value.toStringAsFixed(1)} V';
    }
    final text = value?.toString().trim();
    return text?.isNotEmpty == true ? text! : 'Não informado';
  }

  String get gsmSignalLabel {
    final rssi = _pixelRssiFromRow(this);
    if (rssi != null) {
      final dBm = rssi > 0 ? -rssi : rssi;
      return '${dBm.toStringAsFixed(0)} dBm';
    }
    final gsm = _pixelGsmFromRow(this);
    if (gsm != null) return '${gsm.toStringAsFixed(0)}%';
    return 'Não informado';
  }

  String get driverName {
    final value = device.attributes?['driver'] ??
        device.attributes?['driverName'] ??
        device.attributes?['motorista'];
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'Não informado' : text;
  }

  String get modelLabel {
    final value = device.attributes?['model'] ??
        device.attributes?['vehicleModel'] ??
        device.category;
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'Não informado' : text;
  }

  String get address {
    if (!hasValidGps) return 'Não informado';

    final value = resolvedAddress ??
        position?.address ??
        position?.attributes?['address'] ??
        device.attributes?['address'] ??
        device.attributes?['lastAddress'];
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
    return 'Não informado';
  }

  String get eventsSummary {
    if (recentEvents.isEmpty) {
      return 'Não informado';
    }

    return recentEvents.take(3).map((event) {
      final rawTime = '${event['eventTime'] ?? event['serverTime'] ?? ''}';
      final parsed = DateTime.tryParse(rawTime);
      final time = parsed == null
          ? '--:--'
          : '${parsed.toLocal().hour.toString().padLeft(2, '0')}:'
              '${parsed.toLocal().minute.toString().padLeft(2, '0')}';
      final type = '${event['type'] ?? 'evento'}';
      return '$time ${_humanizeEventType(type)}';
    }).join('\n');
  }

  String get latestEventLabel {
    if (recentEvents.isEmpty) return 'Não informado';
    final type = '${recentEvents.first['type'] ?? 'evento'}';
    return _humanizeEventType(type);
  }

  List<String> get recentAlertLabels {
    final items = <String>[];
    for (final event in recentEvents) {
      final type = '${event['type'] ?? ''}'.trim();
      final normalized = type.toLowerCase();
      if (normalized.contains('alarm') ||
          normalized.contains('overspeed') ||
          normalized.contains('panic') ||
          normalized.contains('sos') ||
          normalized.contains('geofence') ||
          normalized.contains('ignition') ||
          normalized.contains('offline')) {
        items.add(_humanizeEventType(type));
      }
      if (items.length == 3) break;
    }
    return items;
  }

  String get directionLabel {
    final bearing = markerRotation;
    if (bearing == null) return 'Não informado';
    return _bearingToCardinalLabel(bearing);
  }

  String get relativeLastPoint {
    final parsed = lastCommunicationAt;
    if (parsed == null) return 'Não informado';
    final diff = DateTime.now().difference(parsed);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'h\u00E1 ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'h\u00E1 ${diff.inHours} h';
    return 'h\u00E1 ${diff.inDays} dias';
  }

  String get sensorSummary {
    final rows = sensorRows;
    if (rows.isEmpty) return 'Não informado';
    return rows.map((row) => '${row.label}: ${row.value}').join('\n');
  }

  List<SensorDisplaySection> sensorSections({required bool includeTechnical}) {
    return buildSensorDisplaySections(
      deviceAttributes: device.attributes,
      positionAttributes: position?.attributes,
      includeTechnical: includeTechnical,
      preferredKeys: _configuredSensorKeys,
    );
  }

  List<_VehicleSensorRow> get sensorRows {
    final rows = <_VehicleSensorRow>[];
    final sections = sensorSections(includeTechnical: false);
    for (final section in sections) {
      for (final item in section.items) {
        rows.add(
          _VehicleSensorRow(
            key: item.key,
            label: item.label,
            value: item.value,
            icon: item.icon,
          ),
        );
      }
    }
    return rows;
  }

  List<String> get _configuredSensorKeys {
    final raw = device.attributes?['souSensors'];
    final configured = <String>{};

    if (raw is List) {
      for (final item in raw) {
        final key = '${item ?? ''}'.trim().toLowerCase();
        if (key.isNotEmpty) {
          configured.add(key);
        }
      }
    } else if (raw is String) {
      for (final part in raw.split(',')) {
        final key = part.trim().toLowerCase();
        if (key.isNotEmpty) {
          configured.add(key);
        }
      }
    }

    if (configured.isEmpty) {
      return _defaultSensorKeys;
    }
    return configured.toList(growable: false);
  }
}

class _VehicleSensorRow {
  const _VehicleSensorRow({
    required this.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String key;
  final String label;
  final String value;
  final IconData icon;
}

IconData _vehicleIconForSnapshot(_VehicleSnapshot snapshot) {
  final raw = [
    snapshot.device.category,
    snapshot.device.attributes?['category'],
    snapshot.device.attributes?['type'],
    snapshot.device.attributes?['model'],
    snapshot.device.name,
  ].whereType<Object>().join(' ').toLowerCase();

  if (raw.contains('bike') || raw.contains('bicic')) {
    return Icons.pedal_bike_rounded;
  }
  if (raw.contains('phone') || raw.contains('cel') || raw.contains('smart')) {
    return Icons.smartphone_rounded;
  }
  if (raw.contains('retro') ||
      raw.contains('escav') ||
      raw.contains('maquina')) {
    return Icons.construction_rounded;
  }
  if (raw.contains('boat') || raw.contains('barco') || raw.contains('embarc')) {
    return Icons.directions_boat_filled_rounded;
  }
  return Icons.local_shipping_rounded;
}

String _bearingToCardinalLabel(double bearing) {
  const directions = [
    'Norte',
    'Nordeste',
    'Leste',
    'Sudeste',
    'Sul',
    'Sudoeste',
    'Oeste',
    'Noroeste',
  ];
  final normalized = ((bearing % 360) + 360) % 360;
  final index = ((normalized + 22.5) / 45).floor() % 8;
  return directions[index];
}

class _OperationalMenuItem {
  const _OperationalMenuItem({
    required this.id,
    required this.label,
    required this.icon,
    this.badge,
    this.color,
  });

  final String id;
  final String label;
  final IconData icon;
  final String? badge;
  final Color? color;

  _OperationalMenuItem copyWith({
    String? id,
    String? label,
    IconData? icon,
    String? badge,
  }) {
    return _OperationalMenuItem(
      id: id ?? this.id,
      label: label ?? this.label,
      icon: icon ?? this.icon,
      badge: badge,
      color: color,
    );
  }
}

const List<_OperationalMenuItem> _operationalMenu = [
  _OperationalMenuItem(
    id: 'dashboard',
    label: 'Dashboard',
    icon: Icons.space_dashboard_outlined,
    color: Color(0xFF3B82F6),
  ),
  _OperationalMenuItem(
    id: 'map',
    label: 'Mapa',
    icon: Icons.map_outlined,
    color: Color(0xFF10B981),
  ),
  _OperationalMenuItem(
    id: 'vehicles',
    label: 'Ve\u00EDculos',
    icon: Icons.directions_car_outlined,
    color: Color(0xFFF59E0B),
  ),
  _OperationalMenuItem(
    id: 'devices',
    label: 'Equipamentos',
    icon: Icons.gps_fixed_outlined,
    color: Color(0xFF8B5CF6),
  ),
  _OperationalMenuItem(
    id: 'alerts',
    label: 'Alertas',
    icon: Icons.warning_amber_outlined,
    color: Color(0xFFEF4444),
  ),
  _OperationalMenuItem(
    id: 'geofences',
    label: 'Cercas',
    icon: Icons.fence_outlined,
    color: Color(0xFF14B8A6),
  ),
  _OperationalMenuItem(
    id: 'maintenance',
    label: 'Manuten\u00E7\u00E3o',
    icon: Icons.build_outlined,
    color: Color(0xFFD97706),
  ),
  _OperationalMenuItem(
    id: 'reports',
    label: 'Relat\u00F3rios',
    icon: Icons.insert_chart_outlined,
    color: Color(0xFF6366F1),
  ),
  _OperationalMenuItem(
    id: 'commands',
    label: 'Comandos',
    icon: Icons.terminal_outlined,
    color: Color(0xFF64748B),
  ),
  _OperationalMenuItem(
    id: 'communication',
    label: 'Comunica\u00E7\u00E3o',
    icon: Icons.chat_bubble_outline,
    color: Color(0xFF06B6D4),
  ),
  _OperationalMenuItem(
    id: 'tickets',
    label: 'Chamados',
    icon: Icons.support_agent_outlined,
    color: Color(0xFFF43F5E),
  ),
  _OperationalMenuItem(
    id: 'ai-operations',
    label: 'IA Operacional',
    icon: Icons.auto_awesome_outlined,
    color: Color(0xFF7C3AED),
  ),
  _OperationalMenuItem(
    id: 'finance',
    label: 'Financeiro',
    icon: Icons.account_balance_wallet_outlined,
    color: Color(0xFF059669),
  ),
  _OperationalMenuItem(
    id: 'inventory',
    label: 'Estoque',
    icon: Icons.inventory_2_outlined,
    color: Color(0xFFCA8A04),
  ),
  _OperationalMenuItem(
    id: 'mdvr',
    label: 'MDVR / C\u00E2meras',
    icon: Icons.videocam_outlined,
    color: Color(0xFFDC2626),
  ),
  _OperationalMenuItem(
    id: 'telemetry',
    label: 'Telemetria',
    icon: Icons.sensors_outlined,
    color: Color(0xFF2563EB),
  ),
  _OperationalMenuItem(
    id: 'tpms',
    label: 'TPMS',
    icon: Icons.tire_repair_outlined,
    color: Color(0xFF0EA5E9),
  ),
  _OperationalMenuItem(
    id: 'logs',
    label: 'Data Log',
    icon: Icons.article_outlined,
    color: Color(0xFF6B7280),
  ),
  _OperationalMenuItem(
    id: 'automations',
    label: 'Automa\u00E7\u00F5es',
    icon: Icons.auto_fix_high_outlined,
    color: Color(0xFFEC4899),
  ),
  _OperationalMenuItem(
    id: 'settings',
    label: 'Configura\u00E7\u00F5es',
    icon: Icons.settings_outlined,
    color: Color(0xFF9CA3AF),
  ),
];
