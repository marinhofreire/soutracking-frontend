import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/display_text_formatter.dart';
import '../../data/models.dart';
import '../../state/session_state.dart';

enum _CommunicationTab { conversations, notifications }

class ZproCommunicationScreen extends ConsumerStatefulWidget {
  const ZproCommunicationScreen({super.key});

  @override
  ConsumerState<ZproCommunicationScreen> createState() =>
      _ZproCommunicationScreenState();
}

class _ZproCommunicationScreenState
    extends ConsumerState<ZproCommunicationScreen> {
  final _messageController = TextEditingController();

  _CommunicationTab _activeTab = _CommunicationTab.conversations;
  String _selectedChannel = 'Todos';
  String _selectedStatus = 'Todos';
  String _selectedPeriod = 'Hoje';
  int? _selectedDeviceId;
  _CommunicationRow? _selectedRow;
  bool _sending = false;
  String _pendingCommandType = 'custom';

  @override
  void initState() {
    super.initState();
    _messageController.text =
        'Central SouTracking: retorno operacional em andamento.';
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_selectedDeviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um equipamento.')),
      );
      return;
    }

    final text = formatDisplayText(_messageController.text, fallback: '')
        .replaceAll('N\u00E3o informado', '')
        .trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite uma mensagem ou comando.')),
      );
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
          'deviceId': _selectedDeviceId,
          'type': _pendingCommandType,
          'attributes': {'data': text},
        },
      );
      if (!mounted) return;
      ref.invalidate(commandsProvider);
      _messageController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mensagem enviada com sucesso.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao enviar mensagem: $error')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _setQuickCommand({
    required String type,
    required String message,
  }) {
    setState(() {
      _pendingCommandType = type;
      _messageController.text = message;
    });
  }

  Future<void> _exportRows(List<_CommunicationRow> rows) async {
    final header = 'Data/Hora;Dispositivo;Canal;Mensagem;Status';
    final lines = <String>[
      header,
      for (final row in rows)
        [
          _formatDateTime(row.dateTime),
          row.deviceName,
          row.channel,
          row.message,
          row.status,
        ].map(_escapeCsv).join(';'),
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Hist\u00F3rico copiado para a \u00E1rea de transfer\u00EAncia.'),
      ),
    );
  }

  void _openHistoryDialog(List<_CommunicationRow> rows) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hist\u00F3rico de envios'),
        content: SizedBox(
          width: 640,
          child: rows.isEmpty
              ? const Text('N\u00E3o informado')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: rows.length.clamp(0, 20),
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_formatDateTime(row.dateTime)} • ${row.deviceName}',
                          style: const TextStyle(
                            color: Color(0xFF1F2A44),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${row.channel} • ${row.status}',
                          style: const TextStyle(
                            color: Color(0xFF60718D),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          row.message,
                          style: const TextStyle(
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devices =
        ref.watch(devicesProvider).valueOrNull ?? const <TraccarDevice>[];
    final positions =
        ref.watch(positionsProvider).valueOrNull ?? const <TraccarPosition>[];
    final commands = ref.watch(commandsProvider).valueOrNull ??
        const <Map<String, dynamic>>[];
    final notifications = ref.watch(notificationsProvider).valueOrNull ??
        const <Map<String, dynamic>>[];

    final latestByDevice = <int, TraccarPosition>{
      for (final item in positions) item.deviceId: item,
    };
    final devicesById = <int, TraccarDevice>{for (final d in devices) d.id: d};

    final conversationRows = _buildConversationRows(
      commands: commands,
      devicesById: devicesById,
      latestByDevice: latestByDevice,
    );
    final notificationRows = _buildNotificationRows(
      notifications: notifications,
      devicesById: devicesById,
      latestByDevice: latestByDevice,
    );

    final activeRows = _applyFilters(
      _activeTab == _CommunicationTab.conversations
          ? conversationRows
          : notificationRows,
    );

    final selectedDevice = devicesById[_selectedDeviceId];
    final selectedPosition =
        selectedDevice == null ? null : latestByDevice[selectedDevice.id];
    final selectedStatus = _deviceStatusLabel(selectedDevice, selectedPosition);
    final selectedStatusColor = _statusColor(selectedStatus);
    final conversationHistory = activeRows
        .where((row) => row.deviceId == _selectedDeviceId)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headerBar(
          onExport: () => _exportRows(activeRows),
          onHistory: () => _openHistoryDialog(activeRows),
          onNewMessage: () {
            setState(() {
              _pendingCommandType = 'custom';
              _messageController.text = '';
            });
          },
        ),
        const SizedBox(height: 10),
        _filterBar(devices),
        const SizedBox(height: 10),
        _tabBar(),
        const SizedBox(height: 10),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 6,
                child: _leftListPanel(
                  rows: activeRows,
                  onSelect: (row) {
                    setState(() {
                      _selectedRow = row;
                      _selectedDeviceId = row.deviceId;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: _rightConversationPanel(
                  selectedDevice: selectedDevice,
                  selectedPosition: selectedPosition,
                  selectedStatus: selectedStatus,
                  selectedStatusColor: selectedStatusColor,
                  history: conversationHistory,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _headerBar({
    required VoidCallback onExport,
    required VoidCallback onHistory,
    required VoidCallback onNewMessage,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comunica\u00E7\u00E3o Operacional',
            style: TextStyle(
              color: Color(0xFF1F2A44),
              fontWeight: FontWeight.w900,
              fontSize: 15.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatDisplayText(
              'Envio de comandos, mensagens e notifica\u00E7\u00F5es para dispositivos',
            ),
            style: const TextStyle(
              color: Color(0xFF60718D),
              fontWeight: FontWeight.w600,
              fontSize: 11.8,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _topActionButton(
                label: 'Exportar',
                icon: Icons.file_download_outlined,
                onTap: onExport,
              ),
              _topActionButton(
                label: 'Hist\u00F3rico de envios',
                icon: Icons.history_rounded,
                onTap: onHistory,
              ),
              _topActionButton(
                label: 'Nova mensagem',
                icon: Icons.add_rounded,
                onTap: onNewMessage,
                primary: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterBar(List<TraccarDevice> devices) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: _panelDecoration(),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _filterDropdown<String>(
            label: 'Canal',
            value: _selectedChannel,
            options: const ['Todos', 'Comando', 'Mensagem', 'Notifica\u00E7\u00E3o'],
            width: 146,
            onChanged: (value) => setState(() => _selectedChannel = value),
          ),
          _filterDropdown<int?>(
            label: 'Equipamento',
            value: _selectedDeviceId,
            options: [null, ...devices.map((e) => e.id)],
            width: 188,
            optionLabel: (id) {
              if (id == null) return 'Todos';
              final device = devices.where((d) => d.id == id).firstOrNull;
              return formatDisplayText(device?.name);
            },
            onChanged: (value) => setState(() => _selectedDeviceId = value),
          ),
          _filterDropdown<String>(
            label: 'Status',
            value: _selectedStatus,
            options: const ['Todos', 'Enviado', 'Pendente', 'Falha'],
            width: 132,
            onChanged: (value) => setState(() => _selectedStatus = value),
          ),
          _filterDropdown<String>(
            label: 'Per\u00EDodo',
            value: _selectedPeriod,
            options: const ['Hoje', '7 dias', '30 dias'],
            width: 124,
            onChanged: (value) => setState(() => _selectedPeriod = value),
          ),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedChannel = 'Todos';
                _selectedDeviceId = null;
                _selectedStatus = 'Todos';
                _selectedPeriod = 'Hoje';
              });
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Limpar filtros'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Configura\u00E7\u00F5es r\u00E1pidas abertas.')),
              );
            },
            icon: const Icon(Icons.tune_rounded, size: 16),
            label: const Text('Configura\u00E7\u00F5es'),
          ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          _tabChip(
            label: 'Conversas',
            active: _activeTab == _CommunicationTab.conversations,
            onTap: () =>
                setState(() => _activeTab = _CommunicationTab.conversations),
          ),
          const SizedBox(width: 8),
          _tabChip(
            label: 'Notifica\u00E7\u00F5es',
            active: _activeTab == _CommunicationTab.notifications,
            onTap: () =>
                setState(() => _activeTab = _CommunicationTab.notifications),
          ),
        ],
      ),
    );
  }

  Widget _leftListPanel({
    required List<_CommunicationRow> rows,
    required ValueChanged<_CommunicationRow> onSelect,
  }) {
    return Container(
      decoration: _panelDecoration(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFDDE6F2)),
              ),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: _HeaderLabel('Data / Hora')),
                Expanded(flex: 3, child: _HeaderLabel('Dispositivo')),
                Expanded(flex: 2, child: _HeaderLabel('Canal')),
                Expanded(flex: 5, child: _HeaderLabel('Mensagem')),
                Expanded(flex: 2, child: _HeaderLabel('Status')),
              ],
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? const _EmptyMessage(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Nenhum registro encontrado',
                    subtitle: 'Atualize os filtros ou aguarde novos dados',
                  )
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      color: Color(0xFFE6EDF7),
                    ),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      final selected = _selectedRow?.id == row.id;
                      return Material(
                        color: selected
                            ? const Color(0xFFE8F1FF).withValues(alpha: 0.78)
                            : Colors.transparent,
                        child: InkWell(
                          onTap: () => onSelect(row),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child:
                                      _BodyLabel(_formatDateTime(row.dateTime)),
                                ),
                                Expanded(
                                    flex: 3, child: _BodyLabel(row.deviceName)),
                                Expanded(
                                    flex: 2, child: _BodyLabel(row.channel)),
                                Expanded(
                                  flex: 5,
                                  child: _BodyLabel(
                                    row.message,
                                    maxLines: 2,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _statusChip(row.status),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _rightConversationPanel({
    required TraccarDevice? selectedDevice,
    required TraccarPosition? selectedPosition,
    required String selectedStatus,
    required Color selectedStatusColor,
    required List<_CommunicationRow> history,
  }) {
    final deviceName = formatDisplayText(selectedDevice?.name);
    final statusText = formatDisplayText(selectedStatus);
    final address = formatDisplayText(selectedPosition?.address);

    return Container(
      decoration: _panelDecoration(),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFDDE6F2))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        deviceName,
                        style: const TextStyle(
                          color: Color(0xFF1F2A44),
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: selectedStatusColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: selectedStatusColor.withValues(alpha: 0.34),
                        ),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: selectedStatusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Endereço: $address',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF60718D),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: history.isEmpty
                ? const _EmptyMessage(
                    icon: Icons.sms_outlined,
                    title: 'Sem hist\u00F3rico desta conversa',
                    subtitle:
                        'Selecione outro equipamento ou envie uma mensagem',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final row = history[index];
                      return Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                          constraints: const BoxConstraints(maxWidth: 360),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F1FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCFE0FA)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.message,
                                style: const TextStyle(
                                  color: Color(0xFF1F2A44),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_formatDateTime(row.dateTime)} • ${row.status}',
                                style: const TextStyle(
                                  color: Color(0xFF60718D),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFDDE6F2))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 520;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                    _quickCommandButton(
                      label: 'Bloquear motor',
                      onTap: () => _setQuickCommand(
                        type: 'engineStop',
                        message: 'Comando de bloqueio de motor acionado.',
                      ),
                    ),
                    _quickCommandButton(
                      label: 'Desbloquear motor',
                      onTap: () => _setQuickCommand(
                        type: 'engineResume',
                        message: 'Comando de desbloqueio de motor acionado.',
                      ),
                    ),
                    _quickCommandButton(
                      label: 'Reiniciar dispositivo',
                      onTap: () => _setQuickCommand(
                        type: 'custom',
                        message: 'Solicita\u00E7\u00E3o de rein\u00EDcio remoto enviada.',
                      ),
                    ),
                    _quickCommandButton(
                      label: 'Mais comandos',
                      onTap: () => _setQuickCommand(
                        type: 'positionSingle',
                        message:
                            'Solicita\u00E7\u00E3o de atualiza\u00E7\u00E3o imediata de posi\u00E7\u00E3o.',
                      ),
                    ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (compact) ...[
                          TextField(
                            controller: _messageController,
                            minLines: 1,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Digite uma mensagem/comando...',
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _sending ? null : _sendMessage,
                              icon: _sending
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded, size: 16),
                              label: Text(_sending ? 'Enviando...' : 'Enviar'),
                            ),
                          ),
                        ] else
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  minLines: 1,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    hintText: 'Digite uma mensagem/comando...',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: _sending ? null : _sendMessage,
                                icon: _sending
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.send_rounded, size: 16),
                                label: Text(_sending ? 'Enviando...' : 'Enviar'),
                              ),
                            ],
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_CommunicationRow> _buildConversationRows({
    required List<Map<String, dynamic>> commands,
    required Map<int, TraccarDevice> devicesById,
    required Map<int, TraccarPosition> latestByDevice,
  }) {
    final rows = <_CommunicationRow>[];
    for (final item in commands) {
      final deviceId = _toInt(item['deviceId']) ?? -1;
      final device = devicesById[deviceId];
      final position = latestByDevice[deviceId];

      final rawType =
          formatDisplayText(item['type'], fallback: 'custom').toLowerCase();
      final channel = switch (rawType) {
        'engineStop' || 'engineResume' || 'positionSingle' => 'Comando',
        'alarm' => 'Notificação',
        _ => 'Mensagem',
      };

      final attrs = item['attributes'];
      final attrMap = attrs is Map
          ? attrs.cast<String, dynamic>()
          : const <String, dynamic>{};
      final message = formatDisplayText(
        item['description'] ??
            attrMap['message'] ??
            attrMap['data'] ??
            item['text'] ??
            'N\u00E3o informado',
      );
      final status = formatDisplayText(item['status'] ?? 'Enviado');
      final dateTime = _parseDateTime(
            item['sentAt'] ??
                item['serverTime'] ??
                item['deviceTime'] ??
                item['fixTime'],
          ) ??
          DateTime.now();

      rows.add(
        _CommunicationRow(
          id: 'cmd-${item['id'] ?? rows.length}-$deviceId',
          deviceId: deviceId,
          deviceName: formatDisplayText(device?.name),
          channel: channel,
          message: message,
          status: status,
          dateTime: dateTime,
          onlineStatus: _deviceStatusLabel(device, position),
        ),
      );
    }

    rows.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return rows;
  }

  List<_CommunicationRow> _buildNotificationRows({
    required List<Map<String, dynamic>> notifications,
    required Map<int, TraccarDevice> devicesById,
    required Map<int, TraccarPosition> latestByDevice,
  }) {
    final rows = <_CommunicationRow>[];
    for (final item in notifications) {
      final attrs = item['attributes'];
      final attrMap = attrs is Map
          ? attrs.cast<String, dynamic>()
          : const <String, dynamic>{};
      final deviceId = _toInt(
            item['deviceId'] ??
                item['targetId'] ??
                attrMap['deviceId'] ??
                attrMap['targetId'],
          ) ??
          -1;
      final device = devicesById[deviceId];
      final position = latestByDevice[deviceId];
      final status = formatDisplayText(
        item['status'] ?? attrMap['status'] ?? 'Enviado',
      );
      final dateTime = _parseDateTime(
            item['serverTime'] ??
                item['eventTime'] ??
                item['createdAt'] ??
                item['updatedAt'],
          ) ??
          DateTime.now();

      rows.add(
        _CommunicationRow(
          id: 'not-${item['id'] ?? rows.length}-$deviceId',
          deviceId: deviceId,
          deviceName: formatDisplayText(device?.name),
          channel: 'Notificação',
          message: formatDisplayText(
            item['message'] ??
                attrMap['message'] ??
                item['type'] ??
                'N\u00E3o informado',
          ),
          status: status,
          dateTime: dateTime,
          onlineStatus: _deviceStatusLabel(device, position),
        ),
      );
    }

    rows.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return rows;
  }

  List<_CommunicationRow> _applyFilters(List<_CommunicationRow> rows) {
    final now = DateTime.now();
    final from = switch (_selectedPeriod) {
      '7 dias' => now.subtract(const Duration(days: 7)),
      '30 dias' => now.subtract(const Duration(days: 30)),
      _ => DateTime(now.year, now.month, now.day),
    };

    return rows.where((row) {
      final channelOk =
          _selectedChannel == 'Todos' || row.channel == _selectedChannel;
      final deviceOk =
          _selectedDeviceId == null || row.deviceId == _selectedDeviceId;
      final statusOk = _selectedStatus == 'Todos' ||
          row.status.toLowerCase().contains(_selectedStatus.toLowerCase());
      final dateOk = row.dateTime.isAfter(from);
      return channelOk && deviceOk && statusOk && dateOk;
    }).toList(growable: false);
  }

  String _deviceStatusLabel(TraccarDevice? device, TraccarPosition? position) {
    if (device == null) return 'N\u00E3o informado';
    final status = device.status.trim().toLowerCase();
    final at = _parseDateTime(device.lastUpdate ?? position?.fixTime);
    if (at == null) return 'Sem comunicação';
    final stale = DateTime.now().difference(at).inHours >= 12;
    if (stale) return 'Sem comunicação';
    if (status == 'offline' || status == 'unknown') return 'Offline';
    return 'Online';
  }

  Color _statusColor(String status) {
    final normalized = status.toLowerCase();
    if (normalized.contains('online')) return const Color(0xFF16A34A);
    if (normalized.contains('offline')) return const Color(0xFF64748B);
    if (normalized.contains('falha') || normalized.contains('erro')) {
      return const Color(0xFFEF4444);
    }
    if (normalized.contains('comunica')) return const Color(0xFFF59E0B);
    return const Color(0xFF176EEB);
  }

  DateTime? _parseDateTime(dynamic raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  int? _toInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse('${raw ?? ''}');
  }

  String _formatDateTime(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final y = value.year.toString().padLeft(4, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }

  String _escapeCsv(String value) {
    final safe = formatDisplayText(value);
    if (safe.contains(';') || safe.contains('"') || safe.contains('\n')) {
      return '"${safe.replaceAll('"', '""')}"';
    }
    return safe;
  }

  Decoration _panelDecoration() {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.84),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFDDE6F2)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF13273F).withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _topActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    if (primary) {
      return FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }

  Widget _tabChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: active ? const Color(0xFFE8F1FF) : const Color(0xFFF8FAFF),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? const Color(0xFFAECFFF) : const Color(0xFFDDE6F2),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFF176EEB) : const Color(0xFF60718D),
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(
        formatDisplayText(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10.3,
        ),
      ),
    );
  }

  Widget _quickCommandButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11.2, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _filterDropdown<T>({
    required String label,
    required T value,
    required List<T> options,
    required ValueChanged<T> onChanged,
    required double width,
    String Function(T option)? optionLabel,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T>(
        value: value,
        isDense: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        items: [
          for (final option in options)
            DropdownMenuItem<T>(
              value: option,
              child: Text(
                optionLabel != null
                    ? optionLabel(option)
                    : formatDisplayText(option.toString()),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    );
  }
}

class _CommunicationRow {
  const _CommunicationRow({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.channel,
    required this.message,
    required this.status,
    required this.dateTime,
    required this.onlineStatus,
  });

  final String id;
  final int deviceId;
  final String deviceName;
  final String channel;
  final String message;
  final String status;
  final DateTime dateTime;
  final String onlineStatus;
}

class _HeaderLabel extends StatelessWidget {
  const _HeaderLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF60718D),
        fontWeight: FontWeight.w700,
        fontSize: 11.2,
      ),
    );
  }
}

class _BodyLabel extends StatelessWidget {
  const _BodyLabel(
    this.text, {
    this.maxLines = 1,
  });

  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      formatDisplayText(text),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFF1F2A44),
        fontWeight: FontWeight.w600,
        fontSize: 11.2,
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF9DB1CC), size: 22),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF60718D),
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
