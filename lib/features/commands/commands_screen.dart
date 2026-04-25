import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/session_state.dart';

class CommandsScreen extends ConsumerStatefulWidget {
  const CommandsScreen({super.key});

  @override
  ConsumerState<CommandsScreen> createState() => _CommandsScreenState();
}

class _CommandsScreenState extends ConsumerState<CommandsScreen> {
  int? _deviceId;
  String _commandType = 'engineStop';
  bool _sending = false;
  final TextEditingController _customDataController =
      TextEditingController(text: 'AT');

  @override
  void dispose() {
    _customDataController.dispose();
    super.dispose();
  }

  Future<void> _sendCommand() async {
    if (_deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um dispositivo.')),
      );
      return;
    }

    final isCustom = _commandType == 'custom';
    final customData = _customDataController.text.trim();
    if (isCustom && customData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o payload do comando custom.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar comando remoto'),
          content: Text(
            'Enviar "$_commandType" para o dispositivo #$_deviceId? '
            'Essa ação será executada no Traccar real.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.send_outlined),
              label: const Text('Enviar'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    setState(() => _sending = true);
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);

    try {
      await client.createEntity(
        path: '/commands/send',
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'deviceId': _deviceId,
          'type': _commandType,
          if (isCustom)
            'attributes': {
              'data': customData,
            },
        },
      );
      ref.invalidate(commandsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comando enviado com sucesso.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao enviar comando: $error')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesProvider);
    final commandsAsync = ref.watch(commandsProvider);

    final commandItems = const [
      DropdownMenuItem(value: 'engineStop', child: Text('engineStop')),
      DropdownMenuItem(value: 'engineResume', child: Text('engineResume')),
      DropdownMenuItem(value: 'alarm', child: Text('alarm')),
      DropdownMenuItem(value: 'positionSingle', child: Text('positionSingle')),
      DropdownMenuItem(value: 'custom', child: Text('custom')),
    ];

    final list = commandsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('Nenhum comando cadastrado.'));
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            final title =
                (item['description'] ?? item['type'] ?? 'Comando').toString();
            final subtitle = [
              if (item['type'] != null) 'Tipo: ${item['type']}',
              if (item['deviceId'] != null) 'Dispositivo: ${item['deviceId']}',
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
                leading: const Icon(Icons.terminal_outlined),
                title: Text(title),
                subtitle: subtitle.isEmpty ? null : Text(subtitle),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('Erro ao carregar comandos: $error')),
    );

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comandos remotos',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        devicesAsync.when(
          data: (devices) {
            return DropdownButtonFormField<int?>(
              initialValue: _deviceId,
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Selecionar dispositivo'),
                ),
                ...devices.map(
                  (device) => DropdownMenuItem<int?>(
                    value: device.id,
                    child: Text('${device.name} (#${device.id})'),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _deviceId = value),
              decoration: const InputDecoration(labelText: 'Dispositivo'),
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text('Erro ao carregar dispositivos: $error'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _commandType,
          items: commandItems,
          onChanged: (value) {
            if (value == null) return;
            setState(() => _commandType = value);
          },
          decoration: const InputDecoration(labelText: 'Tipo de comando'),
        ),
        if (_commandType == 'custom') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _customDataController,
            decoration: const InputDecoration(
              labelText: 'Payload custom',
              hintText: 'Ex: AT+RST',
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: _sending ? null : _sendCommand,
              icon: _sending
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(_sending ? 'Enviando...' : 'Enviar comando'),
            ),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(commandsProvider),
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
