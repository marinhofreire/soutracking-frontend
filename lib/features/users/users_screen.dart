import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  bool _admin = false;
  bool _readonly = false;
  bool _disabled = false;
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
                    SwitchListTile(
                      value: _admin,
                      onChanged: (value) => setState(() => _admin = value),
                      title: const Text('Administrador'),
                    ),
                    SwitchListTile(
                      value: _readonly,
                      onChanged: (value) => setState(() => _readonly = value),
                      title: const Text('Somente leitura'),
                    ),
                    SwitchListTile(
                      value: _disabled,
                      onChanged: (value) => setState(() => _disabled = value),
                      title: const Text('Desativado'),
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
      await client.createUser(
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'name': name,
          'email': email,
          'password': password,
          if (phone.isNotEmpty) 'phone': phone,
          'administrator': _admin,
          'readonly': _readonly,
          'disabled': _disabled,
        },
      );
      ref.invalidate(usersProvider);
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _phoneController.clear();
      setState(() {
        _admin = false;
        _readonly = false;
        _disabled = false;
      });
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

class _UserTableRow extends StatelessWidget {
  const _UserTableRow({required this.user});

  final TraccarUser user;

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
            flex: 32,
            child: Row(
              children: [
                AdminAvatar(name: user.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    user.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF24364F),
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
              child: Wrap(
                spacing: 8,
                children: const [
                  _ActionIcon(icon: Icons.visibility_outlined),
                  _ActionIcon(icon: Icons.edit_outlined),
                  _ActionIcon(icon: Icons.security_outlined),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: const Color(0xFFF6F9FC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCE5F0)),
      ),
      child: Icon(icon, size: 16, color: const Color(0xFF6B7C95)),
    );
  }
}
