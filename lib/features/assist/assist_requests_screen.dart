import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_router.dart';
import 'assist_dispatch_state.dart';

class AssistRequestsScreen extends ConsumerWidget {
  const AssistRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dispatchState = ref.watch(assistDispatchProvider);
    final requests = dispatchState.requests;
    final activeCount = requests
        .where((request) => request.status != AssistRequestStatus.finalizado)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Demandas',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.assistCreate),
              icon: const Icon(Icons.add),
              label: const Text('Criar chamado'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Ativos agora: $activeCount • Despacho por parceiro mais próximo',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            child: requests.isEmpty
                ? const Center(child: Text('Nenhum chamado criado ainda.'))
                : ListView.separated(
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      final partner = ref
                          .read(assistDispatchProvider.notifier)
                          .partnerById(request.assignedPartnerId);
                      final status = assistStatusLabel(request.status);
                      final channel = assistChannelLabel(request.channel);
                      final split = assistSplitModeLabel(request.splitMode);
                      final dispatchMode =
                          assistDispatchModeLabel(request.dispatchMode);
                      final offeredPartner = ref
                          .read(assistDispatchProvider.notifier)
                          .partnerById(request.currentOfferPartnerId);
                      final offeredNames = request.currentOfferPartnerIds
                          .map(
                            (id) => ref
                                .read(assistDispatchProvider.notifier)
                                .partnerById(id)
                                ?.name,
                          )
                          .whereType<String>()
                          .toList(growable: false);
                      final distanceText = request.distanceKm == null
                          ? 'Sem parceiro próximo disponível'
                          : '${request.distanceKm!.toStringAsFixed(1)} km do parceiro';
                      final etaText = request.estimatedArrivalMinutes == null
                          ? 'ETA --'
                          : 'ETA ${request.estimatedArrivalMinutes} min';
                      final offerText = request.waitingAcceptance
                          ? '\nRodada ativa: ${request.currentOfferPartnerIds.length} parceiro(s) • líder ${offeredPartner?.name ?? request.currentOfferPartnerId ?? 'parceiro'} • expira em ${request.offerExpiresAt == null ? '--' : request.offerExpiresAt!.difference(DateTime.now()).inSeconds.clamp(0, 9999)}s${offeredNames.isEmpty ? '' : '\nOfertados: ${offeredNames.join(', ')}'}'
                          : '';

                      return ListTile(
                        leading: const Icon(Icons.support_agent_outlined),
                        title: Text('#${request.id} - ${request.service}'),
                        subtitle: Text(
                          'Status: $status • Canal: $channel • Perfil: $dispatchMode\n${request.customer}\n${partner?.name ?? 'Aguardando parceiro'} • $distanceText • $etaText$offerText\nRota: ${request.routeDistanceKm.toStringAsFixed(1)} km • Serviço: R\$ ${request.serviceAmount.toStringAsFixed(2)} • Plataforma: R\$ ${request.platformFeeAmount.toStringAsFixed(2)} • $split',
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
