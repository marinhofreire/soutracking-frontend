import 'package:flutter/material.dart';

import '../models/report_models.dart';

class ReportsKpiRow extends StatelessWidget {
  const ReportsKpiRow({super.key, required this.summary});

  final ReportKpiSummary summary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _KpiCard(
          label: 'Relatórios gerados',
          value: summary.generated.toString(),
          color: const Color(0xFF3F8CFF),
          icon: Icons.description_outlined,
        ),
        _KpiCard(
          label: 'Em processamento',
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
          icon: Icons.warning_amber_rounded,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E0EE)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF5F738F),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF25344A),
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
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

