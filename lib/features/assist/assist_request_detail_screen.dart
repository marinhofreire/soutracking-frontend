import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'assist_dispatch_state.dart';

class AssistRequestDetailScreen extends ConsumerWidget {
  const AssistRequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(assistDispatchProvider);
    AssistRequest? request;
    for (final item in state.requests) {
      if (item.id == requestId) {
        request = item;
        break;
      }
    }

    if (request == null) {
      return const Card(
        child: Center(child: Text('Chamado não encontrado.')),
      );
    }
    final requestData = request;

    final notifier = ref.read(assistDispatchProvider.notifier);
    final partner = notifier.partnerById(requestData.assignedPartnerId);
    final offeredPartners = requestData.currentOfferPartnerIds
        .map((id) => notifier.partnerById(id))
        .whereType<AssistPartner>()
        .toList(growable: false);
    final routingOptions = notifier.routingOptionsForRequest(requestData);
    final statusLabel = assistStatusLabel(requestData.status);
    final priorityLabel = assistPriorityLabel(requestData.priority);
    final channelLabel = assistChannelLabel(requestData.channel);
    final splitLabel = assistSplitModeLabel(requestData.splitMode);
    final dispatchModeLabel = assistDispatchModeLabel(requestData.dispatchMode);
    final offerSecondsLeft = requestData.offerExpiresAt
        ?.difference(DateTime.now())
        .inSeconds
        .clamp(0, 9999);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Chamado #$requestId',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('Status: $statusLabel')),
                Chip(label: Text('Prioridade: $priorityLabel')),
                Chip(label: Text('Serviço: ${requestData.service}')),
                Chip(label: Text('Canal: $channelLabel')),
                Chip(label: Text('Perfil: $dispatchModeLabel')),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.person_pin_circle_outlined),
              title: Text(partner?.name ?? 'Sem parceiro alocado'),
              subtitle: Text(
                partner == null
                    ? 'Sem parceiro online para este tipo agora.'
                    : 'Distância: ${requestData.distanceKm?.toStringAsFixed(1) ?? '--'} km • ${partner.phone} • ⭐ ${partner.rating.toStringAsFixed(1)} • ETA ${requestData.estimatedArrivalMinutes ?? '--'} min',
              ),
            ),
            if (requestData.waitingAcceptance)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Oferta em andamento',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        offeredPartners.isEmpty
                            ? 'Oferta enviada para parceiros da rodada atual.'
                            : 'Parceiros ofertados: ${offeredPartners.map((item) => item.name).join(', ')}',
                      ),
                      if (offerSecondsLeft != null)
                        Text(
                            'Tempo restante para resposta: ${offerSecondsLeft}s'),
                      const SizedBox(height: 10),
                      ...requestData.currentOfferPartnerIds.map(
                        (partnerId) {
                          final roundPartner = notifier.partnerById(partnerId);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(roundPartner?.name ?? partnerId),
                                FilledButton.icon(
                                  onPressed: () {
                                    final result = notifier.acceptCurrentOffer(
                                      requestData.id,
                                      partnerId: partnerId,
                                    );
                                    if (!result.success && context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            result.message ??
                                                'Falha no aceite da oferta.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('Aceitar'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    final result = notifier.rejectCurrentOffer(
                                      requestData.id,
                                      partnerId: partnerId,
                                    );
                                    if (!result.success && context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            result.message ??
                                                'Falha na recusa da oferta.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.cancel_outlined),
                                  label: const Text('Recusar'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      TextButton.icon(
                        onPressed: () {
                          final result = notifier.expireCurrentOffer(
                            requestData.id,
                          );
                          if (!result.success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result.message ??
                                      'Falha ao expirar oferta atual.',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.timer_off_outlined),
                        label: const Text('Expirar parceiro líder da rodada'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: Text(
                'Serviço: R\$ ${requestData.serviceAmount.toStringAsFixed(2)} • Plataforma: R\$ ${requestData.platformFeeAmount.toStringAsFixed(2)}',
              ),
              subtitle: Text(
                'Repasse parceiro: R\$ ${requestData.partnerNetAmount.toStringAsFixed(2)} • $splitLabel',
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  'Cliente: ${requestData.customer}\n'
                  'Descrição: ${requestData.description.isEmpty ? 'Sem descrição' : requestData.description}\n'
                  'Origem: ${requestData.originLatitude.toStringAsFixed(5)}, ${requestData.originLongitude.toStringAsFixed(5)}\n'
                  'Destino: ${requestData.destinationLatitude.toStringAsFixed(5)}, ${requestData.destinationLongitude.toStringAsFixed(5)}\n'
                  'Região: ${requestData.regionKey} • Rota: ${requestData.routeDistanceKm.toStringAsFixed(1)} km\n\n'
                  'Preferidos: ${requestData.preferredPartnerIds.isEmpty ? 'nenhum' : requestData.preferredPartnerIds.join(', ')}\n'
                  'Política: ${requestData.preferredPartnersOnly ? 'somente preferidos' : 'preferidos primeiro, com fallback automático'}\n\n'
                  'Dossiê instalação: ${requestData.dossierReady ? 'completo' : 'pendente'}\n\n'
                  'Fluxo operacional:\n'
                  '1) Chamado criado\n'
                  '2) Oferta por rodada para parceiro mais próximo (com janela)\n'
                  '3) Aceite/recusa/timeout avança para próximo parceiro elegível\n'
                  '4) Com aceite, inicia execução e avança até finalização\n'
                  '5) Se necessário, redespacha para nova esteira de ofertas',
                ),
              ),
            ),
            if (requestData.installationChecklistRequired)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dossiê do veículo (instalação):',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    requestData.installationChecklist == null
                        ? 'Checklist ainda não registrado.'
                        : 'Fixação: ${requestData.installationChecklist!.fixacaoSegura ? 'OK' : 'Pendente'} • Chicote: ${requestData.installationChecklist!.chicoteProtegido ? 'OK' : 'Pendente'} • Elétrica: ${requestData.installationChecklist!.semInterferenciaEletrica ? 'OK' : 'Pendente'} • Comunicação: ${requestData.installationChecklist!.testeComunicacaoOk ? 'OK' : 'Pendente'}',
                  ),
                  const SizedBox(height: 4),
                  if (requestData.installationChecklist != null) ...[
                    Text(
                        'Foto local: ${requestData.installationChecklist!.fotoLocalInstalacao}'),
                    Text(
                        'Foto chicote: ${requestData.installationChecklist!.fotoChicote}'),
                    Text(
                        'Foto acabamento: ${requestData.installationChecklist!.fotoAcabamento}'),
                  ],
                  const SizedBox(height: 10),
                ],
              ),
            if (routingOptions.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Roteirização sugerida (proximidade):',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  ...routingOptions.map(
                    (option) => Text(
                      '• ${option.partner.name}${option.preferred ? ' (preferido)' : ''} — ${option.distanceKm.toStringAsFixed(1)} km • ETA ${option.etaMinutes} min',
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: requestData.status ==
                              AssistRequestStatus.finalizado ||
                          requestData.waitingAcceptance
                      ? null
                      : () {
                          final result = notifier.advanceStatus(requestData.id);
                          if (!result.advanced && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result.message ??
                                      'Não foi possível avançar o status.',
                                ),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.playlist_add_check_circle_outlined),
                  label: const Text('Avançar status'),
                ),
                OutlinedButton.icon(
                  onPressed: () => notifier.redispatchNearest(requestData.id),
                  icon: const Icon(Icons.radar_outlined),
                  label: const Text('Redespachar mais próximo'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
