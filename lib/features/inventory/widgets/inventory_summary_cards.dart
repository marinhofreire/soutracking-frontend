import 'package:flutter/material.dart';

import '../../admin/admin_reference_ui.dart';
import '../models/inventory_models.dart';

class InventorySummaryCards extends StatelessWidget {
  const InventorySummaryCards({super.key, required this.cards});

  final List<InventorySummaryCard> cards;

  @override
  Widget build(BuildContext context) {
    return AdminGlassPanel(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final card in cards)
            Container(
              width: 230,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDE5F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    style: const TextStyle(
                      color: Color(0xFF60718D),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.value,
                    style: const TextStyle(
                      color: Color(0xFF1F2A44),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    card.subtitle,
                    style: const TextStyle(
                      color: Color(0xFF7A8CA8),
                      fontSize: 11,
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
