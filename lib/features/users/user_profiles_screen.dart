import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/session_state.dart';
import '../admin/admin_reference_ui.dart';

class UserProfilesScreen extends ConsumerWidget {
  const UserProfilesScreen({super.key});

  void _openCreateProfileDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Novo Perfil'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nome do perfil',
              hintText: 'Ex.: Coordenador Regional',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Informe o nome do perfil.'),
                    ),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Fluxo de perfil "$name" iniciado. Proximo passo: ajustar permissoes.',
                    ),
                  ),
                );
              },
              child: const Text('Criar'),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);
  }

  void _openProfilePermissionsDialog(
    BuildContext context,
    AdminRoleSummary profile,
    List<TraccarUser> users,
  ) {
    final roleUsers =
        users.where((user) => deriveUserRole(user) == profile.label).toList();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Permissoes - ${profile.label}'),
          content: SizedBox(
            width: 460,
            child: roleUsers.isEmpty
                ? const Text('Nenhum usuario neste perfil no momento.')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Usuarios vinculados: ${roleUsers.length}'),
                      const SizedBox(height: 10),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: roleUsers.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final user = roleUsers[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              leading: const Icon(Icons.person_outline),
                              title: Text(user.name),
                              subtitle: Text(user.email),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fechar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Abra Permissoes dos Usuarios no menu para ajustar acessos.',
                    ),
                  ),
                );
              },
              child: const Text('Ir para Permissoes'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);

    return AdminReferenceScaffold(
      title: 'Perfis de Usuários',
      selectedMenu: 'profiles',
      action: AdminActionButton(
        label: 'Novo Perfil',
        onPressed: () => _openCreateProfileDialog(context),
      ),
      child: usersAsync.when(
        data: (users) {
          final profiles = buildRoleSummaries(users);
          return Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFD),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        'Perfil',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: const Color(0xFF7A8CA8),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Usuários',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: const Color(0xFF7A8CA8),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Ações',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: const Color(0xFF7A8CA8),
                              fontWeight: FontWeight.w700,
                            ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (final profile in profiles) ...[
                _ProfileRow(
                  profile: profile,
                  onOpenPermissions: () => _openProfilePermissionsDialog(
                    context,
                    profile,
                    users,
                  ),
                ),
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
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.profile,
    required this.onOpenPermissions,
  });

  final AdminRoleSummary profile;
  final VoidCallback onOpenPermissions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9EEF5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Row(
              children: [
                AdminAvatar(name: profile.label),
                const SizedBox(width: 12),
                Text(
                  profile.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF2A3B57),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${profile.count}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF334A68),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onOpenPermissions,
                icon: const Icon(Icons.shield_outlined, size: 16),
                label: const Text('Permissões'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF60748F),
                  side: const BorderSide(color: Color(0xFFD5DFEA)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
