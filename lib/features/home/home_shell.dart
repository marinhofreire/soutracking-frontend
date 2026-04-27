import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../core/white_label.dart';
import '../../data/models.dart';
import '../../state/session_state.dart';
import '../../widgets/status_pill.dart';
import '../admin/admin_tenants_screen.dart';
import '../alerts/alerts_screen.dart';
import '../assist/assist_create_request_screen.dart';
import '../assist/assist_requests_screen.dart';
import '../assist/demand_control_panel_screen.dart';
import '../attributes/attributes_screen.dart';
import '../business/business_reference_screens.dart';
import '../calendars/calendars_screen.dart';
import '../calls/calls_screen.dart';
import '../commands/commands_screen.dart';
import '../communication/zpro_communication_screen.dart';
import '../common/placeholder_screen.dart';
import '../clients/clients_screen.dart';
import '../drivers/drivers_screen.dart';
import '../events/events_screen.dart';
import '../finance/finance_screen.dart';
import '../geofences/geofences_screen.dart';
import '../groups/groups_screen.dart';
import '../history/history_screen.dart';
import '../inventory/inventory_screen.dart';
import '../journey/journey_checkin_screen.dart';
import '../maintenance/maintenance_screen.dart';
import '../map/map_screen.dart';
import '../mdvr/mdvr_devices_screen.dart';
import '../notifications/notifications_screen.dart';
import '../orders/orders_screen.dart';
import '../permissions/permissions_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../sharing/sharing_screen.dart';
import '../statistics/statistics_screen.dart';
import '../users/user_profiles_screen.dart';
import '../users/users_screen.dart';
import '../vehicles/vehicles_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  gmaps.GoogleMapController? _googleMapController;

  final bool _showHighlightsRail = false;

  bool _menuOpen = true;
  bool _kpiListOpen = false;
  bool _profileCompact = false;
  _KpiFilter _activeKpiFilter = _KpiFilter.online;
  _VehicleBottomTab _activeBottomTab = _VehicleBottomTab.overview;
  TraccarDevice? _previewVehicle;
  TraccarDevice? _selectedVehicle;
  String? _activePanelId;
  String? _activePanelTitle;
  double _currentZoom = 13.0;
  DateTime _blockSurfaceClearUntil = DateTime.fromMillisecondsSinceEpoch(0);

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
      _clearOperationalSurface(force: true);
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

  void _openVehicleDetails(_VehicleSnapshot snapshot) {
    setState(() {
      _selectedVehicle = snapshot.device;
      _previewVehicle = null;
      _activeBottomTab = _VehicleBottomTab.overview;
      _menuOpen = false;
      _kpiListOpen = false;
      _activePanelId = null;
      _activePanelTitle = null;
    });
    _focusVehicle(snapshot);
  }

  void _focusVehicle(_VehicleSnapshot snapshot) {
    _googleMapController?.animateCamera(
      gmaps.CameraUpdate.newCameraPosition(
        gmaps.CameraPosition(
          target: snapshot.latLng,
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
    final target = selected?.latLng ??
        (snapshots.isEmpty
            ? const gmaps.LatLng(-23.55052, -46.633308)
            : snapshots.first.latLng);
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

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesProvider);
    final positionsAsync = ref.watch(positionsProvider);
    final latestEventsAsync = ref.watch(latestEventsProvider);
    final brand =
        ref.watch(whiteLabelProvider).value ?? WhiteLabelConfig.fallback;

    final devices = devicesAsync.valueOrNull ?? const <TraccarDevice>[];
    final positions = positionsAsync.valueOrNull ?? const <TraccarPosition>[];
    final latestEvents =
        latestEventsAsync.valueOrNull ?? const <Map<String, dynamic>>[];
    final snapshots = _buildSnapshots(devices, positions);
    _VehicleSnapshot? enrichSnapshot(_VehicleSnapshot? snapshot) {
      if (snapshot == null) return null;
      final selectedAddress =
          ref.watch(reverseGeocodeProvider(_geocodeKey(snapshot))).valueOrNull;
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
    final menuItems = _menuWithRealtimeBadges(
      alertCount: realAlertCount,
      orderCount: ref.watch(ordersProvider).valueOrNull?.length ?? 0,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: _OperationalMap(
              snapshots: snapshots,
              selectedDeviceId: selectedMapDeviceId,
              onMapCreated: (controller) => _googleMapController = controller,
              onCameraMove: (position) => _currentZoom = position.zoom,
              onMapTap: _clearOperationalSurface,
              onVehicleTap: _previewVehicleOnMap,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.16),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.26),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),
          _TopSearchBar(
            brand: brand,
            onMenuTap: _toggleMenu,
            menuOpen: _menuOpen,
            alertCount: realAlertCount,
            panelOpen: _activePanelVisible,
            activeTitle: _activePanelTitle,
            activeSubtitle: _panelSubtitle(_activePanelId),
            onRefresh: _refreshOperationalData,
            onClosePanel: _closePanel,
            profileCompact: _profileCompact,
            onProfileTap: () {
              setState(() => _profileCompact = !_profileCompact);
            },
          ),
          if (!_activePanelVisible)
            Positioned(
              left: _menuOpen ? 226 : 80,
              right: 266,
              top: 74,
              child: _SurfaceGuard(
                child: _KpiStrip(
                  kpis: kpis,
                  activeFilter: _kpiListOpen ? _activeKpiFilter : null,
                  onTap: _openKpi,
                ),
              ),
            ),
          if (!_activePanelVisible)
            _MapControls(
              top: 126,
              left: _menuOpen ? 226 : 24,
              onRecenter: () => _recenter(snapshots),
              onZoomIn: () => _zoomBy(1),
              onZoomOut: () => _zoomBy(-1),
            ),
          _SideMenu(
            open: _menuOpen,
            items: menuItems,
            activeId: _activePanelId,
            onSelect: _openPanel,
            onLogout: () => ref.read(sessionProvider.notifier).logout(),
          ),
          if (_showHighlightsRail) _HighlightsRail(open: !_activePanelVisible),
          _KpiVehicleList(
            open: _kpiListOpen,
            title: _activeKpiFilter.title,
            snapshots: filteredSnapshots,
            onVehicleTap: _previewVehicleOnMap,
          ),
          _IntegratedPanel(
            open: _activePanelVisible,
            title: _activePanelTitle ?? '',
            subtitle: _panelSubtitle(_activePanelId),
            onClose: _closePanel,
            child: _panelFor(_activePanelId),
          ),
          if (previewSnapshot != null)
            _VehicleCompactPopup(
              snapshot: previewSnapshot,
              onDetails: () => _openVehicleDetails(previewSnapshot),
              onClose: () => setState(() => _previewVehicle = null),
            ),
          _VehicleBottomBar(
            snapshot: selectedSnapshot,
            activeTab: _activeBottomTab,
            onTabChanged: (tab) => setState(() => _activeBottomTab = tab),
            onClose: () => setState(() => _selectedVehicle = null),
          ),
          if (devicesAsync.isLoading ||
              positionsAsync.isLoading ||
              latestEventsAsync.isLoading)
            const Positioned(
              right: 24,
              top: 86,
              child: _SyncBadge(),
            ),
        ],
      ),
    );
  }

  bool get _activePanelVisible => _activePanelId != null;

  String _panelSubtitle(String? id) {
    switch (id) {
      case 'dashboard':
        return 'Visão operacional';
      case 'vehicles':
        return 'Frota, cercas, histórico e sensores';
      case 'alerts':
        return 'Eventos e notificações';
      case 'orders':
        return 'Ordens de serviço integradas';
      case 'calls':
        return 'Chamados e atendimento';
      case 'clients':
        return 'Carteira e operação comercial';
      case 'drivers':
        return 'Motoristas e vínculos';
      case 'reports':
        return 'Relatórios Traccar dos últimos 7 dias';
      case 'finance':
        return 'Gestão financeira integrada';
      case 'inventory':
        return 'Estoque, chips e ativos';
      case 'settings':
        return 'Administração, servidor e anúncios';
      default:
        return 'Painel integrado';
    }
  }

  List<_VehicleSnapshot> _buildSnapshots(
    List<TraccarDevice> devices,
    List<TraccarPosition> positions,
  ) {
    final positionByDeviceId = <int, TraccarPosition>{
      for (final position in positions) position.deviceId: position,
    };
    const fallbackCenter = gmaps.LatLng(-23.55052, -46.633308);

    return [
      for (var i = 0; i < devices.length; i++)
        _VehicleSnapshot(
          device: devices[i],
          position: positionByDeviceId[devices[i].id],
          fallbackLatLng: gmaps.LatLng(
            fallbackCenter.latitude + (i * 0.018),
            fallbackCenter.longitude + (i.isEven ? i * 0.018 : -i * 0.016),
          ),
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

  String _geocodeKey(_VehicleSnapshot snapshot) {
    final latLng = snapshot.latLng;
    return '${latLng.latitude.toStringAsFixed(6)},'
        '${latLng.longitude.toStringAsFixed(6)}';
  }

  List<_VehicleSnapshot> _filterSnapshots(
    List<_VehicleSnapshot> snapshots,
    _KpiFilter filter,
  ) {
    switch (filter) {
      case _KpiFilter.online:
        return snapshots.where((it) => it.isOnline).toList(growable: false);
      case _KpiFilter.offline:
        return snapshots.where((it) => it.isOffline).toList(growable: false);
      case _KpiFilter.moving:
        return snapshots.where((it) => it.isMoving).toList(growable: false);
      case _KpiFilter.alerts:
        return snapshots.where((it) => it.hasAlert).toList(growable: false);
    }
  }

  List<_OperationalMenuItem> _menuWithRealtimeBadges({
    required int alertCount,
    required int orderCount,
  }) {
    return [
      for (final item in _operationalMenu)
        if (item.id == 'alerts')
          item.copyWith(badge: _badgeText(alertCount))
        else if (item.id == 'orders')
          item.copyWith(badge: _badgeText(orderCount))
        else
          item,
    ];
  }

  String? _badgeText(int value) {
    if (value <= 0) return null;
    return value > 99 ? '99+' : '$value';
  }

  Widget _panelFor(String? id) {
    switch (id) {
      case 'dashboard':
        return const GeneralPanelScreen();
      case 'vehicles':
        return const _TraccarToolsPanel(
          key: ValueKey('monitoring-tools'),
          title: 'Monitoramento',
          entries: [
            _PanelToolEntry(
              label: 'Veículos',
              icon: Icons.directions_car_outlined,
              detail: 'Dispositivos de Rastreamento',
              child: VehiclesScreen(),
            ),
            _PanelToolEntry(
              label: 'Grupos',
              icon: Icons.folder_open_outlined,
              detail: 'Agrupamento operacional',
              child: GroupsScreen(),
            ),
            _PanelToolEntry(
              label: 'Cercas',
              icon: Icons.polyline_outlined,
              detail: 'Geofences',
              child: GeofencesScreen(),
            ),
            _PanelToolEntry(
              label: 'Histórico',
              icon: Icons.history_rounded,
              detail: 'Rotas por período',
              child: HistoryScreen(),
            ),
            _PanelToolEntry(
              label: 'Compartilhar',
              icon: Icons.share_outlined,
              detail: 'Links e envio',
              child: SharingScreen(),
            ),
            _PanelToolEntry(
              label: 'Jornada',
              icon: Icons.fact_check_outlined,
              detail: 'Check-in',
              child: JourneyCheckinScreen(),
            ),
            _PanelToolEntry(
              label: 'Sensores',
              icon: Icons.sensors_outlined,
              detail: 'Atributos reais',
              child: AttributesScreen(),
            ),
          ],
        );
      case 'alerts':
        return const AlertsScreen();
      case 'orders':
        return const ServiceOrdersScreen();
      case 'calls':
        return const CallsScreen();
      case 'clients':
        return const ClientsScreen();
      case 'drivers':
        return const DriversScreen();
      case 'reports':
        return const ReportsScreen();
      case 'finance':
        return const FinanceScreen();
      case 'inventory':
        return const InventoryScreen();
      case 'settings':
        return _TraccarToolsPanel(
          key: const ValueKey('settings-tools'),
          title: 'Configurações',
          entries: [
            _PanelToolEntry(
              label: 'Preferências',
              icon: Icons.settings_outlined,
              child: SettingsScreen(
                onLogout: () => ref.read(sessionProvider.notifier).logout(),
              ),
            ),
            const _PanelToolEntry(
              label: 'Usuários',
              icon: Icons.people_outline,
              detail: 'Contas Traccar',
              child: UsersScreen(),
            ),
            const _PanelToolEntry(
              label: 'Perfis',
              icon: Icons.badge_outlined,
              detail: 'Papéis visuais',
              child: UserProfilesScreen(),
            ),
            const _PanelToolEntry(
              label: 'Permissões',
              icon: Icons.vpn_key_outlined,
              detail: 'Controle local',
              child: PermissionsScreen(),
            ),
            const _PanelToolEntry(
              label: 'Calendários',
              icon: Icons.calendar_month_outlined,
              child: CalendarsScreen(),
            ),
            const _PanelToolEntry(
              label: 'Manutenções',
              icon: Icons.build_outlined,
              child: MaintenanceScreen(),
            ),
            const _PanelToolEntry(
              label: 'Comandos salvos',
              icon: Icons.terminal_outlined,
              detail: 'Envio com confirmação',
              child: CommandsScreen(),
            ),
            const _PanelToolEntry(
              label: 'Servidor',
              icon: Icons.dns_outlined,
              detail: 'Anúncios e versão',
              child: _ServerAnnouncementPanel(),
            ),
          ],
        );
      case 'groups':
        return const GroupsScreen();
      case 'geofences':
        return const GeofencesScreen();
      case 'commands':
        return const CommandsScreen();
      case 'history':
        return const HistoryScreen();
      case 'notifications':
        return const NotificationsScreen();
      case 'journey':
        return const JourneyCheckinScreen();
      case 'sharing':
        return const SharingScreen();
      case 'maintenance':
        return const MaintenanceScreen();
      case 'attributes':
        return const AttributesScreen();
      case 'calendars':
        return const CalendarsScreen();
      case 'statistics':
        return const StatisticsScreen();
      case 'users':
        return const UsersScreen();
      case 'user-profiles':
        return const UserProfilesScreen();
      case 'permissions':
        return const PermissionsScreen();
      case 'assist-create':
        return const AssistCreateRequestScreen();
      case 'demand-control':
        return const DemandControlPanelScreen();
      case 'mdvr':
        return const MdvrDevicesScreen();
      case 'zpro':
        return const ZproCommunicationScreen();
      case 'admin-tenants':
        return const AdminTenantsScreen();
      case 'map':
        return const MapScreen();
      default:
        return const PlaceholderScreen(
          title: 'Painel operacional',
          subtitle: 'Selecione um menu para abrir o painel integrado.',
        );
    }
  }
}

class _OperationalMap extends StatelessWidget {
  const _OperationalMap({
    required this.snapshots,
    required this.selectedDeviceId,
    required this.onMapCreated,
    required this.onCameraMove,
    required this.onMapTap,
    required this.onVehicleTap,
  });

  final List<_VehicleSnapshot> snapshots;
  final int? selectedDeviceId;
  final ValueChanged<gmaps.GoogleMapController> onMapCreated;
  final ValueChanged<gmaps.CameraPosition> onCameraMove;
  final VoidCallback onMapTap;
  final ValueChanged<_VehicleSnapshot> onVehicleTap;

  static const String _darkOperationalMapStyle = '''
[
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit.station","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#d6e2f2"}]},
  {"featureType":"road","elementType":"labels.text.stroke","stylers":[{"color":"#1b2430"},{"weight":3}]},
  {"featureType":"water","stylers":[{"color":"#172a3d"}]},
  {"featureType":"landscape","stylers":[{"saturation":-25},{"lightness":-20}]}
]
''';

  @override
  Widget build(BuildContext context) {
    final initialTarget = snapshots.isEmpty
        ? const gmaps.LatLng(-23.55052, -46.633308)
        : snapshots.first.latLng;
    final selected = snapshots
        .where((snapshot) => snapshot.device.id == selectedDeviceId)
        .cast<_VehicleSnapshot?>()
        .firstOrNull;

    return gmaps.GoogleMap(
      style: _darkOperationalMapStyle,
      initialCameraPosition: gmaps.CameraPosition(
        target: initialTarget,
        zoom: 13,
        tilt: 35,
      ),
      mapType: gmaps.MapType.hybrid,
      trafficEnabled: true,
      buildingsEnabled: true,
      mapToolbarEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      scrollGesturesEnabled: false,
      zoomGesturesEnabled: false,
      onMapCreated: onMapCreated,
      onCameraMove: onCameraMove,
      onTap: (_) => onMapTap(),
      markers: {
        for (final snapshot in snapshots)
          gmaps.Marker(
            markerId: gmaps.MarkerId('vehicle-${snapshot.device.id}'),
            position: snapshot.latLng,
            icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
              snapshot.markerHue,
            ),
            onTap: () => onVehicleTap(snapshot),
          ),
      },
      circles: {
        for (final snapshot in snapshots.where((it) => it.hasAlert))
          gmaps.Circle(
            circleId: gmaps.CircleId('alert-${snapshot.device.id}'),
            center: snapshot.latLng,
            radius: 120,
            fillColor: Colors.redAccent.withValues(alpha: 0.18),
            strokeColor: Colors.redAccent.withValues(alpha: 0.42),
            strokeWidth: 2,
          ),
        if (selected != null)
          gmaps.Circle(
            circleId: gmaps.CircleId('selected-${selected.device.id}'),
            center: selected.latLng,
            radius: 90,
            fillColor: selected.statusColor.withValues(alpha: 0.22),
            strokeColor: selected.statusColor.withValues(alpha: 0.75),
            strokeWidth: 3,
          ),
      },
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
    required this.onMenuTap,
    required this.menuOpen,
    required this.alertCount,
    required this.panelOpen,
    required this.activeTitle,
    required this.activeSubtitle,
    required this.onRefresh,
    required this.onClosePanel,
    required this.profileCompact,
    required this.onProfileTap,
  });

  final WhiteLabelConfig brand;
  final VoidCallback onMenuTap;
  final bool menuOpen;
  final int alertCount;
  final bool panelOpen;
  final String? activeTitle;
  final String activeSubtitle;
  final VoidCallback onRefresh;
  final VoidCallback onClosePanel;
  final bool profileCompact;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final title = activeTitle?.trim().isNotEmpty == true
        ? activeTitle!.trim()
        : 'Operação';

    return Positioned(
      left: 16,
      right: 16,
      top: 16,
      child: _SurfaceGuard(
        child: Row(
          children: [
            _GlassButton(
              tooltip: menuOpen ? 'Fechar menu' : 'Abrir menu',
              icon: menuOpen ? Icons.close_rounded : Icons.apps_rounded,
              onTap: onMenuTap,
            ),
            const SizedBox(width: 10),
            _GlassSurface(
              width: 172,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF37C1A3),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(
                      Icons.navigation_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      brand.appName.replaceAll(' Fleet', 'Tracking'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1F2A44),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _GlassSurface(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: panelOpen
                      ? Row(
                          key: ValueKey('panel-context-$title'),
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
                                    title == 'Ordens de Serviço'
                                        ? 'Ordens de Serviço • Operação integrada'
                                        : '$title • Dados de Rastreamento',
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
                            const SizedBox(width: 4),
                            _TopIcon(
                              icon: Icons.notifications_none_outlined,
                              count: alertCount > 0 ? alertCount : null,
                            ),
                            const SizedBox(width: 8),
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
                        )
                      : Row(
                          key: const ValueKey('global-search'),
                          children: [
                            const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF71819B),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Buscar veículo, placa, motorista...',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Color(0xFF60718D),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            _TopIcon(icon: Icons.layers_outlined, count: null),
                            const SizedBox(width: 8),
                            _TopIcon(
                              icon: Icons.notifications_none_outlined,
                              count: alertCount > 0 ? alertCount : null,
                            ),
                            const SizedBox(width: 8),
                            _TopIcon(
                                icon: Icons.grid_view_rounded, count: null),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onProfileTap,
                child: _GlassSurface(
                  width: profileCompact ? 48 : 138,
                  padding: profileCompact
                      ? EdgeInsets.zero
                      : const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                  child: SizedBox(
                    height: 32,
                    child: profileCompact
                        ? const Center(
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Color(0xFFD7E0ED),
                              child: Icon(
                                Icons.person,
                                color: Color(0xFF52627C),
                                size: 18,
                              ),
                            ),
                          )
                        : const Center(
                            child: Text(
                              'Administrador',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xFF1F2A44),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
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
    required this.items,
    required this.activeId,
    required this.onSelect,
    required this.onLogout,
  });

  final bool open;
  final List<_OperationalMenuItem> items;
  final String? activeId;
  final ValueChanged<_OperationalMenuItem> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      left: open ? 16 : -230,
      top: 74,
      bottom: 18,
      width: 206,
      child: IgnorePointer(
        ignoring: !open,
        child: _SurfaceGuard(
          child: AnimatedOpacity(
            opacity: open ? 1 : 0,
            duration: const Duration(milliseconds: 160),
            child: _GlassSurface(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
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
                          selected: activeId == item.id,
                          onTap: () => onSelect(item),
                        );
                      },
                    ),
                  ),
                  const Divider(color: Color(0xFFE2E8F0)),
                  Row(
                    children: [
                      const Icon(
                        Icons.circle,
                        color: Color(0xFF10B981),
                        size: 14,
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
    required this.selected,
    required this.onTap,
  });

  final _OperationalMenuItem item;
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
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: selected
                ? Border.all(color: const Color(0xFFB7D5FF))
                : Border.all(color: Colors.transparent),
          ),
          child: Row(
            children: [
              Icon(item.icon, color: color, size: 18),
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
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _KpiFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
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
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: _GlassSurface(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          borderColor: selected
              ? const Color(0xFF2D8CFF)
              : Colors.white.withValues(alpha: 0.64),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF2D8CFF)
                      : const Color(0xFFE7EEF8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  filter.icon,
                  size: 16,
                  color: selected ? Colors.white : const Color(0xFF526B8D),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                filter.title,
                style: const TextStyle(
                  color: Color(0xFF25344A),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$value',
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF0B63D8)
                      : const Color(0xFF1F2A44),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
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

class _KpiVehicleList extends StatelessWidget {
  const _KpiVehicleList({
    required this.open,
    required this.title,
    required this.snapshots,
    required this.onVehicleTap,
  });

  final bool open;
  final String title;
  final List<_VehicleSnapshot> snapshots;
  final ValueChanged<_VehicleSnapshot> onVehicleTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      left: open ? 226 : -376,
      top: 126,
      bottom: 18,
      width: 348,
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
                              'Nenhum veículo encontrado',
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
                      '${snapshot.speedLabel} • ${snapshot.ignitionLabel}',
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
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onClose,
  });

  final bool open;
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 760;
    final leftInset = compact ? 16.0 : 238.0;
    final rightInset = compact ? 16.0 : 32.0;
    final availableWidth = screenWidth - leftInset - rightInset;
    final width = availableWidth.clamp(320.0, 1240.0).toDouble();
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
                  SizedBox(
                    height: 68,
                    child: Row(
                      children: [
                        const SizedBox(width: 18),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF176EEB).withValues(alpha: 0.12),
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
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
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
                    text: 'Google Maps híbrido sempre visível.',
                  ),
                  _HighlightItem(
                    icon: Icons.layers_outlined,
                    title: 'Menus translúcidos',
                    text: 'Painéis claros sobre o mapa.',
                  ),
                  _HighlightItem(
                    icon: Icons.speed_rounded,
                    title: 'Tráfego e velocidade',
                    text: 'Tráfego Google + telemetria do veículo.',
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
    required this.onDetails,
    required this.onClose,
  });

  final _VehicleSnapshot snapshot;
  final VoidCallback onDetails;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 270,
      top: 142,
      child: _SurfaceGuard(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 410),
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
                          label: 'Velocidade:',
                          value: snapshot.speedLabel,
                        ),
                        const SizedBox(height: 5),
                        _PopupTextLine(
                          label: 'Último Ponto:',
                          value: snapshot.relativeLastPoint,
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
                              onTap: onDetails,
                            ),
                            const SizedBox(width: 8),
                            _PopupAction(
                              icon: Icons.share_outlined,
                              tooltip: 'Compartilhar',
                              onTap: onDetails,
                            ),
                            const SizedBox(width: 8),
                            _PopupAction(
                              icon: Icons.more_horiz_rounded,
                              tooltip: 'Mais opções',
                              onTap: onDetails,
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
    );
  }
}

class _VehicleBottomBar extends StatelessWidget {
  const _VehicleBottomBar({
    required this.snapshot,
    required this.activeTab,
    required this.onTabChanged,
    required this.onClose,
  });

  final _VehicleSnapshot? snapshot;
  final _VehicleBottomTab activeTab;
  final ValueChanged<_VehicleBottomTab> onTabChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final visible = snapshot != null;
    final width = MediaQuery.sizeOf(context).width;
    final height = width >= 860 ? 336.0 : 460.0;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      left: 48,
      right: 48,
      bottom: visible ? 24 : -height - 28,
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
        final header = SizedBox(
          height: 68,
          child: Row(
            children: [
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Voltar',
                onPressed: onClose,
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF176EEB),
                  size: 18,
                ),
              ),
              _VehicleAvatar(snapshot: snapshot, size: 62, iconSize: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  snapshot.device.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1F2A44),
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onClose,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF60718D),
                ),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Fechar'),
              ),
              const SizedBox(width: 12),
            ],
          ),
        );

        final summary = _BottomStatusCard(snapshot: snapshot);
        final metrics = Wrap(
          spacing: 42,
          runSpacing: 12,
          children: [
            _VehicleMetricPair(label: 'Velocidade', value: snapshot.speedLabel),
            _VehicleMetricPair(label: 'Ignição', value: snapshot.ignitionLabel),
            _VehicleMetricPair(label: 'Bateria', value: snapshot.batteryLabel),
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
                  const SizedBox(height: 14),
                  tabBar,
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
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 260, child: summary),
                        const SizedBox(width: 30),
                        Expanded(child: metrics),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: tabBar,
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
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
          detail: 'Espaço pronto para fotos, MDVR e evidências do dispositivo.',
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
        title: 'Localização Atual',
        icon: Icons.place_outlined,
        body: snapshot.address,
        action: 'Ver no mapa',
      ),
      _DetailCard(
        title: 'Últimos Eventos',
        icon: Icons.timeline_outlined,
        body: snapshot.eventsSummary,
      ),
      _SpeedChartCard(snapshot: snapshot),
      _DetailCard(
        title: 'Informações',
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
          title: 'Informações do veículo',
          icon: Icons.badge_outlined,
          body:
              'Modelo   ${snapshot.modelLabel}\nMotorista ${snapshot.driverName}\nIgnição  ${snapshot.ignitionLabel}\nBateria  ${snapshot.batteryLabel}',
        ),
        const SizedBox(height: 10),
        _DetailCard(
          title: 'Sensores',
          icon: Icons.sensors_outlined,
          body: snapshot.sensorSummary,
        ),
      ],
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
            'Essa ação será executada no Traccar real.',
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
  switch (normalized) {
    case 'deviceOnline':
      return 'Dispositivo online';
    case 'deviceOffline':
      return 'Dispositivo offline';
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
            'Último Ponto: ${snapshot.relativeLastPoint}',
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
  overview('Visão Geral', Icons.dashboard_customize_outlined),
  photos('Fotos', Icons.image_outlined),
  commands('Comandos', Icons.terminal_rounded),
  chart('Gráfico', Icons.show_chart_outlined),
  info('Informações', Icons.info_outline_rounded);

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
                  'Velocidade (últimas 2 horas)',
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
                  snapshot.speed.clamp(10, 95).toDouble(),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xEEF7F9FD),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.68),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF183153).withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 10),
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
            child: SizedBox(
              width: 46,
              height: 46,
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
        Icon(icon, color: const Color(0xFF71819B), size: 20),
        if (count != null)
          Positioned(
            right: -5,
            top: -7,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Color(0xFFFF4D61),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
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
        title: 'Nenhuma opção disponível',
        detail: 'Este painel ainda não possui ferramentas configuradas.',
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
              detail: 'O Traccar não retornou tipos de notificação agora.',
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

class _ServerAnnouncementPanel extends ConsumerWidget {
  const _ServerAnnouncementPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverAsync = ref.watch(serverProvider);
    final timezonesAsync = ref.watch(timezonesProvider);
    return serverAsync.when(
      data: (server) {
        final announcement = '${server?['announcement'] ?? ''}'.trim();
        final version = '${server?['version'] ?? '-'}';
        final readonly = server?['readonly'] == true ? 'Sim' : 'Não';
        final deviceReadonly =
            server?['deviceReadonly'] == true ? 'Sim' : 'Não';
        final timezones = timezonesAsync.valueOrNull ?? const <String>[];
        return ListView(
          children: [
            _SimpleToolRow(
              icon: Icons.dns_outlined,
              title: 'Servidor Traccar',
              detail: 'Versão $version',
            ),
            const SizedBox(height: 8),
            _SimpleToolRow(
              icon: Icons.lock_outline,
              title: 'Modo leitura',
              detail: 'Sistema: $readonly • Dispositivos: $deviceReadonly',
            ),
            const SizedBox(height: 8),
            _SimpleToolRow(
              icon: Icons.campaign_outlined,
              title: 'Anúncio',
              detail: announcement.isEmpty
                  ? 'Sem anúncio configurado no servidor.'
                  : announcement,
            ),
            const SizedBox(height: 8),
            _SimpleToolRow(
              icon: Icons.public_outlined,
              title: 'Fusos disponíveis',
              detail: '${timezones.length} opções retornadas pelo Traccar',
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
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
    return _FleetKpis(
      online: snapshots.where((it) => it.isOnline).length,
      offline: snapshots.where((it) => it.isOffline).length,
      moving: snapshots.where((it) => it.isMoving).length,
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
  const _VehicleSnapshot({
    required this.device,
    required this.position,
    required this.fallbackLatLng,
    required this.index,
    this.resolvedAddress,
    this.recentEvents = const [],
  });

  final TraccarDevice device;
  final TraccarPosition? position;
  final gmaps.LatLng fallbackLatLng;
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
      fallbackLatLng: fallbackLatLng,
      index: index,
      resolvedAddress: resolvedAddress ?? this.resolvedAddress,
      recentEvents: recentEvents ?? this.recentEvents,
    );
  }

  gmaps.LatLng get latLng {
    final current = position;
    if (current == null) return fallbackLatLng;
    return gmaps.LatLng(current.latitude, current.longitude);
  }

  String get normalizedStatus => device.status.toLowerCase().trim();

  bool get isOnline => normalizedStatus == 'online';

  bool get isOffline => normalizedStatus == 'offline';

  double get speed => position?.speed ?? (index.isEven ? 48 : 0);

  bool get isMoving => speed > 1;

  bool get ignition {
    final value = position?.attributes?['ignition'] ??
        device.attributes?['ignition'] ??
        device.attributes?['ignitionOn'];
    if (value is bool) return value;
    if (value is num) return value > 0;
    if (value is String) {
      final normalized = value.toLowerCase().trim();
      return normalized == 'true' ||
          normalized == 'on' ||
          normalized == 'ligada' ||
          normalized == '1';
    }
    return isMoving || isOnline;
  }

  bool get hasAlert =>
      isOffline || normalizedStatus == 'unknown' || speed >= 80;

  String get statusLabel {
    if (hasAlert && speed >= 80) return 'Alta velocidade';
    if (isMoving) return 'Em Movimento';
    if (isOnline) return 'Online';
    if (isOffline) return 'Offline';
    return 'Indefinido';
  }

  Color get statusColor {
    if (hasAlert && speed >= 80) return const Color(0xFFE74B4B);
    if (isMoving || isOnline) return const Color(0xFF10B981);
    if (isOffline) return const Color(0xFFE74B4B);
    return const Color(0xFFF59E0B);
  }

  double get markerHue {
    if (hasAlert && speed >= 80) return gmaps.BitmapDescriptor.hueRed;
    if (isMoving || isOnline) return gmaps.BitmapDescriptor.hueGreen;
    if (isOffline) return gmaps.BitmapDescriptor.hueOrange;
    return gmaps.BitmapDescriptor.hueAzure;
  }

  double get mapBearing => (index * 34) % 360;

  String get speedLabel => '${speed.toStringAsFixed(0)} km/h';

  String get ignitionLabel => ignition ? 'Ligada' : 'Desligada';

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
    return text?.isNotEmpty == true ? text! : '12.6 V';
  }

  String get driverName {
    final value = device.attributes?['driver'] ??
        device.attributes?['driverName'] ??
        device.attributes?['motorista'];
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'João Almeida' : text;
  }

  String get modelLabel {
    final value = device.attributes?['model'] ??
        device.attributes?['vehicleModel'] ??
        device.category;
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'Fiat Ducato' : text;
  }

  String get address {
    final value = resolvedAddress ??
        position?.address ??
        position?.attributes?['address'] ??
        device.attributes?['address'] ??
        device.attributes?['lastAddress'];
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
    return 'Av. Paulista, 1723\nSão Paulo - SP';
  }

  String get eventsSummary {
    if (recentEvents.isEmpty) {
      return 'Sem eventos recentes\nÚltimo ponto $relativeLastPoint\n${hasAlert ? 'Status exige atenção' : 'Operação normal'}';
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
    final source = device.lastUpdate ?? position?.fixTime;
    final parsed = source == null ? null : DateTime.tryParse(source);
    if (parsed == null) return 'há 2 min';
    final diff = DateTime.now().difference(parsed.toLocal());
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours} h';
    return 'há ${diff.inDays} dias';
  }

  String get sensorSummary {
    final attrs = {
      ...?device.attributes,
      ...?position?.attributes,
    };
    if (attrs.isEmpty) return 'Combustível 75%, GPS excelente';
    final keys = attrs.keys.take(4).join(', ');
    return keys.isEmpty ? 'Combustível 75%, GPS excelente' : keys;
  }
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
    icon: Icons.home_outlined,
  ),
  _OperationalMenuItem(id: 'map', label: 'Mapa', icon: Icons.map_outlined),
  _OperationalMenuItem(
    id: 'vehicles',
    label: 'Veículos',
    icon: Icons.directions_car_outlined,
  ),
  _OperationalMenuItem(
    id: 'alerts',
    label: 'Alertas',
    icon: Icons.warning_amber_outlined,
    badge: '12',
  ),
  _OperationalMenuItem(
    id: 'orders',
    label: 'Ordens de Serviço',
    icon: Icons.assignment_outlined,
  ),
  _OperationalMenuItem(
    id: 'calls',
    label: 'Chamados',
    icon: Icons.support_agent_outlined,
  ),
  _OperationalMenuItem(
    id: 'clients',
    label: 'Clientes',
    icon: Icons.groups_2_outlined,
  ),
  _OperationalMenuItem(
    id: 'drivers',
    label: 'Motoristas',
    icon: Icons.badge_outlined,
  ),
  _OperationalMenuItem(
    id: 'reports',
    label: 'Relatórios',
    icon: Icons.insert_chart_outlined,
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
    id: 'settings',
    label: 'Configurações',
    icon: Icons.settings_outlined,
  ),
];
