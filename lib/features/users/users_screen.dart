import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_permissions.dart';
import '../../data/models.dart';
import '../../state/session_state.dart';
import '../admin/admin_reference_ui.dart';
import '../../ui/module_scaffold.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  String _profileFilter = 'Todos', _search = '';
  int? _selectedId;
  final _detailKey = GlobalKey();
  final _rowKeys = <int, GlobalKey<_UserTableRowState>>{};
  AppUserRole _selectedRole = AppUserRole.operator;
  bool _saving = false;

  Future<void> _openCreateUserDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: SizedBox(
                width: 1104,
                height: 580,
                child: StatefulBuilder(
                    builder: (context, setModal) => AnimatedBuilder(
                        animation: Listenable.merge(
                            [_nameController, _emailController]),
                        builder: (context, _) => ModuleScaffold(
                                title: 'Novo usuário',
                                subtitle:
                                    'Dados de contato e perfil de acesso.',
                                navigation: const Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      ModuleSectionLabel('Cadastro'),
                                      ModuleListItem(
                                          title: 'Dados do usuário',
                                          icon: Icons.person_outline_rounded,
                                          selected: true),
                                      ModuleSectionLabel('Acesso'),
                                      Text(
                                          'O perfil selecionado mantém as permissões já configuradas.',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF60718D)))
                                    ]),
                                content: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      TextField(
                                        controller: _nameController,
                                        decoration: const InputDecoration(
                                            labelText: 'Nome'),
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: _emailController,
                                        decoration: const InputDecoration(
                                            labelText: 'E-mail'),
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: _passwordController,
                                        decoration: const InputDecoration(
                                            labelText: 'Senha'),
                                        obscureText: true,
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: _phoneController,
                                        decoration: const InputDecoration(
                                            labelText: 'Telefone'),
                                      ),
                                      const SizedBox(height: 12),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Perfil de acesso',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              color: const Color(0xFF7A8CA8),
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      DropdownButtonFormField<AppUserRole>(
                                        isExpanded: true,
                                        initialValue: _selectedRole,
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                        ),
                                        items: AppUserRole.values
                                            .map(
                                              (role) => DropdownMenuItem(
                                                value: role,
                                                child:
                                                    Text(labelFromRole(role)),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (role) {
                                          if (role != null) {
                                            setState(
                                                () => _selectedRole = role);
                                            setModal(() {});
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _roleDescription(_selectedRole),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: const Color(0xFF9AA8BC),
                                            ),
                                      ),
                                      const SizedBox(height: 16),
                                    ]),
                                detail: ModuleCard(
                                    title: 'Resumo do usuário',
                                    child: Column(children: [
                                      ModuleDetailRow(
                                          'Nome',
                                          _nameController.text.trim().isEmpty
                                              ? 'Não informado'
                                              : _nameController.text.trim()),
                                      ModuleDetailRow(
                                          'E-mail',
                                          _emailController.text.trim().isEmpty
                                              ? 'Não informado'
                                              : _emailController.text.trim()),
                                      ModuleDetailRow('Perfil',
                                          labelFromRole(_selectedRole))
                                    ])),
                                actions: [
                                  OutlinedButton(
                                      onPressed: _saving
                                          ? null
                                          : () => Navigator.of(context).pop(),
                                      child: const Text('Cancelar')),
                                  AdminActionButton(
                                    label: _saving
                                        ? 'Salvando...'
                                        : 'Criar Usuário',
                                    onPressed: _saving
                                        ? null
                                        : () async {
                                            final navigator =
                                                Navigator.of(context);
                                            final pending = _createUser();
                                            setModal(() {});
                                            final created = await pending;
                                            if (context.mounted)
                                              setModal(() {});
                                            if (!context.mounted) {
                                              return;
                                            }
                                            if (created) {
                                              navigator.pop();
                                            }
                                          },
                                  )
                                ])))));
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _roleDescription(AppUserRole role) {
    return switch (role) {
      AppUserRole.superAdmin =>
        'Acesso total — cria usuários, vê todos os tenants e configurações do sistema.',
      AppUserRole.master =>
        'Revenda — gerencia seus próprios clientes, dispositivos e usuários.',
      AppUserRole.operator =>
        'Operador — mapa, alertas, relatórios e comandos. Sem gestão de usuários.',
      AppUserRole.client =>
        'Cliente final — visualiza seus veículos. Comandos conforme plano contratado.',
      AppUserRole.viewer =>
        'Somente leitura — acessa mapa e posições. Sem comandos nem alertas.',
    };
  }

  Future<bool> _createUser() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final phone = _phoneController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome, e-mail e senha são obrigatórios.')),
      );
      return false;
    }

    setState(() => _saving = true);
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);

    try {
      final flags = traccarFlagsFromRole(_selectedRole);
      await client.createUser(
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'name': name,
          'email': email,
          'password': password,
          if (phone.isNotEmpty) 'phone': phone,
          ...flags,
          'attributes': {
            'soutracking_role': soutrackingAttrFromRole(_selectedRole),
          },
        },
      );
      ref.invalidate(usersProvider);
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _phoneController.clear();
      setState(() => _selectedRole = AppUserRole.operator);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuário criado com sucesso.')),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Falha ao criar usuário: $e')));
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);
    final users = usersAsync.valueOrNull ?? <TraccarUser>[];
    final profiles = {'Todos', ...users.map(deriveUserRole)}.toList();
    final visible = users
        .where((u) =>
            (_profileFilter == 'Todos' ||
                deriveUserRole(u) == _profileFilter) &&
            ('${u.name} ${u.email}')
                .toLowerCase()
                .contains(_search.trim().toLowerCase()))
        .toList();
    final selected = visible.where((u) => u.id == _selectedId).firstOrNull;
    return LayoutBuilder(
        builder: (context, size) => ModuleScaffold(
                title: 'Usuários',
                subtitle: 'Perfis, contatos e acessos da equipe.',
                navigation: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const ModuleSectionLabel('Perfis de acesso'),
                      for (final profile in profiles)
                        ModuleListItem(
                            title: profile,
                            subtitle:
                                '${users.where((u) => profile == "Todos" || deriveUserRole(u) == profile).length} usuários',
                            selected: profile == _profileFilter,
                            onTap: () =>
                                setState(() => _profileFilter = profile))
                    ]),
                content: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                          decoration: const InputDecoration(
                              labelText: 'Buscar usuário',
                              hintText: 'Nome ou e-mail',
                              prefixIcon: Icon(Icons.search_rounded)),
                          onChanged: (v) => setState(() => _search = v)),
                      const SizedBox(height: 14),
                      usersAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, _) => const ModuleEmpty(
                              'Não foi possível carregar os usuários',
                              'Tente novamente em instantes.'),
                          data: (_) => visible.isEmpty
                              ? const ModuleEmpty('Nenhum usuário encontrado',
                                  'Revise os filtros ou cadastre um usuário.',
                                  icon: Icons.people_outline)
                              : Column(children: [
                                  for (final u in visible)
                                    _UserTableRow(
                                        key: _rowKeys.putIfAbsent(
                                            u.id,
                                            () => GlobalKey<
                                                _UserTableRowState>()),
                                        user: u,
                                        selected: u.id == _selectedId,
                                        onSelect: () {
                                          setState(() => _selectedId = u.id);
                                          if (size.maxWidth < 932)
                                            WidgetsBinding.instance
                                                .addPostFrameCallback((_) {
                                              final target =
                                                  _detailKey.currentContext;
                                              if (target != null)
                                                Scrollable.ensureVisible(target,
                                                    alignment: 0,
                                                    duration: const Duration(
                                                        milliseconds: 220));
                                            });
                                        })
                                ]))
                    ]),
                detail: KeyedSubtree(
                    key: _detailKey,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const ModuleSectionLabel('Detalhes do usuário'),
                          if (selected == null)
                            const ModuleEmpty('Selecione um usuário',
                                'Contato, perfil e acesso à Visão executiva aparecem aqui.')
                          else ...[
                            ModuleCard(
                                title: selected.name,
                                child: Column(children: [
                                  _UserPhoto(user: selected, size: 56),
                                  const SizedBox(height: 14),
                                  _UserEmail(selected.email),
                                  ModuleDetailRow(
                                      'Perfil', deriveUserRole(selected)),
                                  ModuleDetailRow('Status',
                                      selected.disabled ? 'Inativo' : 'Ativo'),
                                  const ModuleDetailRow(
                                      'Último acesso', 'Não informado')
                                ])),
                            ModuleCard(
                                title: 'Visão executiva',
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ModuleStatusChip(
                                          selected.attributes?[
                                                      'souExecutiveView'] ==
                                                  true
                                              ? 'Liberada'
                                              : 'Bloqueada',
                                          tone: selected.attributes?[
                                                      'souExecutiveView'] ==
                                                  true
                                              ? ModuleTone.success
                                              : ModuleTone.neutral),
                                      const SizedBox(height: 10),
                                      const Text(
                                          'Use Editar para alterar a liberação deste usuário.',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF60718D)))
                                    ]))
                          ]
                        ])),
                footerLabel: '${visible.length} usuários exibidos',
                actions: [
                  OutlinedButton.icon(
                      onPressed: selected == null
                          ? null
                          : () => _rowKeys[selected.id]
                              ?.currentState
                              ?._toggleDisabled(),
                      icon: Icon(selected?.disabled == true
                          ? Icons.lock_open_rounded
                          : Icons.block_rounded),
                      label: Text(selected?.disabled == true
                          ? 'Reativar'
                          : 'Desativar')),
                  FilledButton.icon(
                      onPressed: _openCreateUserDialog,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Novo usuário'))
                ]));
  }
}

class _UserTableRow extends ConsumerStatefulWidget {
  const _UserTableRow(
      {super.key, required this.user, this.selected = false, this.onSelect});
  final bool selected;
  final VoidCallback? onSelect;

  final TraccarUser user;

  @override
  ConsumerState<_UserTableRow> createState() => _UserTableRowState();
}

class _UserTableRowState extends ConsumerState<_UserTableRow> {
  bool _busy = false;

  Future<void> _openEditDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _EditUserDialog(user: widget.user),
    );
    ref.invalidate(usersProvider);
  }

  Future<void> _toggleDisabled() async {
    if (_busy) return;
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    final user = widget.user;
    setState(() => _busy = true);
    try {
      await client.updateEntityById(
        path: '/users',
        id: user.id,
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'id': user.id,
          'name': user.name,
          'email': user.email,
          'administrator': user.administrator,
          'readonly': user.readonly,
          'disabled': !user.disabled,
          if (user.attributes != null) 'attributes': user.attributes,
        },
      );
      ref.invalidate(usersProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir usuário'),
        content: Text('Deseja excluir "${widget.user.name}" permanentemente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    setState(() => _busy = true);
    try {
      await client.deleteEntity(
        path: '/users/${widget.user.id}',
        cookie: session.cookie,
        authHeader: session.authHeader,
      );
      ref.invalidate(usersProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return ModuleListItem(
        title: user.name,
        subtitle:
            '${user.email}\n${deriveUserRole(user)} · ${user.disabled ? "Inativo" : "Ativo"}',
        selected: widget.selected,
        onTap: widget.onSelect,
        trailing: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Wrap(spacing: 4, children: [
                _ActionIconBtn(
                    icon: Icons.edit_outlined,
                    tooltip: 'Editar',
                    onPressed: _openEditDialog),
                _ActionIconBtn(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Excluir',
                    color: const Color(0xFFB42318),
                    onPressed: _confirmDelete)
              ]));
  }
}

class _ActionIconBtn extends StatelessWidget {
  const _ActionIconBtn({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? const Color(0xFF6B7C95);
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: iconColor.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, size: 15, color: iconColor),
        ),
      ),
    );
  }
}

// ── Edit User Dialog ──────────────────────────────────────────────────────────

class _EditUserDialog extends ConsumerStatefulWidget {
  const _EditUserDialog({required this.user});
  final TraccarUser user;

  @override
  ConsumerState<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends ConsumerState<_EditUserDialog> {
  late bool _executiveView;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _passwordCtrl;
  late AppUserRole _role;
  bool _saving = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _executiveView = widget.user.attributes?['souExecutiveView'] == true;
    _nameCtrl = TextEditingController(text: widget.user.name);
    _emailCtrl = TextEditingController(text: widget.user.email);
    _phoneCtrl = TextEditingController();
    _passwordCtrl = TextEditingController();

    final roleStr = widget.user.soutrackingRole;
    _role = AppUserRole.values.firstWhere(
      (r) => soutrackingAttrFromRole(r) == roleStr,
      orElse: () => AppUserRole.operator,
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String _roleDescription(AppUserRole role) => switch (role) {
        AppUserRole.superAdmin =>
          'Acesso total — cria usuários e vê todos os dados.',
        AppUserRole.master =>
          'Revenda — gerencia seus clientes e dispositivos.',
        AppUserRole.operator =>
          'Operador — mapa, alertas, relatórios e comandos.',
        AppUserRole.client => 'Cliente final — visualiza seus veículos.',
        AppUserRole.viewer =>
          'Somente leitura — mapa e posições, sem comandos.',
      };

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome e e-mail são obrigatórios.')),
      );
      return;
    }
    setState(() => _saving = true);
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    final flags = traccarFlagsFromRole(_role);

    try {
      final body = <String, dynamic>{
        'id': widget.user.id,
        'name': name,
        'email': email,
        'administrator': widget.user.administrator,
        'readonly': widget.user.readonly,
        'disabled': widget.user.disabled,
        ...flags,
        'attributes': {
          ...?widget.user.attributes,
          'soutracking_role': soutrackingAttrFromRole(_role),
          'souExecutiveView': _executiveView,
        },
      };
      if (_passwordCtrl.text.isNotEmpty) {
        body['password'] = _passwordCtrl.text;
      }
      await client.updateEntityById(
        path: '/users',
        id: widget.user.id,
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: body,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuário atualizado com sucesso.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static const _fieldDecoration = InputDecoration(
    filled: true,
    fillColor: Color(0xFFF7F9FD),
    border:
        OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFDDE5F0))),
    enabledBorder:
        OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFDDE5F0))),
  );

  @override
  Widget build(BuildContext context) {
    return Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
            width: 1104,
            height: 580,
            child: AnimatedBuilder(
                animation: Listenable.merge([_nameCtrl, _emailCtrl]),
                builder: (context, _) => ModuleScaffold(
                        title: 'Editar usuário',
                        subtitle: 'Contato, perfil e acesso à Visão executiva.',
                        navigation: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const ModuleSectionLabel('Usuário'),
                              _UserPhoto(user: widget.user, size: 56),
                              const SizedBox(height: 12),
                              Text(widget.user.name,
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              ModuleStatusChip(
                                  widget.user.disabled ? 'Inativo' : 'Ativo',
                                  tone: widget.user.disabled
                                      ? ModuleTone.neutral
                                      : ModuleTone.success)
                            ]),
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _nameCtrl,
                              decoration: _fieldDecoration.copyWith(
                                labelText: 'Nome',
                                prefixIcon:
                                    const Icon(Icons.badge_outlined, size: 18),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _fieldDecoration.copyWith(
                                labelText: 'E-mail',
                                prefixIcon: const Icon(
                                    Icons.alternate_email_rounded,
                                    size: 18),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _passwordCtrl,
                              obscureText: !_showPassword,
                              decoration: _fieldDecoration.copyWith(
                                labelText:
                                    'Nova senha (deixe em branco para manter)',
                                prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 18),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _showPassword
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () => setState(
                                      () => _showPassword = !_showPassword),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Perfil de acesso',
                              style: TextStyle(
                                  color: Color(0xFF1F2A44),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<AppUserRole>(
                              isExpanded: true,
                              initialValue: _role,
                              decoration: _fieldDecoration,
                              items: AppUserRole.values
                                  .map((r) => DropdownMenuItem(
                                        value: r,
                                        child: Text(labelFromRole(r)),
                                      ))
                                  .toList(),
                              onChanged: (r) {
                                if (r != null) setState(() => _role = r);
                              },
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _roleDescription(_role),
                              style: const TextStyle(
                                  color: Color(0xFF60718D), fontSize: 11.5),
                            ),
                          ],
                        ),
                        detail: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ModuleCard(
                                  title: 'Resumo do usuário',
                                  child: Column(children: [
                                    ModuleDetailRow('Nome', _nameCtrl.text),
                                    _UserEmail(_emailCtrl.text),
                                    ModuleDetailRow(
                                        'Perfil', labelFromRole(_role))
                                  ])),
                              ModuleCard(
                                  title: 'Visão executiva',
                                  child: SwitchListTile(
                                    title: const Text('Visão executiva',
                                        style: TextStyle(fontSize: 12)),
                                    subtitle: const Text(
                                        'Permitir o acesso à visão executiva do Dashboard.',
                                        style: TextStyle(fontSize: 11)),
                                    value: _executiveView,
                                    onChanged: _saving
                                        ? null
                                        : (value) => setState(
                                            () => _executiveView = value),
                                  ))
                            ]),
                        actions: [
                          OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF526684),
                              side: const BorderSide(color: Color(0xFFDDE5F0)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                            ),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.check_rounded, size: 15),
                            label: Text(
                                _saving ? 'Salvando...' : 'Salvar alterações'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF176EEB),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                            ),
                          )
                        ]))));
  }
}

class _UserPhoto extends StatelessWidget {
  const _UserPhoto({required this.user, this.size = 36});
  final TraccarUser user;
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: SizedBox(
          width: size,
          height: size,
          child: user.photoUrl.isEmpty
              ? AdminAvatar(name: user.name)
              : Image.network(user.photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => AdminAvatar(name: user.name))));
}

class _UserEmail extends StatelessWidget {
  const _UserEmail(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('E-mail',
            style: TextStyle(fontSize: 11, color: Color(0xFF60718D))),
        const SizedBox(height: 4),
        Tooltip(
            message: value,
            child: Text(value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)))
      ]));
}
