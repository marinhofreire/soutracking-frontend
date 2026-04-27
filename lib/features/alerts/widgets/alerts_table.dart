import 'package:flutter/material.dart';

import '../../admin/admin_reference_ui.dart';
import '../models/alert_models.dart';

class AlertsTable extends StatelessWidget {
  const AlertsTable({super.key, required this.records});

  final List<AlertRecord> records;

  @override
  Widget build(BuildContext context) {
    return AdminGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lista de alertas',
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
                Expanded(flex: 2, child: _HeaderCell('Severidade')),
                Expanded(flex: 3, child: _HeaderCell('Tipo de alerta')),
                Expanded(flex: 2, child: _HeaderCell('Veiculo')),
                Expanded(flex: 2, child: _HeaderCell('Motorista')),
                Expanded(flex: 3, child: _HeaderCell('Localizacao')),
                Expanded(flex: 2, child: _HeaderCell('Data/Hora')),
                Expanded(flex: 2, child: _HeaderCell('Status')),
                Expanded(flex: 2, child: _HeaderCell('Acoes')),
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
                  Expanded(flex: 2, child: _ValueCell(record.id)),
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AdminStatusChip(
                        label: record.severity.label,
                        color: _severityColor(record.severity),
                      ),
                    ),
                  ),
                  Expanded(flex: 3, child: _ValueCell(record.type)),
                  Expanded(flex: 2, child: _ValueCell(record.vehicle)),
                  Expanded(flex: 2, child: _ValueCell(record.driver)),
                  Expanded(flex: 3, child: _ValueCell(record.location)),
                  Expanded(
                      flex: 2,
                      child: _ValueCell(_formatDateTime(record.dateTime))),
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
                    child: Wrap(
                      spacing: 6,
                      children: [
                        _ActionButton(
                          icon: Icons.visibility_outlined,
                          color: const Color(0xFF3B82F6),
                        ),
                        _ActionButton(
                          icon: Icons.task_alt_outlined,
                          color: const Color(0xFF10B981),
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

  Color _severityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return const Color(0xFFE74B4B);
      case AlertSeverity.high:
        return const Color(0xFFF97316);
      case AlertSeverity.medium:
        return const Color(0xFFF59E0B);
      case AlertSeverity.low:
        return const Color(0xFF3F8CFF);
    }
  }

  Color _statusColor(AlertStatus status) {
    switch (status) {
      case AlertStatus.newAlert:
        return const Color(0xFFE74B4B);
      case AlertStatus.inAnalysis:
        return const Color(0xFFF59E0B);
      case AlertStatus.resolved:
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        color: color.withValues(alpha: 0.10),
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }
}
