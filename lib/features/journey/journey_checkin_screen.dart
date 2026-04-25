import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/session_state.dart';

class JourneyCheckinRecord {
  JourneyCheckinRecord({
    required this.id,
    required this.createdAt,
    required this.driverId,
    required this.driverName,
    required this.deviceId,
    required this.deviceName,
    required this.journeyType,
    required this.status,
    required this.checklist,
    required this.note,
  });

  final String id;
  final DateTime createdAt;
  final int driverId;
  final String driverName;
  final int deviceId;
  final String deviceName;
  final String journeyType;
  final String status;
  final Map<String, bool> checklist;
  final String note;
}

class JourneyCheckinController
    extends StateNotifier<List<JourneyCheckinRecord>> {
  JourneyCheckinController() : super(const []);

  void addRecord(JourneyCheckinRecord record) {
    state = [record, ...state];
  }
}

final journeyCheckinsProvider =
    StateNotifierProvider<JourneyCheckinController, List<JourneyCheckinRecord>>(
  (ref) => JourneyCheckinController(),
);

class JourneyCheckinScreen extends ConsumerStatefulWidget {
  const JourneyCheckinScreen({super.key});

  @override
  ConsumerState<JourneyCheckinScreen> createState() =>
      _JourneyCheckinScreenState();
}

class _JourneyCheckinScreenState extends ConsumerState<JourneyCheckinScreen> {
  int? _driverId;
  int? _deviceId;
  String _journeyType = 'inicio';
  final _noteController = TextEditingController();

  final Map<String, bool> _checklist = {
    'pneus': false,
    'luzes': false,
    'freios': false,
    'documentos': false,
    'avarias': false,
  };

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _labelFromType(String type) {
    switch (type) {
      case 'inicio':
        return 'Início de jornada';
      case 'troca':
        return 'Troca de motorista';
      case 'retorno':
        return 'Retorno';
      case 'fim':
        return 'Fim de jornada';
      default:
        return type;
    }
  }

  Future<void> _save({
    required List<Map<String, dynamic>> drivers,
    required List<TraccarDevice> devices,
  }) async {
    if (_driverId == null || _deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione motorista e dispositivo para continuar.'),
        ),
      );
      return;
    }

    final criticalFailed = ['pneus', 'luzes', 'freios', 'documentos']
        .where((key) => _checklist[key] != true)
        .toList();

    final driver = drivers.firstWhere(
      (d) => d['id'] == _driverId,
      orElse: () => {'id': _driverId, 'name': 'Motorista #$_driverId'},
    );

    final device = devices.firstWhere(
      (d) => d.id == _deviceId,
      orElse: () => TraccarDevice(
        id: _deviceId!,
        name: 'Dispositivo #$_deviceId',
        status: 'unknown',
        lastUpdate: null,
      ),
    );

    final status = criticalFailed.isEmpty ? 'APTO' : 'BLOQUEADO';

    final record = JourneyCheckinRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      driverId: _driverId!,
      driverName: '${driver['name'] ?? 'Motorista #$_driverId'}',
      deviceId: _deviceId!,
      deviceName: device.name,
      journeyType: _journeyType,
      status: status,
      checklist: Map<String, bool>.from(_checklist),
      note: _noteController.text.trim(),
    );

    ref.read(journeyCheckinsProvider.notifier).addRecord(record);

    if (status == 'BLOQUEADO') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Jornada bloqueada. Itens críticos pendentes: ${criticalFailed.join(', ')}',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-in de jornada salvo com sucesso.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final driversAsync = ref.watch(driversProvider);
    final devicesAsync = ref.watch(devicesProvider);
    final records = ref.watch(journeyCheckinsProvider);

    final list = records.isEmpty
        ? const Center(child: Text('Nenhum check-in de jornada registrado'))
        : ListView.separated(
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = records[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Theme.of(context).colorScheme.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item.driverName} → ${item.deviceName}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Chip(
                          label: Text(item.status),
                          backgroundColor: item.status == 'APTO'
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.red.withValues(alpha: 0.2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_labelFromType(item.journeyType)} • ${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: const Color(0xFF60718D)),
                    ),
                    if (item.note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.note,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: const Color(0xFF60718D)),
                      ),
                    ],
                  ],
                ),
              );
            },
          );

    final form = DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF183153).withValues(alpha: 0.12),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Jornada / Check-in',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: const Color(0xFF1F2A44)),
            ),
            const SizedBox(height: 12),
            driversAsync.when(
              data: (drivers) => DropdownButtonFormField<int>(
                initialValue: _driverId,
                items: drivers
                    .map(
                      (d) => DropdownMenuItem<int>(
                        value: d['id'] as int,
                        child: Text('${d['name'] ?? 'Motorista'}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _driverId = value),
                decoration: const InputDecoration(labelText: 'Motorista'),
                dropdownColor: Colors.white,
                style: const TextStyle(color: Color(0xFF1F2A44)),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(
                'Erro motoristas: $error',
                style: const TextStyle(color: Color(0xFF1F2A44)),
              ),
            ),
            const SizedBox(height: 12),
            devicesAsync.when(
              data: (devices) => DropdownButtonFormField<int>(
                initialValue: _deviceId,
                items: devices
                    .map(
                      (d) => DropdownMenuItem<int>(
                        value: d.id,
                        child: Text('${d.name} (${d.status})'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _deviceId = value),
                decoration: const InputDecoration(labelText: 'Dispositivo'),
                dropdownColor: Colors.white,
                style: const TextStyle(color: Color(0xFF1F2A44)),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(
                'Erro dispositivos: $error',
                style: const TextStyle(color: Color(0xFF1F2A44)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _journeyType,
              items: const [
                DropdownMenuItem(
                    value: 'inicio', child: Text('Início de jornada')),
                DropdownMenuItem(
                    value: 'troca', child: Text('Troca de motorista')),
                DropdownMenuItem(value: 'retorno', child: Text('Retorno')),
                DropdownMenuItem(value: 'fim', child: Text('Fim de jornada')),
              ],
              onChanged: (value) =>
                  setState(() => _journeyType = value ?? 'inicio'),
              decoration: const InputDecoration(labelText: 'Tipo da jornada'),
              dropdownColor: Colors.white,
              style: const TextStyle(color: Color(0xFF1F2A44)),
            ),
            const SizedBox(height: 12),
            Text(
              'Checklist pré-jornada',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: const Color(0xFF1F2A44)),
            ),
            const SizedBox(height: 8),
            ..._checklist.keys.map(
              (key) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _checklist[key],
                onChanged: (value) =>
                    setState(() => _checklist[key] = value ?? false),
                title: Text(
                  key[0].toUpperCase() + key.substring(1),
                  style: const TextStyle(color: Color(0xFF1F2A44)),
                ),
                subtitle:
                    ['pneus', 'luzes', 'freios', 'documentos'].contains(key)
                        ? const Text(
                            'Item crítico',
                            style: TextStyle(color: Colors.orangeAccent),
                          )
                        : null,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              minLines: 2,
              maxLines: 3,
              style: const TextStyle(color: Color(0xFF1F2A44)),
              decoration: const InputDecoration(
                labelText: 'Observações (opcional)',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () async {
                final drivers =
                    driversAsync.value ?? const <Map<String, dynamic>>[];
                final devices = devicesAsync.value ?? const <TraccarDevice>[];
                await _save(drivers: drivers, devices: devices);
              },
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Salvar check-in'),
            ),
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        if (!isWide) {
          return ListView(
            children: [
              form,
              const SizedBox(height: 20),
              SizedBox(height: 420, child: list),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 380,
              margin: const EdgeInsets.only(left: 16, right: 20, top: 24),
              child: form,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 24, right: 16),
                child: list,
              ),
            ),
          ],
        );
      },
    );
  }
}
