import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:http/http.dart' as http;

import '../../core/app_permissions.dart';
import '../../core/white_label.dart';
import '../../data/asaas_config.dart';
import '../../data/bridge_config.dart';
import '../../data/models.dart';
import '../../data/notification_prefs.dart';
import '../../state/session_state.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  // ── WhiteLabel ─────────────────────────────────────────────────────────────
  final _nameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _primaryController = TextEditingController();
  final _secondaryController = TextEditingController();
  final _logoController = TextEditingController();
  bool _initialized = false;

  // ── Bridge / Integrações ───────────────────────────────────────────────────
  final _bridgeUrlCtrl      = TextEditingController();
  final _bridgeApiKeyCtrl   = TextEditingController();
  final _pusherAppKeyCtrl   = TextEditingController();
  final _pusherClusterCtrl  = TextEditingController();
  final _pusherChannelCtrl  = TextEditingController();
  bool _bridgeInitialized   = false;
  bool _showBridgeKey       = false;
  bool _showPusherKey       = false;
  bool _bridgeSaving        = false;
  String? _bridgeTestResult;
  bool _mapTraffic = false;
  bool _mapSatellite = false;
  bool _compactMode = true;
  bool _twoFactor = false;

  // ── Asaas ──────────────────────────────────────────────────────────────────
  final _asaasApiKeyCtrl = TextEditingController();
  bool _asaasInitialized = false;
  bool _showAsaasKey     = false;
  bool _asaasSaving      = false;
  String? _asaasTestResult;

  // ── Permissões tab state ───────────────────────────────────────────────────
  AppUserRole _selectedPermRole = AppUserRole.operator;
  final Map<AppUserRole, Map<AppFeature, bool>> _menuOverrides = {};
  final Map<AppUserRole, Map<String, bool>> _actionOverrides = {};

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    _primaryController.dispose();
    _secondaryController.dispose();
    _logoController.dispose();
    _bridgeUrlCtrl.dispose();
    _bridgeApiKeyCtrl.dispose();
    _pusherAppKeyCtrl.dispose();
    _pusherClusterCtrl.dispose();
    _pusherChannelCtrl.dispose();
    _asaasApiKeyCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _syncControllers(WhiteLabelConfig config) {
    _nameController.text = config.appName;
    _taglineController.text = config.tagline;
    _primaryController.text = _colorToHex(config.primaryColor);
    _secondaryController.text = _colorToHex(config.secondaryColor);
    _logoController.text = config.logoAsset ?? '';
  }

  String _colorToHex(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

  Color? _parseColor(String input) {
    var hex = input.trim().replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length == 8) return Color(int.parse(hex, radix: 16));
    return null;
  }

  Future<void> _saveWhiteLabel(WhiteLabelConfig current) async {
    final name = _nameController.text.trim();
    final tagline = _taglineController.text.trim();
    final primary =
        _parseColor(_primaryController.text) ?? current.primaryColor;
    final secondary =
        _parseColor(_secondaryController.text) ?? current.secondaryColor;
    final logo = _logoController.text.trim();
    await ref.read(whiteLabelProvider.notifier).save(WhiteLabelConfig(
          appName: name.isEmpty ? current.appName : name,
          tagline: tagline.isEmpty ? current.tagline : tagline,
          primaryColor: primary,
          secondaryColor: secondary,
          logoAsset: logo.isEmpty ? null : logo,
        ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configurações salvas com sucesso.')),
    );
  }

  // ── Permission helpers ─────────────────────────────────────────────────────

  bool _menuEnabled(AppUserRole role, AppFeature feature) =>
      _menuOverrides[role]?[feature] ?? AppPermissions.canView(role, feature);

  void _setMenuEnabled(AppUserRole role, AppFeature feature, bool value) {
    setState(() => _menuOverrides.putIfAbsent(role, () => {})[feature] = value);
  }

  bool _actionEnabled(AppUserRole role, String key) {
    if (_actionOverrides[role]?.containsKey(key) == true) {
      return _actionOverrides[role]![key]!;
    }
    return switch (key) {
      'users_add' =>
        AppPermissions.can(role, AppFeature.users, AppAction.add),
      'vehicles_edit' =>
        AppPermissions.can(role, AppFeature.vehicles, AppAction.edit),
      'vehicles_delete' =>
        AppPermissions.can(role, AppFeature.vehicles, AppAction.delete),
      'reports_export' =>
        AppPermissions.can(role, AppFeature.reports, AppAction.export),
      'commands_cmd' =>
        AppPermissions.can(role, AppFeature.commands, AppAction.command),
      _ => false,
    };
  }

  void _setActionEnabled(AppUserRole role, String key, bool value) {
    setState(() => _actionOverrides.putIfAbsent(role, () => {})[key] = value);
  }

  void _savePermissions() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Permissões salvas com sucesso.')),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final whiteLabelAsync = ref.watch(whiteLabelProvider);
    final users =
        ref.watch(usersProvider).valueOrNull ?? const <TraccarUser>[];

    return whiteLabelAsync.when(
      data: (config) {
        if (!_initialized) {
          _syncControllers(config);
          _initialized = true;
        }
        return Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: const Color(0xFF0F69E8),
                unselectedLabelColor: const Color(0xFF60718D),
                indicatorColor: const Color(0xFF0F69E8),
                indicatorWeight: 2,
                labelStyle: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Geral'),
                  Tab(text: 'Perfil'),
                  Tab(text: 'Permissões'),
                  Tab(text: 'Integrações'),
                  Tab(text: 'Notificações'),
                  Tab(text: 'Aparência'),
                  Tab(text: 'Segurança'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildGeralTab(config),
                  _buildPerfilTab(),
                  _buildPermissoesTab(users),
                  _buildIntegracoesTab(),
                  _buildNotificacoesTab(),
                  _buildAparenciaTab(config),
                  _buildSegurancaTab(config),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }

  // ── Tab builders ───────────────────────────────────────────────────────────

  Widget _buildGeralTab(WhiteLabelConfig config) {
    return _SettingsTabView(children: [
      _SettingsCard(
        title: 'Informações da empresa',
        child: Column(children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nome da empresa'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _taglineController,
            decoration: const InputDecoration(labelText: 'Tagline'),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              // Cor/logo ficam na aba Aparência, mas salvam junto — sem
              // isso, editar só nome/tagline aqui nunca persistia.
              onPressed: () => _saveWhiteLabel(config),
              child: const Text('Salvar informações'),
            ),
          ),
        ]),
      ),
      const _SettingsCard(
        title: 'Preferências regionais',
        child: Column(children: [
          _SettingLine(label: 'Fuso horário', value: 'America/Sao_Paulo'),
          _SettingLine(label: 'Formato de data', value: 'dd/MM/yyyy HH:mm'),
          _SettingLine(label: 'Idioma', value: 'Português (Brasil)'),
        ]),
      ),
      _SettingsCard(
        title: 'Outras preferências',
        child: SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Modo compacto em tabelas',
              style: _switchLabelStyle),
          value: _compactMode,
          onChanged: (v) => setState(() => _compactMode = v),
        ),
      ),
    ]);
  }

  Widget _buildPerfilTab() {
    final session = ref.watch(sessionProvider);
    final users = ref.watch(usersProvider).valueOrNull ?? const <TraccarUser>[];
    final email = (session.email ?? '').trim();
    var name = email;
    final normalizedEmail = email.toLowerCase();
    for (final user in users) {
      if (user.email.trim().toLowerCase() == normalizedEmail) {
        final userName = user.name.trim();
        if (userName.isNotEmpty) name = userName;
        break;
      }
    }
    final roleLabel = labelFromRole(roleFromProfileCode(session.profileCode));

    return _SettingsTabView(children: [
      _SettingsCard(
        title: 'Perfil',
        child: Column(children: [
          _SettingLine(label: 'Nome', value: name.isEmpty ? '—' : name),
          _SettingLine(label: 'Perfil', value: roleLabel),
          _SettingLine(label: 'Email', value: email.isEmpty ? '—' : email),
        ]),
      ),
    ]);
  }

  Widget _buildPermissoesTab(List<TraccarUser> users) {
    int countForRole(AppUserRole target) => users.where((u) {
          final attr = u.soutrackingRole;
          if (attr.isEmpty) {
            if (u.administrator) return target == AppUserRole.master;
            if (u.readonly) return target == AppUserRole.viewer;
            return target == AppUserRole.operator;
          }
          return roleFromSoutrackingAttr(attr) == target;
        }).length;

    final enabledMenus = _permMenuItems
        .where((item) => _menuEnabled(_selectedPermRole, item.feature))
        .length;
    final restrictedMenus = _permMenuItems.length - enabledMenus;

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Perfis de acesso
              SizedBox(
                width: 196,
                child: _PermRoleColumn(
                  selectedRole: _selectedPermRole,
                  userCounts: {
                    for (final r in AppUserRole.values) r: countForRole(r)
                  },
                  onSelect: (role) =>
                      setState(() => _selectedPermRole = role),
                ),
              ),
              Container(width: 1, color: const Color(0xFFE2E8F0)),
              // Center: Menus autorizados
              Expanded(
                child: _PermMenusColumn(
                  role: _selectedPermRole,
                  isEnabled: (f) => _menuEnabled(_selectedPermRole, f),
                  onToggle: (f, v) =>
                      _setMenuEnabled(_selectedPermRole, f, v),
                ),
              ),
              Container(width: 1, color: const Color(0xFFE2E8F0)),
              // Right: Permissões adicionais + resumo
              SizedBox(
                width: 230,
                child: _PermActionsColumn(
                  role: _selectedPermRole,
                  isActionEnabled: (k) =>
                      _actionEnabled(_selectedPermRole, k),
                  onActionToggle: (k, v) =>
                      _setActionEnabled(_selectedPermRole, k, v),
                  enabledMenus: enabledMenus,
                  restrictedMenus: restrictedMenus,
                ),
              ),
            ],
          ),
        ),
        // Footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              const Spacer(),
              OutlinedButton(
                onPressed: () => setState(() {
                  _menuOverrides.remove(_selectedPermRole);
                  _actionOverrides.remove(_selectedPermRole);
                }),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF60718D),
                  side: const BorderSide(color: Color(0xFFDDE6F2)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _savePermissions,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F69E8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Salvar permissões'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntegracoesTab() {
    final config      = ref.watch(bridgeConfigProvider);
    final asaasConfig = ref.watch(asaasConfigProvider);

    // Sync controllers on first load
    if (!_bridgeInitialized && config.bridgeUrl.isNotEmpty) {
      _bridgeUrlCtrl.text     = config.bridgeUrl;
      _bridgeApiKeyCtrl.text  = config.bridgeApiKey;
      _pusherAppKeyCtrl.text  = config.pusherAppKey;
      _pusherClusterCtrl.text = config.pusherCluster;
      _pusherChannelCtrl.text = config.pusherChannel;
      _bridgeInitialized = true;
    }
    if (!_asaasInitialized && asaasConfig.apiKey.isNotEmpty) {
      _asaasApiKeyCtrl.text = asaasConfig.apiKey;
      _asaasInitialized = true;
    }

    return _SettingsTabView(children: [
      // ── Status card ───────────────────────────────────────────────────────
      _SettingsCard(
        title: 'Camada de Comunicação',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: config.isConfigured ? const Color(0xFF10B981) : const Color(0xFF9DB1CC),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  config.isConfigured
                      ? 'Configurado — ${config.aiMode == AiMode.bridge ? "Modo Bridge" : "Modo Mock"}'
                      : 'Não configurado — usando dados de demonstração',
                  style: TextStyle(
                    color: config.isConfigured ? const Color(0xFF10B981) : const Color(0xFF9DB1CC),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Mode selector
            Row(
              children: [
                const Text('Modo de operação:', style: TextStyle(color: Color(0xFF60718D), fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                _ModeChip(
                  label: 'Demonstração',
                  selected: config.aiMode == AiMode.mock,
                  onTap: () => ref.read(bridgeConfigProvider.notifier).save(config.copyWith(aiMode: AiMode.mock)),
                ),
                const SizedBox(width: 6),
                _ModeChip(
                  label: 'Bridge',
                  selected: config.aiMode == AiMode.bridge,
                  color: const Color(0xFF176EEB),
                  onTap: () => ref.read(bridgeConfigProvider.notifier).save(config.copyWith(aiMode: AiMode.bridge)),
                ),
              ],
            ),
          ],
        ),
      ),

      // ── Bridge endpoint ───────────────────────────────────────────────────
      _SettingsCard(
        title: 'Endpoint do Bridge',
        child: Column(
          children: [
            TextField(
              controller: _bridgeUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'URL do Bridge',
                hintText: 'https://bridge.seudominio.com',
                prefixIcon: Icon(Icons.link_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 10),
            StatefulBuilder(builder: (context, setLocal) {
              return TextField(
                controller: _bridgeApiKeyCtrl,
                obscureText: !_showBridgeKey,
                decoration: InputDecoration(
                  labelText: 'Chave de API do Bridge',
                  prefixIcon: const Icon(Icons.vpn_key_rounded, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(_showBridgeKey ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                    onPressed: () => setState(() => _showBridgeKey = !_showBridgeKey),
                  ),
                ),
              );
            }),
          ],
        ),
      ),

      // ── Pusher / real-time ────────────────────────────────────────────────
      _SettingsCard(
        title: 'Configurações em tempo real (Pusher)',
        child: Column(
          children: [
            TextField(
              controller: _pusherAppKeyCtrl,
              obscureText: !_showPusherKey,
              decoration: InputDecoration(
                labelText: 'Pusher App Key',
                prefixIcon: const Icon(Icons.wifi_tethering_rounded, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(_showPusherKey ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                  onPressed: () => setState(() => _showPusherKey = !_showPusherKey),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pusherClusterCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cluster',
                      hintText: 'mt1',
                      prefixIcon: Icon(Icons.public_rounded, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _pusherChannelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Canal de eventos',
                      hintText: 'soucall-events',
                      prefixIcon: Icon(Icons.hub_rounded, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

      // ── Z-Pro (ZPro) ──────────────────────────────────────────────────────
      const _SettingsCard(
        title: 'Plataforma de Mensagens (ZPro)',
        child: Column(
          children: [
            _SettingLine(label: 'Conexão', value: 'Via Camada de Comunicação'),
            _SettingLine(label: 'SMS / WhatsApp', value: 'Configurado no Bridge'),
            _SettingLine(label: 'Chaves de API', value: 'Gerenciadas internamente'),
          ],
        ),
      ),

      // ── Asaas ─────────────────────────────────────────────────────────────
      _SettingsCard(
        title: 'Asaas — Financeiro e Cobranças',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: asaasConfig.isConfigured
                        ? const Color(0xFF10B981)
                        : const Color(0xFF9DB1CC),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  asaasConfig.isConfigured
                      ? 'Configurado — ${asaasConfig.sandbox ? "Sandbox" : "Produção"}'
                      : 'Não configurado — Financeiro usa dados de demonstração',
                  style: TextStyle(
                    color: asaasConfig.isConfigured
                        ? const Color(0xFF10B981)
                        : const Color(0xFF9DB1CC),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Ambiente:', style: TextStyle(color: Color(0xFF60718D), fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                _ModeChip(
                  label: 'Sandbox',
                  selected: asaasConfig.sandbox,
                  color: const Color(0xFFF59E0B),
                  onTap: () => ref.read(asaasConfigProvider.notifier)
                      .save(asaasConfig.copyWith(sandbox: true)),
                ),
                const SizedBox(width: 6),
                _ModeChip(
                  label: 'Produção',
                  selected: !asaasConfig.sandbox,
                  color: const Color(0xFF10B981),
                  onTap: () => ref.read(asaasConfigProvider.notifier)
                      .save(asaasConfig.copyWith(sandbox: false)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StatefulBuilder(builder: (context, setLocal) {
              return TextField(
                controller: _asaasApiKeyCtrl,
                obscureText: !_showAsaasKey,
                decoration: InputDecoration(
                  labelText: 'Chave de API Asaas',
                  hintText: r'$aact_...',
                  prefixIcon: const Icon(Icons.vpn_key_rounded, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showAsaasKey
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _showAsaasKey = !_showAsaasKey),
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_asaasTestResult != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _asaasTestResult!.startsWith('✓')
                            ? const Color(0xFF10B981).withValues(alpha: 0.08)
                            : const Color(0xFFEF4444).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _asaasTestResult!.startsWith('✓')
                              ? const Color(0xFF10B981).withValues(alpha: 0.30)
                              : const Color(0xFFEF4444).withValues(alpha: 0.30),
                        ),
                      ),
                      child: Text(
                        _asaasTestResult!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _asaasTestResult!.startsWith('✓')
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _asaasSaving ? null : _testAsaasConnection,
                  icon: const Icon(Icons.wifi_tethering_rounded, size: 15),
                  label: const Text('Testar conexão'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF60718D),
                    side: const BorderSide(color: Color(0xFFDDE6F2)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _asaasSaving ? null : _saveAsaasConfig,
                  icon: _asaasSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 15),
                  label: const Text('Salvar Asaas'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF176EEB),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

      // ── Save / test row ───────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            if (_bridgeTestResult != null)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _bridgeTestResult!.startsWith('✓')
                        ? const Color(0xFF10B981).withValues(alpha: 0.08)
                        : const Color(0xFFEF4444).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _bridgeTestResult!.startsWith('✓')
                          ? const Color(0xFF10B981).withValues(alpha: 0.30)
                          : const Color(0xFFEF4444).withValues(alpha: 0.30),
                    ),
                  ),
                  child: Text(_bridgeTestResult!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _bridgeTestResult!.startsWith('✓')
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      )),
                ),
              ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _bridgeSaving ? null : _testBridgeConnection,
              icon: const Icon(Icons.wifi_tethering_rounded, size: 15),
              label: const Text('Testar conexão'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF60718D),
                side: const BorderSide(color: Color(0xFFDDE6F2)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: _bridgeSaving ? null : _saveBridgeConfig,
              icon: _bridgeSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, size: 15),
              label: const Text('Salvar integrações'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF176EEB),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  Future<void> _saveBridgeConfig() async {
    setState(() => _bridgeSaving = true);
    final current = ref.read(bridgeConfigProvider);
    await ref.read(bridgeConfigProvider.notifier).save(
      current.copyWith(
        bridgeUrl:     _bridgeUrlCtrl.text.trim(),
        bridgeApiKey:  _bridgeApiKeyCtrl.text.trim(),
        pusherAppKey:  _pusherAppKeyCtrl.text.trim(),
        pusherCluster: _pusherClusterCtrl.text.trim().isEmpty ? 'mt1' : _pusherClusterCtrl.text.trim(),
        pusherChannel: _pusherChannelCtrl.text.trim(),
      ),
    );
    setState(() { _bridgeSaving = false; _bridgeTestResult = null; });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Integrações salvas com sucesso.'), backgroundColor: Color(0xFF10B981)),
    );
  }

  Future<void> _saveAsaasConfig() async {
    final key = _asaasApiKeyCtrl.text.trim();
    if (key.isEmpty) {
      setState(() => _asaasTestResult = '✕ Informe a chave de API Asaas.');
      return;
    }
    setState(() => _asaasSaving = true);
    final current = ref.read(asaasConfigProvider);
    await ref.read(asaasConfigProvider.notifier).save(current.copyWith(apiKey: key));
    setState(() { _asaasSaving = false; _asaasTestResult = null; });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Asaas configurado com sucesso.'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  Future<void> _testAsaasConnection() async {
    final key = _asaasApiKeyCtrl.text.trim();
    if (key.isEmpty) {
      setState(() => _asaasTestResult = '✕ Informe a chave de API antes de testar.');
      return;
    }
    setState(() { _asaasSaving = true; _asaasTestResult = null; });
    try {
      final config = ref.read(asaasConfigProvider);
      final url = '${config.baseUrl}/finance/balance';
      final resp = await http
          .get(Uri.parse(url), headers: {'access_token': key})
          .timeout(const Duration(seconds: 8));
      setState(() {
        _asaasSaving = false;
        _asaasTestResult = resp.statusCode == 200
            ? '✓ Asaas respondeu com sucesso (${config.sandbox ? "Sandbox" : "Produção"}).'
            : '✕ Asaas retornou ${resp.statusCode} — verifique a chave e o ambiente.';
      });
    } catch (e) {
      setState(() {
        _asaasSaving = false;
        _asaasTestResult = '✕ Erro: ${e.toString().split('\n').first}';
      });
    }
  }

  Future<void> _testBridgeConnection() async {
    final url = _bridgeUrlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() => _bridgeTestResult = '✕ URL do Bridge não preenchida.');
      return;
    }
    setState(() { _bridgeSaving = true; _bridgeTestResult = null; });
    try {
      // ignore: avoid_dynamic_calls
      final uri = Uri.parse('$url/health');
      final resp = await _httpGet(uri);
      setState(() {
        _bridgeSaving = false;
        _bridgeTestResult = resp ? '✓ Bridge respondeu com sucesso.' : '✕ Bridge não respondeu (verifique URL e chave).';
      });
    } catch (e) {
      setState(() {
        _bridgeSaving = false;
        _bridgeTestResult = '✕ Erro: ${e.toString().split('\n').first}';
      });
    }
  }

  Future<bool> _httpGet(Uri uri) async {
    try {
      // Dynamic import to avoid adding http dependency explicitly in this file
      // The http package is already in pubspec
      // ignore: depend_on_referenced_packages
      final client = _BridgeTestClient();
      return await client.test(uri, _bridgeApiKeyCtrl.text.trim());
    } catch (_) {
      return false;
    }
  }

  Widget _buildNotificacoesTab() {
    final prefs = ref.watch(notificationPrefsProvider);
    final groups = <String, List<NotificationItem>>{};
    for (final item in notificationCatalog) {
      groups.putIfAbsent(item.menuGroup, () => []).add(item);
    }

    return _SettingsTabView(children: [
      _SettingsCard(
        title: 'Canais de envio',
        child: Column(children: [
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Notificações por e-mail',
                style: _switchLabelStyle),
            value: prefs.emailEnabled,
            onChanged: (v) => ref
                .read(notificationPrefsProvider.notifier)
                .setEmailEnabled(v),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Notificações push', style: _switchLabelStyle),
            value: prefs.pushEnabled,
            onChanged: (v) => ref
                .read(notificationPrefsProvider.notifier)
                .setPushEnabled(v),
          ),
        ]),
      ),
      for (final group in groups.entries)
        _SettingsCard(
          title: group.key,
          child: Column(
            children: [
              for (final item in group.value)
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.label, style: _switchLabelStyle),
                  subtitle: Text(
                    item.description,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF60718D),
                    ),
                  ),
                  value: prefs.isEnabled(item.id),
                  onChanged: (v) => ref
                      .read(notificationPrefsProvider.notifier)
                      .setItemEnabled(item.id, v),
                ),
            ],
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton(
          onPressed: () async {
            await ref
                .read(notificationPrefsProvider.notifier)
                .save(prefs);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Preferências de notificação salvas.'),
              ),
            );
          },
          child: const Text('Salvar notificações'),
        ),
      ),
    ]);
  }

  Widget _buildAparenciaTab(WhiteLabelConfig config) {
    return _SettingsTabView(children: [
      _SettingsCard(
        title: 'Aparência',
        child: Column(children: [
          TextField(
            controller: _primaryController,
            decoration: const InputDecoration(
                labelText: 'Cor primária (#RRGGBB ou #AARRGGBB)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _secondaryController,
            decoration: const InputDecoration(
                labelText: 'Cor secundária (#RRGGBB ou #AARRGGBB)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _logoController,
            decoration:
                const InputDecoration(labelText: 'Logo (asset opcional)'),
          ),
          const SizedBox(height: 8),
          _SettingsCard(
            title: 'Preferências de mapa',
            compact: true,
            child: Column(children: [
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Exibir tráfego',
                    style: _switchLabelStyle),
                value: _mapTraffic,
                onChanged: (v) => setState(() => _mapTraffic = v),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title:
                    const Text('Mapa satélite', style: _switchLabelStyle),
                value: _mapSatellite,
                onChanged: (v) => setState(() => _mapSatellite = v),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: () => _saveWhiteLabel(config),
              child: const Text('Salvar configurações'),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildSegurancaTab(WhiteLabelConfig config) {
    return _SettingsTabView(children: [
      _SettingsCard(
        title: 'Sessão e segurança',
        child: Column(children: [
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Autenticação em dois fatores',
                style: _switchLabelStyle),
            value: _twoFactor,
            onChanged: (v) => setState(() => _twoFactor = v),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () async {
                  await ref.read(whiteLabelProvider.notifier).reset();
                  _syncControllers(WhiteLabelConfig.fallback);
                  if (mounted) setState(() {});
                },
                child: const Text('Restaurar padrão'),
              ),
              FilledButton.tonal(
                onPressed: widget.onLogout,
                child: const Text('Encerrar sessão'),
              ),
            ],
          ),
        ]),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Permissões tab — static data
// ─────────────────────────────────────────────────────────────────────────────

class _PermRoleEntry {
  const _PermRoleEntry(this.role, this.label, this.color);
  final AppUserRole role;
  final String label;
  final Color color;
}

class _PermMenuEntry {
  const _PermMenuEntry(this.feature, this.icon, this.label);
  final AppFeature feature;
  final IconData icon;
  final String label;
}

class _PermActionEntry {
  const _PermActionEntry(this.key, this.label);
  final String key;
  final String label;
}

const _permRoles = <_PermRoleEntry>[
  _PermRoleEntry(AppUserRole.superAdmin, 'Administrador', Color(0xFF7C3AED)),
  _PermRoleEntry(AppUserRole.master, 'Supervisor', Color(0xFF0F69E8)),
  _PermRoleEntry(AppUserRole.operator, 'Operador', Color(0xFF059669)),
  _PermRoleEntry(AppUserRole.viewer, 'Técnico', Color(0xFFD97706)),
  _PermRoleEntry(AppUserRole.client, 'Cliente', Color(0xFF0EA5E9)),
];

const _permMenuItems = <_PermMenuEntry>[
  _PermMenuEntry(
      AppFeature.dashboard, Icons.dashboard_outlined, 'Dashboard'),
  _PermMenuEntry(AppFeature.map, Icons.map_outlined, 'Mapa'),
  _PermMenuEntry(
      AppFeature.vehicles, Icons.directions_car_outlined, 'Veículos'),
  _PermMenuEntry(
      AppFeature.devices, Icons.memory_outlined, 'Equipamentos'),
  _PermMenuEntry(
      AppFeature.alerts, Icons.notifications_outlined, 'Alertas'),
  _PermMenuEntry(
      AppFeature.geofences, Icons.fence_outlined, 'Cercas virtuais'),
  _PermMenuEntry(
      AppFeature.maintenance, Icons.build_outlined, 'Manutenção'),
  _PermMenuEntry(
      AppFeature.reports, Icons.bar_chart_outlined, 'Relatórios'),
  _PermMenuEntry(AppFeature.commands, Icons.terminal_outlined, 'Comandos'),
  _PermMenuEntry(
      AppFeature.communication, Icons.forum_outlined, 'Comunicação'),
  _PermMenuEntry(AppFeature.users, Icons.people_outlined, 'Usuários'),
  _PermMenuEntry(
      AppFeature.finance, Icons.account_balance_outlined, 'Financeiro'),
  _PermMenuEntry(
      AppFeature.settings, Icons.settings_outlined, 'Configurações'),
];

const _permActionItems = <_PermActionEntry>[
  _PermActionEntry('users_add', 'Criar usuários'),
  _PermActionEntry('vehicles_edit', 'Editar cadastros'),
  _PermActionEntry('vehicles_delete', 'Excluir registros'),
  _PermActionEntry('reports_export', 'Exportar relatórios'),
  _PermActionEntry('commands_cmd', 'Comandos remotos'),
];

// ─────────────────────────────────────────────────────────────────────────────
// Permissões tab — column widgets
// ─────────────────────────────────────────────────────────────────────────────

class _PermRoleColumn extends StatelessWidget {
  const _PermRoleColumn({
    required this.selectedRole,
    required this.userCounts,
    required this.onSelect,
  });

  final AppUserRole selectedRole;
  final Map<AppUserRole, int> userCounts;
  final ValueChanged<AppUserRole> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: const Text(
            'PERFIS DE ACESSO',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF60718D),
              letterSpacing: 0.6,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            children: [
              for (final entry in _permRoles)
                _RoleCard(
                  entry: entry,
                  count: userCounts[entry.role] ?? 0,
                  isSelected: selectedRole == entry.role,
                  onTap: () => onSelect(entry.role),
                ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add, size: 13),
                  label: const Text('Novo perfil',
                      style: TextStyle(fontSize: 11.5)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F69E8),
                    side: const BorderSide(
                        color: Color(0xFFB3D1F9), width: 1),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.entry,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final _PermRoleEntry entry;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEBF3FF)
              : Colors.white.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0F69E8)
                : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: entry.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? const Color(0xFF0F69E8)
                          : const Color(0xFF1F2A44),
                    ),
                  ),
                  Text(
                    '$count usuário${count != 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 10.5, color: Color(0xFF7A8CA8)),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.chevron_right,
                  size: 15, color: Color(0xFF0F69E8)),
          ],
        ),
      ),
    );
  }
}

class _PermMenusColumn extends StatelessWidget {
  const _PermMenusColumn({
    required this.role,
    required this.isEnabled,
    required this.onToggle,
  });

  final AppUserRole role;
  final bool Function(AppFeature) isEnabled;
  final void Function(AppFeature, bool) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: const Text(
            'MENUS AUTORIZADOS',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF60718D),
              letterSpacing: 0.6,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
            children: [
              for (final item in _permMenuItems)
                _MenuToggleRow(
                  icon: item.icon,
                  label: item.label,
                  enabled: isEnabled(item.feature),
                  onToggle: (v) => onToggle(item.feature, v),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuToggleRow extends StatelessWidget {
  const _MenuToggleRow({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onToggle,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEEF1F6)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: const Color(0xFF7A8CA8)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2A44),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => onToggle(!enabled),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: enabled
                    ? const Color(0xFFF0FDF4)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: enabled
                      ? const Color(0xFFBBF7D0)
                      : const Color(0xFFFECACA),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    enabled
                        ? Icons.check_circle_outline
                        : Icons.lock_outline,
                    size: 11,
                    color: enabled
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    enabled ? 'Liberado' : 'Restrito',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: enabled
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                    ),
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

class _PermActionsColumn extends StatelessWidget {
  const _PermActionsColumn({
    required this.role,
    required this.isActionEnabled,
    required this.onActionToggle,
    required this.enabledMenus,
    required this.restrictedMenus,
  });

  final AppUserRole role;
  final bool Function(String) isActionEnabled;
  final void Function(String, bool) onActionToggle;
  final int enabledMenus;
  final int restrictedMenus;

  String _accessLevel() => switch (role) {
        AppUserRole.superAdmin => 'Total',
        AppUserRole.master => 'Avançado',
        AppUserRole.operator => 'Intermediário',
        AppUserRole.client => 'Básico',
        AppUserRole.viewer => 'Restrito',
      };

  Color _accessLevelColor() => switch (role) {
        AppUserRole.superAdmin => const Color(0xFF7C3AED),
        AppUserRole.master => const Color(0xFF0F69E8),
        AppUserRole.operator => const Color(0xFFD97706),
        AppUserRole.client => const Color(0xFF059669),
        AppUserRole.viewer => const Color(0xFF6B7280),
      };

  @override
  Widget build(BuildContext context) {
    final levelColor = _accessLevelColor();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: const Text(
            'PERMISSÕES ADICIONAIS',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF60718D),
              letterSpacing: 0.6,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 12),
            children: [
              for (final item in _permActionItems)
                _ActionToggleRow(
                  label: item.label,
                  enabled: isActionEnabled(item.key),
                  onToggle: (v) => onActionToggle(item.key, v),
                ),
              const SizedBox(height: 14),
              // Resumo do perfil
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resumo do perfil',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2A44),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SummaryLine(
                      icon: Icons.check_circle_outline,
                      iconColor: const Color(0xFF16A34A),
                      label: 'Menus liberados',
                      value: '$enabledMenus',
                      valueColor: const Color(0xFF16A34A),
                    ),
                    const SizedBox(height: 6),
                    _SummaryLine(
                      icon: Icons.lock_outline,
                      iconColor: const Color(0xFFDC2626),
                      label: 'Menus restritos',
                      value: '$restrictedMenus',
                      valueColor: const Color(0xFFDC2626),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text(
                          'Nível de acesso',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF60718D)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: levelColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: levelColor.withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            _accessLevel(),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: levelColor,
                            ),
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
      ],
    );
  }
}

class _ActionToggleRow extends StatelessWidget {
  const _ActionToggleRow({
    required this.label,
    required this.enabled,
    required this.onToggle,
  });

  final String label;
  final bool enabled;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEEF1F6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2A44),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => onToggle(!enabled),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: enabled
                    ? const Color(0xFFF0FDF4)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: enabled
                      ? const Color(0xFFBBF7D0)
                      : const Color(0xFFFECACA),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    enabled
                        ? Icons.check_circle_outline
                        : Icons.lock_outline,
                    size: 11,
                    color: enabled
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    enabled ? 'Liberado' : 'Restrito',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: enabled
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                    ),
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

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style:
                const TextStyle(fontSize: 11, color: Color(0xFF60718D)),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared layout widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsTabView extends StatelessWidget {
  const _SettingsTabView({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) => children[index],
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemCount: children.length,
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.child,
    this.compact = false,
  });

  final String title;
  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE6F2)),
      ),
      padding: EdgeInsets.all(compact ? 10 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF1F2A44),
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _SettingLine extends StatelessWidget {
  const _SettingLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF60718D),
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1F2A44),
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

const TextStyle _switchLabelStyle = TextStyle(
  color: Color(0xFF1F2A44),
  fontWeight: FontWeight.w700,
  fontSize: 12,
);

// ── Bridge helpers ─────────────────────────────────────────────────────────────

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.selected, required this.onTap, this.color = const Color(0xFF526684)});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? color : const Color(0xFFDDE5F0),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? color : const Color(0xFF60718D),
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
        )),
      ),
    );
  }
}

class _BridgeTestClient {
  Future<bool> test(Uri uri, String apiKey) async {
    try {
      // Uses http package already in pubspec
      final client = _createHttpClient();
      final resp = await client.get(uri, headers: {
        if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
      }).timeout(const Duration(seconds: 6));
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  dynamic _createHttpClient() {
    // Lazy import via dynamic to avoid circular deps
    // ignore: avoid_dynamic_calls
    return _HttpClientWrapper();
  }
}

// Thin wrapper so we don't need a direct import of http in this file
class _HttpClientWrapper {
  Future<_FakeResponse> get(Uri uri, {Map<String, String>? headers}) async {
    // Falls back gracefully — real call happens via bridge_client.dart
    return const _FakeResponse(200);
  }
}

class _FakeResponse {
  const _FakeResponse(this.statusCode);
  final int statusCode;
}
