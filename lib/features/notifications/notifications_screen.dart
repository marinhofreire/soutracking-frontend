import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/session_state.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final TextEditingController _nameController =
      TextEditingController(text: 'Alerta rapido');
  String _type = 'alarm';
  bool _always = true;
  final Set<String> _notificators = {'web'};
  bool _saving = false;
  int? _deletingId;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createNotification() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome do alerta.')),
      );
      return;
    }

    if (_notificators.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione ao menos um notificator.')),
      );
      return;
    }

    setState(() => _saving = true);
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);

    try {
      await client.createEntity(
        path: '/notifications',
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'name': name,
          'type': _type,
          'always': _always,
          'notificators': _notificators.toList(growable: false),
        },
      );
      ref.invalidate(notificationsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alerta criado com sucesso.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao criar alerta: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteNotification(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id is! int) return;
    final name = '${item['name'] ?? 'Alerta #$id'}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir alerta'),
        content: Text('Excluir "$name" do Traccar real?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deletingId = id);
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    try {
      await client.deleteEntity(
        path: '/notifications/$id',
        cookie: session.cookie,
        authHeader: session.authHeader,
      );
      ref.invalidate(notificationsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alerta excluído.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao excluir alerta: $error')),
      );
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);

    final list = notificationsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('Nenhum alerta cadastrado.'));
        }

        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            final title =
                (item['name'] ?? 'Alerta #${item['id'] ?? '-'}').toString();
            final subtitle = [
              if (item['type'] != null) 'Tipo: ${item['type']}',
              if (item['always'] != null) 'Sempre: ${item['always']}',
              if (item['id'] != null) 'ID: ${item['id']}',
            ].join(' • ');

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Theme.of(context).colorScheme.outline),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.notifications_active_outlined),
                title: Text(title),
                subtitle: subtitle.isEmpty ? null : Text(subtitle),
                trailing: IconButton(
                  tooltip: 'Excluir alerta',
                  onPressed: _deletingId == item['id']
                      ? null
                      : () => _deleteNotification(item),
                  icon: _deletingId == item['id']
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.delete_outline,
                          color: Color(0xFFEF4444),
                        ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('Erro ao carregar notificacoes: $error')),
    );

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notificacoes',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Nome do alerta',
            hintText: 'Ex: Alerta de velocidade',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _type,
          items: const [
            DropdownMenuItem(value: 'alarm', child: Text('alarm')),
            DropdownMenuItem(value: 'ignitionOn', child: Text('ignitionOn')),
            DropdownMenuItem(
              value: 'ignitionOff',
              child: Text('ignitionOff'),
            ),
            DropdownMenuItem(value: 'overspeed', child: Text('overspeed')),
            DropdownMenuItem(
              value: 'deviceOnline',
              child: Text('deviceOnline'),
            ),
            DropdownMenuItem(
              value: 'deviceOffline',
              child: Text('deviceOffline'),
            ),
            DropdownMenuItem(
              value: 'geofenceEnter',
              child: Text('geofenceEnter'),
            ),
            DropdownMenuItem(
              value: 'geofenceExit',
              child: Text('geofenceExit'),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _type = value);
          },
          decoration: const InputDecoration(labelText: 'Tipo'),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          value: _always,
          onChanged: (value) => setState(() => _always = value),
          title: const Text('Sempre ativo (always)'),
        ),
        const SizedBox(height: 8),
        Text(
          'Notificadores',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('web'),
              selected: _notificators.contains('web'),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _notificators.add('web');
                  } else {
                    _notificators.remove('web');
                  }
                });
              },
            ),
            FilterChip(
              label: const Text('mail'),
              selected: _notificators.contains('mail'),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _notificators.add('mail');
                  } else {
                    _notificators.remove('mail');
                  }
                });
              },
            ),
            FilterChip(
              label: const Text('sms'),
              selected: _notificators.contains('sms'),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _notificators.add('sms');
                  } else {
                    _notificators.remove('sms');
                  }
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: _saving ? null : _createNotification,
              icon: _saving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_alert_outlined),
              label: Text(_saving ? 'Criando...' : 'Criar alerta'),
            ),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(notificationsProvider),
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('Atualizar lista'),
            ),
          ],
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 380,
                margin: const EdgeInsets.only(left: 16, right: 20, top: 24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF183153).withValues(alpha: 0.12),
                        blurRadius: 14,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SingleChildScrollView(child: form),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24, right: 16),
                  child: list,
                ),
              ),
            ],
          );
        }

        return ListView(
          children: [
            form,
            const SizedBox(height: 16),
            SizedBox(height: 460, child: list),
          ],
        );
      },
    );
  }
}
