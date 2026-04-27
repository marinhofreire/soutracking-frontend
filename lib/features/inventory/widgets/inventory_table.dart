import 'package:flutter/material.dart';

import '../../admin/admin_reference_ui.dart';
import '../models/inventory_models.dart';

class InventoryTable extends StatelessWidget {
  const InventoryTable({
    super.key,
    required this.records,
    required this.onView,
    required this.onEdit,
  });

  final List<InventoryItemRecord> records;
  final ValueChanged<InventoryItemRecord> onView;
  final ValueChanged<InventoryItemRecord> onEdit;

  @override
  Widget build(BuildContext context) {
    return AdminGlassPanel(
      backgroundColor: const Color(0xF2F8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estoque',
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
                Expanded(flex: 3, child: _HeaderCell('Item')),
                Expanded(flex: 2, child: _HeaderCell('Categoria')),
                Expanded(flex: 1, child: _HeaderCell('Quantidade')),
                Expanded(flex: 2, child: _HeaderCell('Status')),
                Expanded(flex: 2, child: _HeaderCell('Local')),
                Expanded(flex: 2, child: _HeaderCell('Fornecedor')),
                Expanded(flex: 2, child: _HeaderCell('Ultima movimentacao')),
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
                  Expanded(flex: 3, child: _ValueCell(record.item)),
                  Expanded(flex: 2, child: _ValueCell(record.category.label)),
                  Expanded(
                      flex: 1, child: _ValueCell(record.quantity.toString())),
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
                  Expanded(flex: 2, child: _ValueCell(record.location)),
                  Expanded(flex: 2, child: _ValueCell(record.supplier)),
                  Expanded(
                      flex: 2,
                      child: _ValueCell(_dateTime(record.lastMovementAt))),
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
                          icon: Icons.edit_outlined,
                          color: const Color(0xFF10B981),
                          onTap: () => onEdit(record),
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

  String _dateTime(DateTime value) {
    final dd = value.day.toString().padLeft(2, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$dd/$mm ${hh}h$min';
  }

  Color _statusColor(InventoryStatus status) {
    switch (status) {
      case InventoryStatus.available:
        return const Color(0xFF10B981);
      case InventoryStatus.lowStock:
        return const Color(0xFFF59E0B);
      case InventoryStatus.inUse:
        return const Color(0xFF3F8CFF);
      case InventoryStatus.reserved:
        return const Color(0xFF8B5CF6);
      case InventoryStatus.defective:
        return const Color(0xFFE74B4B);
      case InventoryStatus.discarded:
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
