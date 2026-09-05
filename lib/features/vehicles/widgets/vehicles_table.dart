import 'package:flutter/material.dart';

import '../../admin/admin_reference_ui.dart';
import '../models/vehicle_models.dart';

class VehiclesTable extends StatelessWidget {
  const VehiclesTable({super.key, required this.records});

  final List<VehicleRecord> records;

  @override
  Widget build(BuildContext context) {
    return AdminGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Frota operacional',
            style: TextStyle(
              color: Color(0xFF1F2A44),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: _HeaderCell('Placa')),
                Expanded(flex: 3, child: _HeaderCell('Modelo')),
                Expanded(flex: 2, child: _HeaderCell('Motorista')),
                Expanded(flex: 2, child: _HeaderCell('Status')),
                Expanded(flex: 2, child: _HeaderCell('Ignição')),
                Expanded(flex: 2, child: _HeaderCell('Velocidade')),
                Expanded(flex: 2, child: _HeaderCell('Última atualizacao')),
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
                  Expanded(flex: 2, child: _ValueCell(record.plate)),
                  Expanded(flex: 3, child: _ValueCell(record.model)),
                  Expanded(flex: 2, child: _ValueCell(record.driver)),
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
                    child: _ValueCell(record.ignition.label),
                  ),
                  Expanded(
                    flex: 2,
                    child: _ValueCell(
                        '${record.speedKmh.toStringAsFixed(0)} km/h'),
                  ),
                  Expanded(
                    flex: 2,
                    child: _ValueCell(_formatDateTime(record.lastUpdate)),
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

  Color _statusColor(VehicleStatus status) {
    switch (status) {
      case VehicleStatus.online:
        return const Color(0xFF10B981);
      case VehicleStatus.maintenance:
        return const Color(0xFFF59E0B);
      case VehicleStatus.noSignal:
        return const Color(0xFFE74B4B);
      case VehicleStatus.offline:
        return const Color(0xFF64748B);
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
        color: Color(0xFF60718D),
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
