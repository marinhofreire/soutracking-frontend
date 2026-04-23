import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/session_state.dart';

class SchoolTransportScreen extends ConsumerStatefulWidget {
  const SchoolTransportScreen({super.key});

  @override
  ConsumerState<SchoolTransportScreen> createState() =>
      _SchoolTransportScreenState();
}

class _SchoolTransportScreenState extends ConsumerState<SchoolTransportScreen> {
  int? _selectedDeviceId;
  final List<_StudentRide> _students = [
    _StudentRide(
      name: 'Ana Souza',
      guardian: 'Carla Souza',
      phone: '+55 11 99999-1111',
      stopLabel: 'Rua A, 123',
    ),
    _StudentRide(
      name: 'Bruno Lima',
      guardian: 'Carlos Lima',
      phone: '+55 11 99999-2222',
      stopLabel: 'Av. Central, 456',
    ),
    _StudentRide(
      name: 'Camila Alves',
      guardian: 'Paula Alves',
      phone: '+55 11 99999-3333',
      stopLabel: 'Praça das Flores, 90',
    ),
  ];

  void _toggleBoarding(_StudentRide student) {
    setState(() {
      student.boarded = !student.boarded;
      if (!student.boarded) {
        student.arrived = false;
      }
    });
  }

  void _toggleArrival(_StudentRide student) {
    if (!student.boarded) return;
    setState(() => student.arrived = !student.arrived);
  }

  void _sendWhatsApp(_StudentRide student, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('WhatsApp para ${student.guardian}: $message')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transporte Escolar',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Controle embarque/desembarque e notificações aos responsáveis.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: devicesAsync.when(
                data: (devices) {
                  return DropdownButtonFormField<int?>(
                    key: ValueKey(
                      'school-device-${_selectedDeviceId ?? 'all'}',
                    ),
                    initialValue: _selectedDeviceId,
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Selecionar ônibus'),
                      ),
                      ...devices.map(
                        (d) => DropdownMenuItem<int?>(
                          value: d.id,
                          child: Text(d.name),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedDeviceId = value),
                    decoration: const InputDecoration(labelText: 'Ônibus'),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text('Erro: $error'),
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: _selectedDeviceId == null
                  ? null
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Checklist de rota iniciado.'),
                        ),
                      );
                    },
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Iniciar rota'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: _students.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final student = _students[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.school_outlined),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            student.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Chip(
                          label: Text(
                            student.boarded
                                ? (student.arrived ? 'Chegou' : 'Embarcado')
                                : 'Aguardando',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Responsável: ${student.guardian}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                    ),
                    Text(
                      'Ponto: ${student.stopLabel}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _toggleBoarding(student),
                          icon: Icon(
                            student.boarded
                                ? Icons.check_circle_outline
                                : Icons.directions_bus_outlined,
                          ),
                          label: Text(
                            student.boarded ? 'Desembarcar' : 'Embarcar',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: student.boarded
                              ? () => _toggleArrival(student)
                              : null,
                          icon: const Icon(Icons.flag_outlined),
                          label: const Text('Chegou na escola'),
                        ),
                        FilledButton.icon(
                          onPressed: () {
                            final message = student.arrived
                                ? '${student.name} chegou na escola.'
                                : student.boarded
                                ? '${student.name} embarcou no ônibus.'
                                : '${student.name} ainda não embarcou.';
                            _sendWhatsApp(student, message);
                          },
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Avisar responsável'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StudentRide {
  _StudentRide({
    required this.name,
    required this.guardian,
    required this.phone,
    required this.stopLabel,
  });

  final String name;
  final String guardian;
  final String phone;
  final String stopLabel;
  bool boarded = false;
  bool arrived = false;
}
