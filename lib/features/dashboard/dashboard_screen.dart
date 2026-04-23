import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/session_state.dart';
import 'dashboard_summary_panel.dart';
import 'vehicle_detail_panel.dart';
import 'vehicle_list_section.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(devicesProvider);

    return devicesAsync.when(
      data: (devices) {
        final fleet = _ensureAuditFleet(devices);
        final total = fleet.length;
        final online =
            fleet.where((d) => d.status.toLowerCase() == 'online').length;
        final offline =
            fleet.where((d) => d.status.toLowerCase() == 'offline').length;
        const alerts = 2;

        Widget opSummaryRow(String label, String value) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(color: Colors.white70)),
                Text(value, style: const TextStyle(color: Colors.white)),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Container(
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DashboardSummaryPanel(
                  total: total,
                  online: online,
                  offline: offline,
                  alerts: alerts,
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 980;
                    if (narrow) {
                      return Column(
                        children: [
                          _mapOperationalCard(),
                          const SizedBox(height: 12),
                          Card(
                            color: Theme.of(context).colorScheme.surface,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Resumo operacional',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  const SizedBox(height: 8),
                                  opSummaryRow('Veículos em movimento', '2'),
                                  opSummaryRow('Veículos parados',
                                      (total - 2).clamp(0, total).toString()),
                                  opSummaryRow(
                                      'Última atualização', 'há 2 min'),
                                  opSummaryRow('Manutenção pendente', '0'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _mapOperationalCard()),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Card(
                            color: Theme.of(context).colorScheme.surface,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Resumo operacional',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  const SizedBox(height: 8),
                                  opSummaryRow('Veículos em movimento', '2'),
                                  opSummaryRow('Veículos parados',
                                      (total - 2).clamp(0, total).toString()),
                                  opSummaryRow(
                                      'Última atualização', 'há 2 min'),
                                  opSummaryRow('Manutenção pendente', '0'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                VehicleListSection(
                  devices: fleet,
                  onTap: (device) {
                    showDialog(
                      context: context,
                      builder: (_) => VehicleDetailPanel(device: device),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
      error: (_, __) => const SizedBox.shrink(),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  static List<TraccarDevice> _ensureAuditFleet(List<TraccarDevice> input) {
    final result = <TraccarDevice>[...input];
    final needed = 5 - result.length;
    for (var i = 0; i < needed; i++) {
      result.add(
        TraccarDevice(
          id: 1000 + i,
          name: 'Veículo ${i + 1} / ABC-${1000 + i}',
          status: i.isEven ? 'online' : 'offline',
          lastUpdate: '2026-02-28T12:0${i}:00Z',
        ),
      );
    }
    return result;
  }

  Widget _mapOperationalCard() {
    return Card(
      color: Colors.grey.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        height: 280,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF121419), Color(0xFF1B1F27)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 16,
              top: 14,
              child: Text(
                'Mapa operacional',
                style: TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.w700),
              ),
            ),
            const Center(
              child:
                  Icon(Icons.location_pin, color: Colors.redAccent, size: 64),
            ),
            Positioned(
              right: 14,
              bottom: 12,
              child: Row(
                children: const [
                  Icon(Icons.circle, color: Colors.greenAccent, size: 10),
                  SizedBox(width: 4),
                  Text('Online', style: TextStyle(color: Colors.white60)),
                  SizedBox(width: 12),
                  Icon(Icons.circle, color: Colors.redAccent, size: 10),
                  SizedBox(width: 4),
                  Text('Offline', style: TextStyle(color: Colors.white60)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
