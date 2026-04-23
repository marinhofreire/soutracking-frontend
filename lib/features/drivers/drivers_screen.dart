import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/session_state.dart';

class DriversScreen extends ConsumerStatefulWidget {
  const DriversScreen({super.key});

  @override
  ConsumerState<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends ConsumerState<DriversScreen> {
  final _nameController = TextEditingController();
  final _uniqueIdController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _uniqueIdController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _createDriver() async {
    final name = _nameController.text.trim();
    final uniqueId = _uniqueIdController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || uniqueId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome e identificador são obrigatórios.')),
      );
      return;
    }

    setState(() => _saving = true);
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);

    try {
      await client.createEntity(
        path: '/drivers',
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'name': name,
          'uniqueId': uniqueId,
          if (phone.isNotEmpty) 'phone': phone,
        },
      );
      ref.invalidate(driversProvider);
      _nameController.clear();
      _uniqueIdController.clear();
      _phoneController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Motorista criado com sucesso.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Falha ao criar motorista: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final driversAsync = ref.watch(driversProvider);

    final list = driversAsync.when(
      data: (drivers) {
        if (drivers.isEmpty) {
          return const Center(child: Text('Nenhum motorista encontrado'));
        }
        return ListView.separated(
          itemCount: drivers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final driver = drivers[index];
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
                  const Icon(Icons.badge_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${driver['name'] ?? 'Motorista'}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (driver['uniqueId'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'ID: ${driver['uniqueId']}',
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
        Text('Motoristas', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Nome do motorista'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _uniqueIdController,
          decoration: const InputDecoration(labelText: 'Identificador único'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneController,
          decoration: const InputDecoration(labelText: 'Telefone (opcional)'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _saving ? null : _createDriver,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Criar motorista'),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Painel de formulário sempre à esquerda, colado na sidebar
            Container(
              width: 380,
              margin: const EdgeInsets.only(left: 16, right: 20, top: 24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 14,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: form,
                  ),
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
