import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/session_state.dart';

class MdvrDeviceDetailScreen extends ConsumerWidget {
  const MdvrDeviceDetailScreen({super.key, required this.deviceId});

  final String deviceId;

  TraccarDevice? _resolveDevice(List<TraccarDevice> devices) {
    final numericId = int.tryParse(deviceId);
    for (final device in devices) {
      if (numericId != null && device.id == numericId) {
        return device;
      }
      if ((device.uniqueId ?? '').trim() == deviceId.trim()) {
        return device;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(devicesProvider);
    final positionsAsync = ref.watch(positionsProvider);

    return devicesAsync.when(
      data: (devices) {
        final device = _resolveDevice(devices);
        if (device == null) {
          return Center(
            child: Text('Dispositivo MDVR "$deviceId" nao encontrado.'),
          );
        }

        return positionsAsync.when(
          data: (positions) {
            TraccarPosition? position;
            for (final p in positions) {
              if (p.deviceId == device.id) {
                position = p;
                break;
              }
            }

            final attrs = device.attributes ?? const <String, dynamic>{};

            return ListView(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Detalhe MDVR - ${device.name}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        ref.invalidate(devicesProvider);
                        ref.invalidate(positionsProvider);
                      },
                      icon: const Icon(Icons.refresh_outlined),
                      label: const Text('Atualizar'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ID: ${device.id}'),
                        Text('uniqueId: ${device.uniqueId ?? '-'}'),
                        Text('Status: ${device.status}'),
                        Text('Categoria: ${device.category ?? '-'}'),
                        Text('Última atualizacao: ${device.lastUpdate ?? '-'}'),
                        const SizedBox(height: 10),
                        if (position != null) ...[
                          Text(
                            'Posicao: ${position.latitude.toStringAsFixed(6)}, '
                            '${position.longitude.toStringAsFixed(6)}',
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: () async {
                                  final text =
                                      '${position!.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)}';
                                  await Clipboard.setData(
                                    ClipboardData(text: text),
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Coordenadas copiadas.'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy_all_outlined),
                                label: const Text('Copiar coordenadas'),
                              ),
                            ],
                          ),
                        ] else
                          const Text(
                              'Sem posicao recente para este dispositivo.'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Atributos do dispositivo',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        if (attrs.isEmpty)
                          const Text('Nenhum atributo disponivel.')
                        else
                          ...attrs.entries.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('${entry.key}: ${entry.value}'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Erro ao carregar posições: $error')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('Erro ao carregar dispositivo: $error')),
    );
  }
}
