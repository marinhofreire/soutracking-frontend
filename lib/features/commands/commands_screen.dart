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
            'Essa ação será executada no servidor.',
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
      DropdownMenuItem(value: 'engineStop', child: Text('Bloquear')),
      DropdownMenuItem(value: 'engineResume', child: Text('Desbloquear')),
      DropdownMenuItem(value: 'alarm', child: Text('Acionar alarme')),
      DropdownMenuItem(value: 'positionSingle', child: Text('Posição única')),
      DropdownMenuItem(value: 'custom', child: Text('Custom')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xE6FFFFFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD6E0EE)),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Novo comando',
                style: TextStyle(
                  color: Color(0xFF25344A),
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              SizedBox(
                width: 300,
                child: devicesAsync.when(
                  data: (devices) => DropdownButtonFormField<int?>(
                    initialValue: _deviceId,
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Color(0xFF25344A)),
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
                    decoration: _inputDecoration('Dispositivo'),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) =>
                      Text('Erro ao carregar dispositivos: $error'),
                ),
              ),
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String>(
                  initialValue: _commandType,
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: Color(0xFF25344A)),
                  items: commandItems,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _commandType = value);
                  },
                  decoration: _inputDecoration('Tipo de comando'),
                ),
              ),
              if (_commandType == 'custom')
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _customDataController,
                    style: const TextStyle(color: Color(0xFF25344A)),
                    decoration: _inputDecoration(
                      'Payload custom',
                      hintText: 'Ex: AT+RST',
                    ),
                  ),
                ),
              FilledButton.icon(
                onPressed: _sending ? null : _sendCommand,
                icon: _sending
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(_sending ? 'Enviando...' : 'Enviar'),
              ),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(commandsProvider),
                icon: const Icon(Icons.refresh_outlined),
                label: const Text('Atualizar'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xE6FFFFFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD6E0EE)),
            ),
            child: commandsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhum comando cadastrado.',
                      style: TextStyle(
                        color: Color(0xFFA8C0DF),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xCCF8FBFF),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color:
                                const Color(0xFFD6E0EE).withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Expanded(flex: 3, child: _HeaderCell('Comando')),
                          Expanded(flex: 2, child: _HeaderCell('Equipamento')),
                          Expanded(flex: 3, child: _HeaderCell('Enviado em')),
                          Expanded(flex: 2, child: _HeaderCell('Status')),
                          SizedBox(width: 52),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => Divider(
                          color: const Color(0xFFD6E0EE).withValues(alpha: 0.9),
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final title =
                              (item['description'] ?? item['type'] ?? 'Comando')
                                  .toString();
                          final device = (item['deviceId'] ?? '-').toString();
                          final sentAt = (item['sentAt'] ??
                                  item['serverTime'] ??
                                  item['id'] ??
                                  '-')
                              .toString();
                          final status =
                              (item['status'] ?? 'Executado').toString();

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 9),
                            child: Row(
                              children: [
                                Expanded(flex: 3, child: _CellText(title)),
                                Expanded(flex: 2, child: _CellText(device)),
                                Expanded(flex: 3, child: _CellText(sentAt)),
                                Expanded(
                                  flex: 2,
                                  child: _StatusChip(status: status),
                                ),
                                const SizedBox(
                                  width: 52,
                                  child: Icon(
                                    Icons.chevron_right,
                                    color: Color(0xFF5F738F),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('Erro ao carregar comandos: $error'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF5F738F),
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );
  }
}

class _CellText extends StatelessWidget {
  const _CellText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFF334155),
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color = normalized.contains('fail') || normalized.contains('error')
        ? const Color(0xFFE74B4B)
        : normalized.contains('pend')
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          status,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(String label, {String? hintText}) {
  return InputDecoration(
    labelText: label,
    hintText: hintText,
    hintStyle: const TextStyle(color: Color(0xFF5F738F)),
    labelStyle: const TextStyle(color: Color(0xFF5F738F)),
    filled: true,
    fillColor: const Color(0xFFF7F9FD),
    border: const OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFFD6E0EE)),
    ),
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFFD6E0EE)),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFF4A95FF)),
    ),
    isDense: true,
  );
}
