import 'package:flutter/material.dart';

import '../models/driver_models.dart';

class DriversKpiRow extends StatelessWidget {
  const DriversKpiRow({super.key, required this.summary});

  final DriverKpiSummary summary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _KpiCard(
          label: 'Motoristas ativos',
          value: summary.active.toString(),
          color: const Color(0xFF10B981),
          icon: Icons.badge_outlined,
        ),
        _KpiCard(
          label: 'Em rota',
          value: summary.onRoute.toString(),
          color: const Color(0xFF3F8CFF),
          icon: Icons.alt_route_outlined,
        ),
        _KpiCard(
          label: 'Sem veiculo',
          value: summary.withoutVehicle.toString(),
          color: const Color(0xFFF59E0B),
          icon: Icons.no_transfer_outlined,
        ),
        _KpiCard(
          label: 'CNH a vencer',
          value: summary.cnhExpiring.toString(),
          color: const Color(0xFFE74B4B),
          icon: Icons.warning_amber_outlined,
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
      width: 220,
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
                    fontSize: 22,
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
