import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_permissions.dart';
import '../../data/models.dart';
import '../../state/session_state.dart';
import '../admin/admin_reference_ui.dart';

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

  AppUserRole _selectedRole = AppUserRole.operator;
  bool _saving = false;

  Future<void> _openCreateUserDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AdminGlassPanel(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Novo Usuário',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: const Color(0xFF1F2A44),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Nome'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'E-mail'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Senha'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: 'Telefone'),
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(height: 4),
                    Text(
                      'Perfil de acesso',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: const Color(0xFF7A8CA8),
                          ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<AppUserRole>(
                      initialValue: _selectedRole,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: AppUserRole.values
                          .map(
                            (role) => DropdownMenuItem(
                              value: role,
                              child: Text(labelFromRole(role)),
                            ),
                          )
                          .toList(),
                      onChanged: (role) {
                        if (role != null) setState(() => _selectedRole = role);
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _roleDescription(_selectedRole),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF9AA8BC),
                          ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: AdminActionButton(
                        label: _saving ? 'Salvando...' : 'Criar Usuário',
                        onPressed: _saving
                            ? null
                            : () async {
                                final navigator = Navigator.of(context);
                                final created = await _createUser();
                                if (!context.mounted) {
                                  return;
                                }
                                if (created) {
                                  navigator.pop();
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
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
    return AdminReferenceScaffold(
      title: 'Usuários Internos',
      breadcrumbs: const [
        'Usuários Internos',
        'Supervisor',
        'Perfis de Usuários'
      ],
      selectedMenu: 'users',
      action: AdminActionButton(
        label: 'Novo Usuário',
        onPressed: _openCreateUserDialog,
      ),
      child: usersAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('Nenhum usuário encontrado'));
          }
          return Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFD),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    _headerCell(context, 'Nome', 32),
                    _headerCell(context, 'Email', 30),
                    _headerCell(context, 'Perfil', 18),
                    _headerCell(context, 'Status', 18),
                    _headerCell(context, 'Último acesso', 18),
                    _headerCell(context, 'Ações', 14, alignEnd: true),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (final user in users) ...[
                _UserTableRow(user: user),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
        error: (error, _) => Center(child: Text('Erro: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _headerCell(
    BuildContext context,
    String label,
    int flex, {
    bool alignEnd = false,
  }) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF7A8CA8),
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _UserTableRow extends ConsumerStatefulWidget {
  const _UserTableRow({required this.user});

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
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: user.disabled
            ? const Color(0xFFF7FAFD)
            : Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EEF5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 32,
            child: Row(
              children: [
                Opacity(
                  opacity: user.disabled ? 0.45 : 1.0,
                  child: AdminAvatar(name: user.name),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    user.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: user.disabled
                              ? const Color(0xFF9AA8BC)
                              : const Color(0xFF24364F),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 30,
            child: Text(
              user.email,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF74859E),
                  ),
            ),
          ),
          Expanded(
            flex: 18,
            child: Text(
              deriveUserRole(user),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF334A68),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Expanded(
            flex: 18,
            child: AdminStatusChip(
              label: deriveUserStatus(user),
              color: statusColorFor(user),
            ),
          ),
          Expanded(
            flex: 18,
            child: Text(
              deterministicLastAccess(user),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF74859E),
                  ),
            ),
          ),
          Expanded(
            flex: 14,
            child: Align(
              alignment: Alignment.centerRight,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Wrap(
                      spacing: 6,
                      children: [
                        _ActionIconBtn(
                          icon: Icons.edit_outlined,
                          tooltip: 'Editar',
                          onPressed: _openEditDialog,
                        ),
                        _ActionIconBtn(
                          icon: user.disabled
                              ? Icons.lock_open_rounded
                              : Icons.block_rounded,
                          tooltip: user.disabled ? 'Reativar' : 'Desativar',
                          color: user.disabled
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFF59E0B),
                          onPressed: _toggleDisabled,
                        ),
                        _ActionIconBtn(
                          icon: Icons.delete_outline_rounded,
                          tooltip: 'Excluir',
                          color: const Color(0xFFEF4444),
                          onPressed: _confirmDelete,
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
    _nameCtrl     = TextEditingController(text: widget.user.name);
    _emailCtrl    = TextEditingController(text: widget.user.email);
    _phoneCtrl    = TextEditingController();
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
        AppUserRole.superAdmin => 'Acesso total — cria usuários e vê todos os dados.',
        AppUserRole.master     => 'Revenda — gerencia seus clientes e dispositivos.',
        AppUserRole.operator   => 'Operador — mapa, alertas, relatórios e comandos.',
        AppUserRole.client     => 'Cliente final — visualiza seus veículos.',
        AppUserRole.viewer     => 'Somente leitura — mapa e posições, sem comandos.',
      };

  Future<void> _save() async {
    final name  = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome e e-mail são obrigatórios.')),
      );
      return;
    }
    setState(() => _saving = true);
    final session = ref.read(sessionProvider);
    final client  = ref.read(traccarClientProvider);
    final flags   = traccarFlagsFromRole(_role);

    try {
      final body = <String, dynamic>{
        'id':            widget.user.id,
        'name':          name,
        'email':         email,
        'administrator': widget.user.administrator,
        'readonly':      widget.user.readonly,
        'disabled':      widget.user.disabled,
        ...flags,
        'attributes': {
          ...?widget.user.attributes,
          'soutracking_role': soutrackingAttrFromRole(_role),
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: AdminGlassPanel(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Editar Usuário',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: const Color(0xFF1F2A44),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                StatefulBuilder(builder: (_, setLocal) {
                  return TextField(
                    controller: _passwordCtrl,
                    obscureText: !_showPassword,
                    decoration: InputDecoration(
                      labelText: 'Nova senha (deixe em branco para manter)',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 18,
                        ),
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                Text(
                  'Perfil de acesso',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: const Color(0xFF7A8CA8)),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<AppUserRole>(
                  initialValue: _role,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
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
                const SizedBox(height: 4),
                Text(
                  _roleDescription(_role),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: const Color(0xFF9AA8BC)),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: AdminActionButton(
                    label: _saving ? 'Salvando...' : 'Salvar alterações',
                    onPressed: _saving ? null : _save,
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
