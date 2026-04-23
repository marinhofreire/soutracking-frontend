import 'package:flutter/material.dart';
import '../../data/models.dart';
import '../../widgets/status_pill.dart';

class VehicleListSection extends StatelessWidget {
  final List<TraccarDevice> devices;
  final void Function(TraccarDevice) onTap;
  const VehicleListSection(
      {super.key, required this.devices, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Veículos da frota',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Divider(height: 1, color: Colors.white12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.black12),
              columns: const [
                DataColumn(
                    label: Text('Nome/Placa',
                        style: TextStyle(color: Colors.white70))),
                DataColumn(
                    label: Text('Status',
                        style: TextStyle(color: Colors.white70))),
                DataColumn(
                    label: Text('Velocidade',
                        style: TextStyle(color: Colors.white70))),
                DataColumn(
                    label: Text('Ignição',
                        style: TextStyle(color: Colors.white70))),
                DataColumn(
                    label: Text('Última comunicação',
                        style: TextStyle(color: Colors.white70))),
                DataColumn(
                    label:
                        Text('Ação', style: TextStyle(color: Colors.white70))),
              ],
              rows: devices
                  .map((d) => DataRow(cells: [
                        DataCell(Text(d.name,
                            style: const TextStyle(color: Colors.white))),
                        DataCell(StatusPill(status: d.status)),
                        const DataCell(Text('60 km/h',
                            style: TextStyle(color: Colors.white54))),
                        const DataCell(Text('Ligada',
                            style: TextStyle(color: Colors.white54))),
                        DataCell(Text(d.lastUpdate ?? '-',
                            style: const TextStyle(color: Colors.white54))),
                        DataCell(ElevatedButton(
                          onPressed: () => onTap(d),
                          child: const Text('Ver painel'),
                        )),
                      ]))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
