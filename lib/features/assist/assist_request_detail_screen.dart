import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'assist_dispatch_state.dart';

const _kInk = Color(0xFF1F2A44);
const _kMuted = Color(0xFF60718D);
const _kLine = Color(0xFFDDE5F0);
const _kBlue = Color(0xFF176EEB);
const _kBg = Color(0xFFF7F9FD);

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
      return const _Section(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Chamado não encontrado.',
                style: TextStyle(color: _kMuted, fontWeight: FontWeight.w600)),
          ),
        ),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _kBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.assignment_outlined,
                    color: _kBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Chamado #$requestId',
                    style: const TextStyle(
                        color: _kInk,
                        fontWeight: FontWeight.w900,
                        fontSize: 18)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _statusChip(statusLabel, _statusColor(requestData.status)),
              _infoChip('Prioridade: $priorityLabel'),
              _infoChip('Serviço: ${requestData.service}'),
              _infoChip('Canal: $channelLabel'),
              _infoChip('Perfil: $dispatchModeLabel'),
            ],
          ),
          const SizedBox(height: 12),

          // ── Parceiro alocado ────────────────────────────────────────
          _Section(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _kBlue.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_pin_circle_outlined,
                        color: _kBlue, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(partner?.name ?? 'Sem parceiro alocado',
                            style: const TextStyle(
                                color: _kInk,
                                fontWeight: FontWeight.w800,
                                fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(
                          partner == null
                              ? 'Sem parceiro online para este tipo agora.'
                              : 'Distância: ${requestData.distanceKm?.toStringAsFixed(1) ?? '--'} km • ${partner.phone} • ⭐ ${partner.rating.toStringAsFixed(1)} • ETA ${requestData.estimatedArrivalMinutes ?? '--'} min',
                          style: const TextStyle(
                              color: _kMuted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Oferta em andamento ─────────────────────────────────────
          if (requestData.waitingAcceptance) ...[
            const SizedBox(height: 10),
            _Section(
              borderColor: const Color(0xFFF59E0B).withValues(alpha: 0.35),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Oferta em andamento',
                        icon: Icons.timer_outlined,
                        color: Color(0xFFF59E0B)),
                    const SizedBox(height: 8),
                    Text(
                      offeredPartners.isEmpty
                          ? 'Oferta enviada para parceiros da rodada atual.'
                          : 'Parceiros ofertados: ${offeredPartners.map((item) => item.name).join(', ')}',
                      style: const TextStyle(
                          color: _kMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600),
                    ),
                    if (offerSecondsLeft != null) ...[
                      const SizedBox(height: 4),
                      Text('Tempo restante para resposta: ${offerSecondsLeft}s',
                          style: const TextStyle(
                              color: Color(0xFFF59E0B),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800)),
                    ],
                    const SizedBox(height: 10),
                    ...requestData.currentOfferPartnerIds.map((partnerId) {
                      final roundPartner = notifier.partnerById(partnerId);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(roundPartner?.name ?? partnerId,
                                style: const TextStyle(
                                    color: _kInk,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                            FilledButton.icon(
                              onPressed: () {
                                final result = notifier.acceptCurrentOffer(
                                  requestData.id,
                                  partnerId: partnerId,
                                );
                                if (!result.success && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(result.message ??
                                          'Falha no aceite da oferta.'),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.check_circle_outline,
                                  size: 15),
                              label: const Text('Aceitar',
                                  style: TextStyle(fontSize: 12)),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                final result = notifier.rejectCurrentOffer(
                                  requestData.id,
                                  partnerId: partnerId,
                                );
                                if (!result.success && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(result.message ??
                                          'Falha na recusa da oferta.'),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.cancel_outlined, size: 15),
                              label: const Text('Recusar',
                                  style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                                side: const BorderSide(
                                    color: Color(0xFFEF4444)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: () {
                        final result =
                            notifier.expireCurrentOffer(requestData.id);
                        if (!result.success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result.message ??
                                  'Falha ao expirar oferta atual.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.timer_off_outlined, size: 15),
                      label: const Text('Expirar parceiro líder da rodada',
                          style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: _kMuted),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // ── Valores ─────────────────────────────────────────────────
          _Section(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.payments_outlined,
                        color: Color(0xFF16A34A), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Serviço: R\$ ${requestData.serviceAmount.toStringAsFixed(2)} • Plataforma: R\$ ${requestData.platformFeeAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: _kInk,
                              fontWeight: FontWeight.w800,
                              fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Repasse parceiro: R\$ ${requestData.partnerNetAmount.toStringAsFixed(2)} • $splitLabel',
                          style: const TextStyle(
                              color: _kMuted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Dados do chamado ────────────────────────────────────────
          _Section(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('Dados do chamado',
                      icon: Icons.description_outlined, color: _kBlue),
                  const SizedBox(height: 8),
                  _kv('Cliente', requestData.customer),
                  _kv(
                      'Descrição',
                      requestData.description.isEmpty
                          ? 'Sem descrição'
                          : requestData.description),
                  _kv('Origem',
                      '${requestData.originLatitude.toStringAsFixed(5)}, ${requestData.originLongitude.toStringAsFixed(5)}'),
                  _kv('Destino',
                      '${requestData.destinationLatitude.toStringAsFixed(5)}, ${requestData.destinationLongitude.toStringAsFixed(5)}'),
                  _kv('Região',
                      '${requestData.regionKey} • Rota: ${requestData.routeDistanceKm.toStringAsFixed(1)} km'),
                  const SizedBox(height: 8),
                  _kv(
                      'Preferidos',
                      requestData.preferredPartnerIds.isEmpty
                          ? 'nenhum'
                          : requestData.preferredPartnerIds.join(', ')),
                  _kv(
                      'Política',
                      requestData.preferredPartnersOnly
                          ? 'somente preferidos'
                          : 'preferidos primeiro, com fallback automático'),
                  const SizedBox(height: 8),
                  _kv('Dossiê instalação',
                      requestData.dossierReady ? 'completo' : 'pendente'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Fluxo operacional ───────────────────────────────────────
          _Section(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('Fluxo operacional',
                      icon: Icons.route_outlined, color: _kBlue),
                  const SizedBox(height: 8),
                  _step(1, 'Chamado criado'),
                  _step(2,
                      'Oferta por rodada para parceiro mais próximo (com janela)'),
                  _step(3,
                      'Aceite/recusa/timeout avança para próximo parceiro elegível'),
                  _step(4, 'Com aceite, inicia execução e avança até finalização'),
                  _step(5,
                      'Se necessário, redespacha para nova esteira de ofertas'),
                ],
              ),
            ),
          ),

          // ── Checklist de instalação ─────────────────────────────────
          if (requestData.installationChecklistRequired) ...[
            const SizedBox(height: 10),
            _Section(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Dossiê do veículo (instalação)',
                        icon: Icons.fact_check_outlined, color: _kBlue),
                    const SizedBox(height: 8),
                    if (requestData.installationChecklist == null)
                      const Text('Checklist ainda não registrado.',
                          style: TextStyle(
                              color: _kMuted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600))
                    else ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _checkChip('Fixação',
                              requestData.installationChecklist!.fixacaoSegura),
                          _checkChip(
                              'Chicote',
                              requestData
                                  .installationChecklist!.chicoteProtegido),
                          _checkChip(
                              'Elétrica',
                              requestData.installationChecklist!
                                  .semInterferenciaEletrica),
                          _checkChip(
                              'Comunicação',
                              requestData
                                  .installationChecklist!.testeComunicacaoOk),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _kv('Foto local',
                          requestData.installationChecklist!.fotoLocalInstalacao),
                      _kv('Foto chicote',
                          requestData.installationChecklist!.fotoChicote),
                      _kv('Foto acabamento',
                          requestData.installationChecklist!.fotoAcabamento),
                    ],
                  ],
                ),
              ),
            ),
          ],

          // ── Roteirização sugerida ───────────────────────────────────
          if (routingOptions.isNotEmpty) ...[
            const SizedBox(height: 10),
            _Section(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Roteirização sugerida (proximidade)',
                        icon: Icons.alt_route_rounded, color: _kBlue),
                    const SizedBox(height: 8),
                    ...routingOptions.map(
                      (option) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.circle,
                                  size: 5, color: _kMuted),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${option.partner.name}${option.preferred ? ' (preferido)' : ''} — ${option.distanceKm.toStringAsFixed(1)} km • ETA ${option.etaMinutes} min',
                                style: const TextStyle(
                                    color: _kInk,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // ── Ações ───────────────────────────────────────────────────
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: requestData.status == AssistRequestStatus.finalizado ||
                        requestData.waitingAcceptance
                    ? null
                    : () {
                        final result = notifier.advanceStatus(requestData.id);
                        if (!result.advanced && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result.message ??
                                  'Não foi possível avançar o status.'),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.playlist_add_check_circle_outlined,
                    size: 16),
                label: const Text('Avançar status',
                    style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  backgroundColor: _kBlue,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => notifier.redispatchNearest(requestData.id),
                icon: const Icon(Icons.radar_outlined, size: 16),
                label: const Text('Redespachar mais próximo',
                    style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kMuted,
                  side: const BorderSide(color: _kLine),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                  color: _kMuted, fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                  color: _kInk, fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _kBlue.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text('$number',
                style: const TextStyle(
                    color: _kBlue, fontSize: 10, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: _kInk, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _checkChip(String label, bool ok) {
    final color = ok ? const Color(0xFF16A34A) : const Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.check_circle : Icons.pending_outlined,
              size: 12, color: color),
          const SizedBox(width: 4),
          Text('$label: ${ok ? 'OK' : 'Pendente'}',
              style: TextStyle(
                  color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _infoChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kLine),
      ),
      child: Text(label,
          style: const TextStyle(
              color: _kMuted, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }

  Color _statusColor(AssistRequestStatus status) {
    return switch (status) {
      AssistRequestStatus.aberto => const Color(0xFF9DB1CC),
      AssistRequestStatus.aguardandoAceite => const Color(0xFFF59E0B),
      AssistRequestStatus.despachado => _kBlue,
      AssistRequestStatus.emDeslocamento => const Color(0xFF7C3AED),
      AssistRequestStatus.emAtendimento => const Color(0xFF0EA5E9),
      AssistRequestStatus.finalizado => const Color(0xFF16A34A),
    };
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child, this.borderColor});
  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? _kLine),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {required this.icon, required this.color});
  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                color: _kInk, fontWeight: FontWeight.w800, fontSize: 12.5)),
      ],
    );
  }
}
