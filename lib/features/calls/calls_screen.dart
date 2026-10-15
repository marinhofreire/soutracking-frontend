import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/bridge_client.dart';
import '../../ui/module_scaffold.dart';

/// Read-only assistance view. Uses the existing source; no dispatch is created.
class CallsScreen extends ConsumerStatefulWidget {
  const CallsScreen({super.key, this.onClose});
  final VoidCallback? onClose;
  @override
  ConsumerState<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends ConsumerState<CallsScreen> {
  String _status = 'todos';
  int? _selectedId;
  static const _labels = {
    'todos': 'Todos',
    'aguardando': 'Aguardando',
    'em_andamento': 'Em andamento',
    'finalizada': 'Finalizados',
    'cancelada': 'Cancelados'
  };
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(chamadosProvider);
    final records = data.valueOrNull?.os ?? const <ChamadoOs>[];
    final visible = records
        .where((r) => _status == 'todos' || r.status == _status)
        .toList();
    final selected = visible.where((r) => r.id == _selectedId).firstOrNull;
    return ModuleScaffold(
      title: 'Chamados',
      subtitle: 'Acompanhe as solicitações de assistência do SouFind.',
      navigation:
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const ModuleSectionLabel('Status'),
        for (final e in _labels.entries)
          ModuleListItem(
              title: e.value,
              subtitle:
                  '${records.where((r) => e.key == "todos" || r.status == e.key).length} chamados',
              selected: _status == e.key,
              onTap: () => setState(() => _status = e.key),
              icon: switch (e.key) {
                'aguardando' => Icons.hourglass_empty_rounded,
                'em_andamento' => Icons.directions_car_rounded,
                'finalizada' => Icons.check_circle_rounded,
                _ => Icons.receipt_long_rounded
              }),
      ]),
      content: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const ModuleEmpty(
            'Não foi possível carregar os chamados',
            'Tente atualizar a lista.'),
        data: (_) => visible.isEmpty
            ? const ModuleEmpty('Nenhum chamado neste grupo',
                'As solicitações de assistência aparecerão aqui.',
                icon: Icons.headset_mic_rounded)
            : Column(children: [
                for (final r in visible)
                  ModuleListItem(
                      title: r.bookingNumber.isEmpty
                          ? 'Chamado #${r.id}'
                          : r.bookingNumber,
                      subtitle: '${r.tipo} · ${r.origem}',
                      icon: Icons.headset_mic_rounded,
                      selected: r.id == _selectedId,
                      onTap: () => setState(() => _selectedId = r.id),
                      trailing: ModuleStatusChip(_labels[r.status] ?? r.status,
                          tone: r.status == 'finalizada'
                              ? ModuleTone.success
                              : r.status == 'aguardando'
                                  ? ModuleTone.warning
                                  : ModuleTone.neutral))
              ]),
      ),
      detail: selected == null
          ? const ModuleEmpty('Selecione um chamado',
              'O serviço, a origem e o parceiro aparecem aqui.')
          : ModuleCard(
              title: 'Resumo do chamado',
              child: Column(children: [
                ModuleDetailRow('Número', selected.bookingNumber),
                ModuleDetailRow('Serviço', selected.tipo),
                ModuleDetailRow(
                    'Status', _labels[selected.status] ?? selected.status),
                ModuleDetailRow('Origem', selected.origem),
                ModuleDetailRow('Destino', selected.destino),
                ModuleDetailRow(
                    'Parceiro', selected.parceiro ?? 'Não definido'),
                ModuleDetailRow('Valor',
                    'R\$ ${selected.valor.toStringAsFixed(2).replaceAll('.', ',')}'),
              ])),
      headerActions: [
        IconButton(
            tooltip: 'Atualizar',
            onPressed: () => ref.invalidate(chamadosProvider),
            icon: const Icon(Icons.refresh_rounded))
      ],
    );
  }
}
