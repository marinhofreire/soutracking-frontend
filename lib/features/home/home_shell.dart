import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../core/app_constants.dart';
import '../../core/white_label.dart';
import '../../data/bridge_client.dart';
import '../../data/models.dart';
import '../../data/openf1_client.dart';
import '../../state/session_state.dart';
import '../../widgets/status_pill.dart';
import '../alerts/alerts_screen.dart';
import '../attributes/attributes_screen.dart';
import '../business/business_reference_screens.dart';
import '../calendars/calendars_screen.dart';
import '../calls/calls_screen.dart';
import '../communication/zpro_communication_screen.dart';
import '../common/placeholder_screen.dart';
import '../common/report_screen.dart';
import '../clients/clients_screen.dart';
import '../commands/commands_screen.dart';
import '../devices/devices_screen.dart';
import '../drivers/drivers_screen.dart';
import '../finance/finance_screen.dart';
import '../geofences/geofences_screen.dart';
import '../groups/groups_screen.dart';
import '../history/history_screen.dart';
import '../inventory/inventory_screen.dart';
import '../login/login_screen.dart';
import '../maintenance/maintenance_screen.dart';
import '../map/map_screen.dart';
import '../notifications/notifications_screen.dart';
import '../permissions/permissions_screen.dart';
import '../reports/reports_screen.dart';
import '../routes/routes_screen.dart';
import '../settings/settings_screen.dart';
import '../statistics/statistics_screen.dart';
import '../telemetry/sensor_presentation.dart';
import '../telemetry/telemetry_sensors_screen.dart';
import '../users/users_screen.dart';
import '../vehicles/vehicles_screen.dart';
import 'visual_settings_controller.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  gmaps.GoogleMapController? _googleMapController;

  final bool _showHighlightsRail = false;

  bool _menuOpen = false;
  bool _kpiListOpen = false;
  _KpiFilter _activeKpiFilter = _KpiFilter.online;
  _VehicleBottomTab _activeBottomTab = _VehicleBottomTab.overview;
  TraccarDevice? _previewVehicle;
  TraccarDevice? _selectedVehicle;
  String? _activePanelId;
  String? _activePanelTitle;
  bool _copilotPanelOpen = false;
  _VisualDiagnosis? _lastVisualDiagnosis;
  double _currentZoom = 13.0;
  DateTime _blockSurfaceClearUntil = DateTime.fromMillisecondsSinceEpoch(0);

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
        'preservar navegação existente.';

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
      _menuOpen = false;
      _kpiListOpen = false;
      _previewVehicle = null;
      _selectedVehicle = null;
      _activePanelId = null;
      _activePanelTitle = null;
    });
  }

  void _toggleMenu() {
    setState(() {
      _menuOpen = !_menuOpen;
      _kpiListOpen = false;
      _previewVehicle = null;
      _selectedVehicle = null;
      _activePanelId = null;
      _activePanelTitle = null;
    });
  }

  void _openKpi(_KpiFilter filter) {
    setState(() {
      _activeKpiFilter = filter;
      _kpiListOpen = true;
      _menuOpen = false;
      _previewVehicle = null;
      _selectedVehicle = null;
      _activePanelId = null;
      _activePanelTitle = null;
    });
  }

  void _openPanel(_OperationalMenuItem item) {
    if (item.id == 'map') {
      _blockSurfaceClearUntil = DateTime.now().add(
        const Duration(milliseconds: 700),
      );
      setState(() {
        _activePanelId = null;
        _activePanelTitle = null;
        _menuOpen = true;
        _kpiListOpen = false;
        _previewVehicle = null;
        _selectedVehicle = null;
      });
      return;
    }

    _blockSurfaceClearUntil = DateTime.now().add(
      const Duration(milliseconds: 700),
    );
    setState(() {
      _activePanelId = item.id;
      _activePanelTitle = item.label;
      _menuOpen = true;
      _kpiListOpen = false;
      _previewVehicle = null;
      _selectedVehicle = null;
    });
  }

  void _previewVehicleOnMap(_VehicleSnapshot snapshot) {
    setState(() {
      _previewVehicle = snapshot.device;
      _selectedVehicle = null;
      _menuOpen = false;
      _kpiListOpen = false;
      _activePanelId = null;
      _activePanelTitle = null;
    });
    _focusVehicle(snapshot);
  }

  void _openVehicleDetails(
    _VehicleSnapshot snapshot, {
    _VehicleBottomTab initialTab = _VehicleBottomTab.overview,
  }) {
    // Prevent accidental map tap propagation from clearing the opened panel.
    _blockSurfaceClearUntil = DateTime.now().add(
      const Duration(milliseconds: 700),
    );
    setState(() {
      _selectedVehicle = snapshot.device;
      _previewVehicle = null;
      _activeBottomTab = initialTab;
      _menuOpen = false;
      _kpiListOpen = false;
      _activePanelId = null;
      _activePanelTitle = null;
    });
    _focusVehicle(snapshot);
  }

  void _openVehicleAlerts(_VehicleSnapshot snapshot) {
    _openVehicleDetails(snapshot, initialTab: _VehicleBottomTab.overview);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Eventos recentes do veiculo carregados.')),
    );
  }

  Future<void> _shareVehicle(_VehicleSnapshot snapshot) async {
    _blockSurfaceClearUntil = DateTime.now().add(
      const Duration(milliseconds: 700),
    );
    final latLng = snapshot.latLngOrNull;
    if (latLng == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veiculo sem posicao real para compartilhar.'),
        ),
      );
      return;
    }
    final mapsUrl =
        'https://maps.google.com/?q=${latLng.latitude},${latLng.longitude}';
    final shareText =
        '${snapshot.device.name} - ${snapshot.speedLabel}\n$mapsUrl';
    await Clipboard.setData(ClipboardData(text: shareText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Link do veiculo copiado para compartilhar.')),
    );
  }

  void _focusVehicle(_VehicleSnapshot snapshot) {
    final latLng = snapshot.latLngOrNull;
    if (latLng == null) return;
    _googleMapController?.animateCamera(
      gmaps.CameraUpdate.newCameraPosition(
        gmaps.CameraPosition(
          target: latLng,
          zoom: 16,
          tilt: 45,
          bearing: snapshot.mapBearing,
        ),
      ),
    );
  }

  void _zoomBy(double delta) {
    final nextZoom = (_currentZoom + delta).clamp(4.0, 19.0).toDouble();
    setState(() => _currentZoom = nextZoom);
    _googleMapController?.animateCamera(gmaps.CameraUpdate.zoomTo(nextZoom));
  }

  void _recenter(List<_VehicleSnapshot> snapshots) {
    final selected = _snapshotForDevice(
      _selectedVehicle ?? _previewVehicle,
      snapshots,
    );
    final firstWithPosition = snapshots
        .where((snapshot) => snapshot.hasPosition)
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
      _activePanelId = null;
      _activePanelTitle = null;
    });
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
    final devicesAsync = ref.watch(devicesProvider);
    final positionsAsync = ref.watch(positionsProvider);
    final latestEventsAsync = ref.watch(latestEventsProvider);
    final brand =
        ref.watch(whiteLabelProvider).value ?? WhiteLabelConfig.fallback;
    final visualSettings = ref.watch(visualSettingsProvider);
    final visualController = ref.read(visualSettingsProvider.notifier);

    final devices = devicesAsync.valueOrNull ?? const <TraccarDevice>[];
    final positions = positionsAsync.valueOrNull ?? const <TraccarPosition>[];
    final latestEvents =
        latestEventsAsync.valueOrNull ?? const <Map<String, dynamic>>[];
    final snapshots = _buildSnapshots(devices, positions);
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
    final rawPreviewSnapshot = _snapshotForDevice(
      _previewVehicle,
      snapshots,
    );
    final selectedSnapshot = enrichSnapshot(rawSelectedSnapshot);
    final previewSnapshot = enrichSnapshot(rawPreviewSnapshot);
    final selectedMapDevice = _selectedVehicle ?? _previewVehicle;
    final selectedMapDeviceId = selectedMapDevice?.id;
    final snapshotKpis = _FleetKpis.fromSnapshots(snapshots);
    final realAlertCount =
        latestEvents.isNotEmpty ? latestEvents.length : snapshotKpis.alerts;
    final kpis = snapshotKpis.copyWith(alerts: realAlertCount);
    final filteredSnapshots = _filterSnapshots(snapshots, _activeKpiFilter);
    final currentSession = ref.watch(sessionProvider);
    final sessionUsers =
        ref.watch(usersProvider).valueOrNull ?? const <TraccarUser>[];
    final isPixeltiSession = _isPixeltiUser(currentSession);
    final profileName = _resolveProfileName(currentSession, sessionUsers);
    final profileDetail = _resolveProfileDetail(currentSession, sessionUsers);
    final menuItems = _menuWithRealtimeBadges(
      session: currentSession,
      alertCount: realAlertCount,
      orderCount: ref.watch(ordersProvider).valueOrNull?.length ?? 0,
      showDataLog: _shouldShowDataLogMenu(currentSession),
    );
    final pixelTelemetryMode = _activePanelId == 'telemetry-demo';
    final fullMapVisible = _activePanelId == null &&
        !_kpiListOpen &&
        _previewVehicle == null &&
        _selectedVehicle == null;
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
                  selectedDeviceId: selectedMapDeviceId,
                  mapMode: visualSettings.mapMode,
                  onMapCreated: (controller) =>
                      _googleMapController = controller,
                  onCameraMove: (position) => _currentZoom = position.zoom,
                  onMapTap: _clearOperationalSurface,
                  onVehicleTap: _previewVehicleOnMap,
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: visualSettings.backdropOverlayAlpha,
                      ),
                    ),
                  ),
                ),
              ),
              if (snapshots.isEmpty && !_activePanelVisible)
                const Positioned.fill(
                  child: _NoVehiclesMapHint(),
                ),
              if (!pixelTelemetryMode)
                _TopSearchBar(
                  brand: brand,
                  logoMode: visualSettings.logoMode,
                  hideLogoOnFullMap: fullMapVisible,
                  kpis: kpis,
                  activeFilter: _kpiListOpen ? _activeKpiFilter : null,
                  onKpiTap: _openKpi,
                  onMenuTap: _toggleMenu,
                  menuOpen: _menuOpen,
                  alertCount: realAlertCount,
                  panelOpen: _activePanelVisible,
                  activeTitle: _activePanelTitle,
                  activeSubtitle: _panelSubtitle(_activePanelId),
                  onRefresh: _refreshOperationalData,
                  onClosePanel: _closePanel,
                  onLogout: () {
                    _handleLogout();
                  },
                  profileName: profileName,
                  profileDetail: profileDetail,
                  compactProfileMenu: isPixeltiSession,
                ),
              if (!pixelTelemetryMode) const _RoadSpeedLegend(),
              if (!pixelTelemetryMode)
                _SideMenu(
                  open: _menuOpen,
                  cardDensity: visualSettings.cardDensity,
                  items: menuItems,
                  activeId: _activePanelId,
                  onSelect: _openPanel,
                  onLogout: () {
                    _handleLogout();
                  },
                ),
              if (_showHighlightsRail)
                _HighlightsRail(open: !_activePanelVisible),
              if (!pixelTelemetryMode)
                _KpiVehicleList(
                  open: _kpiListOpen,
                  cardDensity: visualSettings.cardDensity,
                  title: _activeKpiFilter.title,
                  snapshots: filteredSnapshots,
                  onVehicleTap: _previewVehicleOnMap,
                ),
              if (!pixelTelemetryMode)
                _IntegratedPanel(
                  open: _activePanelVisible,
                  cardDensity: visualSettings.cardDensity,
                  title: _activePanelTitle ?? '',
                  subtitle: _panelSubtitle(_activePanelId),
                  hideHeader: _activePanelId == 'logs',
                  onClose: _closePanel,
                  child: _panelFor(_activePanelId),
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
              if (!pixelTelemetryMode && previewSnapshot != null)
                _VehicleCompactPopup(
                  snapshot: previewSnapshot,
                  balloonScale: visualSettings.balloonScale,
                  cardDensity: visualSettings.cardDensity,
                  onDetails: () => _openVehicleDetails(previewSnapshot),
                  onAlerts: () => _openVehicleAlerts(previewSnapshot),
                  onShare: () {
                    _shareVehicle(previewSnapshot);
                  },
                  onMore: () => _openVehicleDetails(
                    previewSnapshot,
                    initialTab: _VehicleBottomTab.commands,
                  ),
                  onClose: () => setState(() => _previewVehicle = null),
                ),
              if (!pixelTelemetryMode)
                _VehicleBottomBar(
                  snapshot: selectedSnapshot,
                  cardDensity: visualSettings.cardDensity,
                  activeTab: _activeBottomTab,
                  onTabChanged: (tab) => setState(() => _activeBottomTab = tab),
                  onClose: () => setState(() => _selectedVehicle = null),
                ),
              if (!pixelTelemetryMode &&
                  (devicesAsync.isLoading ||
                      positionsAsync.isLoading ||
                      latestEventsAsync.isLoading))
                const Positioned(
                  right: 24,
                  top: 86,
                  child: _SyncBadge(),
                ),
              if (!pixelTelemetryMode && !isPixeltiSession)
                _CopilotFloatingButton(
                  open: _copilotPanelOpen,
                  onTap: _toggleCopilotPanel,
                ),
              if (!pixelTelemetryMode && !isPixeltiSession)
                _CopilotOperationalPanel(
                  open: _copilotPanelOpen,
                  settings: visualSettings,
                  diagnosis: _lastVisualDiagnosis,
                  onClose: _toggleCopilotPanel,
                  onDiagnose: () => _runVisualDiagnosis(visualSettings),
                  onReset: visualController.reset,
                  onBalloonSize: visualController.setBalloonSize,
                  onLogoMode: visualController.setLogoMode,
                  onCardDensity: visualController.setCardDensity,
                  onTransparency: visualController.setTransparency,
                  onFontSize: visualController.setFontSize,
                  onMapMode: visualController.setMapMode,
                ),
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
        return 'Visao geral da operacao';
      case 'map':
        return 'Monitoramento em tempo real';
      case 'vehicles':
        return 'Cadastro e ciclo de vida da frota';
      case 'devices':
        return 'Gestao operacional de rastreadores';
      case 'routes':
        return 'Historico, replay e quilometragem';
      case 'alerts':
        return 'Eventos, regras e notificacoes';
      case 'maintenance':
        return 'Planos e historico de manutencao';
      case 'geofences':
        return 'Cercas e zonas inteligentes';
      case 'tickets':
        return 'Abertura e acompanhamento de chamados';
      case 'communication':
        return 'Atendimento e mensagens operacionais';
      case 'ai-operations':
        return 'Assistente inteligente da operacao';
      case 'finance':
        return 'Gestao financeira e cobrancas';
      case 'inventory':
        return 'Estoque e equipamentos vinculados';
      case 'mdvr':
        return 'Monitoramento de cameras e evidencias';
      case 'telemetry-demo':
        return 'Telemetria operacional em tempo real';
      case 'logs':
        return 'Data log por comunicacao do dispositivo';
      case 'reports':
        return 'Relatorios operacionais e executivos';
      case 'automations':
        return 'Regras e gatilhos automaticos';
      case 'settings':
        return 'Governanca e parametros do ambiente';
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

    return [
      for (var i = 0; i < devices.length; i++)
        _VehicleSnapshot(
          device: devices[i],
          position: positionByDeviceId[devices[i].id],
          index: i,
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
            .where((it) => it.isOperationalOffline)
            .toList(growable: false);
      case _KpiFilter.moving:
        return snapshots
            .where((it) => it.isOperationalMoving)
            .toList(growable: false);
      case _KpiFilter.alerts:
        return snapshots.where((it) => it.hasAlert).toList(growable: false);
    }
  }

  List<_OperationalMenuItem> _menuWithRealtimeBadges({
    required SessionState session,
    required int alertCount,
    required int orderCount,
    required bool showDataLog,
  }) {
    final rawMenu = _operationalMenu;
    final baseMenu = showDataLog
        ? rawMenu
        : rawMenu.where((item) => item.id != 'logs').toList(growable: false);
    final menuWithoutAi = _isPixeltiUser(session)
        ? baseMenu
            .where((item) => item.id != 'ai-operations')
            .toList(growable: false)
        : baseMenu;
    final filteredMenu = _filterMenuForSession(menuWithoutAi, session);

    return [
      for (final item in filteredMenu)
        if (item.id == 'alerts')
          item.copyWith(badge: _badgeText(alertCount))
        else if (item.id == 'tickets')
          item.copyWith(badge: _badgeText(orderCount))
        else
          item,
    ];
  }

  List<_OperationalMenuItem> _filterMenuForSession(
    List<_OperationalMenuItem> items,
    SessionState session,
  ) {
    if (_isAdminSession(session)) {
      return items;
    }

    final modules = session.tenantConfig.modules;
    bool enabled(String key) => modules[key] == true;

    // Menus com backend/API operacional para perfil cliente.
    const apiBackedMenuIds = {
      'dashboard',
      'map',
      'vehicles',
      'devices',
      'routes',
      'alerts',
      'maintenance',
      'geofences',
      'reports',
    };

    bool allowByModule(String menuId) {
      switch (menuId) {
        case 'dashboard':
        case 'map':
        case 'vehicles':
        case 'routes':
        case 'alerts':
        case 'maintenance':
          return enabled('tracking') ||
              enabled('fleet') ||
              enabled('maintenance') ||
              enabled('monitoring');
        case 'devices':
          return enabled('tracking') || enabled('devices');
        case 'geofences':
          return enabled('tracking') ||
              enabled('geofences') ||
              enabled('geofence');
        case 'tickets':
          return enabled('demand') || enabled('assist');
        case 'communication':
          return enabled('zpro') || enabled('communication');
        case 'ai-operations':
          return enabled('ai') || enabled('ai_ops') || enabled('assistant');
        case 'finance':
          return enabled('finance');
        case 'inventory':
          return enabled('inventory');
        case 'mdvr':
          return enabled('mdvr') || enabled('cameras');
        case 'logs':
          return enabled('data_log') || enabled('datalog') || enabled('logs');
        case 'reports':
          return enabled('tracking') ||
              enabled('reports') ||
              enabled('reports_plus');
        case 'automations':
          return enabled('automations') ||
              enabled('automation') ||
              enabled('rules');
        case 'settings':
          return enabled('admin');
        default:
          return true;
      }
    }

    return items
        .where((item) => apiBackedMenuIds.contains(item.id))
        .where((item) => allowByModule(item.id))
        .toList(growable: false);
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
    return kPixeltiPilotMode || _isPixeltiUser(session);
  }

  bool _shouldShowDataLogMenu(SessionState session) {
    if (_isAdminSession(session)) {
      return true;
    }
    if (_isPixeltiUser(session)) {
      return false;
    }
    if (kEnableDataLogMenu) {
      return true;
    }
    final modules = session.tenantConfig.modules;
    return modules['data_log'] == true ||
        modules['datalog'] == true ||
        modules['logs'] == true;
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
        return _buildTelemetryDemoPanel();
      case 'logs':
        return _buildLogsPanel();
      case 'reports':
        return _buildReportsPanel();
      case 'automations':
        return _buildAutomationsPanel();
      case 'settings':
        return _buildSettingsPanel();
      default:
        return const PlaceholderScreen(
          title: 'Painel operacional',
          subtitle: 'Selecione um menu para abrir o painel integrado.',
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
    if (!kShowPlaceholderPanels) {
      return const <_PanelToolEntry>[];
    }
    return [
      for (final item in items)
        _placeholderEntry(
          moduleTitle: moduleTitle,
          label: item.label,
          icon: item.icon,
          description: item.description,
        ),
    ];
  }

  Widget _buildDashboardPanel() {
    if (_isPilotView(ref.watch(sessionProvider))) {
      return _TraccarToolsPanel(
        key: const ValueKey('dashboard-tools'),
        title: 'Dashboard',
        entries: const [
          _PanelToolEntry(
            label: 'Visao geral',
            icon: Icons.space_dashboard_outlined,
            detail: 'Resumo em tempo real',
            child: GeneralPanelScreen(),
          ),
          _PanelToolEntry(
            label: 'Frota em tempo real',
            icon: Icons.directions_car_outlined,
            detail: 'Dados do SouTracking',
            child: VehiclesScreen(),
          ),
          _PanelToolEntry(
            label: 'Alertas criticos',
            icon: Icons.warning_amber_outlined,
            detail: 'Eventos de risco',
            child: AlertsScreen(),
          ),
        ],
      );
    }

    return _TraccarToolsPanel(
      key: const ValueKey('dashboard-tools'),
      title: 'Dashboard',
      entries: [
        const _PanelToolEntry(
          label: 'Visao geral',
          icon: Icons.space_dashboard_outlined,
          detail: 'Resumo em tempo real',
          child: GeneralPanelScreen(),
        ),
        const _PanelToolEntry(
          label: 'Frota em tempo real',
          icon: Icons.directions_car_outlined,
          detail: 'Dados do SouTracking',
          child: VehiclesScreen(),
        ),
        const _PanelToolEntry(
          label: 'Alertas criticos',
          icon: Icons.warning_amber_outlined,
          detail: 'Eventos de risco',
          child: AlertsScreen(),
        ),
        const _PanelToolEntry(
          label: 'Chamados abertos',
          icon: Icons.support_agent_outlined,
          detail: 'Fila operacional',
          child: CallsScreen(),
        ),
        const _PanelToolEntry(
          label: 'Financeiro resumido',
          icon: Icons.account_balance_wallet_outlined,
          detail: 'Visao financeira',
          child: FinanceScreen(),
        ),
        if (kShowPlaceholderPanels)
          _placeholderEntry(
            moduleTitle: 'Dashboard',
            label: 'Saude da operacao',
            icon: Icons.health_and_safety_outlined,
            description:
                'Painel de saude operacional com qualidade de sinais e riscos.',
            cards: const [
              'Sinal de rastreamento por regiao',
              'Latencia media de eventos',
              'Status de sensores criticos',
            ],
          ),
      ],
    );
  }

  Widget _buildMapPanel() {
    return _TraccarToolsPanel(
      key: const ValueKey('map-tools'),
      title: 'Mapa',
      entries: const [
        _PanelToolEntry(
          label: 'Mapa principal',
          icon: Icons.map_outlined,
          detail: 'Monitoramento em tempo real',
          child: MapScreen(),
        ),
      ],
    );
  }

  Widget _buildVehiclesPanel() {
    if (_isPilotView(ref.watch(sessionProvider))) {
      return _TraccarToolsPanel(
        key: const ValueKey('vehicles-tools'),
        title: 'Veiculos',
        entries: const [
          _PanelToolEntry(
            label: 'Lista de veiculos',
            icon: Icons.list_alt_outlined,
            detail: 'Cadastro atual da frota',
            child: VehiclesScreen(),
          ),
        ],
      );
    }

    return _TraccarToolsPanel(
      key: const ValueKey('vehicles-tools'),
      title: 'Veiculos',
      entries: [
        const _PanelToolEntry(
          label: 'Lista de veiculos',
          icon: Icons.list_alt_outlined,
          detail: 'Cadastro atual da frota',
          child: VehiclesScreen(),
        ),
        const _PanelToolEntry(
          label: 'Motorista vinculado',
          icon: Icons.person_outline,
          detail: 'Dados de condutor',
          child: DriversScreen(),
        ),
        const _PanelToolEntry(
          label: 'Equipamento vinculado',
          icon: Icons.memory_outlined,
          detail: 'Atributos e sensores',
          child: AttributesScreen(),
        ),
        const _PanelToolEntry(
          label: 'Chip vinculado',
          icon: Icons.sim_card_outlined,
          detail: 'Estoque e ativos',
          child: InventoryScreen(),
        ),
        const _PanelToolEntry(
          label: 'Historico do veiculo',
          icon: Icons.history_outlined,
          detail: 'Rotas e eventos',
          child: HistoryScreen(),
        ),
        const _PanelToolEntry(
          label: 'Situacao financeira',
          icon: Icons.payments_outlined,
          detail: 'Resumo de cobrancas',
          child: FinanceScreen(),
        ),
        ..._placeholderEntries(
          moduleTitle: 'Relatorios',
          items: const [
            (
              label: 'Detalhe do veiculo',
              icon: Icons.info_outline,
              description: 'Ficha completa do veiculo com visao consolidada.',
            ),
            (
              label: 'Cadastro/edicao',
              icon: Icons.edit_outlined,
              description: 'Fluxo visual de cadastro e edicao de veiculos.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDevicesPanel() {
    return _TraccarToolsPanel(
      key: const ValueKey('devices-tools'),
      title: 'Dispositivos',
      entries: const [
        _PanelToolEntry(
          label: 'Lista de dispositivos',
          icon: Icons.gps_fixed_outlined,
          detail: 'Cadastro operacional',
          child: DevicesScreen(),
        ),
      ],
    );
  }

  Widget _buildRoutesPanel() {
    if (_isPilotView(ref.watch(sessionProvider))) {
      return _TraccarToolsPanel(
        key: const ValueKey('routes-tools'),
        title: 'Rotas',
        entries: const [
          _PanelToolEntry(
            label: 'Historico de rota',
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
          label: 'Historico de rota',
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
          moduleTitle: 'Relatorios',
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
              description: 'Consolidado de quilometragem rodada por veiculo.',
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
    if (_isPilotView(ref.watch(sessionProvider))) {
      return _TraccarToolsPanel(
        key: const ValueKey('alerts-tools'),
        title: 'Alertas',
        entries: const [
          _PanelToolEntry(
            label: 'Lista de alertas',
            icon: Icons.notifications_active_outlined,
            detail: 'Eventos ativos',
            child: AlertsScreen(),
          ),
        ],
      );
    }

    return _TraccarToolsPanel(
      key: const ValueKey('alerts-tools'),
      title: 'Alertas',
      entries: [
        const _PanelToolEntry(
          label: 'Lista de alertas',
          icon: Icons.notifications_active_outlined,
          detail: 'Eventos ativos',
          child: AlertsScreen(),
        ),
        ..._placeholderEntries(
          moduleTitle: 'Relatorios',
          items: const [
            (
              label: 'Excesso de velocidade',
              icon: Icons.speed_outlined,
              description: 'Monitoramento visual de limites de velocidade.',
            ),
            (
              label:
                  'IgniÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o',
              icon: Icons.power_settings_new_outlined,
              description:
                  'Eventos de igniÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o ligada e desligada.',
            ),
            (
              label:
                  'Entrada/saÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â­da de cerca',
              icon: Icons.fence_outlined,
              description: 'Alertas de cruzamento de geofence.',
            ),
            (
              label:
                  'Sem comunicaÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o',
              icon: Icons.portable_wifi_off_outlined,
              description:
                  'DetecÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o de perda de comunicaÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o com rastreador.',
            ),
            (
              label: 'Bateria baixa',
              icon: Icons.battery_alert_outlined,
              description:
                  'Fila de dispositivos com bateria crÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â­tica.',
            ),
            (
              label:
                  'BotÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o de pÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢nico',
              icon: Icons.sos_outlined,
              description:
                  'Canal de emergÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Âªncia com prioridade alta.',
            ),
            (
              label: 'Jammer/suspeita',
              icon: Icons.gps_not_fixed_outlined,
              description: 'Indicadores visuais de interferencia ou jammer.',
            ),
            (
              label: 'Alertas por WhatsApp',
              icon: Icons.forum_outlined,
              description: 'Painel para regras de envio por WhatsApp.',
            ),
            (
              label: 'Regras de alerta',
              icon: Icons.rule_folder_outlined,
              description: 'Configuracao visual de regras operacionais.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMaintenancePanel() {
    return _TraccarToolsPanel(
      key: const ValueKey('maintenance-tools'),
      title: 'Manutencao',
      entries: const [
        _PanelToolEntry(
          label: 'Planos de manutencao',
          icon: Icons.build_outlined,
          detail: 'Itens preventivos por km, dias e horas',
          child: MaintenanceScreen(),
        ),
      ],
    );
  }

  Widget _buildGeofencesPanel() {
    return _TraccarToolsPanel(
      key: const ValueKey('geofences-tools'),
      title: 'Cercas',
      entries: [
        const _PanelToolEntry(
          label: 'Lista de cercas',
          icon: Icons.polyline_outlined,
          detail: 'Cercas cadastradas',
          child: GeofencesScreen(),
        ),
        ..._placeholderEntries(
          moduleTitle: 'Relatorios',
          items: const [
            (
              label: 'Criar cerca no mapa',
              icon: Icons.draw_outlined,
              description:
                  'Editor visual para desenhar cerca diretamente no mapa.',
            ),
            (
              label: 'Criar cerca por endereco',
              icon: Icons.location_on_outlined,
              description:
                  'CriaÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o guiada usando endereÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§o como referÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Âªncia.',
            ),
            (
              label: 'Criar cerca por raio',
              icon: Icons.radio_button_checked_outlined,
              description:
                  'DefiniÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o de cerca circular por raio.',
            ),
            (
              label: 'Cerca residencial',
              icon: Icons.home_work_outlined,
              description:
                  'Modelo rÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡pido para cercas residenciais.',
            ),
            (
              label: 'Cerca comercial',
              icon: Icons.storefront_outlined,
              description:
                  'Modelo rÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡pido para cercas comerciais.',
            ),
            (
              label: 'Area de risco',
              icon: Icons.report_problem_outlined,
              description:
                  'ClassificaÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o visual de zonas de risco.',
            ),
            (
              label: 'Area permitida',
              icon: Icons.check_circle_outline,
              description:
                  'ClassificaÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o visual de zonas permitidas.',
            ),
            (
              label: 'Cerca inteligente via IA',
              icon: Icons.psychology_outlined,
              description:
                  'Estrutura para sugestÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o automÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡tica de cercas.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTicketsPanel() {
    return _TraccarToolsPanel(
      key: const ValueKey('tickets-tools'),
      title: 'Chamados',
      entries: [
        const _PanelToolEntry(
          label: 'Abrir chamado',
          icon: Icons.add_comment_outlined,
          detail: 'Envio em modo controlado',
          child: _BridgeTicketCreateScreen(),
        ),
        const _PanelToolEntry(
          label: 'Chamados em andamento',
          icon: Icons.pending_actions_outlined,
          detail: 'Painel de execucao',
          child: CallsScreen(),
        ),
        const _PanelToolEntry(
          label: 'Chamados finalizados',
          icon: Icons.task_alt_outlined,
          detail: 'Historico de atendimento',
          child: CallsScreen(),
        ),
        ..._placeholderEntries(
          moduleTitle: 'Relatorios',
          items: const [
            (
              label: 'Guincho',
              icon: Icons.local_shipping_outlined,
              description: 'Fila especializada para atendimento com guincho.',
            ),
            (
              label: 'Pane eletrica',
              icon: Icons.electrical_services_outlined,
              description: 'Classificacao visual para pane eletrica.',
            ),
            (
              label: 'Pane mecanica',
              icon: Icons.handyman_outlined,
              description: 'Classificacao visual para pane mecanica.',
            ),
            (
              label: 'Instalacao',
              icon: Icons.settings_input_antenna_outlined,
              description: 'Fluxo visual para instalacao de rastreador.',
            ),
            (
              label: 'Manutencao',
              icon: Icons.build_outlined,
              description: 'Controle visual de manutencoes em aberto.',
            ),
            (
              label: 'Vistoria',
              icon: Icons.fact_check_outlined,
              description: 'Checklist visual para vistoria tecnica.',
            ),
            (
              label: 'Sinistro',
              icon: Icons.car_crash_outlined,
              description: 'Fluxo para ocorrencias de sinistro.',
            ),
            (
              label: 'Suporte tecnico',
              icon: Icons.support_agent_outlined,
              description: 'Canal dedicado de suporte tecnico.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommunicationPanel() {
    return _TraccarToolsPanel(
      key: const ValueKey('communication-tools'),
      title: 'Comunicacao',
      entries: [
        const _PanelToolEntry(
          label: 'Conversas',
          icon: Icons.chat_bubble_outline,
          detail: 'Hub atual de mensagens',
          child: ZproCommunicationScreen(),
        ),
        ..._placeholderEntries(
          moduleTitle: 'Relatorios',
          items: const [
            (
              label: 'WhatsApp cliente',
              icon: Icons.contact_phone_outlined,
              description: 'Canal visual para conversa com cliente.',
            ),
            (
              label: 'WhatsApp motorista',
              icon: Icons.drive_eta_outlined,
              description: 'Canal visual para conversa com motorista.',
            ),
            (
              label: 'WhatsApp tecnico',
              icon: Icons.construction_outlined,
              description: 'Canal visual para conversa com tecnico.',
            ),
            (
              label: 'Enviar localizacao',
              icon: Icons.send_to_mobile_outlined,
              description: 'Atalho visual para envio de localizacao.',
            ),
            (
              label: 'Enviar cobranca',
              icon: Icons.request_quote_outlined,
              description: 'Atalho visual para envio de cobranca.',
            ),
            (
              label: 'Enviar alerta',
              icon: Icons.notification_add_outlined,
              description: 'Atalho visual para envio de alerta.',
            ),
            (
              label: 'Enviar relatorio',
              icon: Icons.send_outlined,
              description: 'Atalho visual para compartilhar relatorios.',
            ),
            (
              label: 'Historico de atendimento',
              icon: Icons.history_toggle_off_outlined,
              description: 'Linha do tempo das interacoes.',
            ),
            (
              label: 'Criar ticket',
              icon: Icons.confirmation_number_outlined,
              description: 'Abertura visual de ticket de atendimento.',
            ),
            (
              label: 'Integracao SouCall via Bridge futuramente',
              icon: Icons.link_outlined,
              description: 'Integracao sera plugada em etapa futura.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAiOperationsPanel() {
    return _TraccarToolsPanel(
      key: const ValueKey('ai-operations-tools'),
      title: 'IA Operacional',
      entries: const [
        _PanelToolEntry(
          label: 'Criar alerta por IA',
          icon: Icons.auto_awesome_outlined,
          detail: 'Assistente ativo para alertas',
          child: _AiOperationAssistantScreen(
            operationId: 'alerta',
            title: 'Criar alerta por IA',
            description:
                'Sugere e envia um alerta operacional com base no contexto informado.',
          ),
        ),
        _PanelToolEntry(
          label: 'Criar cerca por IA',
          icon: Icons.psychology_outlined,
          detail: 'Assistente ativo para geofence',
          child: _AiOperationAssistantScreen(
            operationId: 'cerca',
            title: 'Criar cerca por IA',
            description:
                'Sugere parametros de cerca e registra a criacao no fluxo operacional.',
          ),
        ),
        _PanelToolEntry(
          label: 'Criar relatorio por IA',
          icon: Icons.analytics_outlined,
          detail: 'Assistente ativo para relatorios',
          child: _AiOperationAssistantScreen(
            operationId: 'relatorio',
            title: 'Criar relatorio por IA',
            description:
                'Monta e dispara uma solicitacao de relatorio assistida por prompt.',
          ),
        ),
        _PanelToolEntry(
          label: 'Criar chamado por IA',
          icon: Icons.support_outlined,
          detail: 'Fluxo ativo de abertura',
          child: _BridgeTicketCreateScreen(),
        ),
        _PanelToolEntry(
          label: 'Resumo diario',
          icon: Icons.calendar_view_day_outlined,
          detail: 'Visao consolidada da operacao',
          child: StatisticsScreen(),
        ),
        _PanelToolEntry(
          label: 'Diagnostico de risco',
          icon: Icons.monitor_heart_outlined,
          detail: 'Eventos criticos em tempo real',
          child: AlertsScreen(),
        ),
        _PanelToolEntry(
          label: 'Sugestao de acao',
          icon: Icons.tips_and_updates_outlined,
          detail: 'Recomendacao operacional',
          child: _AiOperationAssistantScreen(
            operationId: 'acao',
            title: 'Sugestao de acao',
            description:
                'Registra recomendacoes de acao priorizadas para o operador.',
          ),
        ),
        _PanelToolEntry(
          label: 'Regras inteligentes',
          icon: Icons.rule_outlined,
          detail: 'Motor ativo de regras IA',
          child: _AutomationWorkbenchScreen(
            title: 'Regras inteligentes',
            description:
                'Configura regras orientadas por IA com gatilhos e acao recomendada.',
            scope: 'ia-rules',
            actionType: 'evento',
          ),
        ),
      ],
    );
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
          label: 'Cobrancas',
          icon: Icons.receipt_long_outlined,
          detail: 'Painel financeiro atual',
          child: FinanceScreen(),
        ),
        ..._placeholderEntries(
          moduleTitle: 'Relatorios',
          items: const [
            (
              label: 'Pix',
              icon: Icons.pix_outlined,
              description: 'Estrutura visual de cobrancas por Pix.',
            ),
            (
              label: 'Boleto',
              icon: Icons.description_outlined,
              description: 'Estrutura visual de cobrancas por boleto.',
            ),
            (
              label: 'Cartao',
              icon: Icons.credit_card_outlined,
              description: 'Estrutura visual de cobrancas por cartao.',
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
              label: 'Relatorios financeiros',
              icon: Icons.bar_chart_outlined,
              description: 'Conjunto de relatorios financeiros.',
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
    return _TraccarToolsPanel(
      key: const ValueKey('inventory-tools'),
      title: 'Estoque',
      entries: const [
        _PanelToolEntry(
          label: 'Painel demo Estoque',
          icon: Icons.inventory_2_outlined,
          detail: 'Controle operacional (demo)',
          child: _InventoryDemoScreen(),
        ),
      ],
    );
  }

  Widget _buildMdvrPanel() {
    return _TraccarToolsPanel(
      key: const ValueKey('mdvr-tools'),
      title: 'MDVR / Cameras',
      entries: const [
        _PanelToolEntry(
          label: 'Painel demo MDVR',
          icon: Icons.videocam_outlined,
          detail: 'Monitoramento visual (demo)',
          child: _MdvrDemoScreen(),
        ),
      ],
    );
  }

  Widget _buildTelemetryDemoPanel() {
    return _TraccarToolsPanel(
      key: const ValueKey('telemetry-demo-tools'),
      title: 'Telemetria',
      entries: [
        const _PanelToolEntry(
          label: 'Frota em tempo real',
          icon: Icons.directions_car_outlined,
          detail: 'Visao operacional',
          child: VehiclesScreen(),
        ),
        const _PanelToolEntry(
          label: 'Dispositivos',
          icon: Icons.gps_fixed_outlined,
          detail: 'Visao operacional em tempo real',
          child: DevicesScreen(),
        ),
        const _PanelToolEntry(
          label: 'Comandos',
          icon: Icons.terminal_outlined,
          detail: 'Acoes remotas no equipamento',
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

  Widget _buildLogsPanel() {
    return const HistoryScreen();
  }

  Widget _buildReportsPanel() {
    if (_isPilotView(ref.watch(sessionProvider))) {
      return _TraccarToolsPanel(
        key: const ValueKey('reports-tools'),
        title: 'Relatorios',
        entries: const [
          _PanelToolEntry(
            label: 'Rotas',
            icon: Icons.route_outlined,
            detail: 'Relatorios atuais',
            child: ReportsScreen(),
          ),
        ],
      );
    }

    return _TraccarToolsPanel(
      key: const ValueKey('reports-tools'),
      title: 'Relatorios',
      entries: [
        const _PanelToolEntry(
          label: 'Rotas',
          icon: Icons.route_outlined,
          detail: 'Relatorios atuais',
          child: ReportsScreen(),
        ),
        const _PanelToolEntry(
          label: 'Combinado',
          icon: Icons.merge_type_outlined,
          detail: 'Endpoint /reports/combined',
          child: ReportScreen(
            title: 'Relatorio Combinado',
            endpointPath: '/reports/combined',
          ),
        ),
        const _PanelToolEntry(
          label: 'Eventos',
          icon: Icons.event_note_outlined,
          detail: 'Endpoint /reports/events',
          child: ReportScreen(
            title: 'Relatorio de Eventos',
            endpointPath: '/reports/events',
          ),
        ),
        const _PanelToolEntry(
          label: 'Viagens',
          icon: Icons.luggage_outlined,
          detail: 'Endpoint /reports/trips',
          child: ReportScreen(
            title: 'Relatorio de Viagens',
            endpointPath: '/reports/trips',
          ),
        ),
        const _PanelToolEntry(
          label: 'Paradas',
          icon: Icons.pause_circle_outline,
          detail: 'Endpoint /reports/stops',
          child: ReportScreen(
            title: 'Relatorio de Paradas',
            endpointPath: '/reports/stops',
          ),
        ),
        const _PanelToolEntry(
          label: 'Resumo',
          icon: Icons.summarize_outlined,
          detail: 'Endpoint /reports/summary',
          child: ReportScreen(
            title: 'Relatorio Resumo',
            endpointPath: '/reports/summary',
          ),
        ),
        const _PanelToolEntry(
          label: 'Posicoes',
          icon: Icons.timeline_outlined,
          detail: 'Endpoint /reports/route',
          child: ReportScreen(
            title: 'Relatorio de Posicoes',
            endpointPath: '/reports/route',
          ),
        ),
        const _PanelToolEntry(
          label: 'Logs',
          icon: Icons.article_outlined,
          detail: 'Endpoint /reports/logs',
          child: ReportScreen(
            title: 'Relatorio de Logs',
            endpointPath: '/reports/logs',
          ),
        ),
        const _PanelToolEntry(
          label: 'Cercas (report)',
          icon: Icons.fence_outlined,
          detail: 'Endpoint /reports/geofences',
          child: ReportScreen(
            title: 'Relatorio de Cercas',
            endpointPath: '/reports/geofences',
          ),
        ),
        const _PanelToolEntry(
          label: 'Grafico',
          icon: Icons.show_chart_outlined,
          detail: 'Endpoint /reports/chart',
          child: ReportScreen(
            title: 'Relatorio Grafico',
            endpointPath: '/reports/chart',
          ),
        ),
        const _PanelToolEntry(
          label: 'Agendados',
          icon: Icons.schedule_outlined,
          detail: 'Endpoint /reports/scheduled',
          child: ReportScreen(
            title: 'Relatorios Agendados',
            endpointPath: '/reports/scheduled',
            enableDeviceFilter: false,
          ),
        ),
        const _PanelToolEntry(
          label: 'Estatisticas',
          icon: Icons.stacked_bar_chart_outlined,
          detail: 'Endpoint /statistics',
          child: StatisticsScreen(),
        ),
        const _PanelToolEntry(
          label: 'Auditoria',
          icon: Icons.fact_check_outlined,
          detail: 'Endpoint /reports/audit',
          child: ReportScreen(
            title: 'Relatorio de Auditoria',
            endpointPath: '/reports/audit',
            enableDeviceFilter: false,
          ),
        ),
        ..._placeholderEntries(
          moduleTitle: 'Relatorios',
          items: const [
            (
              label: 'Viagens',
              icon: Icons.luggage_outlined,
              description: 'Relatorio de viagens por periodo.',
            ),
            (
              label: 'Paradas',
              icon: Icons.pause_circle_outline,
              description: 'Relatorio de paradas e tempos de espera.',
            ),
            (
              label: 'Eventos',
              icon: Icons.event_note_outlined,
              description: 'Relatorio consolidado de eventos.',
            ),
            (
              label: 'Resumo',
              icon: Icons.summarize_outlined,
              description: 'Resumo executivo para gestao.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAutomationsPanel() {
    return _TraccarToolsPanel(
      key: const ValueKey('automations-tools'),
      title: 'Automacoes',
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
          label: 'Acoes',
          icon: Icons.playlist_add_check_outlined,
          detail: 'Catalogo ativo de acoes',
          child: _AutomationWorkbenchScreen(
            title: 'Acoes',
            description: 'Configura a resposta automatica apos cada gatilho.',
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
                'Configura e testa callbacks para integracoes externas.',
            scope: 'webhooks',
            actionType: 'webhook',
          ),
        ),
        _PanelToolEntry(
          label: 'Alertas automaticos',
          icon: Icons.notification_important_outlined,
          detail: 'Automacao ativa de alertas',
          child: _AutomationWorkbenchScreen(
            title: 'Alertas automaticos',
            description:
                'Dispara alertas automaticos quando o gatilho ocorrer.',
            scope: 'alerts',
            actionType: 'alerta',
          ),
        ),
        _PanelToolEntry(
          label: 'WhatsApp automatico',
          icon: Icons.forum_outlined,
          detail: 'Automacao ativa de WhatsApp',
          child: _AutomationWorkbenchScreen(
            title: 'WhatsApp automatico',
            description:
                'Envia mensagem automatica para o destino configurado.',
            scope: 'whatsapp',
            actionType: 'whatsapp',
          ),
        ),
        _PanelToolEntry(
          label: 'Criacao automatica de chamado',
          icon: Icons.add_box_outlined,
          detail: 'Abertura automatica ativa',
          child: _AutomationWorkbenchScreen(
            title: 'Criacao automatica de chamado',
            description: 'Abre chamado automaticamente com dados do evento.',
            scope: 'tickets',
            actionType: 'ticket',
          ),
        ),
        _PanelToolEntry(
          label: 'Relatorios automaticos',
          icon: Icons.description_outlined,
          detail: 'Agendamento ativo de relatorios',
          child: _AutomationWorkbenchScreen(
            title: 'Relatorios automaticos',
            description: 'Agenda e testa geracao automatica de relatorios.',
            scope: 'reports',
            actionType: 'relatorio',
          ),
        ),
        _PanelToolEntry(
          label: 'Integracao MackFlow/Bridge',
          icon: Icons.link_outlined,
          detail: 'Registro ativo de integracao',
          child: _AutomationWorkbenchScreen(
            title: 'Integracao MackFlow/Bridge',
            description: 'Registra payloads de integracao para uso do Bridge.',
            scope: 'bridge',
            actionType: 'evento',
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsPanel() {
    return _TraccarToolsPanel(
      key: const ValueKey('settings-tools'),
      title: 'Configuracoes',
      entries: [
        _PanelToolEntry(
          label: 'Preferencias gerais',
          icon: Icons.tune_outlined,
          detail: 'Conta, tema e parametros',
          child: SettingsScreen(
            onLogout: () {
              _handleLogout();
            },
          ),
        ),
        const _PanelToolEntry(
          label: 'Usuarios',
          icon: Icons.people_outline,
          detail: 'Gestao de contas',
          child: UsersScreen(),
        ),
        const _PanelToolEntry(
          label: 'Dispositivos',
          icon: Icons.gps_fixed_outlined,
          detail: 'Cadastro operacional',
          child: DevicesScreen(),
        ),
        const _PanelToolEntry(
          label: 'Permissoes',
          icon: Icons.vpn_key_outlined,
          detail: 'Controle de acesso',
          child: PermissionsScreen(),
        ),
        const _PanelToolEntry(
          label: 'Grupos',
          icon: Icons.folder_shared_outlined,
          detail: 'Organizacao operacional',
          child: GroupsScreen(),
        ),
        const _PanelToolEntry(
          label: 'Motoristas',
          icon: Icons.badge_outlined,
          detail: 'Cadastro de motoristas',
          child: DriversScreen(),
        ),
        const _PanelToolEntry(
          label: 'Atributos',
          icon: Icons.sell_outlined,
          detail: 'Campos customizados',
          child: AttributesScreen(),
        ),
        const _PanelToolEntry(
          label: 'Calendarios',
          icon: Icons.calendar_month_outlined,
          detail: 'Regras de agenda e excecoes',
          child: CalendarsScreen(),
        ),
        const _PanelToolEntry(
          label: 'Comandos',
          icon: Icons.terminal_outlined,
          detail: 'Comandos salvos',
          child: CommandsScreen(),
        ),
        const _PanelToolEntry(
          label: 'Manutencao',
          icon: Icons.build_outlined,
          detail: 'Planos e controle tecnico',
          child: MaintenanceScreen(),
        ),
        const _PanelToolEntry(
          label: 'Notificacoes',
          icon: Icons.notifications_outlined,
          detail: 'Preferencias de alerta',
          child: NotificationsScreen(),
        ),
        const _PanelToolEntry(
          label: 'Status do Servidor',
          icon: Icons.dns_outlined,
          detail: 'Saude e configuracoes operacionais',
          child: _ServerStatusPanel(),
        ),
      ],
    );
  }
}

class _OperationalMap extends StatelessWidget {
  const _OperationalMap({
    required this.snapshots,
    required this.selectedDeviceId,
    required this.mapMode,
    required this.onMapCreated,
    required this.onCameraMove,
    required this.onMapTap,
    required this.onVehicleTap,
  });

  final List<_VehicleSnapshot> snapshots;
  final int? selectedDeviceId;
  final VisualMapMode mapMode;
  final ValueChanged<gmaps.GoogleMapController> onMapCreated;
  final ValueChanged<gmaps.CameraPosition> onCameraMove;
  final VoidCallback onMapTap;
  final ValueChanged<_VehicleSnapshot> onVehicleTap;

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

  @override
  Widget build(BuildContext context) {
    final snapshotsWithPosition = snapshots
        .where((snapshot) => snapshot.hasPosition)
        .toList(growable: false);
    final initialTarget = snapshots.isEmpty
        ? const gmaps.LatLng(-23.55052, -46.633308)
        : (snapshotsWithPosition.isNotEmpty
            ? snapshotsWithPosition.first.latLng
            : const gmaps.LatLng(-23.55052, -46.633308));
    final selected = snapshots
        .where((snapshot) => snapshot.device.id == selectedDeviceId)
        .cast<_VehicleSnapshot?>()
        .firstOrNull;
    final mapType = switch (mapMode) {
      VisualMapMode.normal => gmaps.MapType.normal,
      VisualMapMode.premium => gmaps.MapType.hybrid,
      VisualMapMode.dark => gmaps.MapType.normal,
    };
    final mapStyle = switch (mapMode) {
      VisualMapMode.dark => _darkMapStyle,
      VisualMapMode.normal || VisualMapMode.premium => _cleanMapStyle,
    };
    const trafficEnabled = true;

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
      markers: {
        for (final snapshot in snapshotsWithPosition)
          gmaps.Marker(
            markerId: gmaps.MarkerId('vehicle-${snapshot.device.id}'),
            position: snapshot.latLng,
            icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
              snapshot.device.id == selectedDeviceId
                  ? gmaps.BitmapDescriptor.hueYellow
                  : snapshot.markerHue,
            ),
            onTap: () => onVehicleTap(snapshot),
          ),
      },
      circles: {
        for (final snapshot in snapshotsWithPosition.where((it) => it.hasAlert))
          gmaps.Circle(
            circleId: gmaps.CircleId('alert-${snapshot.device.id}'),
            center: snapshot.latLng,
            radius: 120,
            fillColor: Colors.redAccent.withValues(alpha: 0.18),
            strokeColor: Colors.redAccent.withValues(alpha: 0.42),
            strokeWidth: 2,
          ),
        if (selected != null && selected.hasPosition)
          gmaps.Circle(
            circleId: gmaps.CircleId('selected-${selected.device.id}'),
            center: selected.latLng,
            radius: 110,
            fillColor: const Color(0xFFF8C530).withValues(alpha: 0.18),
            strokeColor: const Color(0xFFF8C530).withValues(alpha: 0.38),
            strokeWidth: 2,
          ),
      },
    );
  }
}

class _RoadSpeedLegend extends StatelessWidget {
  const _RoadSpeedLegend();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 18,
      top: 94,
      child: _SurfaceGuard(
        child: _GlassSurface(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'Velocidade das vias',
                style: TextStyle(
                  color: Color(0xFF1F2A44),
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                ),
              ),
              SizedBox(height: 6),
              _SpeedLegendItem(color: Color(0xFF16A34A), label: 'Livre'),
              SizedBox(height: 4),
              _SpeedLegendItem(color: Color(0xFFF59E0B), label: 'Moderado'),
              SizedBox(height: 4),
              _SpeedLegendItem(color: Color(0xFFDC2626), label: 'Lento'),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeedLegendItem extends StatelessWidget {
  const _SpeedLegendItem({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF52627C),
            fontWeight: FontWeight.w700,
            fontSize: 10.8,
          ),
        ),
      ],
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

  @override
  Widget build(BuildContext context) {
    final title = activeTitle?.trim().isNotEmpty == true
        ? activeTitle!.trim()
        : 'Operacao';
    final brandName =
        brand.appName.trim().isEmpty ? 'SouTracking' : brand.appName.trim();
    final brandLogoAsset = brand.logoAsset?.trim() ?? '';
    final hasBrandLogo = brandLogoAsset.isNotEmpty;
    final hideBrand =
        logoMode == VisualLogoMode.hideOnFullMap && hideLogoOnFullMap;
    final compactLogo = logoMode == VisualLogoMode.compact;
    final logoHeight = compactLogo ? 18.0 : 24.0;
    final brandWidth = compactLogo ? 178.0 : (hasBrandLogo ? 236.0 : 186.0);

    return Positioned(
      left: 16,
      right: 16,
      top: 16,
      child: _SurfaceGuard(
        child: Row(
          children: [
            _GlassButton(
              tooltip: menuOpen ? 'Recolher menu' : 'Expandir menu',
              icon: menuOpen ? Icons.menu_open_rounded : Icons.menu_rounded,
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
            const SizedBox(width: 14),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: panelOpen
                    ? _GlassSurface(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        child: Row(
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$title - Dados de rastreamento',
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
                      )
                    : _KpiStrip(
                        kpis: kpis,
                        activeFilter: activeFilter,
                        onTap: onKpiTap,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            _TopIcon(
              icon: Icons.notifications_none_outlined,
              count: alertCount > 0 ? alertCount : null,
            ),
            const SizedBox(width: 10),
            const _TopIcon(icon: Icons.grid_view_rounded, count: null),
            const SizedBox(width: 10),
            _ProfileMenuButton(
              onLogout: onLogout,
              profileName: profileName,
              profileDetail: profileDetail,
              compactMenu: compactProfileMenu,
            ),
          ],
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
  });

  final VoidCallback onLogout;
  final String profileName;
  final String profileDetail;
  final bool compactMenu;

  static const String _profileMenuKey = 'my-profile';
  static const String _logoutMenuKey = 'logout';

  @override
  Widget build(BuildContext context) {
    final displayName =
        profileName.trim().isEmpty ? 'Usuario' : profileName.trim();
    final displayDetail =
        profileDetail.trim().isEmpty ? 'Conta SouTracking' : profileDetail;
    final width = compactMenu ? 186.0 : 218.0;

    return PopupMenuButton<String>(
      tooltip: 'Menu do perfil',
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
        if (value == _logoutMenuKey) {
          onLogout();
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Perfil ativo nesta sessao.'),
        ));
      },
      itemBuilder: (context) {
        return const [
          PopupMenuItem<String>(
            value: _profileMenuKey,
            child: Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 18,
                  color: Color(0xFF52627C),
                ),
                SizedBox(width: 10),
                Expanded(child: Text('Meu perfil')),
              ],
            ),
          ),
          PopupMenuDivider(),
          PopupMenuItem<String>(
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
          horizontal: 12,
          vertical: compactMenu ? 6 : 7,
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 15,
              backgroundColor: Color(0xFFF7F9FD),
              child: Icon(
                Icons.person_outline_rounded,
                color: Color(0xFF52627C),
                size: 17,
              ),
            ),
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
  });

  final bool open;
  final VisualCardDensity cardDensity;
  final List<_OperationalMenuItem> items;
  final String? activeId;
  final ValueChanged<_OperationalMenuItem> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final expanded = open;
    final compactDensity = cardDensity == VisualCardDensity.compact;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      left: compactDensity ? 12 : 16,
      top: 86,
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
                    const Divider(color: Color(0xFFE2E8F0)),
                    Row(
                      children: [
                        const Icon(
                          Icons.circle,
                          color: Color(0xFF10B981),
                          size: 12,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Online\nConectado ao servidor',
                            style: TextStyle(
                              color: Color(0xFF52627C),
                              height: 1.25,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Sair',
                          onPressed: onLogout,
                          icon: const Icon(
                            Icons.logout_rounded,
                            color: Color(0xFF71819B),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 6),
                    IconButton(
                      tooltip: 'Sair',
                      onPressed: onLogout,
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Color(0xFF71819B),
                        size: 18,
                      ),
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
    final color = selected ? const Color(0xFF176EEB) : const Color(0xFF25344A);
    return Material(
      color: selected
          ? const Color(0xFFE7F0FF).withValues(alpha: 0.92)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 38,
          padding: EdgeInsets.symmetric(horizontal: expanded ? 10 : 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: selected
                ? Border.all(color: const Color(0xFFB7D5FF))
                : Border.all(color: Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment:
                expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(item.icon, color: color, size: 18),
              if (expanded) ...[
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                if (item.badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4D61),
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
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _KpiFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final filter = _KpiFilter.values[index];
          return _KpiChip(
            filter: filter,
            value: kpis.valueFor(filter),
            selected: activeFilter == filter,
            onTap: () => onTap(filter),
          );
        },
      ),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFEAF3FF)
                : Colors.white.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  selected ? const Color(0xFFB7D5FF) : const Color(0xFFE3EAF3),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF183153).withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF176EEB).withValues(alpha: 0.18)
                      : const Color(0xFFF1F5FB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  filter.icon,
                  size: 17,
                  color: selected
                      ? const Color(0xFF176EEB)
                      : const Color(0xFF526B8D),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    filter.title,
                    style: const TextStyle(
                      color: Color(0xFF4B5C77),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
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
                      height: 1.05,
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
}

class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.top,
    required this.left,
    required this.onRecenter,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final double top;
  final double left;
  final VoidCallback onRecenter;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      left: left,
      top: top,
      child: _SurfaceGuard(
        child: Column(
          children: [
            _GlassButton(
              tooltip: 'Centralizar',
              icon: Icons.navigation_rounded,
              onTap: onRecenter,
              selected: true,
            ),
            const SizedBox(height: 10),
            _GlassButton(
              tooltip: 'Aproximar',
              icon: Icons.add_rounded,
              onTap: onZoomIn,
            ),
            const SizedBox(height: 4),
            _GlassButton(
              tooltip: 'Afastar',
              icon: Icons.remove_rounded,
              onTap: onZoomOut,
            ),
            const SizedBox(height: 10),
            _GlassButton(
              tooltip: 'Mapa 3D',
              icon: Icons.view_in_ar_outlined,
              onTap: onRecenter,
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
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: const Text(
            'Nenhum veiculo disponivel no momento',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
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
    required this.title,
    required this.snapshots,
    required this.onVehicleTap,
  });

  final bool open;
  final VisualCardDensity cardDensity;
  final String title;
  final List<_VehicleSnapshot> snapshots;
  final ValueChanged<_VehicleSnapshot> onVehicleTap;

  @override
  Widget build(BuildContext context) {
    final compactDensity = cardDensity == VisualCardDensity.compact;
    final panelWidth = compactDensity ? 320.0 : 348.0;
    final openedLeft = compactDensity ? 210.0 : 226.0;
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
                              'Nenhum veiculo disponivel no momento',
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
    required this.title,
    required this.subtitle,
    this.hideHeader = false,
    required this.child,
    required this.onClose,
  });

  final bool open;
  final VisualCardDensity cardDensity;
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
    final leftInset = compact ? 16.0 : (compactDensity ? 216.0 : 238.0);
    final rightInset = compact ? 16.0 : 32.0;
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
        type: 'Ignicao',
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
        label: 'Relatorios',
        icon: Icons.insert_chart_outlined,
        selected: false
      ),
      (
        id: 'communication',
        label: 'Comunicacao',
        icon: Icons.chat_bubble_outline,
        selected: false
      ),
      (
        id: 'settings',
        label: 'Configuracoes',
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
                      label: item.label,
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
                            'Visao geral dos equipamentos da operacao',
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
                        title: 'Sem Comunicacao',
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
                            'Historico detalhado de dados e eventos dos equipamentos',
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
              DataColumn(label: Text('Veiculo / Ativo')),
              DataColumn(label: Text('Grupo')),
              DataColumn(label: Text('Ultima Conexao')),
              DataColumn(label: Text('Velocidade')),
              DataColumn(label: Text('Ignicao')),
              DataColumn(label: Text('Bateria')),
              DataColumn(label: Text('Sinal GSM')),
              DataColumn(label: Text('Acoes')),
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
    final model =
        row.modelLabel == 'Nao informado' ? row.device.name : row.modelLabel;
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
  if (!row.hasPosition || row.hasStaleLastUpdate) {
    return 'Sem comunicacao';
  }
  if (row.isOperationalMoving) return 'Em movimento';
  if (row.isOperationalOnline) return 'Online';
  if (row.isOperationalOffline) return 'Offline';
  return 'Indefinido';
}

Color _statusColor(_VehicleSnapshot row) {
  if (!row.hasPosition || row.hasStaleLastUpdate) {
    return const Color(0xFFFF5D64);
  }
  if (row.isOperationalMoving) return const Color(0xFF3EA0FF);
  if (row.isOperationalOnline) return const Color(0xFF2EDD87);
  if (row.isOperationalOffline) return const Color(0xFFA0AFC3);
  return const Color(0xFFF8D04C);
}

String _rssiText(_VehicleSnapshot row) {
  final rssi = _pixelRssiFromRow(row);
  if (rssi != null) {
    return rssi.toStringAsFixed(0);
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
    if (rssi <= -100) return _PixelSignalLevel.critical;
    if (rssi <= -92) return _PixelSignalLevel.low;
    if (rssi <= -80) return _PixelSignalLevel.medium;
    return _PixelSignalLevel.good;
  }

  final gsm = _pixelGsmFromRow(row);
  if (gsm == null) return _PixelSignalLevel.unknown;
  if (gsm < 8) return _PixelSignalLevel.critical;
  if (gsm < 16) return _PixelSignalLevel.low;
  if (gsm < 26) return _PixelSignalLevel.medium;
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
  if (rssi != null) return '${rssi.toStringAsFixed(0)} dBm';
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
                        'Google Maps hÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â­brido sempre visÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â­vel.',
                  ),
                  _HighlightItem(
                    icon: Icons.layers_outlined,
                    title:
                        'Menus translÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Âºcidos',
                    text:
                        'PainÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©is claros sobre o mapa.',
                  ),
                  _HighlightItem(
                    icon: Icons.speed_rounded,
                    title:
                        'TrÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡fego e velocidade',
                    text:
                        'TrÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡fego Google + telemetria do veÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â­culo.',
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
    required this.onDetails,
    required this.onAlerts,
    required this.onShare,
    required this.onMore,
    required this.onClose,
  });

  final _VehicleSnapshot snapshot;
  final double balloonScale;
  final VisualCardDensity cardDensity;
  final VoidCallback onDetails;
  final VoidCallback onAlerts;
  final VoidCallback onShare;
  final VoidCallback onMore;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final compactDensity = cardDensity == VisualCardDensity.compact;
    return Positioned(
      left: compactDensity ? 242 : 270,
      top: 142,
      child: _SurfaceGuard(
        child: Transform.scale(
          scale: balloonScale,
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: compactDensity ? 380 : 410,
            ),
            child: _LightVehiclePanel(
              borderRadius: 18,
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _VehicleAvatar(snapshot: snapshot, size: 112, iconSize: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.76),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDDE5F0)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  snapshot.device.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF1F2A44),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: onClose,
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: Color(0xFF71819B),
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _StatusLine(snapshot: snapshot),
                          const SizedBox(height: 7),
                          _PopupTextLine(
                            label: 'Identificador:',
                            value: snapshot.identifierLabel,
                          ),
                          const SizedBox(height: 5),
                          _PopupTextLine(
                            label: 'Status:',
                            value: snapshot.connectionStatusLabel,
                          ),
                          const SizedBox(height: 5),
                          _PopupTextLine(
                            label: 'Velocidade:',
                            value: snapshot.speedLabel,
                          ),
                          const SizedBox(height: 5),
                          _PopupTextLine(
                            label: 'Ignicao:',
                            value: snapshot.ignitionLabel,
                          ),
                          const SizedBox(height: 5),
                          _PopupTextLine(
                            label: 'Ultima comunicacao:',
                            value: snapshot.lastCommunicationLabel,
                          ),
                          const SizedBox(height: 5),
                          _PopupTextLine(
                            label: 'Lat/Lng:',
                            value: snapshot.latLngLabel,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _PopupAction(
                                icon: Icons.remove_red_eye_outlined,
                                tooltip: 'Ver detalhes',
                                onTap: onDetails,
                              ),
                              const SizedBox(width: 8),
                              _PopupAction(
                                icon: Icons.notifications_none_outlined,
                                tooltip: 'Alertas',
                                onTap: onAlerts,
                              ),
                              const SizedBox(width: 8),
                              _PopupAction(
                                icon: Icons.share_outlined,
                                tooltip: 'Compartilhar',
                                onTap: onShare,
                              ),
                              const SizedBox(width: 8),
                              _PopupAction(
                                icon: Icons.more_horiz_rounded,
                                tooltip: 'Mais op\u00E7\u00F5es',
                                onTap: onMore,
                              ),
                            ],
                          ),
                        ],
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

class _VehicleBottomBar extends StatelessWidget {
  const _VehicleBottomBar({
    required this.snapshot,
    required this.cardDensity,
    required this.activeTab,
    required this.onTabChanged,
    required this.onClose,
  });

  final _VehicleSnapshot? snapshot;
  final VisualCardDensity cardDensity;
  final _VehicleBottomTab activeTab;
  final ValueChanged<_VehicleBottomTab> onTabChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final visible = snapshot != null;
    final width = MediaQuery.sizeOf(context).width;
    final compactDensity = cardDensity == VisualCardDensity.compact;
    final height = width >= 980
        ? (compactDensity ? 214.0 : 232.0)
        : (compactDensity ? 392.0 : 420.0);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      left: width >= 980 ? (compactDensity ? 148 : 166) : 16,
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
                      activeTab: activeTab,
                      onTabChanged: onTabChanged,
                      onClose: onClose,
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
    required this.activeTab,
    required this.onTabChanged,
    required this.onClose,
  });

  final _VehicleSnapshot snapshot;
  final _VehicleBottomTab activeTab;
  final ValueChanged<_VehicleBottomTab> onTabChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 960;
        final showTabs = activeTab != _VehicleBottomTab.overview;
        final header = SizedBox(
          height: 76,
          child: Row(
            children: [
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Voltar',
                onPressed: onClose,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF4F7FC),
                  side: const BorderSide(color: Color(0xFFDDE5F0)),
                ),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF5A6D89),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              _VehicleAvatar(snapshot: snapshot, size: 52, iconSize: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      snapshot.device.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1F2A44),
                        fontWeight: FontWeight.w900,
                        fontSize: 33,
                        height: 0.95,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _StatusLine(snapshot: snapshot),
                  ],
                ),
              ),
              _PopupAction(
                icon: Icons.remove_red_eye_outlined,
                tooltip: 'Visualizar',
                onTap: () => onTabChanged(_VehicleBottomTab.overview),
              ),
              const SizedBox(width: 8),
              _PopupAction(
                icon: Icons.notifications_none_outlined,
                tooltip: 'Alertas',
                onTap: () => onTabChanged(_VehicleBottomTab.info),
              ),
              const SizedBox(width: 8),
              _PopupAction(
                icon: Icons.more_vert_rounded,
                tooltip: 'Mais opcoes',
                onTap: () => onTabChanged(_VehicleBottomTab.commands),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Fechar',
                onPressed: onClose,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF4F7FC),
                  side: const BorderSide(color: Color(0xFFDDE5F0)),
                ),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFF5A6D89),
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
        );

        final summary = _BottomStatusCard(snapshot: snapshot);
        final metrics = Wrap(
          spacing: 42,
          runSpacing: 12,
          children: [
            _VehicleMetricPair(label: 'Velocidade', value: snapshot.speedLabel),
            _VehicleMetricPair(
                label: 'Igni\u00E7\u00E3o', value: snapshot.ignitionLabel),
            _VehicleMetricPair(
                label: 'Bateria interna', value: snapshot.batteryLabel),
            _VehicleMetricPair(label: 'Motorista', value: snapshot.driverName),
          ],
        );

        final tabBar = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final tab in _VehicleBottomTab.values) ...[
                _VehicleTabChip(
                  icon: tab.icon,
                  label: tab.label,
                  selected: activeTab == tab,
                  onTap: () => onTabChanged(tab),
                ),
                if (tab != _VehicleBottomTab.values.last)
                  const SizedBox(width: 8),
              ],
            ],
          ),
        );

        final body = compact
            ? ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                children: [
                  summary,
                  const SizedBox(height: 12),
                  metrics,
                  if (showTabs) ...[
                    const SizedBox(height: 14),
                    tabBar,
                    const SizedBox(height: 12),
                  ] else
                    const SizedBox(height: 12),
                  _BottomTabContent(
                    snapshot: snapshot,
                    tab: activeTab,
                    compact: true,
                  ),
                ],
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 168, child: summary),
                        const SizedBox(width: 24),
                        Expanded(child: metrics),
                      ],
                    ),
                  ),
                  if (showTabs)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: tabBar,
                    ),
                  if (showTabs) const SizedBox(height: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                      child: _BottomTabContent(
                        snapshot: snapshot,
                        tab: activeTab,
                        compact: false,
                      ),
                    ),
                  ),
                ],
              );

        return Column(
          children: [
            header,
            const Divider(height: 1, color: Color(0xFFDDE5F0)),
            Expanded(child: body),
          ],
        );
      },
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
      (
        'positionSingle',
        Icons.my_location_outlined,
        'PosiÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o'
      ),
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
  switch (normalized) {
    case 'deviceOnline':
      return 'Dispositivo online';
    case 'deviceOffline':
      return 'Dispositivo offline';
    case 'deviceUnknown':
      return 'Status desconhecido';
    case 'ignitionOn':
      return 'IgniÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o ligada';
    case 'ignitionOff':
      return 'IgniÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o desligada';
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
  overview('Visao geral', Icons.dashboard_customize_outlined),
  photos('Fotos', Icons.image_outlined),
  commands('Comandos', Icons.terminal_rounded),
  chart('Grafico', Icons.show_chart_outlined),
  info('Informacoes', Icons.info_outline_rounded);

  const _VehicleBottomTab(this.label, this.icon);

  final String label;
  final IconData icon;
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
        Icon(Icons.circle, color: snapshot.statusColor, size: 14),
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

class _TopIcon extends StatelessWidget {
  const _TopIcon({required this.icon, required this.count});

  final IconData icon;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE1E8F2)),
          ),
          child: Icon(icon, color: const Color(0xFF526684), size: 20),
        ),
        if (count != null)
          Positioned(
            right: -8,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
    );
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
      bottom: 20,
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
                              title: 'Tamanho dos baloes',
                              selected: settings.balloonSize,
                              options: const [
                                _CopilotOption(
                                  value: VisualBalloonSize.small,
                                  label: 'Pequeno',
                                ),
                                _CopilotOption(
                                  value: VisualBalloonSize.medium,
                                  label: 'Medio',
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
                                      label: 'Sugestao de ajuste',
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
          'Se a tela ficar densa, combine com cards confortavel.';
    }
    if (text.contains('transparen') || text.contains('vidro')) {
      return 'Transparencia baixa melhora leitura; alta destaca mapa. '
          'Para uso diário, media costuma equilibrar visual e legibilidade.';
    }
    if (text.contains('card') || text.contains('compact')) {
      return 'Cards compactos aumentam área útil; confortavel melhora leitura. '
          'Você pode alternar instantaneamente para comparar.';
    }
    if (text.contains('resumo') || text.contains('status')) {
      return summary();
    }
    if (text.contains('balao') || text.contains('popup')) {
      return 'Tamanho dos baloes ajusta o popup rápido do veículo no mapa. '
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
    _contextController.text = 'Operacao monitorada pelo painel SouTracking';
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
      'operacao': widget.operationId,
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
                  labelText: 'Alvo (veiculo, grupo ou regra)',
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
                  hintText: 'Descreva o que a IA deve gerar para a operacao.',
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
    'Suporte tecnico',
    'Sem comunicacao',
    'Instalacao',
    'Manutencao',
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
        'Veiculo: $vehicleId\n'
        'Status: aguardando envio para SouFind.';
  }

  Future<void> _criarChamado() async {
    final vehicleId = _vehicleIdController.text.trim();
    final descricao = _descricaoController.text.trim();
    if (vehicleId.isEmpty || descricao.isEmpty) {
      setState(() {
        _erro = 'Preencha veiculo e descricao para criar o chamado.';
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
                  labelText: 'Veiculo',
                  hintText: 'Ex.: ABC-1234 ou ID do veiculo',
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
      title: 'Em manutencao',
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
      status: 'Manutencao',
      technician: 'Carlos Tecnico',
      vehicle: 'XYZ-9876',
      movement: 'Retorno tecnico',
    ),
  ];

  static const _history = <String>[
    '23:10 Entrada de rastreador 4G',
    '22:45 Saida de chip Vivo para tecnico',
    '21:30 Instalacao no veiculo ABC-1234',
    '20:10 Rele enviado para manutencao',
  ];

  static const _actions = <String>[
    'Entrada',
    'Saida para tecnico',
    'Instalar no veiculo',
    'Trocar chip',
    'Enviar para manutencao',
    'Devolver ao estoque',
    'Dar baixa',
    'Ver historico',
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
                'Controle de rastreadores, chips, acessorios e movimentacoes operacionais.',
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
                      DataColumn(label: Text('Veiculo')),
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
                'Movimentacoes (demo)',
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
                'Historico simulado',
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
              _InventoryFlowLine(text: 'Aba Movimentacoes registra historico'),
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
      case 'manutencao':
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
      title: 'Sem comunicacao',
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
                'MDVR / Cameras',
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
            'Veiculo vinculado: ABC-1234',
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
    'AustrÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡lia',
    'China',
    'JapÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o',
    'Bahrein'
  ];
  static const _sessionOptions = [
    'Treino',
    'ClassificaÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o',
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
    'AustrÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡lia':
        _RaceTelemetryCircuit(
      raceName:
          'AustrÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡lia',
      trackSubtitle:
          'Albert Park ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ Setores 1/2/3',
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
              'AceleraÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o mÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡xima',
          sector: 'Setor 3',
          position: Offset(0.76, 0.43),
          accent: Color(0xFF22C55E),
        ),
        _RaceTelemetryEvent(
          id: 'aus-4',
          label:
              'Perda de aderÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Âªncia',
          sector: 'Setor 1',
          position: Offset(0.34, 0.24),
          accent: Color(0xFFA855F7),
        ),
        _RaceTelemetryEvent(
          id: 'aus-5',
          label:
              'Volta rÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡pida',
          sector: 'Setor 2',
          position: Offset(0.63, 0.30),
          accent: Color(0xFF3B82F6),
        ),
      ],
    ),
    'China': _RaceTelemetryCircuit(
      raceName: 'China',
      trackSubtitle:
          'Shanghai ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ Setores 1/2/3',
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
              'AceleraÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o mÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡xima',
          sector: 'Setor 3',
          position: Offset(0.69, 0.27),
          accent: Color(0xFF3B82F6),
        ),
      ],
    ),
    'JapÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o':
        _RaceTelemetryCircuit(
      raceName:
          'JapÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o',
      trackSubtitle:
          'Suzuka ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ Setores 1/2/3',
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
              'Perda de aderÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Âªncia',
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
              'Volta rÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡pida',
          sector: 'Setor 2',
          position: Offset(0.46, 0.22),
          accent: Color(0xFF3B82F6),
        ),
      ],
    ),
    'Bahrein': _RaceTelemetryCircuit(
      raceName: 'Bahrein',
      trackSubtitle:
          'Sakhir ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ Setores 1/2/3',
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
              'AceleraÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o mÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡xima',
          sector: 'Setor 3',
          position: Offset(0.63, 0.24),
          accent: Color(0xFF3B82F6),
        ),
        _RaceTelemetryEvent(
          id: 'bah-5',
          label:
              'Volta rÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡pida',
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
          'hÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ 9 s',
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
          'hÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ 7 s',
      fuelOrLoad: 49,
      trackerTemperature: 40,
      behavior:
          'atenÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o',
    ),
    'Norris': const _RaceTelemetryDriverSnapshot(
      tireCompound:
          'MÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©dio',
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
          'hÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ 11 s',
      fuelOrLoad: 56,
      trackerTemperature: 38,
      behavior: 'normal',
    ),
    'Leclerc': const _RaceTelemetryDriverSnapshot(
      tireCompound:
          'IntermediÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡rio',
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
          'hÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ 13 s',
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
      case 'ClassificaÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o':
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
      case 'ClassificaÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o':
        return 210;
      case 'Corrida':
        return 0;
    }
    return 0;
  }

  int _raceAdjust(String race) {
    switch (race) {
      case 'AustrÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡lia':
        return 2;
      case 'China':
        return -1;
      case 'JapÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o':
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
                'ClassificaÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o'
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
                  'ClassificaÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o'
              ? 'atenÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o'
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
                    'DemonstraÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o tÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©cnica com dados pÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Âºblicos/simulados. Sem uso de marca oficial.',
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
                        'SessÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o',
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
            'MÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©tricas de corrida',
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
                  'SessÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o',
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
                '${snapshot.tireTempC}ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°C',
          ),
          _RaceTelemetryInfoLine(
            label: 'Temperatura do motor',
            value:
                '${snapshot.engineTempC}ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°C',
          ),
          _RaceTelemetryInfoLine(
            label:
                'Gap para comparaÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o',
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
                'IgniÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o',
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
                'ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ltima comunicaÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o',
            value: snapshot.lastCommunication,
          ),
          _RaceTelemetryInfoLine(
            label:
                'Temperatura do baÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Âº/motor',
            value:
                '${snapshot.trackerTemperature}ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°C',
          ),
          _RaceTelemetryInfoLine(
            label:
                'NÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â­vel de combustÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â­vel/carga',
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
            'A mesma lÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³gica usada para analisar velocidade, pneus, temperatura e comportamento em uma corrida pode ser aplicada em veÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â­culos de frota, guinchos, caminhÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Âµes, mÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡quinas e operaÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Âµes crÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â­ticas.',
            style: TextStyle(
              color: Color(0xFFBCD3F3),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const _RaceTelemetryBullet(
              text:
                  'detectar conduÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o agressiva;'),
          const _RaceTelemetryBullet(
              text:
                  'prever manutenÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o;'),
          const _RaceTelemetryBullet(
              text:
                  'monitorar bateria e comunicaÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o;'),
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
            'ComparaÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o',
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
                'DiferenÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§a de velocidade',
            value: formatDelta(comparison.speedDelta, ' km/h'),
          ),
          _RaceTelemetryInfoLine(
            label:
                'DiferenÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§a de frenagem',
            value: formatDelta(comparison.brakingDelta, '%'),
          ),
          _RaceTelemetryInfoLine(
            label:
                'DiferenÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§a de aceleraÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o',
            value: formatDelta(comparison.throttleDelta, '%'),
          ),
          _RaceTelemetryInfoLine(
            label:
                'DiferenÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§a de desgaste de pneu',
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
      severityLabel: 'Medio',
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
      severityLabel: 'Medio',
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
      severityLabel: 'Medio',
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
      severity: 'Medio',
      accent: Color(0xFF22C55E),
    ),
    _TelemetryRecentEvent(
      time: '14:24:12',
      section: 'Curva 4',
      event: 'Reducao brusca',
      value: '173 km/h',
      severity: 'Medio',
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
                        '${safeEvents[i].cornerLabel} ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ ${safeEvents[i].eventLabel}',
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
                      '${selectedEvent.cornerLabel} ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ ${selectedEvent.eventTime}',
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
                      'Velocidade ${selectedEvent.speedKmh} km/h ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ RPM ${selectedEvent.rpm} ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ Marcha ${selectedEvent.gear}',
                      style: const TextStyle(
                        color: Color(0xFFDCEAFE),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Acelerador ${selectedEvent.throttle}% ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ Freio ${selectedEvent.brake}% ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ Temp ${selectedEvent.temperatureC}C',
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
                          '${event.time} ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ ${event.section} ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ ${event.event}',
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
                'DemonstraÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o tÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©cnica com dados pÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Âºblicos/snapshot. Sem uso de marca oficial.',
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
            'Operacao > Demo Telemetria',
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
                      'Operacao > Demo Telemetria',
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
              onTap: () => onAction('Mais acoes'),
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
                  'GPS 23ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°42\'45.8"S   46ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°41\'19.6"W',
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
              onPressed: () {},
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
      return const _EmptyToolState(
        icon: Icons.dashboard_customize_outlined,
        title:
            'Nenhuma opÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o disponÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â­vel',
        detail:
            'Este painel ainda nÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o possui ferramentas configuradas.',
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
                child: selected.child,
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
      timezone: 'Nao informado',
      serviceVersion: 'Nao informado',
      operationalConfig: 'Nao informado',
      communicationLevel: 'Nao informado',
      defaultCoordinates: 'Nao informado',
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
        timezone: 'Nao informado',
        serviceVersion: 'Nao informado',
        operationalConfig: 'Nao informado',
        communicationLevel: 'Nao informado',
        defaultCoordinates: 'Nao informado',
        message:
            'Seu usuario nao tem permissao para consultar essas configuracoes.',
      );
    }
    if (code != null && code >= 500) {
      return _ServerPanelSnapshot(
        state: _ServerPanelState.unavailable,
        apiStatus: 'Indisponivel',
        lastReadAt: now,
        environment: _resolveEnvironmentLabel(kTraccarBaseUrl),
        userLabel: _cleanText(currentSession.email, fallback: 'Usuario atual'),
        timezone: 'Nao informado',
        serviceVersion: 'Nao informado',
        operationalConfig: 'Nao informado',
        communicationLevel: 'Nao informado',
        defaultCoordinates: 'Nao informado',
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
      timezone: 'Nao informado',
      serviceVersion: 'Nao informado',
      operationalConfig: 'Nao informado',
      communicationLevel: 'Nao informado',
      defaultCoordinates: 'Nao informado',
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
  return 'Nao informado';
}

String _resolveCommunicationLevel(Map<String, dynamic> server) {
  var level = 0;
  if (server['emailEnabled'] == true) level++;
  if (server['textEnabled'] == true) level++;
  if (server['geocoderEnabled'] == true) level++;

  if (level >= 3) return 'Alto';
  if (level == 2) return 'Medio';
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
  return 'Nao informado';
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
              title: 'Configuracoes operacionais',
              detail: status.operationalConfig,
            ),
            const SizedBox(height: 8),
            _SimpleToolRow(
              icon: Icons.wifi_tethering_outlined,
              title: 'Nivel de comunicacao',
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
  });

  final IconData icon;
  final String title;
  final String detail;

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
  online('Online', Icons.wifi_tethering_rounded),
  offline('Offline', Icons.wifi_off_rounded),
  moving('Em movimento', Icons.near_me_outlined),
  alerts('Alertas', Icons.warning_amber_rounded);

  const _KpiFilter(this.title, this.icon);

  final String title;
  final IconData icon;
}

class _FleetKpis {
  const _FleetKpis({
    required this.online,
    required this.offline,
    required this.moving,
    required this.alerts,
  });

  final int online;
  final int offline;
  final int moving;
  final int alerts;

  _FleetKpis copyWith({
    int? online,
    int? offline,
    int? moving,
    int? alerts,
  }) {
    return _FleetKpis(
      online: online ?? this.online,
      offline: offline ?? this.offline,
      moving: moving ?? this.moving,
      alerts: alerts ?? this.alerts,
    );
  }

  factory _FleetKpis.fromSnapshots(List<_VehicleSnapshot> snapshots) {
    if (snapshots.isEmpty) {
      return const _FleetKpis(online: 0, offline: 0, moving: 0, alerts: 0);
    }

    var online = 0;
    var offline = 0;
    var moving = 0;

    for (final snapshot in snapshots) {
      if (snapshot.isOperationalOnline) {
        online++;
      } else {
        // Status offline/unknown ou atualizaÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o antiga entram no offline operacional.
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
    }
  }
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
  });

  final TraccarDevice device;
  final TraccarPosition? position;
  final int index;
  final String? resolvedAddress;
  final List<Map<String, dynamic>> recentEvents;

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
    );
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

  bool get hasValidGps => hasValidGpsPosition(
        latitude: position?.latitude,
        longitude: position?.longitude,
        attributes: _mergedAttributes,
      );

  bool get isStatusUnknownOrUninformed {
    if (normalizedStatus.isEmpty) return true;
    return normalizedStatus == 'unknown' ||
        normalizedStatus == 'nao informado' ||
        normalizedStatus ==
            'nÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£o informado' ||
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

  bool get isOperationalOnline =>
      normalizedStatus == 'online' && !hasStaleLastUpdate;

  bool get isOperationalOffline =>
      normalizedStatus == 'offline' ||
      isStatusUnknownOrUninformed ||
      hasStaleLastUpdate ||
      !isOperationalOnline;

  bool get isOperationalMoving => hasPosition && (speed ?? 0) > 0;

  bool get isOperationalStopped => hasPosition && !isOperationalMoving;

  bool get isOnline => normalizedStatus == 'online';

  bool get isOffline => normalizedStatus == 'offline';

  double? get speed {
    final value = position?.speed;
    if (value == null) return null;
    if (!value.isFinite) return null;
    return value;
  }

  bool get isMoving => (speed ?? 0) > 1;

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

  bool get hasAlert =>
      isOffline || normalizedStatus == 'unknown' || (speed ?? 0) >= 80;

  String get identifierLabel {
    final value = device.uniqueId ??
        device.attributes?['plate'] ??
        device.attributes?['plateNumber'] ??
        device.attributes?['licensePlate'] ??
        device.attributes?['registration'] ??
        device.attributes?['identifier'];
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'Nao informado' : text;
  }

  String get connectionStatusLabel {
    if (isOnline) return 'Online';
    if (isOffline) return 'Offline';
    return 'Nao informado';
  }

  String get statusLabel {
    if (hasAlert && (speed ?? 0) >= 80) return 'Alta velocidade';
    if (isMoving) return 'Em Movimento';
    if (isOnline) return 'Online';
    if (isOffline) return 'Offline';
    return 'Indefinido';
  }

  Color get statusColor {
    if (hasAlert && (speed ?? 0) >= 80) return const Color(0xFFE74B4B);
    if (isMoving || isOnline) return const Color(0xFF10B981);
    if (isOffline) return const Color(0xFFE74B4B);
    return const Color(0xFFF59E0B);
  }

  double get markerHue {
    if (hasAlert && (speed ?? 0) >= 80) return gmaps.BitmapDescriptor.hueRed;
    if (isMoving || isOnline) return gmaps.BitmapDescriptor.hueGreen;
    if (isOffline) return gmaps.BitmapDescriptor.hueOrange;
    return gmaps.BitmapDescriptor.hueAzure;
  }

  double get mapBearing => (index * 34) % 360;

  String get speedLabel {
    final current = speed;
    if (current == null) return 'Nao informado';
    return '${current.toStringAsFixed(0)} km/h';
  }

  String get latLngLabel {
    return formatGpsCoordinateLabel(
      latitude: position?.latitude,
      longitude: position?.longitude,
      attributes: _mergedAttributes,
    );
  }

  String get lastCommunicationLabel {
    final parsed = lastCommunicationAt;
    if (parsed == null) return 'Nao informado';
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final year = parsed.year.toString().padLeft(4, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  String get ignitionLabel {
    final value = ignition;
    if (value == null) return 'Nao informado';
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
    return text?.isNotEmpty == true ? text! : 'Nao informado';
  }

  String get driverName {
    final value = device.attributes?['driver'] ??
        device.attributes?['driverName'] ??
        device.attributes?['motorista'];
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'Nao informado' : text;
  }

  String get modelLabel {
    final value = device.attributes?['model'] ??
        device.attributes?['vehicleModel'] ??
        device.category;
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'Nao informado' : text;
  }

  String get address {
    if (!hasValidGps) return 'Sem GPS v\u00E1lido';

    final value = resolvedAddress ??
        position?.address ??
        position?.attributes?['address'] ??
        device.attributes?['address'] ??
        device.attributes?['lastAddress'];
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
    return 'Nao informado';
  }

  String get eventsSummary {
    if (recentEvents.isEmpty) {
      return 'Sem eventos recentes\n'
          '\u00DAltima comunica\u00E7\u00E3o: ${relativeLastPoint == 'Nao informado' ? 'Nao informado' : relativeLastPoint}';
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

  String get relativeLastPoint {
    final parsed = lastCommunicationAt;
    if (parsed == null) return 'Nao informado';
    final diff = DateTime.now().difference(parsed);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'h\u00E1 ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'h\u00E1 ${diff.inHours} h';
    return 'h\u00E1 ${diff.inDays} dias';
  }

  String get sensorSummary {
    final rows = sensorRows;
    if (rows.isEmpty) return 'Sensores n\u00E3o recebidos';
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

class _OperationalMenuItem {
  const _OperationalMenuItem({
    required this.id,
    required this.label,
    required this.icon,
    this.badge,
  });

  final String id;
  final String label;
  final IconData icon;
  final String? badge;

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
    );
  }
}

const List<_OperationalMenuItem> _operationalMenu = [
  _OperationalMenuItem(
    id: 'dashboard',
    label: 'Dashboard',
    icon: Icons.space_dashboard_outlined,
  ),
  _OperationalMenuItem(id: 'map', label: 'Mapa', icon: Icons.map_outlined),
  _OperationalMenuItem(
    id: 'vehicles',
    label: 'Veiculos',
    icon: Icons.directions_car_outlined,
  ),
  _OperationalMenuItem(
    id: 'routes',
    label: 'Rotas',
    icon: Icons.route_outlined,
  ),
  _OperationalMenuItem(
    id: 'alerts',
    label: 'Alertas',
    icon: Icons.warning_amber_outlined,
    badge: '12',
  ),
  _OperationalMenuItem(
    id: 'maintenance',
    label: 'Manutencao',
    icon: Icons.build_outlined,
  ),
  _OperationalMenuItem(
    id: 'geofences',
    label: 'Cercas',
    icon: Icons.fence_outlined,
  ),
  _OperationalMenuItem(
    id: 'tickets',
    label: 'Chamados',
    icon: Icons.support_agent_outlined,
  ),
  _OperationalMenuItem(
    id: 'communication',
    label: 'Comunicacao',
    icon: Icons.chat_bubble_outline,
  ),
  _OperationalMenuItem(
    id: 'ai-operations',
    label: 'IA Operacional',
    icon: Icons.psychology_outlined,
  ),
  _OperationalMenuItem(
    id: 'finance',
    label: 'Financeiro',
    icon: Icons.account_balance_wallet_outlined,
  ),
  _OperationalMenuItem(
    id: 'inventory',
    label: 'Estoque',
    icon: Icons.inventory_2_outlined,
  ),
  _OperationalMenuItem(
    id: 'mdvr',
    label: 'MDVR / Cameras',
    icon: Icons.videocam_outlined,
  ),
  _OperationalMenuItem(
    id: 'telemetry-demo',
    label: 'Telemetria',
    icon: Icons.sensors_outlined,
  ),
  _OperationalMenuItem(
    id: 'logs',
    label: 'Data Log',
    icon: Icons.article_outlined,
  ),
  _OperationalMenuItem(
    id: 'reports',
    label: 'Relatorios',
    icon: Icons.insert_chart_outlined,
  ),
  _OperationalMenuItem(
    id: 'automations',
    label: 'Automacoes',
    icon: Icons.bolt_outlined,
  ),
  _OperationalMenuItem(
    id: 'settings',
    label: 'Configuracoes',
    icon: Icons.settings_outlined,
  ),
];

const List<_OperationalMenuItem> _pixeltiPilotMenu = [
  _OperationalMenuItem(
    id: 'dashboard',
    label: 'Dashboard',
    icon: Icons.space_dashboard_outlined,
  ),
  _OperationalMenuItem(id: 'map', label: 'Mapa', icon: Icons.map_outlined),
  _OperationalMenuItem(
    id: 'vehicles',
    label: 'Veiculos',
    icon: Icons.directions_car_outlined,
  ),
  _OperationalMenuItem(
    id: 'devices',
    label: 'Dispositivos',
    icon: Icons.gps_fixed_outlined,
  ),
  _OperationalMenuItem(
    id: 'routes',
    label: 'Rotas',
    icon: Icons.route_outlined,
  ),
  _OperationalMenuItem(
    id: 'alerts',
    label: 'Alertas',
    icon: Icons.warning_amber_outlined,
  ),
  _OperationalMenuItem(
    id: 'maintenance',
    label: 'Manutencao',
    icon: Icons.build_outlined,
  ),
  _OperationalMenuItem(
    id: 'reports',
    label: 'Relatorios',
    icon: Icons.insert_chart_outlined,
  ),
];
