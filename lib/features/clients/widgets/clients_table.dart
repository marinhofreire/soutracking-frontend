import 'package:flutter/material.dart';

import '../../admin/admin_reference_ui.dart';
import '../models/client_models.dart';

class ClientsTable extends StatelessWidget {
  const ClientsTable({super.key, required this.records});

  final List<ClientRecord> records;

  @override
  Widget build(BuildContext context) {
    return AdminGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Carteira de clientes',
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
                Expanded(flex: 3, child: _HeaderCell('Cliente')),
                Expanded(flex: 2, child: _HeaderCell('Segmento')),
                Expanded(flex: 2, child: _HeaderCell('Frota')),
                Expanded(flex: 2, child: _HeaderCell('Ultimo servico')),
                Expanded(flex: 2, child: _HeaderCell('Saldo')),
                Expanded(flex: 2, child: _HeaderCell('Status')),
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
                    child: _ClientCell(
                      name: record.name,
                      contact: record.contact,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _ValueCell(record.segment),
                  ),
                  Expanded(
                    flex: 2,
                    child: _ValueCell('${record.vehicleCount} veiculos'),
                  ),
                  Expanded(
                    flex: 2,
                    child: _ValueCell(_formatDate(record.lastService)),
                  ),
                  Expanded(
                    flex: 2,
                    child: _ValueCell(_formatCurrency(record.balance)),
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
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    final dd = value.day.toString().padLeft(2, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final yyyy = value.year.toString();
    return '$dd/$mm/$yyyy';
  }

  String _formatCurrency(double value) {
    return 'R\$ ${value.toStringAsFixed(2)}';
  }

  Color _statusColor(ClientStatus status) {
    switch (status) {
      case ClientStatus.active:
        return const Color(0xFF10B981);
      case ClientStatus.late:
        return const Color(0xFFE74B4B);
      case ClientStatus.inactive:
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

class _ClientCell extends StatelessWidget {
  const _ClientCell({required this.name, required this.contact});

  final String name;
  final String contact;

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
          contact,
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
