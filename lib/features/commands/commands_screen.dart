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
            'Essa ação será executada no servidor de rastreamento.',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDDE5F0)),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Comandos remotos',
                style: TextStyle(
                  color: Color(0xFF1F2A44),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              SizedBox(
                width: 300,
                child: devicesAsync.when(
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
                      decoration: const InputDecoration(
                        labelText: 'Dispositivo',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) =>
                      Text('Erro ao carregar dispositivos: $error'),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: _commandType,
                  items: commandItems,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _commandType = value);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Tipo de comando',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              if (_commandType == 'custom')
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: _customDataController,
                    decoration: const InputDecoration(
                      labelText: 'Payload custom',
                      hintText: 'Ex: AT+RST',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
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
        ),
        const SizedBox(height: 10),
        Expanded(child: list),
      ],
    );
  }
}
