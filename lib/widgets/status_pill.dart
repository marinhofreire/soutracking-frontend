import 'package:flutter/material.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    Color color;
    String label;

    switch (normalized) {
      case 'online':
        color = Colors.greenAccent;
        label = 'Online';
        break;
      case 'offline':
        color = Colors.redAccent;
        label = 'Offline';
        break;
      default:
        color = Colors.orangeAccent;
        label = 'Indefinido';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
