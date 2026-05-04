import 'package:flutter/material.dart';

import '../../admin/admin_reference_ui.dart';
import '../models/report_models.dart';

class ReportCategoryCards extends StatelessWidget {
  const ReportCategoryCards({
    super.key,
    required this.categories,
    required this.onGenerate,
  });

  final List<ReportCategory> categories;
  final ValueChanged<ReportType> onGenerate;

  @override
  Widget build(BuildContext context) {
    return AdminGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Categorias de relatório',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final category in categories)
                _CategoryCard(category: category, onGenerate: onGenerate),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onGenerate});

  final ReportCategory category;
  final ValueChanged<ReportType> onGenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconForType(category.type), color: const Color(0xFF9FCEFF)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category.type.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            category.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFB8C5D9),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${category.generatedCount} gerados',
                  style: const TextStyle(
                    color: Color(0xFFDDE5F0),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => onGenerate(category.type),
                icon: const Icon(Icons.play_arrow_outlined, size: 16),
                label: const Text('Gerar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconForType(ReportType type) {
    switch (type) {
      case ReportType.trips:
        return Icons.trip_origin_outlined;
      case ReportType.routes:
        return Icons.alt_route_outlined;
      case ReportType.events:
        return Icons.event_note_outlined;
      case ReportType.stops:
        return Icons.stop_circle_outlined;
      case ReportType.distance:
        return Icons.straighten_outlined;
      case ReportType.speed:
        return Icons.speed_outlined;
      case ReportType.alerts:
        return Icons.warning_amber_outlined;
      case ReportType.drivers:
        return Icons.badge_outlined;
      case ReportType.vehicles:
        return Icons.local_shipping_outlined;
    }
  }
}
