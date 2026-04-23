import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/session_state.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  final _nameController = TextEditingController();
  final _parentIdController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _parentIdController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    final parentId = int.tryParse(_parentIdController.text.trim());

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome do grupo é obrigatório.')),
      );
      return;
    }

    setState(() => _saving = true);
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);

    try {
      await client.createEntity(
        path: '/groups',
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {'name': name, if (parentId != null) 'groupId': parentId},
      );
      ref.invalidate(groupsProvider);
      _nameController.clear();
      _parentIdController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grupo criado com sucesso.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Falha ao criar grupo: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsProvider);

    final list = groupsAsync.when(
      data: (groups) {
        if (groups.isEmpty) {
          return const Center(child: Text('Nenhum grupo encontrado'));
        }
        return ListView.separated(
          itemCount: groups.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final group = groups[index];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_open_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${group['name'] ?? 'Grupo'}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (group['groupId'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Pai: ${group['groupId']}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      error: (error, _) => Center(child: Text('Erro: $error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Grupos', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Nome do grupo'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _parentIdController,
          decoration: const InputDecoration(
            labelText: 'Grupo pai (ID opcional)',
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _saving ? null : _createGroup,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Criar grupo'),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        // Sempre ancorar o painel à esquerda, logo após a sidebar
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Painel de formulário sempre à esquerda, colado na sidebar
            Container(
              width: 380,
              margin: const EdgeInsets.only(left: 16, right: 20, top: 24),
              child: Card(
                color: Colors.grey[900],
                elevation: 6,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(child: form),
                ),
              ),
            ),
            // Lista ocupa o restante da área
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 24, right: 16),
                child: list,
              ),
            ),
          ],
        );
      },
    );
  }
}
