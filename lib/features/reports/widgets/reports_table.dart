import 'package:flutter/material.dart';

import '../../admin/admin_reference_ui.dart';
import '../models/report_models.dart';

class ReportsTable extends StatelessWidget {
  const ReportsTable({
    super.key,
    required this.records,
    required this.onView,
  });

  final List<ReportRecord> records;
  final ValueChanged<ReportRecord> onView;

  @override
  Widget build(BuildContext context) {
    return AdminGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Relatórios recentes',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          if (records.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.84),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDE5F0)),
              ),
              child: const Text(
                'Nenhum relatório encontrado para o período selecionado',
                style: TextStyle(
                  color: Color(0xFF25344A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: _HeaderCell('Nome do relatório')),
                  Expanded(flex: 2, child: _HeaderCell('Tipo')),
                  Expanded(flex: 2, child: _HeaderCell('Veículo/Motorista')),
                  Expanded(flex: 2, child: _HeaderCell('Período')),
                  Expanded(flex: 1, child: _HeaderCell('Status')),
                  Expanded(flex: 2, child: _HeaderCell('Criado em')),
                  Expanded(flex: 2, child: _HeaderCell('Ações')),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final record in records)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.84),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDDE5F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _NameCell(
                        name: record.name,
                        details:
                            '${record.totalRecords} registros • ${record.format.label}',
                      ),
                    ),
                    Expanded(flex: 2, child: _ValueCell(record.type.label)),
                    Expanded(
                      flex: 2,
                      child: _ValueCell('${record.vehicle} / ${record.driver}'),
                    ),
                    Expanded(flex: 2, child: _ValueCell(record.period)),
                    Expanded(
                      flex: 1,
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
                      child: _ValueCell(_formatDateTime(record.createdAt)),
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
                            icon: Icons.picture_as_pdf_outlined,
                            color: const Color(0xFFE74B4B),
                            onTap: () {},
                          ),
                          _ActionButton(
                            icon: Icons.grid_on_outlined,
                            color: const Color(0xFF10B981),
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
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

  Color _statusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.ready:
        return const Color(0xFF10B981);
      case ReportStatus.processing:
        return const Color(0xFF3F8CFF);
      case ReportStatus.scheduled:
        return const Color(0xFFF59E0B);
      case ReportStatus.failed:
        return const Color(0xFFE74B4B);
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

class _NameCell extends StatelessWidget {
  const _NameCell({required this.name, required this.details});

  final String name;
  final String details;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
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
          details,
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
