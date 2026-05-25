String formatDisplayText(
  dynamic value, {
  String fallback = 'Não informado',
}) {
  if (value == null) return fallback;

  var text = value.toString().trim();
  if (text.isEmpty) return fallback;

  // Normalize common broken terms first.
  const directReplacements = <String, String>{
    'Nao informado': 'Não informado',
    'Não Informado': 'Não informado',
    'Sem Comunicacao': 'Sem comunicação',
    'Sem comunicacao': 'Sem comunicação',
    'Comunicacao': 'Comunicação',
    'Configuracoes': 'Configurações',
    'Relatorios': 'Relatórios',
    'Manutencao': 'Manutenção',
    'Historico': 'Histórico',
    'Ignicao': 'Ignição',
    'Ultima conexao': 'Última conexão',
    'Ultima conexão': 'Última conexão',
    'Ultima atualização': 'Última atualização',
    'Acoes rapidas': 'Ações rápidas',
    'Acoes Rapidas': 'Ações rápidas',
    'Acoes': 'Ações',
    'Cameras': 'Câmeras',
    'numero oficial': 'número oficial',
    'Distancia': 'Distância',
    'Formula': 'Fórmula',
    'Lubrificacao': 'Lubrificação',
    'oleo': 'óleo',
    'Proxima execucao': 'Próxima execução',
    'Concluidos': 'Concluídos',
    'Atualizacao': 'Atualização',
    'Medio': 'Médio',
    'Tamanho dos baloes': 'Tamanho dos balões',
  };
  directReplacements.forEach((from, to) {
    text = text.replaceAll(from, to);
  });

  // Patch frequent mojibake fragments.
  const mojibakeReplacements = <String, String>{
    'Ã¡': 'á',
    'Ã¢': 'â',
    'Ã£': 'ã',
    'Ãª': 'ê',
    'Ã©': 'é',
    'Ã­': 'í',
    'Ã³': 'ó',
    'Ã´': 'ô',
    'Ãµ': 'õ',
    'Ãº': 'ú',
    'Ã§': 'ç',
    'Ã\u0081': 'Á',
    'Ã\u0089': 'É',
    'Ã\u008d': 'Í',
    'Ã\u0093': 'Ó',
    'Ã\u009a': 'Ú',
    'Ã\u0087': 'Ç',
    'ÃƒÂ§': 'ç',
    'ÃƒÂ£': 'ã',
    'ÃƒÂ¡': 'á',
    'ÃƒÂ©': 'é',
    'ÃƒÂ³': 'ó',
    'ÃƒÂº': 'ú',
    'ÃƒÂª': 'ê',
    'ÃƒÂ´': 'ô',
    'ÃƒÂµ': 'õ',
    'ÃƒÂ­': 'í',
    'Ã‚': '',
    'Âº': 'º',
    'Â°': '°',
    'â€¢': '•',
    'â€“': '–',
    'â€”': '—',
    'â€œ': '"',
    'â€\u009d': '"',
    'â€˜': '\'',
    'â€™': '\'',
    'Ãƒâ€šÃ‚Â·': '•',
  };
  mojibakeReplacements.forEach((from, to) {
    text = text.replaceAll(from, to);
  });

  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  text = _normalizeRelativeTimeText(text);

  final lower = text.toLowerCase();
  if (lower == 'n/a' || lower == 'null' || lower == '--') {
    return fallback;
  }

  // If text remains visibly corrupted, avoid exposing broken UI.
  if (text.contains('Ã') || text.contains('�')) {
    return fallback;
  }

  return text.isEmpty ? fallback : text;
}

String _normalizeRelativeTimeText(String text) {
  var normalized = text;

  normalized = normalized.replaceAllMapped(
    RegExp(r'\bha\s+(\d+)\s*min\b', caseSensitive: false),
    (m) => 'há ${m.group(1)} min',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'\bha\s+(\d+)\s*h\b', caseSensitive: false),
    (m) => 'há ${m.group(1)} h',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'\bha\s+1\s*d\b', caseSensitive: false),
    (_) => 'há 1 dia',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'\bha\s+(\d+)\s*d\b', caseSensitive: false),
    (m) => 'há ${m.group(1)} dias',
  );

  return normalized;
}
