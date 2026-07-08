import 'package:flutter/material.dart';

import '../models/client_models.dart';

class ClientsKpiRow extends StatelessWidget {
  const ClientsKpiRow({super.key, required this.summary});

  final ClientKpiSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _KpiCard(label: 'Total',         value: '${summary.total}',    color: const Color(0xFF176EEB)),
        const SizedBox(width: 10),
        _KpiCard(label: 'Ativos',        value: '${summary.active}',   color: const Color(0xFF22C55E)),
        const SizedBox(width: 10),
        _KpiCard(label: 'Inadimplentes', value: '${summary.overdue}',  color: const Color(0xFFEF4444)),
        const SizedBox(width: 10),
        _KpiCard(label: 'Inativos',      value: '${summary.inactive}', color: const Color(0xFF9CA3AF)),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDDE6F2)),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF60718D),
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
