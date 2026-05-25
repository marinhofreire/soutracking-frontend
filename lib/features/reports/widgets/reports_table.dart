import 'package:flutter/material.dart';

import '../../admin/admin_reference_ui.dart';
import '../models/report_models.dart';

class ReportsTable extends StatelessWidget {
  const ReportsTable({
    super.key,
    required this.records,
    required this.onView,
    required this.onExportPdf,
    required this.onExportExcel,
    required this.canExportRow,
    required this.pdfEnabled,
  });

  final List<ReportRecord> records;
  final ValueChanged<ReportRecord> onView;
  final ValueChanged<ReportRecord> onExportPdf;
  final ValueChanged<ReportRecord> onExportExcel;
  final bool canExportRow;
  final bool pdfEnabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E0EE)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF6FAFF),
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
                Expanded(flex: 3, child: _HeaderCell('Nome do relatório')),
                Expanded(flex: 2, child: _HeaderCell('Tipo')),
                Expanded(flex: 2, child: _HeaderCell('Período')),
                Expanded(flex: 2, child: _HeaderCell('Gerado em')),
                Expanded(flex: 1, child: _HeaderCell('Status')),
                SizedBox(width: 110),
              ],
            ),
          ),
          if (records.isEmpty)
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Nenhum relatório encontrado para o período selecionado.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF60718D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: records.length,
                separatorBuilder: (_, __) => Divider(
                  color: const Color(0xFFD6E0EE).withValues(alpha: 0.85),
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final record = records[index];
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _NameCell(
                            name: record.name,
                            details:
                                '${record.vehicle} - ${record.totalRecords} registros',
                          ),
                        ),
                        Expanded(flex: 2, child: _ValueCell(record.type.label)),
                        Expanded(flex: 2, child: _ValueCell(record.period)),
                        Expanded(
                          flex: 2,
                          child: _ValueCell(_formatDateTime(record.createdAt)),
                        ),
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
                        SizedBox(
                          width: 110,
                          child: Row(
                            children: [
                              _ActionButton(
                                icon: Icons.visibility_outlined,
                                color: const Color(0xFF176EEB),
                                onTap: () => onView(record),
                              ),
                              const SizedBox(width: 6),
                              _ActionButton(
                                icon: Icons.picture_as_pdf_outlined,
                                color: const Color(0xFFE74B4B),
                                enabled: pdfEnabled,
                                onTap: () => onExportPdf(record),
                              ),
                              const SizedBox(width: 6),
                              _ActionButton(
                                icon: Icons.grid_on_outlined,
                                color: const Color(0xFF10B981),
                                enabled: canExportRow,
                                onTap: () => onExportExcel(record),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
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
        color: Color(0xFF5F738F),
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
        color: Color(0xFF334155),
        fontWeight: FontWeight.w600,
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
            color: Color(0xFF25344A),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          details,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF5F738F),
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
    this.enabled = true,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? color.withValues(alpha: 0.35)
                : const Color(0xFFA3B1C6).withValues(alpha: 0.55),
          ),
          color:
              enabled ? color.withValues(alpha: 0.1) : const Color(0xFFEFF3F9),
        ),
        child: Icon(
          icon,
          color: enabled ? color : const Color(0xFF94A3B8),
          size: 14,
        ),
      ),
    );
  }
}
