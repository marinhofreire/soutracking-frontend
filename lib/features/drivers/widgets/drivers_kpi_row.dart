import 'package:flutter/material.dart';

import '../models/driver_models.dart';

class DriversKpiRow extends StatelessWidget {
  const DriversKpiRow({super.key, required this.summary});

  final DriverKpiSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final cardWidth = (constraints.maxWidth - (spacing * 5)) / 6;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _DriverKpiCard(
              width: cardWidth,
              label: 'Total de motoristas',
              value: summary.active.toString(),
              caption: 'cadastrados',
              color: const Color(0xFF176EEB),
              icon: Icons.badge_outlined,
            ),
            _DriverKpiCard(
              width: cardWidth,
              label: 'Ativos',
              value: '--',
              caption: 'sem status real',
              color: const Color(0xFF18A558),
              icon: Icons.verified_user_outlined,
            ),
            _DriverKpiCard(
              width: cardWidth,
              label: 'Em rota',
              value: '--',
              caption: 'sem vinculo real',
              color: const Color(0xFF176EEB),
              icon: Icons.alt_route_outlined,
            ),
            _DriverKpiCard(
              width: cardWidth,
              label: 'Sem veiculo',
              value: '--',
              caption: 'sem vinculo real',
              color: const Color(0xFFF59E0B),
              icon: Icons.no_transfer_outlined,
            ),
            _DriverKpiCard(
              width: cardWidth,
              label: 'CNH a vencer',
              value: summary.cnhExpiring.toString(),
              caption: 'validade cadastrada',
              color: const Color(0xFFE74B4B),
              icon: Icons.warning_amber_outlined,
            ),
            _DriverKpiCard(
              width: cardWidth,
              label: 'Inativos',
              value: '--',
              caption: 'sem status real',
              color: const Color(0xFF8291A8),
              icon: Icons.person_off_outlined,
            ),
          ],
        );
      },
    );
  }
}

class _DriverKpiCard extends StatelessWidget {
  const _DriverKpiCard({
    required this.width,
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
    required this.icon,
  });

  final double width;
  final String label;
  final String value;
  final String caption;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width.clamp(138, 220).toDouble(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E1EF)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF50647E),
                    fontSize: 10.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF1F2A44),
                    fontSize: 19,
                    height: 0.98,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
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
