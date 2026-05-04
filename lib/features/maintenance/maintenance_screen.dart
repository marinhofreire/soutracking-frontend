import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/session_state.dart';

class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  final _nameController = TextEditingController();
  final _startController = TextEditingController();
  final _periodController = TextEditingController();
  String _type = 'distance';
  int? _deviceId;
  bool _saving = false;
  int? _deletingId;

  @override
  void dispose() {
    _nameController.dispose();
    _startController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  Future<void> _createMaintenance() async {
    final name = _nameController.text.trim();
    final start = double.tryParse(_startController.text.trim());
    final period = double.tryParse(_periodController.text.trim());

    if (name.isEmpty || start == null || period == null || _deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nome, dispositivo, início e período são obrigatórios.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);

    try {
      await client.createEntity(
        path: '/maintenance',
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'name': name,
          'type': _type,
          'start': start,
          'period': period,
          'deviceId': _deviceId,
        },
      );
      ref.invalidate(maintenanceProvider);
      _nameController.clear();
      _startController.clear();
      _periodController.clear();
      setState(() {
        _type = 'distance';
        _deviceId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plano criado com sucesso.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Falha ao criar plano: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteMaintenance(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id is! int) return;
    final name = '${item['name'] ?? 'Manutenção #$id'}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir manutenção'),
        content: Text('Excluir "$name" do servidor de rastreamento?'),
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
        path: '/maintenance/$id',
        cookie: session.cookie,
        authHeader: session.authHeader,
      );
      ref.invalidate(maintenanceProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manutenção excluída.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao excluir manutenção: $error')),
      );
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maintenanceAsync = ref.watch(maintenanceProvider);
    final devicesAsync = ref.watch(devicesProvider);

    final list = maintenanceAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('Nenhum plano de manutenção'));
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            final title = item['name'] ?? 'Manutenção';
            final subtitle = [
              if (item['type'] != null) 'Tipo: ${item['type']}',
              if (item['deviceId'] != null) 'Device: ${item['deviceId']}',
            ].join(' • ');
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
                  const Icon(Icons.build_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$title',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: const Color(0xFF60718D)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Excluir manutenção',
                    onPressed: _deletingId == item['id']
                        ? null
                        : () => _deleteMaintenance(item),
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
                ],
              ),
            );
          },
        );
      },
      error: (error, _) => Center(child: Text('Erro: $error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );

    final form = Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Manutenção',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: const Color(0xFF1F2A44))),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nome do plano'),
            style: const TextStyle(color: Color(0xFF1F2A44)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('maintenance-type-$_type'),
            initialValue: _type,
            items: const [
              DropdownMenuItem(value: 'distance', child: Text('Distância')),
              DropdownMenuItem(
                  value: 'engineHours', child: Text('Horas motor')),
              DropdownMenuItem(value: 'days', child: Text('Dias')),
            ],
            onChanged: (value) => setState(() => _type = value ?? 'distance'),
            decoration: const InputDecoration(labelText: 'Tipo'),
            dropdownColor: Colors.white,
            style: const TextStyle(color: Color(0xFF1F2A44)),
          ),
          const SizedBox(height: 12),
          devicesAsync.when(
            data: (devices) {
              return DropdownButtonFormField<int>(
                key: ValueKey('maintenance-device-${_deviceId ?? 'all'}'),
                initialValue: _deviceId,
                items: devices
                    .map(
                      (d) => DropdownMenuItem<int>(
                          value: d.id, child: Text(d.name)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _deviceId = value),
                decoration: const InputDecoration(labelText: 'Dispositivo'),
                dropdownColor: Colors.white,
                style: const TextStyle(color: Color(0xFF1F2A44)),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Erro: $error',
                style: const TextStyle(color: Color(0xFF1F2A44))),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _startController,
            decoration: const InputDecoration(labelText: 'Valor inicial'),
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Color(0xFF1F2A44)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _periodController,
            decoration: const InputDecoration(labelText: 'Período'),
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Color(0xFF1F2A44)),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _createMaintenance,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Criar plano'),
          ),
        ],
      ),
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
                child: form,
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
            const SizedBox(height: 20),
            SizedBox(height: 420, child: list),
          ],
        );
      },
    );
  }
}
