import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../core/white_label.dart';
import '../../data/bridge_client.dart';
import '../../data/models.dart';
import '../../data/openf1_client.dart';
import '../../state/session_state.dart';
import '../../widgets/status_pill.dart';
import '../admin/admin_tenants_screen.dart';
import '../alerts/alerts_screen.dart';
import '../attributes/attributes_screen.dart';
import '../business/business_reference_screens.dart';
import '../calls/calls_screen.dart';
import '../communication/zpro_communication_screen.dart';
import '../common/placeholder_screen.dart';
import '../clients/clients_screen.dart';
import '../drivers/drivers_screen.dart';
import '../finance/finance_screen.dart';
import '../geofences/geofences_screen.dart';
import '../groups/groups_screen.dart';
import '../history/history_screen.dart';
import '../inventory/inventory_screen.dart';
import '../map/map_screen.dart';
import '../notifications/notifications_screen.dart';
import '../permissions/permissions_screen.dart';
import '../reports/reports_screen.dart';
import '../routes/routes_screen.dart';
import '../settings/settings_screen.dart';
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
          if (snapshots.isEmpty && !_activePanelVisible)
            const Positioned.fill(
              child: _NoVehiclesMapHint(),
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
        return 'Visao geral da operacao';
      case 'map':
        return 'Monitoramento em tempo real';
      case 'vehicles':
        return 'Cadastro e ciclo de vida da frota';
      case 'routes':
        return 'Historico, replay e quilometragem';
      case 'alerts':
        return 'Eventos, regras e notificacoes';
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
        return 'Demonstracao de telemetria';
      case 'reports':
        return 'Relatórios operacionais e executivos';
      case 'automations':
        return 'Regras e gatilhos automaticos';
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
    required int alertCount,
    required int orderCount,
  }) {
    return [
      for (final item in _operationalMenu)
        if (item.id == 'alerts')
          item.copyWith(badge: _badgeText(alertCount))
        else if (item.id == 'tickets')
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
        return _buildDashboardPanel();
      case 'map':
        return _buildMapPanel();
      case 'vehicles':
        return _buildVehiclesPanel();
      case 'routes':
        return _buildRoutesPanel();
      case 'alerts':
        return _buildAlertsPanel();
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
      entries: [
        const _PanelToolEntry(
          label: 'Mapa em tempo real',
          icon: Icons.map_outlined,
          detail: 'Base SouTracking ativa',
          child: MapScreen(),
        ),
        const _PanelToolEntry(
          label: 'Veiculos no mapa',
          icon: Icons.pin_drop_outlined,
          detail: 'Posicionamento ao vivo',
          child: MapScreen(),
        ),
        ..._placeholderEntries(
          moduleTitle: 'Mapa',
          items: const [
            (
              label: 'Puxar localizacao',
              icon: Icons.my_location_outlined,
              description:
                  'Acao rapida para solicitar posicao atual do veiculo.',
            ),
            (
              label: 'Criar alerta',
              icon: Icons.add_alert_outlined,
              description:
                  'Criacao visual de alerta contextual a partir do mapa.',
            ),
            (
              label: 'Abrir chamado',
              icon: Icons.confirmation_number_outlined,
              description: 'Atalho para abrir chamado com contexto da posicao.',
            ),
            (
              label: 'Enviar WhatsApp',
              icon: Icons.forum_outlined,
              description:
                  'Fluxo visual de envio de mensagem para cliente e motorista.',
            ),
            (
              label: 'Ver cameras',
              icon: Icons.videocam_outlined,
              description:
                  'Atalho para visualizar cameras associadas ao veiculo.',
            ),
            (
              label: 'Camadas do mapa',
              icon: Icons.layers_outlined,
              description: 'Controle de camadas e filtros de exibicao no mapa.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVehiclesPanel() {
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
          moduleTitle: 'Veiculos',
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

  Widget _buildRoutesPanel() {
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
          detail: 'Estrutura criada',
          child: _ModulePlaceholderScreen(
            moduleTitle: 'Rotas',
            submenuTitle: 'Replay',
            description: 'Estrutura visual criada e padronizada.',
          ),
        ),
        ..._placeholderEntries(
          moduleTitle: 'Rotas',
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
          moduleTitle: 'Alertas',
          items: const [
            (
              label: 'Excesso de velocidade',
              icon: Icons.speed_outlined,
              description: 'Monitoramento visual de limites de velocidade.',
            ),
            (
              label: 'Ignição',
              icon: Icons.power_settings_new_outlined,
              description: 'Eventos de ignição ligada e desligada.',
            ),
            (
              label: 'Entrada/saída de cerca',
              icon: Icons.fence_outlined,
              description: 'Alertas de cruzamento de geofence.',
            ),
            (
              label: 'Sem comunicação',
              icon: Icons.portable_wifi_off_outlined,
              description: 'Detecção de perda de comunicação com rastreador.',
            ),
            (
              label: 'Bateria baixa',
              icon: Icons.battery_alert_outlined,
              description: 'Fila de dispositivos com bateria crítica.',
            ),
            (
              label: 'Botão de pânico',
              icon: Icons.sos_outlined,
              description: 'Canal de emergência com prioridade alta.',
            ),
            (
              label: 'Jammer/suspeita',
              icon: Icons.gps_not_fixed_outlined,
              description: 'Indicadores visuais de interferência ou jammer.',
            ),
            (
              label: 'Alertas por WhatsApp',
              icon: Icons.forum_outlined,
              description: 'Painel para regras de envio por WhatsApp.',
            ),
            (
              label: 'Regras de alerta',
              icon: Icons.rule_folder_outlined,
              description: 'Configuração visual de regras operacionais.',
            ),
          ],
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
          moduleTitle: 'Cercas',
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
              description: 'Criação guiada usando endereço como referência.',
            ),
            (
              label: 'Criar cerca por raio',
              icon: Icons.radio_button_checked_outlined,
              description: 'Definição de cerca circular por raio.',
            ),
            (
              label: 'Cerca residencial',
              icon: Icons.home_work_outlined,
              description: 'Modelo rápido para cercas residenciais.',
            ),
            (
              label: 'Cerca comercial',
              icon: Icons.storefront_outlined,
              description: 'Modelo rápido para cercas comerciais.',
            ),
            (
              label: 'Area de risco',
              icon: Icons.report_problem_outlined,
              description: 'Classificação visual de zonas de risco.',
            ),
            (
              label: 'Area permitida',
              icon: Icons.check_circle_outline,
              description: 'Classificação visual de zonas permitidas.',
            ),
            (
              label: 'Cerca inteligente via IA',
              icon: Icons.psychology_outlined,
              description: 'Estrutura para sugestão automática de cercas.',
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
          moduleTitle: 'Chamados',
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
          moduleTitle: 'Comunicacao',
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
      entries: _placeholderEntries(
        moduleTitle: 'IA Operacional',
        items: const [
          (
            label: 'Criar alerta por IA',
            icon: Icons.auto_awesome_outlined,
            description: 'Assistente para criacao automatica de alertas.',
          ),
          (
            label: 'Criar cerca por IA',
            icon: Icons.psychology_outlined,
            description: 'Assistente para sugestao de cercas.',
          ),
          (
            label: 'Criar relatorio por IA',
            icon: Icons.analytics_outlined,
            description: 'Geracao assistida de relatorios.',
          ),
          (
            label: 'Criar chamado por IA',
            icon: Icons.support_outlined,
            description: 'Abertura assistida de chamados.',
          ),
          (
            label: 'Resumo diario',
            icon: Icons.calendar_view_day_outlined,
            description: 'Resumo diario da operacao com IA.',
          ),
          (
            label: 'Diagnostico de risco',
            icon: Icons.monitor_heart_outlined,
            description: 'Analise de risco com recomendacoes.',
          ),
          (
            label: 'Sugestao de acao',
            icon: Icons.tips_and_updates_outlined,
            description: 'Sugestoes de acao priorizadas para operacao.',
          ),
          (
            label: 'Regras inteligentes',
            icon: Icons.rule_outlined,
            description: 'Motor visual para regras inteligentes.',
          ),
        ],
      ),
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
          moduleTitle: 'Financeiro',
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
      title: 'Demo Telemetria',
      entries: [
        const _PanelToolEntry(
          label: 'Painel demo',
          icon: Icons.dashboard_customize_outlined,
          detail: 'Sessao travada para apresentacao',
          child: _TelemetryDemoScreen(),
        ),
        ..._placeholderEntries(
          moduleTitle: 'Demo Telemetria',
          items: const [
            (
              label: 'OpenF1',
              icon: Icons.sports_motorsports_outlined,
              description: 'Estrutura visual para integracao OpenF1.',
            ),
            (
              label: 'Corrida real travada',
              icon: Icons.flag_outlined,
              description: 'Cenario demo de corrida fixa para apresentacao.',
            ),
            (
              label: 'Mapa do circuito',
              icon: Icons.track_changes_outlined,
              description: 'Visualizacao do circuito em mapa dedicado.',
            ),
            (
              label: 'Evento clicavel',
              icon: Icons.touch_app_outlined,
              description: 'Interacao visual com eventos da corrida.',
            ),
            (
              label: 'Telemetria avancada',
              icon: Icons.insights_outlined,
              description: 'Cards de telemetria com metricas simuladas.',
            ),
            (
              label: 'Relatorio travado',
              icon: Icons.article_outlined,
              description: 'Relatorio demonstrativo com dados fixos.',
            ),
            (
              label: 'Replay da sessao',
              icon: Icons.replay_outlined,
              description: 'Fluxo visual de replay da sessao.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReportsPanel() {
    return _TraccarToolsPanel(
      key: const ValueKey('reports-tools'),
      title: 'Relatórios',
      entries: [
        const _PanelToolEntry(
          label: 'Rotas',
          icon: Icons.route_outlined,
          detail: 'Relatórios atuais',
          child: ReportsScreen(),
        ),
        ..._placeholderEntries(
          moduleTitle: 'Relatórios',
          items: const [
            (
              label: 'Viagens',
              icon: Icons.luggage_outlined,
              description: 'Relatório de viagens por período.',
            ),
            (
              label: 'Paradas',
              icon: Icons.pause_circle_outline,
              description: 'Relatório de paradas e tempos de espera.',
            ),
            (
              label: 'Eventos',
              icon: Icons.event_note_outlined,
              description: 'Relatório consolidado de eventos.',
            ),
            (
              label: 'Resumo',
              icon: Icons.summarize_outlined,
              description: 'Resumo executivo para gestão.',
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
      entries: _placeholderEntries(
        moduleTitle: 'Automacoes',
        items: const [
          (
            label: 'Regras automaticas',
            icon: Icons.rule_folder_outlined,
            description: 'Cadastro visual de regras automaticas.',
          ),
          (
            label: 'Gatilhos',
            icon: Icons.flash_on_outlined,
            description: 'Definicao visual de gatilhos de execucao.',
          ),
          (
            label: 'Acoes',
            icon: Icons.playlist_add_check_outlined,
            description: 'Catalogo visual de acoes automatizadas.',
          ),
          (
            label: 'Webhooks',
            icon: Icons.webhook_outlined,
            description: 'Estrutura visual de webhooks e endpoints.',
          ),
          (
            label: 'Alertas automaticos',
            icon: Icons.notification_important_outlined,
            description: 'Automacao de envio de alertas.',
          ),
          (
            label: 'WhatsApp automatico',
            icon: Icons.forum_outlined,
            description: 'Automacao de mensagens por WhatsApp.',
          ),
          (
            label: 'Criacao automatica de chamado',
            icon: Icons.add_box_outlined,
            description: 'Abertura automatica de chamados por evento.',
          ),
          (
            label: 'Relatorios automaticos',
            icon: Icons.description_outlined,
            description: 'Agendamento automatico de relatorios.',
          ),
          (
            label: 'Integracao MackFlow/Bridge futuramente',
            icon: Icons.link_outlined,
            description: 'Integracao sera plugada em etapa futura.',
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPanel() {
    return _TraccarToolsPanel(
      key: const ValueKey('settings-tools'),
      title: 'Configurações',
      entries: [
        const _PanelToolEntry(
          label: 'Usuários',
          icon: Icons.people_outline,
          detail: 'Gestão de contas',
          child: UsersScreen(),
        ),
        const _PanelToolEntry(
          label: 'Permissões',
          icon: Icons.vpn_key_outlined,
          detail: 'Controle de acesso',
          child: PermissionsScreen(),
        ),
        const _PanelToolEntry(
          label: 'Grupos',
          icon: Icons.folder_shared_outlined,
          detail: 'Organização operacional',
          child: GroupsScreen(),
        ),
        _placeholderEntry(
          moduleTitle: 'Configurações',
          label: 'Dispositivos',
          icon: Icons.gps_fixed_outlined,
          description: 'Estrutura visual de cadastro de dispositivos.',
        ),
        const _PanelToolEntry(
          label: 'Motoristas',
          icon: Icons.badge_outlined,
          detail: 'Cadastro de motoristas',
          child: DriversScreen(),
        ),
        const _PanelToolEntry(
          label: 'Notificações',
          icon: Icons.notifications_outlined,
          detail: 'Preferências de alerta',
          child: NotificationsScreen(),
        ),
        const _PanelToolEntry(
          label: 'Servidor de rastreamento',
          icon: Icons.dns_outlined,
          detail: 'Servidor e anúncios',
          child: _ServerAnnouncementPanel(),
        ),
      ],
    );
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

  @override
  Widget build(BuildContext context) {
    final title = activeTitle?.trim().isNotEmpty == true
        ? activeTitle!.trim()
        : 'OperaÃ§Ã£o';
    final brandName =
        brand.appName.trim().isEmpty ? 'SouTracking' : brand.appName.trim();
    final brandLogoAsset = brand.logoAsset?.trim() ?? '';
    final hasBrandLogo = brandLogoAsset.isNotEmpty;

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
              width: hasBrandLogo ? 228 : 172,
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.asset(
                        'assets/branding/soutracking_icon_lamp.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.navigation_rounded,
                            color: Colors.white,
                            size: 16,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: hasBrandLogo
                        ? Image.asset(
                            brandLogoAsset,
                            height: 22,
                            fit: BoxFit.contain,
                            alignment: Alignment.centerLeft,
                            errorBuilder: (context, error, stackTrace) {
                              return Text(
                                brandName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF1F2A44),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              );
                            },
                          )
                        : Text(
                            brandName,
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
                                    title == 'Ordens de ServiÃ§o'
                                        ? 'Ordens de Servico - Operacao integrada'
                                        : '$title - Dados de Rastreamento',
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
                                'Buscar veiculo, placa, motorista...',
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
            const _ProfileMenuButton(),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuButton extends StatelessWidget {
  const _ProfileMenuButton();

  static const List<({String id, String label, IconData icon})> _profileItems =
      [
    (id: 'my-profile', label: 'Meu perfil', icon: Icons.person_outline),
    (id: 'account-data', label: 'Dados da conta', icon: Icons.badge),
    (id: 'change-password', label: 'Trocar senha', icon: Icons.lock_reset),
    (id: 'preferences', label: 'Preferencias', icon: Icons.tune_outlined),
    (
      id: 'notifications',
      label: 'Notificacoes',
      icon: Icons.notifications_outlined,
    ),
    (
      id: 'theme',
      label: 'Tema / Aparencia',
      icon: Icons.palette_outlined,
    ),
    (
      id: 'company-unit',
      label: 'Empresa / Unidade',
      icon: Icons.apartment_outlined,
    ),
    (
      id: 'account-integrations',
      label: 'Integracoes da conta',
      icon: Icons.extension_outlined,
    ),
    (id: 'help', label: 'Ajuda', icon: Icons.help_outline),
    (id: 'logout', label: 'Sair', icon: Icons.logout_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final labelById = {
      for (final item in _profileItems) item.id: item.label,
    };

    return PopupMenuButton<String>(
      tooltip: 'Menu do perfil',
      onSelected: (value) {
        final label = labelById[value] ?? value;
        final message = value == 'logout'
            ? 'Acao visual: Sair (sem backend nesta etapa).'
            : '$label: estrutura criada. Integracao sera plugada em etapa futura.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
      itemBuilder: (context) {
        final regularItems = _profileItems.where((item) => item.id != 'logout');
        return [
          for (final item in regularItems)
            PopupMenuItem<String>(
              value: item.id,
              child: Row(
                children: [
                  Icon(item.icon, size: 18, color: const Color(0xFF52627C)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item.label)),
                ],
              ),
            ),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'logout',
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
        width: 186,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: const [
            CircleAvatar(
              radius: 15,
              backgroundColor: Color(0xFFD7E0ED),
              child: Icon(
                Icons.person,
                color: Color(0xFF52627C),
                size: 17,
              ),
            ),
            SizedBox(width: 9),
            Expanded(
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
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF52627C),
              size: 20,
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
                      '${snapshot.speedLabel} â€¢ ${snapshot.ignitionLabel}',
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
                    text: 'Google Maps hÃ­brido sempre visÃ­vel.',
                  ),
                  _HighlightItem(
                    icon: Icons.layers_outlined,
                    title: 'Menus translÃºcidos',
                    text: 'PainÃ©is claros sobre o mapa.',
                  ),
                  _HighlightItem(
                    icon: Icons.speed_rounded,
                    title: 'TrÃ¡fego e velocidade',
                    text: 'TrÃ¡fego Google + telemetria do veÃ­culo.',
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
                              tooltip: 'Mais opÃ§Ãµes',
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
            _VehicleMetricPair(
                label: 'IgniÃ§Ã£o', value: snapshot.ignitionLabel),
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
          detail:
              'EspaÃ§o pronto para fotos, MDVR e evidÃªncias do dispositivo.',
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
        title: 'LocalizaÃ§Ã£o Atual',
        icon: Icons.place_outlined,
        body: snapshot.address,
        action: 'Ver no mapa',
      ),
      _DetailCard(
        title: 'Ãšltimos Eventos',
        icon: Icons.timeline_outlined,
        body: snapshot.eventsSummary,
      ),
      _SpeedChartCard(snapshot: snapshot),
      _DetailCard(
        title: 'InformaÃ§Ãµes',
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
          title: 'InformaÃ§Ãµes do veÃ­culo',
          icon: Icons.badge_outlined,
          body:
              'Modelo   ${snapshot.modelLabel}\nMotorista ${snapshot.driverName}\nIgniÃ§Ã£o  ${snapshot.ignitionLabel}\nBateria  ${snapshot.batteryLabel}',
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
      ('positionSingle', Icons.my_location_outlined, 'PosiÃ§Ã£o'),
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
      return 'IgniÃ§Ã£o ligada';
    case 'ignitionOff':
      return 'IgniÃ§Ã£o desligada';
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
            'Ãšltimo Ponto: ${snapshot.relativeLastPoint}',
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
  overview('VisÃ£o Geral', Icons.dashboard_customize_outlined),
  photos('Fotos', Icons.image_outlined),
  commands('Comandos', Icons.terminal_rounded),
  chart('GrÃ¡fico', Icons.show_chart_outlined),
  info('InformaÃ§Ãµes', Icons.info_outline_rounded);

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
                  'Velocidade (Ãºltimas 2 horas)',
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
                      'Acelerador ${selectedEvent.throttle}% • Freio ${selectedEvent.brake}% • Temp ${selectedEvent.temperatureC}C',
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
                  'GPS 23°42\'45.8"S   46°41\'19.6"W',
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
        title: 'Nenhuma opÃ§Ã£o disponÃ­vel',
        detail: 'Este painel ainda nÃ£o possui ferramentas configuradas.',
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
              title: 'Servidor de rastreamento',
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
              detail:
                  '${timezones.length} opções retornadas pelo servidor de rastreamento',
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

  bool get hasPosition => position != null;

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
    final current = position;
    if (current == null) return 'Nao informado';
    return '${current.latitude.toStringAsFixed(6)}, '
        '${current.longitude.toStringAsFixed(6)}';
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
          'Ultima comunicacao: ${relativeLastPoint == 'Nao informado' ? 'Nao informado' : relativeLastPoint}';
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
    if (diff.inMinutes < 60) return 'hÃ¡ ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hÃ¡ ${diff.inHours} h';
    return 'hÃ¡ ${diff.inDays} dias';
  }

  String get sensorSummary {
    final attrs = {
      ...?device.attributes,
      ...?position?.attributes,
    };
    if (attrs.isEmpty) return 'Nao informado';
    final keys = attrs.keys.take(4).join(', ');
    return keys.isEmpty ? 'Nao informado' : keys;
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
    label: 'Demo Telemetria',
    icon: Icons.sports_motorsports_outlined,
  ),
  _OperationalMenuItem(
    id: 'reports',
    label: 'Relatórios',
    icon: Icons.insert_chart_outlined,
  ),
  _OperationalMenuItem(
    id: 'automations',
    label: 'Automacoes',
    icon: Icons.bolt_outlined,
  ),
  _OperationalMenuItem(
    id: 'settings',
    label: 'Configurações',
    icon: Icons.settings_outlined,
  ),
];
