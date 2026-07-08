import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/session_state.dart';

final savedCommandsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final session = ref.watch(sessionProvider);
  final client = ref.watch(traccarClientProvider);
  try {
    return await client.getList(
      path: '/commands',
      cookie: session.cookie,
      authHeader: session.authHeader,
    );
  } catch (_) {
    return [];
  }
});

class CommandsScreen extends ConsumerStatefulWidget {
  const CommandsScreen({super.key});

  @override
  ConsumerState<CommandsScreen> createState() => _CommandsScreenState();
}

class _CommandsScreenState extends ConsumerState<CommandsScreen> {
  // ── Send-now form ─────────────────────────────────────────────────────────
  int? _deviceId;
  String _sendType = 'engineStop';
  String _sendOutputIndex = '1';
  String _sendOutputData = '1';
  bool _sending = false;
  final TextEditingController _sendCustomCtrl =
      TextEditingController(text: 'AT');

  // ── Create-command dialog ─────────────────────────────────────────────────
  bool _saving = false;
  final TextEditingController _dlgDescCtrl = TextEditingController();
  int? _dlgDeviceId;
  String _dlgType = 'engineStop';
  String _dlgOutputIndex = '1';
  String _dlgOutputData = '1';
  final TextEditingController _dlgCustomCtrl = TextEditingController();

  static const _commandTypes = [
    ('engineStop', 'Bloquear motor'),
    ('engineResume', 'Desbloquear motor'),
    ('outputControl', 'Acionar saída (relê)'),
    ('alarm', 'Acionar alarme'),
    ('positionSingle', 'Posição única'),
    ('custom', 'Custom'),
  ];

  static const _outputIndices = ['1', '2', '3', '4', '5', '6', '7', '8'];

  String _typeLabel(String type) {
    for (final t in _commandTypes) {
      if (t.$1 == type) return t.$2;
    }
    return type;
  }

  @override
  void dispose() {
    _sendCustomCtrl.dispose();
    _dlgDescCtrl.dispose();
    _dlgCustomCtrl.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _sendCommand() async {
    if (_deviceId == null) {
      _snack('Selecione um dispositivo.');
      return;
    }
    if (_sendType == 'custom' && _sendCustomCtrl.text.trim().isEmpty) {
      _snack('Informe o payload do comando custom.');
      return;
    }

    final confirmed = await _confirmDialog(
      'Confirmar envio',
      'Enviar "${_typeLabel(_sendType)}" para dispositivo #$_deviceId?\n'
          'Esta ação será executada imediatamente.',
    );
    if (confirmed != true) return;

    setState(() => _sending = true);
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    try {
      final body = <String, dynamic>{
        'deviceId': _deviceId,
        'type': _sendType,
      };
      if (_sendType == 'outputControl') {
        body['attributes'] = {
          'index': _sendOutputIndex,
          'data': _sendOutputData,
        };
      } else if (_sendType == 'custom') {
        body['attributes'] = {'data': _sendCustomCtrl.text.trim()};
      }
      await client.createEntity(
        path: '/commands/send',
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: body,
      );
      if (!mounted) return;
      _snack('Comando enviado com sucesso.');
    } catch (e) {
      if (!mounted) return;
      _snack('Falha ao enviar: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendSaved(Map<String, dynamic> cmd) async {
    final name = cmd['description'] ?? _typeLabel(cmd['type'] ?? '');
    final deviceId = cmd['deviceId'];
    if (deviceId == null) {
      _snack('Este comando não possui dispositivo vinculado.');
      return;
    }
    final confirmed = await _confirmDialog(
      'Confirmar envio',
      'Enviar "$name" para dispositivo #$deviceId?',
    );
    if (confirmed != true) return;

    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    try {
      await client.createEntity(
        path: '/commands/send',
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {'id': cmd['id']},
      );
      if (!mounted) return;
      _snack('Comando enviado.');
    } catch (e) {
      if (!mounted) return;
      _snack('Falha ao enviar: $e');
    }
  }

  Future<void> _saveCommand() async {
    final desc = _dlgDescCtrl.text.trim();
    if (desc.isEmpty) {
      _snack('Informe um nome para o comando.');
      return;
    }
    if (_dlgType == 'custom' && _dlgCustomCtrl.text.trim().isEmpty) {
      _snack('Informe o payload do comando custom.');
      return;
    }
    setState(() => _saving = true);
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    try {
      final body = <String, dynamic>{
        'description': desc,
        'type': _dlgType,
        if (_dlgDeviceId != null) 'deviceId': _dlgDeviceId,
      };
      if (_dlgType == 'outputControl') {
        body['attributes'] = {
          'index': _dlgOutputIndex,
          'data': _dlgOutputData,
        };
      } else if (_dlgType == 'custom') {
        body['attributes'] = {'data': _dlgCustomCtrl.text.trim()};
      }
      await client.createEntity(
        path: '/commands',
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: body,
      );
      ref.invalidate(savedCommandsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      _snack('Comando salvo com sucesso.');
    } catch (e) {
      if (!mounted) return;
      _snack('Falha ao salvar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteCommand(int id, String name) async {
    final confirmed = await _confirmDialog(
      'Excluir comando',
      'Remover "$name"? Esta ação não pode ser desfeita.',
    );
    if (confirmed != true) return;
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    try {
      await client.deleteEntity(
        path: '/commands/$id',
        cookie: session.cookie,
        authHeader: session.authHeader,
      );
      ref.invalidate(savedCommandsProvider);
      if (!mounted) return;
      _snack('Comando removido.');
    } catch (e) {
      if (!mounted) return;
      _snack('Falha ao remover: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool?> _confirmDialog(String title, String body) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(List<dynamic> devices) {
    _dlgDescCtrl.clear();
    _dlgDeviceId = null;
    _dlgType = 'engineStop';
    _dlgOutputIndex = '1';
    _dlgOutputData = '1';
    _dlgCustomCtrl.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Dialog header ──────────────────────────────────
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A95FF).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add_circle_outline,
                              color: Color(0xFF4A95FF), size: 18),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Criar Comando',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: Color(0xFF1F2A44))),
                              Text('Configure e salve um comando reutilizável',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF5A6B84))),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close, size: 18),
                          style: IconButton.styleFrom(
                              foregroundColor: const Color(0xFF5A6B84)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Nome do comando ────────────────────────────────
                    TextField(
                      controller: _dlgDescCtrl,
                      style: const TextStyle(color: Color(0xFF25344A)),
                      decoration: _inputDecoration('Nome do comando',
                          hintText: 'Ex: Acionar luz dianteira'),
                    ),
                    const SizedBox(height: 12),

                    // ── Tipo ───────────────────────────────────────────
                    DropdownButtonFormField<String>(
                      value: _dlgType,
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Color(0xFF25344A)),
                      decoration: _inputDecoration('Tipo de comando'),
                      items: _commandTypes
                          .map((t) => DropdownMenuItem(
                              value: t.$1, child: Text(t.$2)))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setDlg(() => _dlgType = v);
                        setState(() => _dlgType = v);
                      },
                    ),
                    const SizedBox(height: 12),

                    // ── outputControl options ──────────────────────────
                    if (_dlgType == 'outputControl') ...[
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _dlgOutputIndex,
                              dropdownColor: Colors.white,
                              style: const TextStyle(color: Color(0xFF25344A)),
                              decoration: _inputDecoration('Índice da saída'),
                              items: _outputIndices
                                  .map((i) => DropdownMenuItem(
                                      value: i, child: Text('Saída $i')))
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setDlg(() => _dlgOutputIndex = v);
                                setState(() => _dlgOutputIndex = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _dlgOutputData,
                              dropdownColor: Colors.white,
                              style: const TextStyle(color: Color(0xFF25344A)),
                              decoration: _inputDecoration('Ação'),
                              items: const [
                                DropdownMenuItem(
                                    value: '1', child: Text('Ativar (ON)')),
                                DropdownMenuItem(
                                    value: '0', child: Text('Desativar (OFF)')),
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                setDlg(() => _dlgOutputData = v);
                                setState(() => _dlgOutputData = v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── custom payload ─────────────────────────────────
                    if (_dlgType == 'custom') ...[
                      TextField(
                        controller: _dlgCustomCtrl,
                        style: const TextStyle(color: Color(0xFF25344A)),
                        decoration: _inputDecoration('Payload custom',
                            hintText: 'Ex: AT+RST'),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Dispositivo (opcional) ─────────────────────────
                    DropdownButtonFormField<int?>(
                      value: _dlgDeviceId,
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Color(0xFF25344A)),
                      decoration:
                          _inputDecoration('Dispositivo (opcional)'),
                      items: [
                        const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Nenhum — universal')),
                        ...devices.map((d) => DropdownMenuItem<int?>(
                            value: d.id,
                            child: Text('${d.name} (#${d.id})'))),
                      ],
                      onChanged: (v) {
                        setDlg(() => _dlgDeviceId = v);
                        setState(() => _dlgDeviceId = v);
                      },
                    ),
                    const SizedBox(height: 20),

                    // ── Actions ────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _saving ? null : _saveCommand,
                          icon: _saving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save_outlined, size: 16),
                          label: Text(_saving ? 'Salvando...' : 'Salvar comando'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesProvider);
    final savedAsync = ref.watch(savedCommandsProvider);
    final devices = devicesAsync.valueOrNull ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comandos',
                    style: TextStyle(
                      color: Color(0xFF1F2A44),
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Envie e gerencie comandos remotos para dispositivos rastreados.',
                    style: TextStyle(color: Color(0xFF5A6B84), fontSize: 13),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => _showCreateDialog(devices),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Criar Comando'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4A95FF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Enviar agora ────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8EEF6)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 4,
                  offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enviar agora',
                style: TextStyle(
                    color: Color(0xFF1F2A44),
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Device dropdown
                  SizedBox(
                    width: 280,
                    child: devicesAsync.when(
                      data: (list) => DropdownButtonFormField<int?>(
                        value: _deviceId,
                        dropdownColor: Colors.white,
                        style: const TextStyle(color: Color(0xFF25344A)),
                        items: [
                          const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Selecionar dispositivo')),
                          ...list.map((d) => DropdownMenuItem<int?>(
                              value: d.id,
                              child: Text('${d.name} (#${d.id})'))),
                        ],
                        onChanged: (v) => setState(() => _deviceId = v),
                        decoration: _inputDecoration('Dispositivo'),
                      ),
                      loading: () => const SizedBox(
                          height: 36,
                          child: LinearProgressIndicator()),
                      error: (e, _) =>
                          Text('Erro: $e',
                              style: const TextStyle(
                                  color: Color(0xFFE74B4B))),
                    ),
                  ),
                  // Type dropdown
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      value: _sendType,
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Color(0xFF25344A)),
                      items: _commandTypes
                          .map((t) => DropdownMenuItem(
                              value: t.$1, child: Text(t.$2)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _sendType = v);
                      },
                      decoration: _inputDecoration('Tipo'),
                    ),
                  ),
                  // outputControl extras
                  if (_sendType == 'outputControl') ...[
                    SizedBox(
                      width: 130,
                      child: DropdownButtonFormField<String>(
                        value: _sendOutputIndex,
                        dropdownColor: Colors.white,
                        style: const TextStyle(color: Color(0xFF25344A)),
                        decoration: _inputDecoration('Saída'),
                        items: _outputIndices
                            .map((i) => DropdownMenuItem(
                                value: i, child: Text('Saída $i')))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _sendOutputIndex = v);
                          }
                        },
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: DropdownButtonFormField<String>(
                        value: _sendOutputData,
                        dropdownColor: Colors.white,
                        style: const TextStyle(color: Color(0xFF25344A)),
                        decoration: _inputDecoration('Ação'),
                        items: const [
                          DropdownMenuItem(
                              value: '1', child: Text('Ativar (ON)')),
                          DropdownMenuItem(
                              value: '0', child: Text('Desativar (OFF)')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _sendOutputData = v);
                          }
                        },
                      ),
                    ),
                  ],
                  // custom payload
                  if (_sendType == 'custom')
                    SizedBox(
                      width: 200,
                      child: TextField(
                        controller: _sendCustomCtrl,
                        style: const TextStyle(color: Color(0xFF25344A)),
                        decoration:
                            _inputDecoration('Payload', hintText: 'AT+RST'),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: _sending ? null : _sendCommand,
                    icon: _sending
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_outlined, size: 16),
                    label: Text(_sending ? 'Enviando...' : 'Enviar'),
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Comandos salvos ─────────────────────────────────────────────────
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD6E0EE)),
            ),
            child: Column(
              children: [
                // Section header
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFD),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    border: Border(
                      bottom: BorderSide(
                          color: const Color(0xFFD6E0EE)
                              .withValues(alpha: 0.9)),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Comandos Configurados',
                          style: TextStyle(
                            color: Color(0xFF1F2A44),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            ref.invalidate(savedCommandsProvider),
                        icon: const Icon(Icons.refresh_outlined, size: 16),
                        style: IconButton.styleFrom(
                          foregroundColor: const Color(0xFF5A6B84),
                          padding: const EdgeInsets.all(6),
                          minimumSize: const Size(28, 28),
                        ),
                        tooltip: 'Atualizar',
                      ),
                    ],
                  ),
                ),
                // Table columns header
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFEEF2F8)),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Expanded(flex: 3, child: _HeaderCell('Nome')),
                      Expanded(flex: 2, child: _HeaderCell('Tipo')),
                      Expanded(flex: 2, child: _HeaderCell('Dispositivo')),
                      Expanded(flex: 2, child: _HeaderCell('Saída')),
                      SizedBox(width: 100),
                    ],
                  ),
                ),
                // List
                Expanded(
                  child: savedAsync.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.terminal_outlined,
                                  size: 36,
                                  color: const Color(0xFFA8C0DF)),
                              const SizedBox(height: 8),
                              const Text(
                                'Nenhum comando configurado',
                                style: TextStyle(
                                  color: Color(0xFFA8C0DF),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Clique em "Criar Comando" para adicionar.',
                                style: TextStyle(
                                    color: Color(0xFFA8C0DF), fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(
                          color: Color(0xFFEEF2F8),
                          height: 1,
                        ),
                        itemBuilder: (context, i) {
                          final item = items[i];
                          final id = item['id'] as int? ?? 0;
                          final name = (item['description'] ?? '—').toString();
                          final type = (item['type'] ?? '—').toString();
                          final deviceId = item['deviceId'];
                          final attrs = item['attributes'] as Map? ?? {};
                          final outputIndex = attrs['index']?.toString();
                          final outputData = attrs['data']?.toString();
                          final outputLabel = outputIndex != null
                              ? 'Saída $outputIndex '
                                  '${outputData == '1' ? '(ON)' : '(OFF)'}'
                              : '—';

                          // find device name
                          String deviceLabel = deviceId != null
                              ? '#$deviceId'
                              : 'Universal';
                          if (deviceId != null) {
                            final found = devices
                                .where((d) => d.id == deviceId)
                                .toList();
                            if (found.isNotEmpty) {
                              deviceLabel = found.first.name;
                            }
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 9),
                            child: Row(
                              children: [
                                Expanded(
                                    flex: 3, child: _CellText(name)),
                                Expanded(
                                  flex: 2,
                                  child: _TypeChip(type: type),
                                ),
                                Expanded(
                                    flex: 2,
                                    child: _CellText(deviceLabel)),
                                Expanded(
                                    flex: 2,
                                    child: _CellText(outputLabel)),
                                SizedBox(
                                  width: 100,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.end,
                                    children: [
                                      // Quick send
                                      Tooltip(
                                        message: 'Enviar agora',
                                        child: IconButton(
                                          onPressed: () =>
                                              _sendSaved(item),
                                          icon: const Icon(
                                              Icons.send_outlined,
                                              size: 16),
                                          style: IconButton.styleFrom(
                                            foregroundColor: const Color(
                                                0xFF10B981),
                                            padding:
                                                const EdgeInsets.all(6),
                                            minimumSize:
                                                const Size(30, 30),
                                          ),
                                        ),
                                      ),
                                      // Delete
                                      Tooltip(
                                        message: 'Excluir',
                                        child: IconButton(
                                          onPressed: () =>
                                              _deleteCommand(id, name),
                                          icon: const Icon(
                                              Icons.delete_outline,
                                              size: 16),
                                          style: IconButton.styleFrom(
                                            foregroundColor: const Color(
                                                0xFFE74B4B),
                                            padding:
                                                const EdgeInsets.all(6),
                                            minimumSize:
                                                const Size(30, 30),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Text('Erro ao carregar comandos: $e'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

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
        fontSize: 11,
        letterSpacing: 0.3,
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

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});
  final String type;

  static const _colors = {
    'engineStop': Color(0xFFE74B4B),
    'engineResume': Color(0xFF10B981),
    'outputControl': Color(0xFF4A95FF),
    'alarm': Color(0xFFF59E0B),
    'positionSingle': Color(0xFF8B5CF6),
    'custom': Color(0xFF5A6B84),
  };

  static const _labels = {
    'engineStop': 'Bloquear',
    'engineResume': 'Desbloquear',
    'outputControl': 'Saída relê',
    'alarm': 'Alarme',
    'positionSingle': 'Posição',
    'custom': 'Custom',
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[type] ?? const Color(0xFF5A6B84);
    final label = _labels[type] ?? type;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 10,
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
        borderSide: BorderSide(color: Color(0xFFD6E0EE))),
    enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFD6E0EE))),
    focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF4A95FF))),
    isDense: true,
  );
}
