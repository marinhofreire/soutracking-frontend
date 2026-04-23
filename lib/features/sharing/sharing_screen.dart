import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/session_state.dart';

class SharingScreen extends ConsumerStatefulWidget {
  const SharingScreen({super.key});

  @override
  ConsumerState<SharingScreen> createState() => _SharingScreenState();
}

class _SharingScreenState extends ConsumerState<SharingScreen> {
  final _nameController = TextEditingController(text: 'Compartilhamento rapido');
  final _emailController = TextEditingController();
  final Set<int> _deviceIds = <int>{};
  bool _busy = false;
  List<Map<String, dynamic>> _shares = [];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadShares() async {
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    try {
      final data = await client.getList(
        path: '/shares',
        cookie: session.cookie,
        authHeader: session.authHeader,
      );
      if (!mounted) return;
      setState(() => _shares = data);
    } catch (_) {
      // Some servers may not have /shares enabled.
    }
  }

  Future<void> _createShare() async {
    if (_deviceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione ao menos um veiculo.')),
      );
      return;
    }

    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    setState(() => _busy = true);
    try {
      for (final id in _deviceIds) {
        await client.createEntity(
          path: '/shares',
          cookie: session.cookie,
          authHeader: session.authHeader,
          body: {
            'name': _nameController.text.trim().isEmpty
                ? 'Compartilhamento $id'
                : _nameController.text.trim(),
            'deviceId': id,
            if (_emailController.text.trim().isNotEmpty)
              'attributes': {'emails': _emailController.text.trim()},
          },
        );
      }
      await _loadShares();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compartilhamento criado.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao compartilhar: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.only(top: 20, right: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Compartilhar localizacao',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Descricao'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Emails (opcional)',
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: devicesAsync.when(
                    data: (devices) => ListView(
                      children: [
                        for (final d in devices)
                          CheckboxListTile(
                            value: _deviceIds.contains(d.id),
                            title: Text(d.name),
                            subtitle: Text('ID ${d.id}'),
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _deviceIds.add(d.id);
                                } else {
                                  _deviceIds.remove(d.id);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Erro: $e')),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy ? null : _createShare,
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Salvar'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _loadShares,
                      icon: const Icon(Icons.refresh_outlined),
                      label: const Text('Atualizar links'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(top: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: _shares.isEmpty
                ? const Center(
                    child: Text('Sem links carregados. Clique em Atualizar links.'),
                  )
                : ListView.separated(
                    itemCount: _shares.length,
                    separatorBuilder: (_, __) => const Divider(height: 16),
                    itemBuilder: (context, index) {
                      final item = _shares[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.link_outlined),
                        title: Text('${item['name'] ?? 'Link'}'),
                        subtitle: Text('${item['link'] ?? item['token'] ?? ''}'),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
