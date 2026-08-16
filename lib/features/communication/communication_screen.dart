import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/display_text_formatter.dart';
import '../../data/bridge_client.dart';
import '../../data/models.dart';
import '../../state/session_state.dart';

enum _CommunicationTab { conversations, notifications }

class CommunicationScreen extends ConsumerStatefulWidget {
  const CommunicationScreen({super.key, this.onClose});
  final VoidCallback? onClose;

  @override
  ConsumerState<CommunicationScreen> createState() =>
      _CommunicationScreenState();
}

class _CommunicationScreenState
    extends ConsumerState<CommunicationScreen> {
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();

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
    _searchController.dispose();
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
        .replaceAll('Não informado', '')
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

  void _setQuickCommand({required String type, required String message}) {
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
        content: Text('Histórico copiado para a área de transferência.'),
      ),
    );
  }

  void _openHistoryDialog(List<_CommunicationRow> rows) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Histórico de envios'),
        content: SizedBox(
          width: 640,
          child: rows.isEmpty
              ? const Text('Não informado')
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
    final ticketsAsync = ref.watch(soucallTicketsProvider);
    final tickets = ticketsAsync.valueOrNull ?? const <SoucallTicket>[];
    final ticketsDebug = ticketsAsync.isLoading
        ? 'carregando...'
        : ticketsAsync.hasError
            ? 'erro: ${ticketsAsync.error}'
            : 'ok (${tickets.length})';
    final notifications = ref.watch(notificationsProvider).valueOrNull ??
        const <Map<String, dynamic>>[];

    final latestByDevice = <int, TraccarPosition>{
      for (final item in positions) item.deviceId: item,
    };
    final devicesById = <int, TraccarDevice>{for (final d in devices) d.id: d};

    final conversationRows = _buildConversationRows(tickets: tickets);
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

    final search = _searchController.text.trim().toLowerCase();
    final filteredRows = search.isEmpty
        ? activeRows
        : activeRows.where((r) =>
            r.deviceName.toLowerCase().contains(search) ||
            r.message.toLowerCase().contains(search)).toList();

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
        // ── Header ──────────────────────────────────────────────────────────
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF176EEB).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.forum_rounded,
                color: Color(0xFF176EEB),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comunicação',
                    style: TextStyle(
                      color: Color(0xFF1F2A44),
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'Mensagens e atendimento via WhatsApp',
                    style: TextStyle(
                      color: Color(0xFF60718D),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                ref.invalidate(soucallTicketsProvider);
                ref.invalidate(notificationsProvider);
              },
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Atualizar',
              style: IconButton.styleFrom(foregroundColor: const Color(0xFF60718D)),
            ),
            IconButton(
              onPressed: widget.onClose,
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Fechar',
              style: IconButton.styleFrom(foregroundColor: const Color(0xFF60718D)),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Toolbar ─────────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDDE5F0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Search
              SizedBox(
                width: 180,
                height: 36,
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Buscar...',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9DB1CC)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF9DB1CC)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    filled: true,
                    fillColor: const Color(0xFFF7F9FD),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFDDE5F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFDDE5F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF176EEB)),
                    ),
                  ),
                ),
              ),
              _filterDropdown<String>(
                label: 'Canal',
                value: _selectedChannel,
                options: const ['Todos', 'Comando', 'Mensagem', 'Notificação'],
                width: 136,
                onChanged: (v) => setState(() => _selectedChannel = v),
              ),
              _filterDropdown<int?>(
                label: 'Equipamento',
                value: _selectedDeviceId,
                options: [null, ...devices.map((e) => e.id)],
                width: 176,
                optionLabel: (id) {
                  if (id == null) return 'Todos';
                  return formatDisplayText(devices.where((d) => d.id == id).firstOrNull?.name);
                },
                onChanged: (v) => setState(() => _selectedDeviceId = v),
              ),
              _filterDropdown<String>(
                label: 'Status',
                value: _selectedStatus,
                options: const ['Todos', 'Enviado', 'Pendente', 'Falha'],
                width: 124,
                onChanged: (v) => setState(() => _selectedStatus = v),
              ),
              _filterDropdown<String>(
                label: 'Período',
                value: _selectedPeriod,
                options: const ['Hoje', '7 dias', '30 dias'],
                width: 116,
                onChanged: (v) => setState(() => _selectedPeriod = v),
              ),
              // Tabs inline
              _tabChip(
                label: 'Conversas',
                count: conversationRows.length,
                active: _activeTab == _CommunicationTab.conversations,
                onTap: () => setState(() => _activeTab = _CommunicationTab.conversations),
              ),
              _tabChip(
                label: 'Notificações',
                count: notificationRows.length,
                active: _activeTab == _CommunicationTab.notifications,
                onTap: () => setState(() => _activeTab = _CommunicationTab.notifications),
              ),
              // Actions
              OutlinedButton.icon(
                onPressed: () => _exportRows(activeRows),
                icon: const Icon(Icons.file_download_outlined, size: 15),
                label: const Text('Exportar', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  foregroundColor: const Color(0xFF526684),
                  side: const BorderSide(color: Color(0xFFDDE5F0)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _openHistoryDialog(activeRows),
                icon: const Icon(Icons.history_rounded, size: 15),
                label: const Text('Histórico', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  foregroundColor: const Color(0xFF526684),
                  side: const BorderSide(color: Color(0xFFDDE5F0)),
                ),
              ),
              FilledButton.icon(
                onPressed: () => setState(() {
                  _pendingCommandType = 'custom';
                  _messageController.text = '';
                }),
                icon: const Icon(Icons.add_rounded, size: 15),
                label: const Text('Nova mensagem', style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  backgroundColor: const Color(0xFF176EEB),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ── Two-panel layout ─────────────────────────────────────────────────
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: _leftListPanel(
                  rows: filteredRows,
                  emptySubtitle: _activeTab == _CommunicationTab.conversations
                      ? 'SouCall: $ticketsDebug'
                      : 'Atualize os filtros ou aguarde novos dados',
                  onSelect: (row) => setState(() {
                    _selectedRow = row;
                    _selectedDeviceId = row.deviceId;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
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

  // ── Left panel ─────────────────────────────────────────────────────────────

  Widget _leftListPanel({
    required List<_CommunicationRow> rows,
    required ValueChanged<_CommunicationRow> onSelect,
    String emptySubtitle = 'Atualize os filtros ou aguarde novos dados',
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: Column(
        children: [
          // Column headers
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE8EFF7))),
            ),
            child: Row(
              children: const [
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
                ? _EmptyMessage(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Nenhum registro encontrado',
                    subtitle: emptySubtitle,
                  )
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFF0F4FA)),
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
                            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _BodyLabel(_formatDateTime(row.dateTime)),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _statusColor(row.onlineStatus),
                                        ),
                                      ),
                                      Expanded(child: _BodyLabel(row.deviceName)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: _channelChip(row.channel),
                                ),
                                Expanded(
                                  flex: 5,
                                  child: _BodyLabel(row.message, maxLines: 2),
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
          // Footer count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE8EFF7))),
            ),
            child: Text(
              '${rows.length} registro${rows.length == 1 ? '' : 's'}',
              style: const TextStyle(
                color: Color(0xFF9DB1CC),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Right panel ────────────────────────────────────────────────────────────

  Widget _rightConversationPanel({
    required TraccarDevice? selectedDevice,
    required TraccarPosition? selectedPosition,
    required String selectedStatus,
    required Color selectedStatusColor,
    required List<_CommunicationRow> history,
  }) {
    final deviceName = formatDisplayText(selectedDevice?.name);
    final address = formatDisplayText(selectedPosition?.address);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: Column(
        children: [
          // Contact header
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE8EFF7))),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF176EEB).withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_car_rounded,
                    color: Color(0xFF176EEB),
                    size: 17,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedDevice == null ? 'Selecione um contato' : deviceName,
                        style: const TextStyle(
                          color: Color(0xFF1F2A44),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      if (selectedDevice != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          address.isNotEmpty ? address : 'Endereço não disponível',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF60718D),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selectedDevice != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: selectedStatusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: selectedStatusColor.withValues(alpha: 0.30)),
                    ),
                    child: Text(
                      selectedStatus,
                      style: TextStyle(
                        color: selectedStatusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Message history
          Expanded(
            child: selectedDevice == null
                ? const _EmptyMessage(
                    icon: Icons.forum_rounded,
                    title: 'Nenhuma conversa selecionada',
                    subtitle: 'Selecione um registro na lista ao lado',
                  )
                : history.isEmpty
                    ? const _EmptyMessage(
                        icon: Icons.sms_outlined,
                        title: 'Sem histórico desta conversa',
                        subtitle: 'Envie uma mensagem para iniciar',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          final row = history[index];
                          return Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                              constraints: const BoxConstraints(maxWidth: 340),
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

          // Input area
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE8EFF7))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick commands
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _quickCommandButton(
                      label: 'Bloquear motor',
                      onTap: () => _setQuickCommand(
                        type: 'engineStop',
                        message: 'Comando de bloqueio de motor acionado.',
                      ),
                    ),
                    _quickCommandButton(
                      label: 'Desbloquear',
                      onTap: () => _setQuickCommand(
                        type: 'engineResume',
                        message: 'Comando de desbloqueio de motor acionado.',
                      ),
                    ),
                    _quickCommandButton(
                      label: 'Reiniciar',
                      onTap: () => _setQuickCommand(
                        type: 'custom',
                        message: 'Solicitação de reinício remoto enviada.',
                      ),
                    ),
                    _quickCommandButton(
                      label: 'Posição',
                      onTap: () => _setQuickCommand(
                        type: 'positionSingle',
                        message: 'Solicitação de atualização de posição.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Message input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'Digite uma mensagem ou comando...',
                          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9DB1CC)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF7F9FD),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFDDE5F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFDDE5F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF176EEB)),
                          ),
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
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 16),
                      label: Text(
                        _sending ? 'Enviando...' : 'Enviar',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF176EEB),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Builders ───────────────────────────────────────────────────────────────

  List<_CommunicationRow> _buildConversationRows({
    required List<SoucallTicket> tickets,
  }) {
    final rows = tickets.map((ticket) {
      final statusLabel = switch (ticket.status) {
        'pending' => 'Aguardando',
        'open' => 'Em atendimento',
        'closed' => 'Encerrado',
        _ => formatDisplayText(ticket.status),
      };
      return _CommunicationRow(
        id: 'ticket-${ticket.id}',
        deviceId: ticket.id,
        deviceName: ticket.contactName,
        channel: 'WhatsApp',
        message: ticket.lastMessage.isEmpty
            ? 'Sem mensagem'
            : ticket.lastMessage,
        status: statusLabel,
        dateTime: ticket.updatedAt,
        onlineStatus: ticket.unreadMessages > 0
            ? '${ticket.unreadMessages} não lida(s)'
            : 'Lido',
      );
    }).toList();
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
      final attrMap =
          attrs is Map ? attrs.cast<String, dynamic>() : const <String, dynamic>{};
      final deviceId = _toInt(
            item['deviceId'] ??
                item['targetId'] ??
                attrMap['deviceId'] ??
                attrMap['targetId'],
          ) ??
          -1;
      final device = devicesById[deviceId];
      final position = latestByDevice[deviceId];
      final dateTime = _parseDateTime(
            item['serverTime'] ??
                item['eventTime'] ??
                item['createdAt'] ??
                item['updatedAt'],
          ) ??
          DateTime.now();

      rows.add(_CommunicationRow(
        id: 'not-${item['id'] ?? rows.length}-$deviceId',
        deviceId: deviceId,
        deviceName: formatDisplayText(device?.name),
        channel: 'Notificação',
        message: formatDisplayText(
          item['message'] ??
              attrMap['message'] ??
              item['type'] ??
              'Não informado',
        ),
        status: formatDisplayText(item['status'] ?? attrMap['status'] ?? 'Enviado'),
        dateTime: dateTime,
        onlineStatus: _deviceStatusLabel(device, position),
      ));
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

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _deviceStatusLabel(TraccarDevice? device, TraccarPosition? position) {
    if (device == null) return 'Não informado';
    final status = device.status.trim().toLowerCase();
    final at = _parseDateTime(device.lastUpdate ?? position?.fixTime);
    if (at == null) return 'Sem comunicação';
    if (DateTime.now().difference(at).inHours >= 12) return 'Sem comunicação';
    if (status == 'offline' || status == 'unknown') return 'Offline';
    return 'Online';
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('online')) return const Color(0xFF16A34A);
    if (s.contains('offline')) return const Color(0xFF64748B);
    if (s.contains('falha') || s.contains('erro')) return const Color(0xFFEF4444);
    if (s.contains('comunica')) return const Color(0xFFF59E0B);
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

  String _formatDateTime(DateTime v) {
    final d = v.day.toString().padLeft(2, '0');
    final mo = v.month.toString().padLeft(2, '0');
    final y = v.year.toString();
    final h = v.hour.toString().padLeft(2, '0');
    final mi = v.minute.toString().padLeft(2, '0');
    return '$d/$mo/$y $h:$mi';
  }

  String _escapeCsv(String value) {
    final safe = formatDisplayText(value);
    if (safe.contains(';') || safe.contains('"') || safe.contains('\n')) {
      return '"${safe.replaceAll('"', '""')}"';
    }
    return safe;
  }

  // ── Small widgets ───────────────────────────────────────────────────────────

  Widget _tabChip({
    required String label,
    required int count,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF176EEB).withValues(alpha: 0.10) : const Color(0xFFF7F9FD),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? const Color(0xFF176EEB).withValues(alpha: 0.40) : const Color(0xFFDDE5F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? const Color(0xFF176EEB) : const Color(0xFF60718D),
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF176EEB) : const Color(0xFF9DB1CC),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
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
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        formatDisplayText(status),
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 10.3),
      ),
    );
  }

  Widget _channelChip(String channel) {
    final (color, icon) = switch (channel) {
      'Comando' => (const Color(0xFF7C3AED), Icons.terminal_rounded),
      'Notificação' => (const Color(0xFFF59E0B), Icons.notifications_outlined),
      _ => (const Color(0xFF176EEB), Icons.chat_bubble_outline_rounded),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            channel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _quickCommandButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FD),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFDDE5F0)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF526684),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
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
          labelStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF60718D)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          filled: true,
          fillColor: const Color(0xFFF7F9FD),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDDE5F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDDE5F0)),
          ),
        ),
        style: const TextStyle(
          color: Color(0xFF1F2A44),
          fontSize: 12,
          fontWeight: FontWeight.w600,
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

// ── Data model ─────────────────────────────────────────────────────────────────

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

// ── Shared widgets ──────────────────────────────────────────────────────────────

class _HeaderLabel extends StatelessWidget {
  const _HeaderLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF9DB1CC),
        fontWeight: FontWeight.w700,
        fontSize: 11,
      ),
    );
  }
}

class _BodyLabel extends StatelessWidget {
  const _BodyLabel(this.text, {this.maxLines = 1});
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
        fontSize: 11.5,
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF176EEB).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF9DB1CC), size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF60718D),
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
