import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/traccar_client.dart';
import '../../state/session_state.dart';
import 'assist_demand_api_service.dart';

enum AssistPriority { baixa, media, alta, critica }

enum AssistChannel { app, zpro, manual }

enum AssistRequestStatus {
  aberto,
  aguardandoAceite,
  despachado,
  emDeslocamento,
  emAtendimento,
  finalizado,
}

enum AssistSplitMode { automatico, manual }

enum AssistDispatchMode { agressivo, equilibrado, tranquilo }

class AssistPartner {
  const AssistPartner({
    required this.id,
    required this.name,
    required this.phone,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.services,
    required this.isOnline,
    required this.isBusy,
  });

  final String id;
  final String name;
  final String phone;
  final double latitude;
  final double longitude;
  final double rating;
  final List<String> services;
  final bool isOnline;
  final bool isBusy;

  AssistPartner copyWith({
    bool? isBusy,
    bool? isOnline,
  }) {
    return AssistPartner(
      id: id,
      name: name,
      phone: phone,
      latitude: latitude,
      longitude: longitude,
      rating: rating,
      services: services,
      isOnline: isOnline ?? this.isOnline,
      isBusy: isBusy ?? this.isBusy,
    );
  }
}

class DemandPricingRule {
  const DemandPricingRule({
    required this.regionKey,
    required this.service,
    required this.basePrice,
    required this.perKmPrice,
  });

  final String regionKey;
  final String service;
  final double basePrice;
  final double perKmPrice;
}

class AssistInstallationChecklist {
  const AssistInstallationChecklist({
    required this.fixacaoSegura,
    required this.chicoteProtegido,
    required this.semInterferenciaEletrica,
    required this.testeComunicacaoOk,
    required this.fotoLocalInstalacao,
    required this.fotoChicote,
    required this.fotoAcabamento,
    this.observacoes,
  });

  final bool fixacaoSegura;
  final bool chicoteProtegido;
  final bool semInterferenciaEletrica;
  final bool testeComunicacaoOk;
  final String fotoLocalInstalacao;
  final String fotoChicote;
  final String fotoAcabamento;
  final String? observacoes;

  bool get isComplete {
    return fixacaoSegura &&
        chicoteProtegido &&
        semInterferenciaEletrica &&
        testeComunicacaoOk &&
        fotoLocalInstalacao.trim().isNotEmpty &&
        fotoChicote.trim().isNotEmpty &&
        fotoAcabamento.trim().isNotEmpty;
  }
}

class AssistRequest {
  const AssistRequest({
    required this.id,
    required this.customer,
    required this.service,
    required this.priority,
    required this.description,
    required this.originLatitude,
    required this.originLongitude,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.regionKey,
    required this.createdAt,
    required this.status,
    required this.channel,
    required this.serviceAmount,
    required this.platformFeePercent,
    required this.splitMode,
    required this.dispatchMode,
    required this.installationChecklistRequired,
    required this.routeDistanceKm,
    required this.preferredPartnerIds,
    required this.preferredPartnersOnly,
    required this.offeredPartnerIds,
    required this.currentOfferPartnerIds,
    required this.dispatchTimeline,
    this.assignedPartnerId,
    this.distanceKm,
    this.estimatedArrivalMinutes,
    this.currentOfferPartnerId,
    this.offerExpiresAt,
    this.installationChecklist,
  });

  final String id;
  final String customer;
  final String service;
  final AssistPriority priority;
  final String description;
  final double originLatitude;
  final double originLongitude;
  final double destinationLatitude;
  final double destinationLongitude;
  final String regionKey;
  final DateTime createdAt;
  final AssistRequestStatus status;
  final AssistChannel channel;
  final double serviceAmount;
  final double platformFeePercent;
  final AssistSplitMode splitMode;
  final AssistDispatchMode dispatchMode;
  final bool installationChecklistRequired;
  final double routeDistanceKm;
  final List<String> preferredPartnerIds;
  final bool preferredPartnersOnly;
  final List<String> offeredPartnerIds;
  final List<String> currentOfferPartnerIds;
  final List<String> dispatchTimeline;
  final String? assignedPartnerId;
  final double? distanceKm;
  final int? estimatedArrivalMinutes;
  final String? currentOfferPartnerId;
  final DateTime? offerExpiresAt;
  final AssistInstallationChecklist? installationChecklist;

  bool get waitingAcceptance {
    return status == AssistRequestStatus.aguardandoAceite &&
        currentOfferPartnerIds.isNotEmpty;
  }

  bool get dossierReady {
    if (!installationChecklistRequired) {
      return true;
    }
    return installationChecklist?.isComplete == true;
  }

  double get platformFeeAmount => serviceAmount * (platformFeePercent / 100);

  double get partnerNetAmount => serviceAmount - platformFeeAmount;

  AssistRequest copyWith({
    AssistRequestStatus? status,
    String? assignedPartnerId,
    double? distanceKm,
    int? estimatedArrivalMinutes,
    AssistChannel? channel,
    double? serviceAmount,
    double? platformFeePercent,
    AssistSplitMode? splitMode,
    AssistDispatchMode? dispatchMode,
    bool? installationChecklistRequired,
    AssistInstallationChecklist? installationChecklist,
    List<String>? preferredPartnerIds,
    bool? preferredPartnersOnly,
    List<String>? offeredPartnerIds,
    List<String>? currentOfferPartnerIds,
    List<String>? dispatchTimeline,
    String? currentOfferPartnerId,
    DateTime? offerExpiresAt,
    bool clearCurrentOffer = false,
  }) {
    return AssistRequest(
      id: id,
      customer: customer,
      service: service,
      priority: priority,
      description: description,
      originLatitude: originLatitude,
      originLongitude: originLongitude,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
      regionKey: regionKey,
      createdAt: createdAt,
      status: status ?? this.status,
      channel: channel ?? this.channel,
      serviceAmount: serviceAmount ?? this.serviceAmount,
      platformFeePercent: platformFeePercent ?? this.platformFeePercent,
      splitMode: splitMode ?? this.splitMode,
      dispatchMode: dispatchMode ?? this.dispatchMode,
      installationChecklistRequired:
          installationChecklistRequired ?? this.installationChecklistRequired,
      routeDistanceKm: routeDistanceKm,
      preferredPartnerIds: preferredPartnerIds ?? this.preferredPartnerIds,
      preferredPartnersOnly:
          preferredPartnersOnly ?? this.preferredPartnersOnly,
      offeredPartnerIds: offeredPartnerIds ?? this.offeredPartnerIds,
      dispatchTimeline: dispatchTimeline ?? this.dispatchTimeline,
      assignedPartnerId: assignedPartnerId ?? this.assignedPartnerId,
      distanceKm: distanceKm ?? this.distanceKm,
      estimatedArrivalMinutes:
          estimatedArrivalMinutes ?? this.estimatedArrivalMinutes,
      currentOfferPartnerId: clearCurrentOffer
          ? null
          : (currentOfferPartnerId ?? this.currentOfferPartnerId),
      currentOfferPartnerIds: clearCurrentOffer
          ? const []
          : (currentOfferPartnerIds ?? this.currentOfferPartnerIds),
      offerExpiresAt:
          clearCurrentOffer ? null : (offerExpiresAt ?? this.offerExpiresAt),
      installationChecklist:
          installationChecklist ?? this.installationChecklist,
    );
  }
}

class AssistDispatchState {
  const AssistDispatchState({
    required this.partners,
    required this.requests,
  });

  final List<AssistPartner> partners;
  final List<AssistRequest> requests;

  AssistDispatchState copyWith({
    List<AssistPartner>? partners,
    List<AssistRequest>? requests,
  }) {
    return AssistDispatchState(
      partners: partners ?? this.partners,
      requests: requests ?? this.requests,
    );
  }
}

class AssistDispatchController extends StateNotifier<AssistDispatchState> {
  AssistDispatchController({
    required Ref ref,
    required TraccarClient client,
  })  : _ref = ref,
        _apiService = AssistDemandApiService(client: client),
        super(
          AssistDispatchState(
            partners: _seedPartners,
            requests: _seedRequests,
          ),
        ) {
    unawaited(_bootstrapFromApi());
  }

  final Ref _ref;
  final AssistDemandApiService _apiService;

  static const int _equilibradoOfferWindowSeconds = 20;
  static const int _equilibradoOfferFanoutPerRound = 3;

  Future<void> _bootstrapFromApi() async {
    final session = _ref.read(sessionProvider);
    final remote = await _apiService.fetchRequests(session: session);
    if (remote == null) {
      return;
    }
    state = state.copyWith(requests: remote);
  }

  Future<void> reloadFromApi() async {
    await _bootstrapFromApi();
  }

  void _syncRequest(String requestId) {
    final request = _requestById(requestId);
    if (request == null) {
      return;
    }
    final session = _ref.read(sessionProvider);
    unawaited(_apiService.upsertRequest(session: session, request: request));
  }

  void _syncSnapshot() {
    final session = _ref.read(sessionProvider);
    unawaited(
      _apiService.syncSnapshot(
        session: session,
        requests: state.requests,
      ),
    );
  }

  double estimateServiceAmount({
    required String regionKey,
    required String service,
    required double routeDistanceKm,
  }) {
    final rule = _findPricingRule(regionKey: regionKey, service: service);
    if (rule == null) {
      return max(60, routeDistanceKm * 8);
    }
    return rule.basePrice + (routeDistanceKm * rule.perKmPrice);
  }

  AssistRequest createRequest({
    required String customer,
    required String service,
    required AssistPriority priority,
    required String description,
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    required String regionKey,
    required double platformFeePercent,
    required AssistSplitMode splitMode,
    AssistDispatchMode dispatchMode = AssistDispatchMode.equilibrado,
    double? serviceAmountOverride,
    AssistChannel channel = AssistChannel.app,
    AssistInstallationChecklist? installationChecklist,
    List<String> preferredPartnerIds = const [],
    bool preferredPartnersOnly = false,
  }) {
    final needsChecklist = demandServiceRequiresInstallationChecklist(service);
    if (needsChecklist &&
        (installationChecklist == null || !installationChecklist.isComplete)) {
      throw ArgumentError(
        'Checklist de instalação com fotos é obrigatório para este serviço.',
      );
    }

    if (platformFeePercent < 0 || platformFeePercent > 100) {
      throw ArgumentError('Taxa da plataforma deve estar entre 0 e 100.');
    }

    final routeDistanceKm = _distanceKm(
      originLatitude,
      originLongitude,
      destinationLatitude,
      destinationLongitude,
    );

    final serviceAmount = serviceAmountOverride ??
        estimateServiceAmount(
          regionKey: regionKey,
          service: service,
          routeDistanceKm: routeDistanceKm,
        );

    if (serviceAmount <= 0) {
      throw ArgumentError('Valor do serviço deve ser maior que zero.');
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final request = AssistRequest(
      id: id,
      customer: customer,
      service: service,
      priority: priority,
      description: description,
      originLatitude: originLatitude,
      originLongitude: originLongitude,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
      regionKey: regionKey,
      createdAt: DateTime.now(),
      channel: channel,
      serviceAmount: serviceAmount,
      platformFeePercent: platformFeePercent,
      splitMode: splitMode,
      dispatchMode: dispatchMode,
      installationChecklistRequired: needsChecklist,
      installationChecklist: installationChecklist,
      routeDistanceKm: routeDistanceKm,
      preferredPartnerIds: preferredPartnerIds,
      preferredPartnersOnly: preferredPartnersOnly,
      offeredPartnerIds: const [],
      currentOfferPartnerIds: const [],
      dispatchTimeline: const ['Chamado criado.'],
      status: AssistRequestStatus.aberto,
    );

    state = state.copyWith(requests: [request, ...state.requests]);
    final dispatched = dispatchNextOffer(request.id) ?? request;
    _syncRequest(dispatched.id);
    return dispatched;
  }

  AssistRequest? dispatchNextOffer(String requestId) {
    var currentRequest = _requestById(requestId);
    if (currentRequest == null) {
      return null;
    }

    if (currentRequest.assignedPartnerId != null &&
        currentRequest.status != AssistRequestStatus.finalizado) {
      return currentRequest;
    }

    final selected = _selectPartnersForRound(
      service: currentRequest.service,
      originLatitude: currentRequest.originLatitude,
      originLongitude: currentRequest.originLongitude,
      preferredPartnerIds: currentRequest.preferredPartnerIds,
      preferredPartnersOnly: currentRequest.preferredPartnersOnly,
      excludedPartnerIds: currentRequest.offeredPartnerIds,
    );

    if (selected.isEmpty) {
      currentRequest = _replaceRequest(
        currentRequest.copyWith(
          status: AssistRequestStatus.aberto,
          clearCurrentOffer: true,
          currentOfferPartnerIds: const [],
          dispatchTimeline: [
            ...currentRequest.dispatchTimeline,
            'Sem parceiros disponíveis no momento. Chamado em fila aberta.',
          ],
        ),
      );
      _syncRequest(currentRequest.id);
      return currentRequest;
    }

    final fanout = _fanoutForMode(currentRequest.dispatchMode);
    final offerWindowSeconds =
        _offerWindowSecondsForMode(currentRequest.dispatchMode);

    final selectedRound = selected.take(fanout).toList(growable: false);

    final offerExpires = DateTime.now().add(
      Duration(seconds: offerWindowSeconds),
    );

    currentRequest = _replaceRequest(
      currentRequest.copyWith(
        status: AssistRequestStatus.aguardandoAceite,
        currentOfferPartnerId: selectedRound.first.partner.id,
        currentOfferPartnerIds: selectedRound
            .map((item) => item.partner.id)
            .toList(growable: false),
        offerExpiresAt: offerExpires,
        offeredPartnerIds: [
          ...currentRequest.offeredPartnerIds,
          ...selectedRound.map((item) => item.partner.id),
        ],
        dispatchTimeline: [
          ...currentRequest.dispatchTimeline,
          'Rodada ${assistDispatchModeLabel(currentRequest.dispatchMode)} enviada para ${selectedRound.map((item) => item.partner.name).join(', ')} (janela ${offerWindowSeconds}s).',
        ],
      ),
    );

    _syncRequest(currentRequest.id);

    return currentRequest;
  }

  AssistActionResult acceptCurrentOffer(String requestId, {String? partnerId}) {
    final request = _requestById(requestId);
    if (request == null) {
      return const AssistActionResult(
          success: false, message: 'Chamado não encontrado.');
    }

    final selectedPartnerId = partnerId ??
        request.currentOfferPartnerId ??
        (request.currentOfferPartnerIds.isEmpty
            ? null
            : request.currentOfferPartnerIds.first);
    if (selectedPartnerId == null) {
      return const AssistActionResult(
          success: false, message: 'Não há oferta ativa para aceite.');
    }

    if (!request.currentOfferPartnerIds.contains(selectedPartnerId)) {
      return const AssistActionResult(
        success: false,
        message: 'Este parceiro não está na rodada ativa de ofertas.',
      );
    }

    final partner = partnerById(selectedPartnerId);
    if (partner == null) {
      return const AssistActionResult(
          success: false, message: 'Parceiro da oferta não encontrado.');
    }

    final distanceKm = _distanceKm(
      request.originLatitude,
      request.originLongitude,
      partner.latitude,
      partner.longitude,
    );

    final updatedRequest = request.copyWith(
      status: AssistRequestStatus.despachado,
      assignedPartnerId: selectedPartnerId,
      distanceKm: distanceKm,
      estimatedArrivalMinutes: _estimateEtaMinutes(distanceKm: distanceKm),
      clearCurrentOffer: true,
      currentOfferPartnerIds: const [],
      dispatchTimeline: [
        ...request.dispatchTimeline,
        '${partner.name} aceitou a oferta e foi despachado.',
      ],
    );

    _replaceRequest(updatedRequest);
    state = state.copyWith(
      partners: _setPartnerBusy(
        partners: state.partners,
        partnerId: selectedPartnerId,
        isBusy: true,
      ),
    );
    _syncRequest(updatedRequest.id);

    return const AssistActionResult(success: true);
  }

  AssistActionResult rejectCurrentOffer(String requestId, {String? partnerId}) {
    final request = _requestById(requestId);
    if (request == null) {
      return const AssistActionResult(
          success: false, message: 'Chamado não encontrado.');
    }

    final selectedPartnerId = partnerId ??
        request.currentOfferPartnerId ??
        (request.currentOfferPartnerIds.isEmpty
            ? null
            : request.currentOfferPartnerIds.first);
    if (selectedPartnerId == null) {
      return const AssistActionResult(
          success: false, message: 'Não há oferta ativa para recusa.');
    }

    if (!request.currentOfferPartnerIds.contains(selectedPartnerId)) {
      return const AssistActionResult(
        success: false,
        message: 'Este parceiro não está na rodada ativa de ofertas.',
      );
    }

    final remainingRound = request.currentOfferPartnerIds
        .where((id) => id != selectedPartnerId)
        .toList(growable: false);
    final partner = partnerById(selectedPartnerId);
    final rejectedRequest = request.copyWith(
      status: remainingRound.isEmpty
          ? AssistRequestStatus.aberto
          : AssistRequestStatus.aguardandoAceite,
      currentOfferPartnerId:
          remainingRound.isEmpty ? null : remainingRound.first,
      currentOfferPartnerIds: remainingRound,
      offerExpiresAt: remainingRound.isEmpty ? null : request.offerExpiresAt,
      dispatchTimeline: [
        ...request.dispatchTimeline,
        '${partner?.name ?? 'Parceiro'} recusou a oferta.',
      ],
    );

    _replaceRequest(rejectedRequest);
    if (remainingRound.isEmpty) {
      dispatchNextOffer(requestId);
    } else {
      _syncRequest(requestId);
    }
    return const AssistActionResult(success: true);
  }

  AssistActionResult expireCurrentOffer(String requestId, {String? partnerId}) {
    final request = _requestById(requestId);
    if (request == null) {
      return const AssistActionResult(
          success: false, message: 'Chamado não encontrado.');
    }

    if (request.currentOfferPartnerIds.isEmpty) {
      return const AssistActionResult(
          success: false, message: 'Não há oferta ativa para expirar.');
    }

    final selectedPartnerId = partnerId ??
        request.currentOfferPartnerId ??
        request.currentOfferPartnerIds.first;
    if (!request.currentOfferPartnerIds.contains(selectedPartnerId)) {
      return const AssistActionResult(
        success: false,
        message: 'Este parceiro não está na rodada ativa de ofertas.',
      );
    }

    final remainingRound = request.currentOfferPartnerIds
        .where((id) => id != selectedPartnerId)
        .toList(growable: false);
    final partner = partnerById(selectedPartnerId);
    final expiredRequest = request.copyWith(
      status: remainingRound.isEmpty
          ? AssistRequestStatus.aberto
          : AssistRequestStatus.aguardandoAceite,
      currentOfferPartnerId:
          remainingRound.isEmpty ? null : remainingRound.first,
      currentOfferPartnerIds: remainingRound,
      offerExpiresAt: remainingRound.isEmpty ? null : request.offerExpiresAt,
      dispatchTimeline: [
        ...request.dispatchTimeline,
        'Oferta para ${partner?.name ?? 'parceiro'} expirou sem resposta.',
      ],
    );

    _replaceRequest(expiredRequest);
    if (remainingRound.isEmpty) {
      dispatchNextOffer(requestId);
    } else {
      _syncRequest(requestId);
    }
    return const AssistActionResult(success: true);
  }

  int processOfferTimeouts() {
    var count = 0;
    final now = DateTime.now();
    for (final request in state.requests) {
      if (request.waitingAcceptance &&
          request.offerExpiresAt != null &&
          now.isAfter(request.offerExpiresAt!)) {
        for (final partnerId in request.currentOfferPartnerIds) {
          expireCurrentOffer(request.id, partnerId: partnerId);
        }
        count += 1;
      }
    }
    return count;
  }

  AssistAdvanceStatusResult advanceStatus(String requestId) {
    AssistAdvanceStatusResult result = const AssistAdvanceStatusResult(
      advanced: false,
      message: 'Chamado não encontrado.',
    );

    List<AssistPartner> nextPartners = state.partners;

    final updated = state.requests.map((request) {
      if (request.id != requestId) return request;

      final nextStatus = _nextStatus(request.status);
      final needsChecklistToFinish =
          nextStatus == AssistRequestStatus.finalizado &&
              request.installationChecklistRequired &&
              !request.dossierReady;

      if (needsChecklistToFinish) {
        result = const AssistAdvanceStatusResult(
          advanced: false,
          message:
              'Finalize o checklist obrigatório de instalação com fotos para encerrar o serviço.',
        );
        return request;
      }

      if (nextStatus == AssistRequestStatus.finalizado &&
          request.assignedPartnerId != null) {
        nextPartners = _setPartnerBusy(
          partners: nextPartners,
          partnerId: request.assignedPartnerId!,
          isBusy: false,
        );
      }

      result = const AssistAdvanceStatusResult(advanced: true);
      return request.copyWith(
        status: nextStatus,
        dispatchTimeline: [
          ...request.dispatchTimeline,
          'Status alterado para ${assistStatusLabel(nextStatus)}.',
        ],
      );
    }).toList();

    state = state.copyWith(partners: nextPartners, requests: updated);
    _syncRequest(requestId);
    return result;
  }

  void redispatchNearest(String requestId) {
    List<AssistPartner> nextPartners = state.partners;

    final updated = state.requests.map((request) {
      if (request.id != requestId) return request;

      if (request.assignedPartnerId != null) {
        nextPartners = _setPartnerBusy(
          partners: nextPartners,
          partnerId: request.assignedPartnerId!,
          isBusy: false,
        );
      }

      return request.copyWith(
        status: AssistRequestStatus.aberto,
        assignedPartnerId: null,
        distanceKm: null,
        estimatedArrivalMinutes: null,
        clearCurrentOffer: true,
        currentOfferPartnerIds: const [],
        dispatchTimeline: [
          ...request.dispatchTimeline,
          'Redespacho solicitado. Reiniciando esteira de ofertas.',
        ],
      );
    }).toList();

    state = state.copyWith(partners: nextPartners, requests: updated);
    dispatchNextOffer(requestId);
    _syncRequest(requestId);
  }

  AssistPartner? partnerById(String? partnerId) {
    if (partnerId == null) return null;
    for (final partner in state.partners) {
      if (partner.id == partnerId) return partner;
    }
    return null;
  }

  List<AssistPartnerRouteOption> routingOptionsForRequest(AssistRequest request,
      {int limit = 3}) {
    final candidates = <AssistPartnerRouteOption>[];
    for (final partner in state.partners) {
      if (!partner.isOnline || partner.isBusy) {
        continue;
      }
      final supportsService = partner.services
          .map((item) => item.toLowerCase())
          .contains(request.service.toLowerCase());
      if (!supportsService) {
        continue;
      }
      final distanceKm = _distanceKm(
        request.originLatitude,
        request.originLongitude,
        partner.latitude,
        partner.longitude,
      );
      final etaMinutes = _estimateEtaMinutes(distanceKm: distanceKm);
      final preferred = request.preferredPartnerIds.contains(partner.id);
      candidates.add(
        AssistPartnerRouteOption(
          partner: partner,
          distanceKm: distanceKm,
          etaMinutes: etaMinutes,
          preferred: preferred,
        ),
      );
    }

    candidates.sort((a, b) {
      if (a.preferred != b.preferred) {
        return a.preferred ? -1 : 1;
      }
      return a.distanceKm.compareTo(b.distanceKm);
    });
    return candidates.take(limit).toList();
  }

  List<_SelectedPartner> _selectPartnersForRound({
    required String service,
    required double originLatitude,
    required double originLongitude,
    required List<String> preferredPartnerIds,
    required bool preferredPartnersOnly,
    List<AssistPartner>? partnersBase,
    List<String> excludedPartnerIds = const [],
  }) {
    final source = partnersBase ?? state.partners;
    final available = source.where((partner) {
      if (!partner.isOnline || partner.isBusy) {
        return false;
      }
      if (excludedPartnerIds.contains(partner.id)) {
        return false;
      }
      return partner.services
          .map((item) => item.toLowerCase())
          .contains(service.toLowerCase());
    }).toList();

    if (available.isEmpty) return const [];

    final preferredAvailable = available
        .where((partner) => preferredPartnerIds.contains(partner.id))
        .toList();

    if (preferredPartnersOnly && preferredAvailable.isEmpty) return const [];

    final workingSet = preferredPartnersOnly ? preferredAvailable : available;

    final ranked = <_SelectedPartner>[];
    for (final partner in workingSet) {
      final distanceKm = _distanceKm(
        originLatitude,
        originLongitude,
        partner.latitude,
        partner.longitude,
      );
      final candidate = _SelectedPartner(
        partner: partner,
        distanceKm: distanceKm,
        etaMinutes: _estimateEtaMinutes(distanceKm: distanceKm),
        preferred: preferredPartnerIds.contains(partner.id),
      );
      ranked.add(candidate);
    }

    ranked.sort((a, b) {
      final etaCompare = a.etaMinutes.compareTo(b.etaMinutes);
      if (etaCompare != 0) return etaCompare;
      final distanceCompare = a.distanceKm.compareTo(b.distanceKm);
      if (distanceCompare != 0) return distanceCompare;
      if (a.preferred != b.preferred) {
        return a.preferred ? -1 : 1;
      }
      return b.partner.rating.compareTo(a.partner.rating);
    });

    return ranked;
  }

  int _fanoutForMode(AssistDispatchMode mode) {
    switch (mode) {
      case AssistDispatchMode.agressivo:
        return 5;
      case AssistDispatchMode.equilibrado:
        return _equilibradoOfferFanoutPerRound;
      case AssistDispatchMode.tranquilo:
        return 1;
    }
  }

  int _offerWindowSecondsForMode(AssistDispatchMode mode) {
    switch (mode) {
      case AssistDispatchMode.agressivo:
        return 12;
      case AssistDispatchMode.equilibrado:
        return _equilibradoOfferWindowSeconds;
      case AssistDispatchMode.tranquilo:
        return 35;
    }
  }

  DemandPricingRule? _findPricingRule({
    required String regionKey,
    required String service,
  }) {
    for (final rule in kDemandPricingRules) {
      if (rule.regionKey.toLowerCase() == regionKey.toLowerCase() &&
          rule.service.toLowerCase() == service.toLowerCase()) {
        return rule;
      }
    }

    for (final rule in kDemandPricingRules) {
      if (rule.regionKey == 'PADRAO' &&
          rule.service.toLowerCase() == service.toLowerCase()) {
        return rule;
      }
    }

    return null;
  }

  List<AssistPartner> _setPartnerBusy({
    required List<AssistPartner> partners,
    required String partnerId,
    required bool isBusy,
  }) {
    return partners
        .map((partner) => partner.id == partnerId
            ? partner.copyWith(isBusy: isBusy)
            : partner)
        .toList();
  }

  AssistRequestStatus _nextStatus(AssistRequestStatus status) {
    switch (status) {
      case AssistRequestStatus.aberto:
        return AssistRequestStatus.despachado;
      case AssistRequestStatus.aguardandoAceite:
        return AssistRequestStatus.despachado;
      case AssistRequestStatus.despachado:
        return AssistRequestStatus.emDeslocamento;
      case AssistRequestStatus.emDeslocamento:
        return AssistRequestStatus.emAtendimento;
      case AssistRequestStatus.emAtendimento:
        return AssistRequestStatus.finalizado;
      case AssistRequestStatus.finalizado:
        return AssistRequestStatus.finalizado;
    }
  }

  AssistRequest? _requestById(String requestId) {
    for (final request in state.requests) {
      if (request.id == requestId) {
        return request;
      }
    }
    return null;
  }

  AssistRequest _replaceRequest(AssistRequest updatedRequest) {
    final next = state.requests
        .map((request) =>
            request.id == updatedRequest.id ? updatedRequest : request)
        .toList();
    state = state.copyWith(requests: next);
    _syncSnapshot();
    return updatedRequest;
  }
}

class _SelectedPartner {
  const _SelectedPartner({
    required this.partner,
    required this.distanceKm,
    required this.etaMinutes,
    required this.preferred,
  });

  final AssistPartner partner;
  final double distanceKm;
  final int etaMinutes;
  final bool preferred;
}

class AssistActionResult {
  const AssistActionResult({
    required this.success,
    this.message,
  });

  final bool success;
  final String? message;
}

class AssistAdvanceStatusResult {
  const AssistAdvanceStatusResult({
    required this.advanced,
    this.message,
  });

  final bool advanced;
  final String? message;
}

class AssistPartnerRouteOption {
  const AssistPartnerRouteOption({
    required this.partner,
    required this.distanceKm,
    required this.etaMinutes,
    required this.preferred,
  });

  final AssistPartner partner;
  final double distanceKm;
  final int etaMinutes;
  final bool preferred;
}

int _estimateEtaMinutes({required double distanceKm}) {
  const avgSpeedKmh = 35.0;
  final minutes = (distanceKm / avgSpeedKmh) * 60;
  return minutes.ceil().clamp(2, 180);
}

double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371.0;
  final dLat = _degreesToRadians(lat2 - lat1);
  final dLon = _degreesToRadians(lon2 - lon1);

  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_degreesToRadians(lat1)) *
          cos(_degreesToRadians(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadius * c;
}

double _degreesToRadians(double degrees) => degrees * pi / 180.0;

String assistStatusLabel(AssistRequestStatus status) {
  switch (status) {
    case AssistRequestStatus.aberto:
      return 'Aberto';
    case AssistRequestStatus.aguardandoAceite:
      return 'Aguardando aceite';
    case AssistRequestStatus.despachado:
      return 'Despachado';
    case AssistRequestStatus.emDeslocamento:
      return 'Em deslocamento';
    case AssistRequestStatus.emAtendimento:
      return 'Em atendimento';
    case AssistRequestStatus.finalizado:
      return 'Finalizado';
  }
}

String assistPriorityLabel(AssistPriority priority) {
  switch (priority) {
    case AssistPriority.baixa:
      return 'Baixa';
    case AssistPriority.media:
      return 'Média';
    case AssistPriority.alta:
      return 'Alta';
    case AssistPriority.critica:
      return 'Crítica';
  }
}

String assistChannelLabel(AssistChannel channel) {
  switch (channel) {
    case AssistChannel.app:
      return 'App';
    case AssistChannel.zpro:
      return 'WhatsApp';
    case AssistChannel.manual:
      return 'Atendente';
  }
}

String assistSplitModeLabel(AssistSplitMode mode) {
  switch (mode) {
    case AssistSplitMode.automatico:
      return 'Split automático';
    case AssistSplitMode.manual:
      return 'Repasse manual';
  }
}

String assistDispatchModeLabel(AssistDispatchMode mode) {
  switch (mode) {
    case AssistDispatchMode.agressivo:
      return 'Agressivo';
    case AssistDispatchMode.equilibrado:
      return 'Equilibrado';
    case AssistDispatchMode.tranquilo:
      return 'Tranquilo';
  }
}

bool demandServiceRequiresInstallationChecklist(String service) {
  final normalized = service.toLowerCase();
  return normalized.contains('instala') || normalized.contains('rastreador');
}

const kDemandRegionCatalog = [
  'PADRAO',
  'SP_CAPITAL',
  'SP_GUARULHOS',
  'RJ_CAPITAL',
  'MG_BH',
];

const kDemandServiceCatalog = [
  'Guincho',
  'Guincho pesado',
  'Socorro mecânico',
  'Socorro elétrico',
  'Moto-socorro',
  'Pane seca',
  'Chaveiro',
  'Troca de pneu',
  'Carga de bateria',
  'Instalação de rastreador',
  'Vistoria veicular',
  'Hospedagem emergencial',
  'Táxi emergencial',
];

const kDemandPricingRules = [
  DemandPricingRule(
      regionKey: 'PADRAO', service: 'Guincho', basePrice: 120, perKmPrice: 6.5),
  DemandPricingRule(
      regionKey: 'PADRAO',
      service: 'Guincho pesado',
      basePrice: 180,
      perKmPrice: 9.0),
  DemandPricingRule(
      regionKey: 'PADRAO',
      service: 'Socorro mecânico',
      basePrice: 90,
      perKmPrice: 3.2),
  DemandPricingRule(
      regionKey: 'PADRAO',
      service: 'Socorro elétrico',
      basePrice: 95,
      perKmPrice: 3.4),
  DemandPricingRule(
      regionKey: 'PADRAO',
      service: 'Moto-socorro',
      basePrice: 70,
      perKmPrice: 2.8),
  DemandPricingRule(
      regionKey: 'PADRAO',
      service: 'Pane seca',
      basePrice: 110,
      perKmPrice: 3.6),
  DemandPricingRule(
      regionKey: 'PADRAO', service: 'Chaveiro', basePrice: 95, perKmPrice: 2.9),
  DemandPricingRule(
      regionKey: 'PADRAO',
      service: 'Troca de pneu',
      basePrice: 85,
      perKmPrice: 2.5),
  DemandPricingRule(
      regionKey: 'PADRAO',
      service: 'Carga de bateria',
      basePrice: 80,
      perKmPrice: 2.4),
  DemandPricingRule(
      regionKey: 'PADRAO',
      service: 'Instalação de rastreador',
      basePrice: 100,
      perKmPrice: 0),
  DemandPricingRule(
      regionKey: 'PADRAO',
      service: 'Vistoria veicular',
      basePrice: 75,
      perKmPrice: 2.2),
  DemandPricingRule(
      regionKey: 'SP_GUARULHOS',
      service: 'Guincho',
      basePrice: 130,
      perKmPrice: 7.0),
  DemandPricingRule(
      regionKey: 'SP_CAPITAL',
      service: 'Socorro mecânico',
      basePrice: 100,
      perKmPrice: 3.5),
];

final assistDispatchProvider =
    StateNotifierProvider<AssistDispatchController, AssistDispatchState>((ref) {
  final client = ref.watch(traccarClientProvider);
  return AssistDispatchController(ref: ref, client: client);
});

const _seedPartners = [
  AssistPartner(
    id: 'p-001',
    name: 'Guincho Leste 24h',
    phone: '+55 11 98888-1001',
    latitude: -23.5551,
    longitude: -46.6402,
    rating: 4.8,
    services: ['Guincho', 'Guincho pesado', 'Pane seca'],
    isOnline: true,
    isBusy: false,
  ),
  AssistPartner(
    id: 'p-002',
    name: 'Mecânica Rota Sul',
    phone: '+55 11 98888-1002',
    latitude: -23.5981,
    longitude: -46.6605,
    rating: 4.7,
    services: [
      'Socorro mecânico',
      'Socorro elétrico',
      'Instalação de rastreador',
      'Vistoria veicular'
    ],
    isOnline: true,
    isBusy: true,
  ),
  AssistPartner(
    id: 'p-003',
    name: 'Chaveiro Express',
    phone: '+55 11 98888-1003',
    latitude: -23.5482,
    longitude: -46.6921,
    rating: 4.6,
    services: ['Chaveiro', 'Moto-socorro', 'Troca de pneu', 'Carga de bateria'],
    isOnline: true,
    isBusy: false,
  ),
];

final _seedRequests = [
  AssistRequest(
    id: '1001',
    customer: 'Operação Linha Amarela',
    service: 'Guincho',
    priority: AssistPriority.alta,
    description: 'Máquina imobilizada em via operacional.',
    originLatitude: -23.5615,
    originLongitude: -46.6554,
    destinationLatitude: -23.5712,
    destinationLongitude: -46.6760,
    regionKey: 'SP_CAPITAL',
    createdAt: DateTime(2026, 3, 1, 9, 10),
    channel: AssistChannel.app,
    serviceAmount: 480,
    platformFeePercent: 14,
    splitMode: AssistSplitMode.automatico,
    dispatchMode: AssistDispatchMode.agressivo,
    installationChecklistRequired: false,
    routeDistanceKm: 2.5,
    preferredPartnerIds: ['p-001'],
    preferredPartnersOnly: false,
    offeredPartnerIds: ['p-001'],
    currentOfferPartnerIds: const [],
    dispatchTimeline: [
      'Chamado criado.',
      'Oferta enviada para Guincho Leste 24h (janela 20s).',
      'Guincho Leste 24h aceitou a oferta e foi despachado.',
    ],
    status: AssistRequestStatus.despachado,
    assignedPartnerId: 'p-001',
    distanceKm: 2.1,
    estimatedArrivalMinutes: 5,
  ),
  AssistRequest(
    id: '1002',
    customer: 'Frota Norte',
    service: 'Socorro mecânico',
    priority: AssistPriority.media,
    description: 'Falha elétrica em caminhão leve.',
    originLatitude: -23.6002,
    originLongitude: -46.6891,
    destinationLatitude: -23.6122,
    destinationLongitude: -46.7010,
    regionKey: 'SP_GUARULHOS',
    createdAt: DateTime(2026, 3, 1, 8, 40),
    channel: AssistChannel.zpro,
    serviceAmount: 220,
    platformFeePercent: 12,
    splitMode: AssistSplitMode.automatico,
    dispatchMode: AssistDispatchMode.equilibrado,
    installationChecklistRequired: false,
    routeDistanceKm: 1.8,
    preferredPartnerIds: const [],
    preferredPartnersOnly: false,
    offeredPartnerIds: ['p-002'],
    currentOfferPartnerIds: const [],
    dispatchTimeline: [
      'Chamado criado.',
      'Oferta enviada para Mecânica Rota Sul (janela 20s).',
      'Mecânica Rota Sul aceitou a oferta e foi despachado.',
      'Status alterado para Em deslocamento.',
    ],
    status: AssistRequestStatus.emDeslocamento,
    assignedPartnerId: 'p-002',
    distanceKm: 3.8,
    estimatedArrivalMinutes: 8,
  ),
];
