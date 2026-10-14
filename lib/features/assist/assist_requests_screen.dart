import '../../core/operational_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_router.dart';
import 'assist_dispatch_state.dart';
import 'assist_request_list_card.dart';

class AssistRequestsScreen extends ConsumerWidget {
  const AssistRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => OperationalPanel(
        child: Builder(builder: (context) => _buildContents(context, ref)),
      );

  Widget _buildContents(BuildContext context, WidgetRef ref) {
    final dispatchState = ref.watch(assistDispatchProvider);
    final requests = dispatchState.requests;
    final activeCount = requests
        .where((request) => request.status != AssistRequestStatus.finalizado)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Demandas',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 7),
                Wrap(
                    spacing: 9,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                              color: const Color(0xFFEDF4FF),
                              borderRadius: BorderRadius.circular(5)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                    color: Color(0xFF176EEB),
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            Text('$activeCount ativos agora',
                                style: const TextStyle(
                                    fontSize: 10, color: Color(0xFF176EEB))),
                          ])),
                      const Text('Despacho por parceiro mais próximo',
                          style: TextStyle(
                              fontSize: 10, color: Color(0xFF71849F))),
                    ]),
              ])),
          const SizedBox(width: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              fixedSize: const Size.fromHeight(33),
              visualDensity: VisualDensity.standard,
            ),
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.assistCreate),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Criar chamado'),
          ),
        ]),
        const SizedBox(height: 14),
        Expanded(
            child: requests.isEmpty
                ? const Center(child: Text('Nenhum chamado criado ainda.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(1, 1, 2, 8),
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
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

                      return AssistRequestListCard(
                        request: request,
                        partnerName: partner?.name ?? 'Aguardando parceiro',
                        status: status,
                        channel: channel,
                        profile: dispatchMode,
                        split: split,
                        distance: distanceText,
                        eta: etaText,
                        offerText: offerText,
                        onTap: () => Navigator.of(context)
                            .pushNamed(AppRoutes.assistRequest(request.id)),
                      );
                    },
                  )),
      ],
    );
  }
}
