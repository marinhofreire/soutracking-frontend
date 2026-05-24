import 'package:flutter/material.dart';

import '../../admin/admin_reference_ui.dart';
import '../models/finance_models.dart';

class FinanceTable extends StatelessWidget {
  const FinanceTable({
    super.key,
    required this.records,
    required this.onView,
    required this.onMarkPaid,
    required this.onCancel,
  });

  final List<FinanceChargeRecord> records;
  final ValueChanged<FinanceChargeRecord> onView;
  final ValueChanged<FinanceChargeRecord> onMarkPaid;
  final ValueChanged<FinanceChargeRecord> onCancel;

  @override
  Widget build(BuildContext context) {
    return AdminGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cobrancas',
            style: TextStyle(
              color: Color(0xFF25344A),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDCE6F4)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: _HeaderCell('ID')),
                Expanded(flex: 2, child: _HeaderCell('Cliente')),
                Expanded(flex: 3, child: _HeaderCell('Descricao')),
                Expanded(flex: 2, child: _HeaderCell('Valor')),
                Expanded(flex: 2, child: _HeaderCell('Vencimento')),
                Expanded(flex: 2, child: _HeaderCell('Forma de pagamento')),
                Expanded(flex: 2, child: _HeaderCell('Status')),
                Expanded(flex: 2, child: _HeaderCell('Criado em')),
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
                  Expanded(flex: 2, child: _ValueCell(record.id)),
                  Expanded(flex: 2, child: _ValueCell(record.client)),
                  Expanded(flex: 3, child: _ValueCell(record.description)),
                  Expanded(
                      flex: 2, child: _ValueCell(_currency(record.amount))),
                  Expanded(flex: 2, child: _ValueCell(_date(record.dueDate))),
                  Expanded(
                    flex: 2,
                    child: _ValueCell(record.paymentMethod.label),
                  ),
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
                  Expanded(flex: 2, child: _ValueCell(_date(record.createdAt))),
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
                          icon: Icons.check_circle_outline,
                          color: const Color(0xFF10B981),
                          onTap: () => onMarkPaid(record),
                        ),
                        _ActionButton(
                          icon: Icons.cancel_outlined,
                          color: const Color(0xFFE74B4B),
                          onTap: () => onCancel(record),
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

  String _currency(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _date(DateTime value) {
    final dd = value.day.toString().padLeft(2, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final yyyy = value.year.toString();
    return '$dd/$mm/$yyyy';
  }

  Color _statusColor(FinanceStatus status) {
    switch (status) {
      case FinanceStatus.paid:
        return const Color(0xFF10B981);
      case FinanceStatus.open:
        return const Color(0xFF3F8CFF);
      case FinanceStatus.overdue:
        return const Color(0xFFE74B4B);
      case FinanceStatus.canceled:
        return const Color(0xFF64748B);
      case FinanceStatus.waitingPayment:
        return const Color(0xFFF59E0B);
      case FinanceStatus.refunded:
        return const Color(0xFF14B8A6);
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
