import 'package:flutter/material.dart';

import '../../admin/admin_reference_ui.dart';
import '../models/call_models.dart';

class CallsTable extends StatelessWidget {
  const CallsTable({
    super.key,
    required this.records,
    required this.onView,
  });

  final List<CallTicket> records;
  final ValueChanged<CallTicket> onView;

  @override
  Widget build(BuildContext context) {
    return AdminGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fila de chamados',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: _HeaderCell('ID')),
                Expanded(flex: 2, child: _HeaderCell('Cliente')),
                Expanded(flex: 2, child: _HeaderCell('Veiculo')),
                Expanded(flex: 2, child: _HeaderCell('Categoria')),
                Expanded(flex: 1, child: _HeaderCell('Prioridade')),
                Expanded(flex: 2, child: _HeaderCell('Atendente')),
                Expanded(flex: 1, child: _HeaderCell('SLA')),
                Expanded(flex: 2, child: _HeaderCell('Status')),
                Expanded(flex: 2, child: _HeaderCell('Abertura')),
                Expanded(flex: 2, child: _HeaderCell('Ações')),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final record in records)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.84),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDE5F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _IdCell(
                      id: record.id,
                      subject: record.subject,
                    ),
                  ),
                  Expanded(flex: 2, child: _ValueCell(record.client)),
                  Expanded(flex: 2, child: _ValueCell(record.vehicle)),
                  Expanded(flex: 2, child: _ValueCell(record.category.label)),
                  Expanded(
                    flex: 1,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AdminStatusChip(
                        label: record.priority.label,
                        color: _priorityColor(record.priority),
                      ),
                    ),
                  ),
                  Expanded(flex: 2, child: _ValueCell(record.attendant)),
                  Expanded(flex: 1, child: _ValueCell(record.sla)),
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AdminStatusChip(
                        label: record.status.label,
                        color: _statusColor(record.status),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _ValueCell(_formatDateTime(record.openedAt)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Wrap(
                      spacing: 6,
                      children: [
                        _ActionButton(
                          icon: Icons.visibility_outlined,
                          color: const Color(0xFF3B82F6),
                          onTap: () => onView(record),
                        ),
                        _ActionButton(
                          icon: Icons.play_arrow_outlined,
                          color: const Color(0xFF10B981),
                          onTap: () => onView(record),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final dd = value.day.toString().padLeft(2, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$dd/$mm $hh:$min';
  }

  Color _statusColor(CallStatus status) {
    switch (status) {
      case CallStatus.open:
        return const Color(0xFF3F8CFF);
      case CallStatus.inProgress:
        return const Color(0xFF10B981);
      case CallStatus.waitingPart:
        return const Color(0xFFF59E0B);
      case CallStatus.waitingCustomer:
        return const Color(0xFF64748B);
      case CallStatus.slaCritical:
        return const Color(0xFFE74B4B);
      case CallStatus.closed:
        return const Color(0xFF0EA5A5);
    }
  }

  Color _priorityColor(CallPriority priority) {
    switch (priority) {
      case CallPriority.critical:
        return const Color(0xFFE74B4B);
      case CallPriority.high:
        return const Color(0xFFF59E0B);
      case CallPriority.medium:
        return const Color(0xFF3F8CFF);
      case CallPriority.low:
        return const Color(0xFF10B981);
    }
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
        color: Color(0xFFB8C5D9),
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );
  }
}

class _ValueCell extends StatelessWidget {
  const _ValueCell(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFF25344A),
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );
  }
}

class _IdCell extends StatelessWidget {
  const _IdCell({required this.id, required this.subject});

  final String id;
  final String subject;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          id,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF1F2A44),
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF60718D),
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
          color: color.withValues(alpha: 0.10),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}
