import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../widgets/status_pill.dart';

class VehicleDetailPanel extends StatelessWidget {
  const VehicleDetailPanel({super.key, required this.device});

  final TraccarDevice device;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF111820),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      device.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  StatusPill(status: device.status),
                ],
              ),
              const SizedBox(height: 12),
              const _CompactRow(
                icon: Icons.speed_rounded,
                label: 'Velocidade',
                value: '60 km/h',
              ),
              const SizedBox(height: 8),
              _CompactRow(
                icon: Icons.circle_outlined,
                label: 'Status',
                value: device.status,
              ),
              const SizedBox(height: 8),
              const _CompactRow(
                icon: Icons.power_settings_new_rounded,
                label: 'Ignição',
                value: 'Ligada',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white60, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
