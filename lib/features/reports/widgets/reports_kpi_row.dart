import 'package:flutter/material.dart';

import '../models/report_models.dart';

class ReportsKpiRow extends StatelessWidget {
  const ReportsKpiRow({super.key, required this.summary});

  final ReportKpiSummary summary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _KpiCard(
          label: 'Relatórios gerados',
          value: summary.generated.toString(),
          color: const Color(0xFF3F8CFF),
          icon: Icons.description_outlined,
        ),
        _KpiCard(
          label: 'Agendados',
          value: summary.scheduled.toString(),
          color: const Color(0xFF10B981),
          icon: Icons.event_available_outlined,
        ),
        _KpiCard(
          label: 'Exportações',
          value: summary.exports.toString(),
          color: const Color(0xFFF59E0B),
          icon: Icons.file_download_outlined,
        ),
        _KpiCard(
          label: 'Alertas críticos',
          value: summary.criticalAlerts.toString(),
          color: const Color(0xFFE74B4B),
          icon: Icons.priority_high_outlined,
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
