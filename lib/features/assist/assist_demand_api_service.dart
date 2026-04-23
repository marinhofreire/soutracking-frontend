import '../../data/traccar_client.dart';
import '../../state/session_state.dart';
import 'assist_demand_api_contract.dart';
import 'assist_dispatch_state.dart';

class AssistDemandApiService {
  AssistDemandApiService({required TraccarClient client}) : _client = client;

  final TraccarClient _client;

  static const String _v1DemandsPath = AssistDemandApiContract.basePath;
  static const String _v1SnapshotPath = AssistDemandApiContract.snapshotPath;

  Future<List<AssistRequest>?> fetchRequests({
    required SessionState session,
  }) async {
    if (!session.isAuthenticated) {
      return null;
    }

    final query = {'tenantId': session.tenantConfig.tenantId};

    try {
      final rows = await _client.getList(
        path: _v1DemandsPath,
        cookie: session.cookie,
        authHeader: session.authHeader,
        query: query,
      );

      final normalizedRows = _unwrapRows(rows);
      return normalizedRows
          .map(_requestFromApi)
          .whereType<AssistRequest>()
          .toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertRequest({
    required SessionState session,
    required AssistRequest request,
  }) async {
    if (!session.isAuthenticated) {
      return;
    }

    final body = _requestToApi(
      session: session,
      request: request,
    );

    try {
      await _client.updateEntity(
        path: '$_v1DemandsPath/${request.id}',
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: body,
      );
      return;
    } catch (_) {
      // tenta criar quando update não existir
    }

    try {
      await _client.createEntity(
        path: _v1DemandsPath,
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: body,
      );
    } catch (_) {
      // endpoint indisponível
    }
  }

  Future<void> syncSnapshot({
    required SessionState session,
    required List<AssistRequest> requests,
  }) async {
    if (!session.isAuthenticated) {
      return;
    }

    final body = {
      'tenantId': session.tenantConfig.tenantId,
      'requests': requests
          .map((request) => _requestToApi(session: session, request: request))
          .toList(growable: false),
    };

    try {
      await _client.updateEntity(
        path: _v1SnapshotPath,
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: body,
      );
      return;
    } catch (_) {
      // fallback
    }

    try {
      await _client.createEntity(
        path: _v1SnapshotPath,
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: body,
      );
    } catch (_) {
      // endpoint opcional; ignora quando indisponível
    }
  }

  List<Map<String, dynamic>> _unwrapRows(List<Map<String, dynamic>> rows) {
    if (rows.length != 1) {
      return rows;
    }

    final first = rows.first;
    final nested = first['items'] ?? first['data'];
    if (nested is List) {
      return nested
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList(growable: false);
    }

    return rows;
  }

  AssistRequest? _requestFromApi(Map<String, dynamic> row) {
    try {
      final rawChecklist = row['installationChecklist'];
      AssistInstallationChecklist? checklist;
      if (rawChecklist is Map) {
        final map = rawChecklist.cast<String, dynamic>();
        checklist = AssistInstallationChecklist(
          fixacaoSegura: map['fixacaoSegura'] == true,
          chicoteProtegido: map['chicoteProtegido'] == true,
          semInterferenciaEletrica: map['semInterferenciaEletrica'] == true,
          testeComunicacaoOk: map['testeComunicacaoOk'] == true,
          fotoLocalInstalacao: (map['fotoLocalInstalacao'] ?? '').toString(),
          fotoChicote: (map['fotoChicote'] ?? '').toString(),
          fotoAcabamento: (map['fotoAcabamento'] ?? '').toString(),
          observacoes: map['observacoes']?.toString(),
        );
      }

      return AssistRequest(
        id: (row['id'] ?? '').toString(),
        customer: (row['customer'] ?? row['cliente'] ?? '').toString(),
        service: (row['service'] ?? row['tipo'] ?? '').toString(),
        priority: _priorityFromString(row['priority']),
        description: (row['description'] ?? '').toString(),
        originLatitude: _toDouble(row['originLatitude']),
        originLongitude: _toDouble(row['originLongitude']),
        destinationLatitude: _toDouble(row['destinationLatitude']),
        destinationLongitude: _toDouble(row['destinationLongitude']),
        regionKey: (row['regionKey'] ?? 'PADRAO').toString(),
        createdAt: DateTime.tryParse((row['createdAt'] ?? '').toString()) ??
            DateTime.now(),
        status: _statusFromString(row['status']),
        channel: _channelFromString(row['channel']),
        serviceAmount: _toDouble(row['serviceAmount']),
        platformFeePercent: _toDouble(row['platformFeePercent']),
        splitMode: _splitFromString(row['splitMode']),
        dispatchMode: _dispatchModeFromString(row['dispatchMode']),
        installationChecklistRequired:
            row['installationChecklistRequired'] == true,
        routeDistanceKm: _toDouble(row['routeDistanceKm']),
        preferredPartnerIds: _stringList(row['preferredPartnerIds']),
        preferredPartnersOnly: row['preferredPartnersOnly'] == true,
        offeredPartnerIds: _stringList(row['offeredPartnerIds']),
        currentOfferPartnerIds: _stringList(row['currentOfferPartnerIds']),
        dispatchTimeline: _stringList(row['dispatchTimeline']),
        assignedPartnerId: row['assignedPartnerId']?.toString(),
        distanceKm: _toNullableDouble(row['distanceKm']),
        estimatedArrivalMinutes: _toNullableInt(row['estimatedArrivalMinutes']),
        currentOfferPartnerId: row['currentOfferPartnerId']?.toString(),
        offerExpiresAt: row['offerExpiresAt'] == null
            ? null
            : DateTime.tryParse(row['offerExpiresAt'].toString()),
        installationChecklist: checklist,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _requestToApi({
    required SessionState session,
    required AssistRequest request,
  }) {
    return {
      'id': request.id,
      'tenantId': session.tenantConfig.tenantId,
      'customer': request.customer,
      'service': request.service,
      'priority': _priorityToString(request.priority),
      'description': request.description,
      'originLatitude': request.originLatitude,
      'originLongitude': request.originLongitude,
      'destinationLatitude': request.destinationLatitude,
      'destinationLongitude': request.destinationLongitude,
      'regionKey': request.regionKey,
      'createdAt': request.createdAt.toIso8601String(),
      'status': _statusToString(request.status),
      'channel': _channelToString(request.channel),
      'serviceAmount': request.serviceAmount,
      'platformFeePercent': request.platformFeePercent,
      'splitMode': _splitToString(request.splitMode),
      'dispatchMode': _dispatchModeToString(request.dispatchMode),
      'installationChecklistRequired': request.installationChecklistRequired,
      'routeDistanceKm': request.routeDistanceKm,
      'preferredPartnerIds': request.preferredPartnerIds,
      'preferredPartnersOnly': request.preferredPartnersOnly,
      'offeredPartnerIds': request.offeredPartnerIds,
      'currentOfferPartnerIds': request.currentOfferPartnerIds,
      'dispatchTimeline': request.dispatchTimeline,
      'assignedPartnerId': request.assignedPartnerId,
      'distanceKm': request.distanceKm,
      'estimatedArrivalMinutes': request.estimatedArrivalMinutes,
      'currentOfferPartnerId': request.currentOfferPartnerId,
      'offerExpiresAt': request.offerExpiresAt?.toIso8601String(),
      'installationChecklist': request.installationChecklist == null
          ? null
          : {
              'fixacaoSegura': request.installationChecklist!.fixacaoSegura,
              'chicoteProtegido':
                  request.installationChecklist!.chicoteProtegido,
              'semInterferenciaEletrica':
                  request.installationChecklist!.semInterferenciaEletrica,
              'testeComunicacaoOk':
                  request.installationChecklist!.testeComunicacaoOk,
              'fotoLocalInstalacao':
                  request.installationChecklist!.fotoLocalInstalacao,
              'fotoChicote': request.installationChecklist!.fotoChicote,
              'fotoAcabamento': request.installationChecklist!.fotoAcabamento,
              'observacoes': request.installationChecklist!.observacoes,
            },
    };
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList(growable: false);
    }
    return const [];
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.')) ?? 0;
    }
    return 0;
  }

  double? _toNullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.'));
    }
    return null;
  }

  int? _toNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  AssistPriority _priorityFromString(dynamic value) {
    switch ((value ?? '').toString().toLowerCase()) {
      case 'baixa':
        return AssistPriority.baixa;
      case 'alta':
        return AssistPriority.alta;
      case 'critica':
      case 'crítica':
        return AssistPriority.critica;
      default:
        return AssistPriority.media;
    }
  }

  String _priorityToString(AssistPriority value) {
    switch (value) {
      case AssistPriority.baixa:
        return 'baixa';
      case AssistPriority.media:
        return 'media';
      case AssistPriority.alta:
        return 'alta';
      case AssistPriority.critica:
        return 'critica';
    }
  }

  AssistChannel _channelFromString(dynamic value) {
    switch ((value ?? '').toString().toLowerCase()) {
      case 'zpro':
        return AssistChannel.zpro;
      case 'manual':
        return AssistChannel.manual;
      default:
        return AssistChannel.app;
    }
  }

  String _channelToString(AssistChannel value) {
    switch (value) {
      case AssistChannel.app:
        return 'app';
      case AssistChannel.zpro:
        return 'zpro';
      case AssistChannel.manual:
        return 'manual';
    }
  }

  AssistSplitMode _splitFromString(dynamic value) {
    switch ((value ?? '').toString().toLowerCase()) {
      case 'manual':
        return AssistSplitMode.manual;
      default:
        return AssistSplitMode.automatico;
    }
  }

  String _splitToString(AssistSplitMode value) {
    switch (value) {
      case AssistSplitMode.automatico:
        return 'automatico';
      case AssistSplitMode.manual:
        return 'manual';
    }
  }

  AssistDispatchMode _dispatchModeFromString(dynamic value) {
    switch ((value ?? '').toString().toLowerCase()) {
      case 'agressivo':
        return AssistDispatchMode.agressivo;
      case 'tranquilo':
        return AssistDispatchMode.tranquilo;
      default:
        return AssistDispatchMode.equilibrado;
    }
  }

  String _dispatchModeToString(AssistDispatchMode value) {
    switch (value) {
      case AssistDispatchMode.agressivo:
        return 'agressivo';
      case AssistDispatchMode.equilibrado:
        return 'equilibrado';
      case AssistDispatchMode.tranquilo:
        return 'tranquilo';
    }
  }

  AssistRequestStatus _statusFromString(dynamic value) {
    switch ((value ?? '').toString().toLowerCase()) {
      case 'aguardandoaceite':
      case 'aguardando_aceite':
        return AssistRequestStatus.aguardandoAceite;
      case 'despachado':
        return AssistRequestStatus.despachado;
      case 'emdeslocamento':
      case 'em_deslocamento':
        return AssistRequestStatus.emDeslocamento;
      case 'ematendimento':
      case 'em_atendimento':
        return AssistRequestStatus.emAtendimento;
      case 'finalizado':
        return AssistRequestStatus.finalizado;
      default:
        return AssistRequestStatus.aberto;
    }
  }

  String _statusToString(AssistRequestStatus value) {
    switch (value) {
      case AssistRequestStatus.aberto:
        return 'aberto';
      case AssistRequestStatus.aguardandoAceite:
        return 'aguardando_aceite';
      case AssistRequestStatus.despachado:
        return 'despachado';
      case AssistRequestStatus.emDeslocamento:
        return 'em_deslocamento';
      case AssistRequestStatus.emAtendimento:
        return 'em_atendimento';
      case AssistRequestStatus.finalizado:
        return 'finalizado';
    }
  }
}
