import 'package:flutter/material.dart';
import '../../data/models.dart';
import '../../widgets/gauge_chart.dart';
import '../../widgets/status_pill.dart';

class VehicleDetailPanel extends StatelessWidget {
  final TraccarDevice device;
  const VehicleDetailPanel({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(device.name,
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  StatusPill(status: device.status),
                ],
              ),
              const SizedBox(height: 14),
              GaugeChart(
                value: 60,
                minValue: 0,
                maxValue: 120,
                title: 'Velocidade',
                unit: 'km/h',
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _infoBlock('Ignição', 'Ligada'),
                  _infoBlock('Bateria', '80%'),
                  _infoBlock('Combustível', '58%'),
                  _infoBlock('Odômetro', '123.456 km'),
                  _infoBlock('Última atualização', device.lastUpdate ?? '-'),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Text(
                  'Localização: Av. Principal, Centro - São Paulo/SP',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 14),
              Text('Eventos recentes',
                  style: Theme.of(context).textTheme.titleSmall),
              ...List.generate(
                3,
                (i) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Evento ${i + 1}',
                      style: const TextStyle(color: Colors.white70)),
                  subtitle: const Text('Descrição do evento',
                      style: TextStyle(color: Colors.white38)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoBlock(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.white54)),
        Text(value,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
