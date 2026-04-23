import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_router.dart';
import 'assist_dispatch_state.dart';

class DemandControlPanelScreen extends ConsumerWidget {
  const DemandControlPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dispatchState = ref.watch(assistDispatchProvider);
    final requests = dispatchState.requests;

    int countByStatus(AssistRequestStatus status) {
      return requests.where((item) => item.status == status).length;
    }

    final openCount = countByStatus(AssistRequestStatus.aberto);
    final waitingCount = countByStatus(AssistRequestStatus.aguardandoAceite);
    final inServiceCount = countByStatus(AssistRequestStatus.emAtendimento) +
        countByStatus(AssistRequestStatus.emDeslocamento) +
        countByStatus(AssistRequestStatus.despachado);
    final doneCount = countByStatus(AssistRequestStatus.finalizado);

    Widget metricCard(String label, String value, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(label),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Painel de controle de demanda',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.assistCreate),
              icon: const Icon(Icons.add),
              label: const Text('Novo chamado'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.assistRequests),
              icon: const Icon(Icons.list_alt_outlined),
              label: const Text('Abrir fila completa'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            metricCard('Abertos', '$openCount', Icons.inbox_outlined),
            const SizedBox(width: 10),
            metricCard(
              'Aguardando aceite',
              '$waitingCount',
              Icons.hourglass_top_outlined,
            ),
            const SizedBox(width: 10),
            metricCard('Em execucao', '$inServiceCount', Icons.sync_outlined),
            const SizedBox(width: 10),
            metricCard('Finalizados', '$doneCount', Icons.task_alt_outlined),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            child: requests.isEmpty
                ? const Center(
                    child: Text('Nenhuma demanda ativa no momento.'),
                  )
                : ListView.separated(
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      final partner = ref
                          .read(assistDispatchProvider.notifier)
                          .partnerById(request.assignedPartnerId);
                      return ListTile(
                        leading: const Icon(Icons.support_agent_outlined),
                        title: Text('#${request.id} - ${request.service}'),
                        subtitle: Text(
                          '${request.customer} • ${assistStatusLabel(request.status)}\n'
                          '${partner?.name ?? 'Sem parceiro'} • '
                          'R\$ ${request.serviceAmount.toStringAsFixed(2)}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context)
                              .pushNamed(AppRoutes.assistRequest(request.id));
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
