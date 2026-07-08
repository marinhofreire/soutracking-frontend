import 'package:flutter/material.dart';

import '../models/report_models.dart';

class ReportCategoryCards extends StatelessWidget {
  const ReportCategoryCards({
    super.key,
    required this.categories,
    required this.onGenerate,
    required this.selectedTypeLabel,
  });

  final List<ReportCategory> categories;
  final ValueChanged<ReportType> onGenerate;
  final String selectedTypeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E0EE)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final category in categories)
            _CategoryPill(
              category: category,
              active: selectedTypeLabel == category.type.label,
              onTap: () => onGenerate(category.type),
            ),
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.category,
    required this.active,
    required this.onTap,
  });

  final ReportCategory category;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        active ? const Color(0xFF9FC3FF) : const Color(0xFFD6E0EE);
    final bgColor = active ? const Color(0xFFEAF3FF) : const Color(0xFFF8FBFF);
    final titleColor =
        active ? const Color(0xFF1E3A5F) : const Color(0xFF3E5679);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 190,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(
                _iconForType(category.type),
                size: 16,
                color:
                    active ? const Color(0xFF2D8CFF) : const Color(0xFF60718D),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.type.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.2,
                      ),
                    ),
                    Text(
                      category.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6F819C),
                        fontWeight: FontWeight.w600,
                        fontSize: 10.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(ReportType type) {
    switch (type) {
      case ReportType.trips:
        return Icons.route_outlined;
      case ReportType.routes:
        return Icons.alt_route_outlined;
      case ReportType.events:
        return Icons.article_outlined;
      case ReportType.stops:
        return Icons.pause_circle_outline_rounded;
      case ReportType.distance:
        return Icons.straighten_outlined;
      case ReportType.speed:
        return Icons.speed_outlined;
      case ReportType.alerts:
        return Icons.warning_amber_outlined;
      case ReportType.drivers:
        return Icons.badge_outlined;
      case ReportType.vehicles:
        return Icons.directions_car_filled_outlined;
    }
  }
}
