import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/device_status.dart';
import '../../data/models.dart';
import '../../state/session_state.dart';
import '../../ui/module_scaffold.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key, this.onOpenVehicle});
  final ValueChanged<int>? onOpenVehicle;
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String filter = 'Todos';
  int? selectedId;
  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesProvider);
    final devices = devicesAsync.valueOrNull ?? const <TraccarDevice>[];
    final positions =
        ref.watch(positionsProvider).valueOrNull ?? const <TraccarPosition>[];
    final byId = {for (final p in positions) p.deviceId: p};
    bool matches(TraccarDevice d, String category) => switch (category) {
          'Online' => isDeviceOnline(d.status),
          'Offline' => isDeviceOffline(d.status),
          'Sem comunicação' => !byId.containsKey(d.id),
          _ => true
        };
    final visible = devices.where((d) => matches(d, filter)).toList();
    final selected = visible.where((d) => d.id == selectedId).firstOrNull;
    final attention = devices
        .where((d) => isDeviceOffline(d.status) || !byId.containsKey(d.id))
        .take(3)
        .toList();
    return ModuleScaffold(
      title: 'Visão geral',
      subtitle: 'Acompanhe os equipamentos e o que precisa de atenção.',
      navigation:
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const ModuleSectionLabel('Situação da frota'),
        for (final label in ['Todos', 'Online', 'Offline', 'Sem comunicação'])
          ModuleListItem(
              title: label,
              subtitle:
                  '${devices.where((d) => matches(d, label)).length} equipamentos',
              icon: switch (label) {
                'Online' => Icons.wifi_tethering,
                'Offline' => Icons.wifi_off,
                'Sem comunicação' => Icons.portable_wifi_off,
                _ => Icons.directions_car_filled_outlined
              },
              selected: filter == label,
              onTap: () => setState(() {
                    filter = label;
                    selectedId = null;
                  }))
      ]),
      content:
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ModuleSectionLabel(filter == 'Todos' ? 'Equipamentos' : filter),
        if (devicesAsync.isLoading)
          const LinearProgressIndicator()
        else if (devicesAsync.hasError)
          const ModuleEmpty('Não foi possível carregar a frota',
              'Tente novamente em instantes.')
        else if (visible.isEmpty)
          const ModuleEmpty('Nenhum equipamento neste grupo',
              'Escolha outro status para consultar os equipamentos.',
              icon: Icons.directions_car_filled_outlined)
        else
          for (final device in visible)
            ModuleListItem(
                title: device.name,
                subtitle: byId[device.id]?.address ??
                    'Última atualização: ${device.lastUpdate ?? 'não informada'}',
                icon: Icons.directions_car_filled_outlined,
                selected: selectedId == device.id,
                onTap: () => setState(() => selectedId = device.id),
                trailing: ModuleStatusChip(
                    isDeviceOnline(device.status) ? 'Online' : 'Offline',
                    tone: isDeviceOnline(device.status)
                        ? ModuleTone.success
                        : ModuleTone.neutral))
      ]),
      detail: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (selected != null)
          ModuleCard(
              title: selected.name,
              child: Column(children: [
                ModuleDetailRow('Status',
                    isDeviceOnline(selected.status) ? 'Online' : 'Offline'),
                ModuleDetailRow('Última posição',
                    byId[selected.id]?.fixTime ?? 'Não informada'),
                if (widget.onOpenVehicle != null)
                  TextButton(
                      onPressed: () => widget.onOpenVehicle!(selected.id),
                      child: const Text('Ver no mapa'))
              ])),
        const ModuleSectionLabel('Precisa de atenção'),
        if (attention.isEmpty)
          const ModuleEmpty('Nenhuma pendência disponível',
              'As ocorrências dos equipamentos aparecem aqui.',
              icon: Icons.notifications_none_rounded)
        else
          for (final device in attention)
            ModuleListItem(
                title: device.name,
                subtitle: byId.containsKey(device.id)
                    ? 'Equipamento offline'
                    : 'Sem posição recebida',
                icon: Icons.warning_amber_rounded,
                onTap: widget.onOpenVehicle == null
                    ? () => setState(() {
                          filter = 'Todos';
                          selectedId = device.id;
                        })
                    : () => widget.onOpenVehicle!(device.id)),
      ]),
      footerLabel: '${visible.length} equipamentos exibidos',
    );
  }
}
