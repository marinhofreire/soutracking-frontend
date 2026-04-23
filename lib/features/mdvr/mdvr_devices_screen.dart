import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_router.dart';
import '../../data/models.dart';
import '../../state/session_state.dart';

class MdvrDevicesScreen extends ConsumerStatefulWidget {
  const MdvrDevicesScreen({super.key});

  @override
  ConsumerState<MdvrDevicesScreen> createState() => _MdvrDevicesScreenState();
}

class _MdvrDevicesScreenState extends ConsumerState<MdvrDevicesScreen> {
  String _query = '';

  bool _isMdvrDevice(TraccarDevice device) {
    final category = (device.category ?? '').toLowerCase();
    final name = device.name.toLowerCase();
    final attrs = device.attributes ?? const <String, dynamic>{};
    final attrsText = attrs.entries
        .map((entry) => '${entry.key}:${entry.value}')
        .join(' ')
        .toLowerCase();

    return category.contains('mdvr') ||
        category.contains('camera') ||
        name.contains('mdvr') ||
        name.contains('camera') ||
        name.contains('dvr') ||
        attrsText.contains('mdvr') ||
        attrsText.contains('camera') ||
        attrsText.contains('video');
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesProvider);
    final positionsAsync = ref.watch(positionsProvider);

    return devicesAsync.when(
      data: (devices) {
        return positionsAsync.when(
          data: (positions) {
            final mdvrOnly = devices.where(_isMdvrDevice).toList();
            final candidates = mdvrOnly.isEmpty ? devices : mdvrOnly;
            final filtered = candidates.where((device) {
              if (_query.trim().isEmpty) return true;
              final q = _query.trim().toLowerCase();
              return device.name.toLowerCase().contains(q) ||
                  '${device.id}'.contains(q) ||
                  (device.uniqueId ?? '').toLowerCase().contains(q);
            }).toList();

            final positionByDeviceId = <int, TraccarPosition>{
              for (final position in positions) position.deviceId: position,
            };

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'Dispositivos MDVR',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Spacer(),
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
                const SizedBox(height: 10),
                TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar por nome, ID ou uniqueId',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  mdvrOnly.isEmpty
                      ? 'Nenhum dispositivo com tag MDVR explicita. Mostrando todos os dispositivos.'
                      : 'Exibindo ${filtered.length} dispositivo(s) MDVR.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text('Nenhum dispositivo encontrado.'))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final device = filtered[index];
                            final position = positionByDeviceId[device.id];
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
                                      const Icon(Icons.videocam_outlined),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${device.name} (#${device.id})',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                      ),
                                      Chip(
                                        label: Text(device.status),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    position == null
                                        ? 'Sem posicao recente.'
                                        : 'Lat ${position.latitude.toStringAsFixed(5)} • Lon ${position.longitude.toStringAsFixed(5)}',
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      FilledButton.tonalIcon(
                                        onPressed: () {
                                          Navigator.of(context).pushNamed(
                                            AppRoutes.mdvrDevice(
                                                '${device.id}'),
                                          );
                                        },
                                        icon: const Icon(Icons.open_in_new),
                                        label: const Text('Detalhes'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          await Clipboard.setData(
                                            ClipboardData(
                                              text:
                                                  '${device.name} (#${device.id})',
                                            ),
                                          );
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Identificacao do dispositivo copiada.',
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.content_copy_outlined,
                                        ),
                                        label: const Text('Copiar ID'),
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
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Erro ao carregar posicoes: $error')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('Erro ao carregar dispositivos: $error')),
    );
  }
}
