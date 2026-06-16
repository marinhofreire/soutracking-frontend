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
            'Eventos de alerta',
            style: TextStyle(
              color: Color(0xFFE7F2FF),
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          if (records.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xD9FFFFFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD6E0EE)),
              ),
              child: const Text(
                'Nenhum alerta encontrado',
                style: TextStyle(
                  color: Color(0xFFA8C0DF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: const Color(0xE6FFFFFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD6E0EE)),
              ),
              child: Column(
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
                          color: const Color(0xFFD6E0EE).withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 2, child: _HeaderCell('Data/Hora')),
                        Expanded(flex: 2, child: _HeaderCell('Equipamento')),
                        Expanded(flex: 3, child: _HeaderCell('Tipo de alerta')),
                        Expanded(flex: 2, child: _HeaderCell('Prioridade')),
                        Expanded(flex: 2, child: _HeaderCell('Status')),
                        Expanded(flex: 4, child: _HeaderCell('Descrição')),
                        SizedBox(width: 56),
                      ],
                    ),
                  ),
                  for (final record in records)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color:
                                const Color(0xFFD6E0EE).withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _ValueCell(_formatDateTime(record.dateTime)),
                          ),
                          Expanded(flex: 2, child: _ValueCell(record.vehicle)),
                          Expanded(flex: 3, child: _ValueCell(record.type)),
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
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: record.status == null
                                  ? const _ValueCell('Não informado')
                                  : AdminStatusChip(
                                      label: record.status!.label,
                                      color: _statusColor(record.status!),
                                    ),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: _ValueCell(
                              record.description,
                              maxLines: 2,
                            ),
                          ),
                          SizedBox(
                            width: 56,
                            child: Row(
                              children: [
                                _ActionIcon(
                                  icon: Icons.visibility_outlined,
                                  color: const Color(0xFF176EEB),
                                ),
                                const SizedBox(width: 6),
                                _ActionIcon(
                                  icon: Icons.more_horiz,
                                  color: const Color(0xFF60718D),
                                ),
                              ],
                            ),
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
        color: Color(0xFF5F738F),
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );
  }
}

class _ValueCell extends StatelessWidget {
  const _ValueCell(this.text, {this.maxLines = 1});

  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFFE4F0FF),
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Icon(icon, color: color, size: 13),
    );
  }
}
