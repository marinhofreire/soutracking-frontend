import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'assist_dispatch_state.dart';

class AssistVisualDashboardScreen extends ConsumerWidget {
  const AssistVisualDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(assistDispatchProvider);
    final requests = state.requests;
    final partners = state.partners;

    int countByStatus(AssistRequestStatus status) {
      return requests.where((item) => item.status == status).length;
    }

    final total = requests.length;
    final inProgress = countByStatus(AssistRequestStatus.emDeslocamento) +
        countByStatus(AssistRequestStatus.emAtendimento) +
        countByStatus(AssistRequestStatus.despachado);
    final waiting = countByStatus(AssistRequestStatus.aguardandoAceite);
    final done = countByStatus(AssistRequestStatus.finalizado);
    final onlinePartners = partners.where((partner) => partner.isOnline).length;
    final busyPartners = partners.where((partner) => partner.isBusy).length;

    Widget kpi(String label, String value, IconData icon) {
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

    Widget progress(String label, int value, Color color) {
      final ratio = total == 0 ? 0.0 : value / total;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: $value', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: ratio.clamp(0, 1),
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      );
    }

    return ListView(
      children: [
        Text(
          'Painel visual de assistencias',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            kpi('Total de chamados', '$total', Icons.assignment_outlined),
            const SizedBox(width: 10),
            kpi('Em andamento', '$inProgress', Icons.sync_outlined),
            const SizedBox(width: 10),
            kpi('Aguardando aceite', '$waiting', Icons.hourglass_top_outlined),
            const SizedBox(width: 10),
            kpi('Finalizados', '$done', Icons.task_alt_outlined),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            kpi('Parceiros online', '$onlinePartners', Icons.wifi_tethering),
            const SizedBox(width: 10),
            kpi('Parceiros ocupados', '$busyPartners', Icons.engineering),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Distribuicao operacional',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                progress('Abertos', countByStatus(AssistRequestStatus.aberto),
                    Colors.blueAccent),
                const SizedBox(height: 10),
                progress('Aguardando aceite', waiting, Colors.amber),
                const SizedBox(height: 10),
                progress('Em andamento', inProgress, Colors.orangeAccent),
                const SizedBox(height: 10),
                progress('Finalizados', done, Colors.greenAccent),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
