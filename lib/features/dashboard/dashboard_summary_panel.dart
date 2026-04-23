import 'package:flutter/material.dart';
import '../../widgets/gauge_chart.dart';

class DashboardSummaryPanel extends StatelessWidget {
  final int total;
  final int online;
  final int offline;
  final int alerts;
  const DashboardSummaryPanel(
      {super.key,
      required this.total,
      required this.online,
      required this.offline,
      required this.alerts});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 980;
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GaugeChart(
                value: online.toDouble(),
                minValue: 0,
                maxValue: total > 0 ? total.toDouble() : 1,
                title: 'Ativos Online',
                unit: '',
                color: Colors.greenAccent,
              ),
              const SizedBox(height: 12),
              _kpiGrid(),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: GaugeChart(
                value: online.toDouble(),
                minValue: 0,
                maxValue: total > 0 ? total.toDouble() : 1,
                title: 'Ativos Online',
                unit: '',
                color: Colors.greenAccent,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(flex: 3, child: _kpiGrid()),
          ],
        );
      },
    );
  }

  Widget _kpiGrid() {
    return Column(
      children: [
        _kpiCard('Total de ativos', total, Colors.blue),
        _kpiCard('Online', online, Colors.greenAccent),
        _kpiCard('Offline', offline, Colors.redAccent),
        _kpiCard('Alertas/Eventos', alerts, Colors.orangeAccent),
      ],
    );
  }

  Widget _kpiCard(String label, int value, Color color) {
    return Card(
      color: color.withOpacity(0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(label, style: TextStyle(color: color)),
        trailing: Text('$value',
            style: TextStyle(
                fontSize: 20, color: color, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
