import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/session_state.dart';
import '../admin/admin_reference_ui.dart';

enum PermissionsVisualMode { access, monitoring }

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  int? _selectedUserId;
  final Map<String, _PermissionState> _permissionStates = {};
  bool _creatingBinding = false;

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);
    final permissionsAsync = ref.watch(permissionsProvider);

    return AdminReferenceScaffold(
      title: 'Permissões dos Usuários',
      breadcrumbs: const [
        'Usuários Internos',
        'Supervisor',
        'Permissões dos Usuários',
      ],
      selectedMenu: 'permissions-access',
      action: Wrap(
        spacing: 10,
        children: [
          OutlinedButton.icon(
            onPressed: _creatingBinding
                ? null
                : () => _openBindingDialog(context),
            icon: const Icon(Icons.link_outlined, size: 18),
            label: const Text('Novo vínculo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF5D728E),
              side: const BorderSide(color: Color(0xFFD4DFEA)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          AdminActionButton(
            label: 'Salvar Permissões',
            icon: Icons.save_outlined,
            onPressed: () {
              final selectedUser = _findSelectedUser(usersAsync);
              final userName = selectedUser?.name ?? 'usuário';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Visual de permissões atualizado para $userName.',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      child: usersAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('Nenhum usuário encontrado'));
          }

          _ensureSelection(users);
          final selectedUser = users.firstWhere(
            (user) => user.id == (_selectedUserId ?? users.first.id),
            orElse: () => users.first,
          );
          if (_permissionStates.isEmpty) {
            _hydrateForUser(selectedUser);
          }

          final bindings =
              permissionsAsync.valueOrNull ?? const <Map<String, dynamic>>[];
          final userBindings = bindings
              .where((item) => item['userId'] == selectedUser.id)
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Seletor de usuário ──────────────────────────────────
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 240,
                      maxWidth: 320,
                    ),
                    child: DropdownButtonFormField<int>(
                      initialValue: selectedUser.id,
                      decoration: const InputDecoration(labelText: 'Usuário'),
                      items: [
                        for (final user in users)
                          DropdownMenuItem<int>(
                            value: user.id,
                            child: Text(user.name),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        final nextUser = users.firstWhere(
                          (user) => user.id == value,
                        );
                        setState(() {
                          _selectedUserId = value;
                          _hydrateForUser(nextUser);
                        });
                      },
                    ),
                  ),
                  AdminStatusChip(
                    label: 'Perfil: ${deriveUserRole(selectedUser)}',
                    color: statusColorFor(selectedUser),
                  ),
                  AdminStatusChip(
                    label: 'Vínculos reais: ${userBindings.length}',
                    color: const Color(0xFF4C84FF),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Seção: Gerenciamento de Acesso ──────────────────────
              _sectionDivider(
                context,
                'GERENCIAMENTO DE ACESSO',
                Icons.vpn_key_outlined,
              ),
              const SizedBox(height: 12),
              _tableHeader(context, 'Módulo'),
              const SizedBox(height: 8),
              for (final module in _modulesFor(
                PermissionsVisualMode.access,
              )) ...[
                _PermissionRow(
                  module: module,
                  state: _permissionStates[module.key]!,
                  onChanged: (next) =>
                      setState(() => _permissionStates[module.key] = next),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 24),

              // ── Seção: Monitoramento ────────────────────────────────
              _sectionDivider(context, 'MONITORAMENTO', Icons.monitor_outlined),
              const SizedBox(height: 12),
              _tableHeader(context, 'Recurso'),
              const SizedBox(height: 8),
              for (final module in _modulesFor(
                PermissionsVisualMode.monitoring,
              )) ...[
                _PermissionRow(
                  module: module,
                  state: _permissionStates[module.key]!,
                  onChanged: (next) =>
                      setState(() => _permissionStates[module.key] = next),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${selectedUser.name}  •  ${deterministicLastAccess(selectedUser)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6B7C95),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        error: (error, _) => Center(child: Text('Erro: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  TraccarUser? _findSelectedUser(AsyncValue<List<TraccarUser>> usersAsync) {
    final users = usersAsync.valueOrNull;
    if (users == null || users.isEmpty) {
      return null;
    }
    final targetId = _selectedUserId ?? users.first.id;
    for (final user in users) {
      if (user.id == targetId) {
        return user;
      }
    }
    return users.first;
  }

  void _ensureSelection(List<TraccarUser> users) {
    if (_selectedUserId != null || users.isEmpty) {
      return;
    }
    _selectedUserId = users.first.id;
  }

  void _hydrateForUser(TraccarUser user) {
    _permissionStates
      ..clear()
      ..addEntries([
        for (final module in _modulesFor(PermissionsVisualMode.access))
          MapEntry(
            module.key,
            _initialStateFor(user, module, PermissionsVisualMode.access),
          ),
        for (final module in _modulesFor(PermissionsVisualMode.monitoring))
          MapEntry(
            module.key,
            _initialStateFor(user, module, PermissionsVisualMode.monitoring),
          ),
      ]);
  }

  _PermissionState _initialStateFor(
    TraccarUser user,
    _PermissionModule module,
    PermissionsVisualMode mode,
  ) {
    final canManage = !user.readonly && !user.disabled;
    final isAdmin = user.administrator;
    final view = !user.disabled;
    final add =
        canManage &&
        (mode == PermissionsVisualMode.access || module.weight <= 3);
    final edit = isAdmin || (canManage && module.weight <= 2);
    final remove = isAdmin && module.weight <= 3;
    return _PermissionState(view: view, add: add, edit: edit, remove: remove);
  }

  List<_PermissionModule> _modulesFor(PermissionsVisualMode mode) {
    if (mode == PermissionsVisualMode.monitoring) {
      return const [
        _PermissionModule('icon', 'Ícone no Painel', Icons.circle_outlined, 1),
        _PermissionModule('map', 'Mapa', Icons.map_outlined, 1),
        _PermissionModule(
          'list',
          'Lista de Dispositivos',
          Icons.list_alt_outlined,
          2,
        ),
        _PermissionModule(
          'status',
          'Status do Veículo',
          Icons.directions_car_outlined,
          2,
        ),
        _PermissionModule('fences', 'Fences', Icons.polyline_outlined, 3),
        _PermissionModule('address', 'Endereço', Icons.place_outlined, 3),
        _PermissionModule(
          'sharing',
          'Compartilhamento',
          Icons.share_outlined,
          4,
        ),
        _PermissionModule('policies', 'Policies', Icons.policy_outlined, 4),
        _PermissionModule('graphers', 'Graphers', Icons.show_chart_outlined, 5),
      ];
    }
    return const [
      _PermissionModule(
        'administracao',
        'Administração',
        Icons.admin_panel_settings_outlined,
        1,
      ),
      _PermissionModule(
        'profiles-admin',
        'Perfis Administrador',
        Icons.badge_outlined,
        1,
      ),
      _PermissionModule(
        'profiles-users',
        'Perfis de Usuários',
        Icons.people_alt_outlined,
        2,
      ),
      _PermissionModule('preferences', 'Preferências', Icons.tune_outlined, 2),
      _PermissionModule(
        'notifications',
        'Notificações',
        Icons.notifications_none_outlined,
        3,
      ),
      _PermissionModule('announcement', 'Anúncio', Icons.campaign_outlined, 3),
    ];
  }

  Widget _sectionDivider(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF4C84FF)),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xFF4C84FF),
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Divider(color: Color(0xFFD4DFEA), thickness: 1)),
      ],
    );
  }

  Widget _tableHeader(BuildContext context, String moduleLabel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFD),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _permissionHeader(context, moduleLabel, 44),
          _permissionHeader(context, 'Ver', 14),
          _permissionHeader(context, 'Adicionar', 14),
          _permissionHeader(context, 'Editar', 14),
          _permissionHeader(context, 'Excluir', 14),
        ],
      ),
    );
  }

  Widget _permissionHeader(BuildContext context, String label, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: const Color(0xFF7A8CA8),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _openBindingDialog(BuildContext context) async {
    final users = ref.read(usersProvider).valueOrNull ?? const <TraccarUser>[];
    final devices = await ref.read(devicesProvider.future);
    if (!context.mounted) {
      return;
    }

    var dialogUserId =
        _selectedUserId ?? (users.isNotEmpty ? users.first.id : null);
    int? dialogDeviceId = devices.isNotEmpty ? devices.first.id : null;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: AdminGlassPanel(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Novo vínculo real Traccar',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: const Color(0xFF1F2A44),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: dialogUserId,
                        decoration: const InputDecoration(labelText: 'Usuário'),
                        items: [
                          for (final user in users)
                            DropdownMenuItem(
                              value: user.id,
                              child: Text(user.name),
                            ),
                        ],
                        onChanged: (value) =>
                            setLocalState(() => dialogUserId = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: dialogDeviceId,
                        decoration: const InputDecoration(
                          labelText: 'Dispositivo',
                        ),
                        items: [
                          for (final device in devices)
                            DropdownMenuItem(
                              value: device.id,
                              child: Text(device.name),
                            ),
                        ],
                        onChanged: (value) =>
                            setLocalState(() => dialogDeviceId = value),
                      ),
                      const SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerRight,
                        child: AdminActionButton(
                          label: _creatingBinding
                              ? 'Salvando...'
                              : 'Criar vínculo',
                          icon: Icons.check_circle_outline,
                          onPressed:
                              _creatingBinding ||
                                  dialogUserId == null ||
                                  dialogDeviceId == null
                              ? null
                              : () async {
                                  Navigator.of(context).pop();
                                  await _createBinding(
                                    dialogUserId!,
                                    dialogDeviceId!,
                                  );
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _createBinding(int userId, int deviceId) async {
    setState(() => _creatingBinding = true);
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    try {
      await client.createEntity(
        path: '/permissions',
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {'userId': userId, 'deviceId': deviceId},
      );
      ref.invalidate(permissionsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vínculo criado com sucesso.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao criar vínculo: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _creatingBinding = false);
      }
    }
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.module,
    required this.state,
    required this.onChanged,
  });

  final _PermissionModule module;
  final _PermissionState state;
  final ValueChanged<_PermissionState> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EEF5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 44,
            child: Row(
              children: [
                Icon(module.icon, color: const Color(0xFF6A7B93), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    module.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF2E405B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _SwitchCell(
            value: state.view,
            onChanged: (value) => onChanged(state.copyWith(view: value)),
          ),
          _SwitchCell(
            value: state.add,
            onChanged: (value) => onChanged(state.copyWith(add: value)),
          ),
          _SwitchCell(
            value: state.edit,
            onChanged: (value) => onChanged(state.copyWith(edit: value)),
          ),
          _SwitchCell(
            value: state.remove,
            onChanged: (value) => onChanged(state.copyWith(remove: value)),
          ),
        ],
      ),
    );
  }
}

class _SwitchCell extends StatelessWidget {
  const _SwitchCell({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 14,
      child: Center(
        child: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeTrackColor: const Color(0xFF10B8A4),
          activeThumbColor: Colors.white,
        ),
      ),
    );
  }
}

class _PermissionModule {
  const _PermissionModule(this.key, this.label, this.icon, this.weight);

  final String key;
  final String label;
  final IconData icon;
  final int weight;
}

class _PermissionState {
  const _PermissionState({
    required this.view,
    required this.add,
    required this.edit,
    required this.remove,
  });

  final bool view;
  final bool add;
  final bool edit;
  final bool remove;

  _PermissionState copyWith({bool? view, bool? add, bool? edit, bool? remove}) {
    return _PermissionState(
      view: view ?? this.view,
      add: add ?? this.add,
      edit: edit ?? this.edit,
      remove: remove ?? this.remove,
    );
  }
}
