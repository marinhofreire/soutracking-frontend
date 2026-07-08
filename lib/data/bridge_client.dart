import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'bridge_config.dart';

// ── Event model ────────────────────────────────────────────────────────────────

enum IaEventType { sugestao, acao, alerta, status }

class IaBridgeEvent {
  IaBridgeEvent({
    required this.id,
    required this.type,
    required this.titulo,
    required this.descricao,
    required this.timestamp,
    this.requerAprovacao = false,
    this.valor,
    this.entidade,
    this.dados = const {},
    this.aprovado,
  });

  final String id;
  final IaEventType type;
  final String titulo;
  final String descricao;
  final DateTime timestamp;
  final bool requerAprovacao;
  final double? valor;
  final String? entidade;
  final Map<String, dynamic> dados;
  bool? aprovado;

  factory IaBridgeEvent.fromJson(Map<String, dynamic> j) {
    return IaBridgeEvent(
      id:               j['id']?.toString() ?? '',
      type:             IaEventType.values.firstWhere(
                          (e) => e.name == j['tipo'], orElse: () => IaEventType.acao),
      titulo:           j['titulo']?.toString() ?? '',
      descricao:        j['descricao']?.toString() ?? '',
      timestamp:        DateTime.tryParse(j['timestamp']?.toString() ?? '') ?? DateTime.now(),
      requerAprovacao:  j['requer_aprovacao'] == true,
      valor:            (j['valor'] as num?)?.toDouble(),
      entidade:         j['entidade']?.toString(),
      dados:            Map<String, dynamic>.from(j['dados'] ?? {}),
      aprovado:         j['aprovado'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'tipo': type.name, 'titulo': titulo, 'descricao': descricao,
    'timestamp': timestamp.toIso8601String(),
    'requer_aprovacao': requerAprovacao,
    if (valor != null) 'valor': valor,
    if (entidade != null) 'entidade': entidade,
    'dados': dados,
    if (aprovado != null) 'aprovado': aprovado,
  };
}

// ── Bridge state ───────────────────────────────────────────────────────────────

enum BridgeConnectionStatus { connected, disconnected, connecting, error }

class IaState {
  const IaState({
    this.status = BridgeConnectionStatus.disconnected,
    this.events = const [],
    this.lastPoll,
    this.errorMsg,
    this.tokensUsed = 0,
    this.acertosHoje = 0,
  });

  final BridgeConnectionStatus status;
  final List<IaBridgeEvent> events;
  final DateTime? lastPoll;
  final String? errorMsg;
  final int tokensUsed;
  final int acertosHoje;

  List<IaBridgeEvent> get pending =>
      events.where((e) => e.requerAprovacao && e.aprovado == null).toList();
  List<IaBridgeEvent> get log =>
      events.where((e) => !e.requerAprovacao || e.aprovado != null)
            .toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  IaState copyWith({
    BridgeConnectionStatus? status,
    List<IaBridgeEvent>? events,
    DateTime? lastPoll,
    String? errorMsg,
    int? tokensUsed,
    int? acertosHoje,
  }) =>
      IaState(
        status:      status      ?? this.status,
        events:      events      ?? this.events,
        lastPoll:    lastPoll    ?? this.lastPoll,
        errorMsg:    errorMsg,
        tokensUsed:  tokensUsed  ?? this.tokensUsed,
        acertosHoje: acertosHoje ?? this.acertosHoje,
      );
}

// ── Provider ───────────────────────────────────────────────────────────────────

final iaProvider = StateNotifierProvider<IaNotifier, IaState>(
  (ref) => IaNotifier(ref),
);

class IaNotifier extends StateNotifier<IaState> {
  IaNotifier(this._ref) : super(const IaState()) {
    _init();
  }

  final Ref _ref;

  Future<void> _init() async {
    final config = await BridgeConfig.load();
    if (config.isConfigured && config.aiMode == AiMode.bridge) {
      await _fetchFromBridge(config);
    } else {
      _loadDemoData();
    }
  }

  Future<void> refresh() async {
    final config = _ref.read(bridgeConfigProvider);
    if (config.isConfigured && config.aiMode == AiMode.bridge) {
      await _fetchFromBridge(config);
    } else {
      _loadDemoData();
    }
  }

  Future<void> _fetchFromBridge(BridgeConfig config) async {
    state = state.copyWith(status: BridgeConnectionStatus.connecting);
    try {
      final uri = Uri.parse('${config.bridgeUrl}/ia/eventos');
      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer ${config.bridgeApiKey}',
        'Content-Type': 'application/json',
      }).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final list = (body['eventos'] as List? ?? [])
            .map((e) => IaBridgeEvent.fromJson(e as Map<String, dynamic>))
            .toList();
        state = state.copyWith(
          status:      BridgeConnectionStatus.connected,
          events:      list,
          lastPoll:    DateTime.now(),
          tokensUsed:  (body['tokens_usados'] as int?) ?? state.tokensUsed,
          acertosHoje: (body['acertos_hoje']  as int?) ?? state.acertosHoje,
        );
      } else {
        state = state.copyWith(
          status:   BridgeConnectionStatus.error,
          errorMsg: 'HTTP ${resp.statusCode}',
        );
        _loadDemoData();
      }
    } catch (e) {
      state = state.copyWith(
        status:   BridgeConnectionStatus.error,
        errorMsg: e.toString(),
      );
      _loadDemoData();
    }
  }

  Future<void> aprovar(String eventId) async {
    final config = _ref.read(bridgeConfigProvider);
    if (config.isConfigured && config.aiMode == AiMode.bridge) {
      try {
        await http.post(
          Uri.parse('${config.bridgeUrl}/ia/aprovar/$eventId'),
          headers: {
            'Authorization': 'Bearer ${config.bridgeApiKey}',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    state = state.copyWith(
      events: state.events.map((e) {
        if (e.id == eventId) { e.aprovado = true; }
        return e;
      }).toList(),
    );
  }

  Future<void> rejeitar(String eventId) async {
    final config = _ref.read(bridgeConfigProvider);
    if (config.isConfigured && config.aiMode == AiMode.bridge) {
      try {
        await http.post(
          Uri.parse('${config.bridgeUrl}/ia/rejeitar/$eventId'),
          headers: {
            'Authorization': 'Bearer ${config.bridgeApiKey}',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    state = state.copyWith(
      events: state.events.map((e) {
        if (e.id == eventId) { e.aprovado = false; }
        return e;
      }).toList(),
    );
  }

  Future<void> enviarComando(Map<String, dynamic> payload) async {
    final config = _ref.read(bridgeConfigProvider);
    if (!config.isConfigured || config.aiMode != AiMode.bridge) return;
    try {
      await http.post(
        Uri.parse('${config.bridgeUrl}/ia/comando'),
        headers: {
          'Authorization': 'Bearer ${config.bridgeApiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  void _loadDemoData() {
    final now = DateTime.now();
    state = state.copyWith(
      status:      BridgeConnectionStatus.disconnected,
      tokensUsed:  4820,
      acertosHoje: 11,
      events: [
        IaBridgeEvent(
          id: 'evt-001',
          type: IaEventType.sugestao,
          titulo: 'Despachar parceiro para chamado #4821',
          descricao: 'Carlos Guincho SP — 1.8 km — R\$ 280 — avaliação 4.9',
          requerAprovacao: true,
          valor: 280.0,
          entidade: 'Chamado #4821',
          timestamp: now.subtract(const Duration(minutes: 3)),
          dados: {'ticketId': '#4821', 'partner': 'Carlos Guincho SP', 'km': 1.8},
        ),
        IaBridgeEvent(
          id: 'evt-002',
          type: IaEventType.sugestao,
          titulo: 'Criar cerca de proteção — Caminhão Frio 01',
          descricao: 'Veículo parado há 2h fora da base. Sugestão: cerca raio 300m vel. 5km/h.',
          requerAprovacao: true,
          entidade: 'Caminhão Frio 01',
          timestamp: now.subtract(const Duration(minutes: 8)),
          dados: {'vehicleId': '142', 'raio': 300, 'velMax': 5},
        ),
        IaBridgeEvent(
          id: 'evt-003',
          type: IaEventType.sugestao,
          titulo: 'Enviar relatório mensal — Transportes Silva',
          descricao: 'Vencimento amanhã. IA gerou o PDF automaticamente. Aprovar envio por WhatsApp.',
          requerAprovacao: true,
          entidade: 'Transportes Silva',
          timestamp: now.subtract(const Duration(minutes: 15)),
          dados: {'clientId': 'c-089', 'tipo': 'mensal'},
        ),
        IaBridgeEvent(
          id: 'evt-004',
          type: IaEventType.acao,
          titulo: 'Alerta de velocidade criado',
          descricao: 'HB20 — placa ABC-2345 — excedeu 120km/h na Rod. dos Bandeirantes. Alerta ativado.',
          entidade: 'HB20 ABC-2345',
          timestamp: now.subtract(const Duration(minutes: 42)),
          aprovado: true,
        ),
        IaBridgeEvent(
          id: 'evt-005',
          type: IaEventType.acao,
          titulo: 'WhatsApp enviado para cliente',
          descricao: 'Ricardo Mendes notificado sobre status do chamado #4821 via WhatsApp.',
          entidade: 'Ricardo Mendes',
          timestamp: now.subtract(const Duration(hours: 1, minutes: 5)),
          aprovado: true,
        ),
        IaBridgeEvent(
          id: 'evt-006',
          type: IaEventType.acao,
          titulo: 'Cerca de manutenção ativada',
          descricao: 'Frota 03 — cerca de entrada na oficina SP Centro criada automaticamente.',
          entidade: 'Frota 03',
          timestamp: now.subtract(const Duration(hours: 2, minutes: 12)),
          aprovado: true,
        ),
        IaBridgeEvent(
          id: 'evt-007',
          type: IaEventType.alerta,
          titulo: 'Ignição detectada fora do horário',
          descricao: 'Veículo FIAT Strada — placa XYZ-9981 — ignição ligada às 02:34. Fora do horário autorizado.',
          entidade: 'Strada XYZ-9981',
          timestamp: now.subtract(const Duration(hours: 3, minutes: 30)),
          aprovado: true,
        ),
        IaBridgeEvent(
          id: 'evt-008',
          type: IaEventType.acao,
          titulo: 'Resumo diário gerado',
          descricao: '14 veículos ativos, 3 alertas, 7 chamados, 2 cercas atualizadas. Relatório salvo.',
          timestamp: now.subtract(const Duration(hours: 5)),
          aprovado: true,
        ),
      ],
    );
  }
}

// ── Legacy methods (kept for compatibility) ────────────────────────────────────

class BridgeClient {
  const BridgeClient();

  Future<Map<String, dynamic>> criarChamado(Map<String, dynamic> payload) async =>
      _mock('criarChamado', payload);
  Future<Map<String, dynamic>> enviarWhatsapp(Map<String, dynamic> payload) async =>
      _mock('enviarWhatsapp', payload);
  Future<Map<String, dynamic>> puxarLocalizacao(Map<String, dynamic> payload) async =>
      _mock('puxarLocalizacao', payload);
  Future<Map<String, dynamic>> criarAlerta(Map<String, dynamic> payload) async =>
      _mock('criarAlerta', payload);
  Future<Map<String, dynamic>> criarCerca(Map<String, dynamic> payload) async =>
      _mock('criarCerca', payload);
  Future<Map<String, dynamic>> gerarRelatorio(Map<String, dynamic> payload) async =>
      _mock('gerarRelatorio', payload);
  Future<Map<String, dynamic>> registrarEvento(Map<String, dynamic> payload) async =>
      _mock('registrarEvento', payload);

  Map<String, dynamic> _mock(String acao, Map<String, dynamic> payload) =>
      {'ok': true, 'modo': 'mock', 'acao': acao, 'payload': payload};
}
