class BridgeClient {
  const BridgeClient();

  Future<Map<String, dynamic>> criarChamado(
    Map<String, dynamic> payload,
  ) async {
    return _mockResponse(acao: 'criarChamado', payload: payload);
  }

  Future<Map<String, dynamic>> enviarWhatsapp(
    Map<String, dynamic> payload,
  ) async {
    return _mockResponse(acao: 'enviarWhatsapp', payload: payload);
  }

  Future<Map<String, dynamic>> puxarLocalizacao(
    Map<String, dynamic> payload,
  ) async {
    return _mockResponse(acao: 'puxarLocalizacao', payload: payload);
  }

  Future<Map<String, dynamic>> criarAlerta(
    Map<String, dynamic> payload,
  ) async {
    return _mockResponse(acao: 'criarAlerta', payload: payload);
  }

  Future<Map<String, dynamic>> criarCerca(
    Map<String, dynamic> payload,
  ) async {
    return _mockResponse(acao: 'criarCerca', payload: payload);
  }

  Future<Map<String, dynamic>> gerarRelatorio(
    Map<String, dynamic> payload,
  ) async {
    return _mockResponse(acao: 'gerarRelatorio', payload: payload);
  }

  Future<Map<String, dynamic>> registrarEvento(
    Map<String, dynamic> payload,
  ) async {
    return _mockResponse(acao: 'registrarEvento', payload: payload);
  }

  Map<String, dynamic> _mockResponse({
    required String acao,
    required Map<String, dynamic> payload,
  }) {
    return {
      'ok': true,
      'modo': 'mock',
      'acao': acao,
      'payload': payload,
    };
  }
}
