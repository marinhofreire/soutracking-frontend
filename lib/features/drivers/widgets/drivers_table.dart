import 'package:flutter/material.dart';

import '../../admin/admin_reference_ui.dart';
import '../models/driver_models.dart';

class DriversTable extends StatelessWidget {
  const DriversTable({super.key, required this.records});

  final List<DriverRecord> records;

  @override
  Widget build(BuildContext context) {
    return AdminGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lista de motoristas',
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
                Expanded(flex: 3, child: _HeaderCell('Motorista')),
                Expanded(flex: 2, child: _HeaderCell('Telefone')),
                Expanded(flex: 2, child: _HeaderCell('CNH')),
                Expanded(flex: 2, child: _HeaderCell('Veiculo vinculado')),
                Expanded(flex: 2, child: _HeaderCell('Status')),
                Expanded(flex: 2, child: _HeaderCell('Ultima atividade')),
                Expanded(flex: 2, child: _HeaderCell('Validade CNH')),
                Expanded(flex: 1, child: _HeaderCell('Score')),
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
                  Expanded(
                    flex: 3,
                    child: _DriverCell(name: record.name, base: record.base),
                  ),
                  Expanded(flex: 2, child: _ValueCell(record.phone)),
                  Expanded(flex: 2, child: _ValueCell(record.cnh)),
                  Expanded(flex: 2, child: _ValueCell(record.vehicle)),
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
                    child: _ValueCell(_formatDateTime(record.lastActivity)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AdminStatusChip(
                        label: _formatCnhLabel(record),
                        color: _cnhColor(record.cnhState),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: _ValueCell(record.score.toString()),
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
                          icon: Icons.edit_outlined,
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

  String _formatDate(DateTime value) {
    final dd = value.day.toString().padLeft(2, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final yyyy = value.year.toString();
    return '$dd/$mm/$yyyy';
  }

  String _formatCnhLabel(DriverRecord record) {
    return '${record.cnhState.label} (${_formatDate(record.cnhExpiry)})';
  }

  Color _statusColor(DriverStatus status) {
    switch (status) {
      case DriverStatus.onRoute:
        return const Color(0xFF3F8CFF);
      case DriverStatus.available:
        return const Color(0xFF10B981);
      case DriverStatus.withoutVehicle:
        return const Color(0xFFF59E0B);
      case DriverStatus.inactive:
        return const Color(0xFF64748B);
    }
  }

  Color _cnhColor(CnhState cnhState) {
    switch (cnhState) {
      case CnhState.valid:
        return const Color(0xFF10B981);
      case CnhState.expiring:
        return const Color(0xFFF59E0B);
      case CnhState.expired:
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

class _DriverCell extends StatelessWidget {
  const _DriverCell({required this.name, required this.base});

  final String name;
  final String base;

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
          base,
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
