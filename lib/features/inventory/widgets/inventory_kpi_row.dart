import 'package:flutter/material.dart';

import '../models/inventory_models.dart';

class InventoryKpiRow extends StatelessWidget {
  const InventoryKpiRow({super.key, required this.summary});

  final InventoryKpiSummary summary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _KpiCard(
          label: 'Itens em estoque',
          value: summary.itemsInStock.toString(),
          color: const Color(0xFF3F8CFF),
          icon: Icons.inventory_2_outlined,
        ),
        _KpiCard(
          label: 'Baixo estoque',
          value: summary.lowStock.toString(),
          color: const Color(0xFFF59E0B),
          icon: Icons.warning_amber_outlined,
        ),
        _KpiCard(
          label: 'Em uso',
          value: summary.inUse.toString(),
          color: const Color(0xFF10B981),
          icon: Icons.handyman_outlined,
        ),
        _KpiCard(
          label: 'Movimentacoes do mes',
          value: summary.monthMovements.toString(),
          color: const Color(0xFF6366F1),
          icon: Icons.swap_horiz_outlined,
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
