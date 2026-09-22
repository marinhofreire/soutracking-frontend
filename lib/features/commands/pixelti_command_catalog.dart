// Catalogo de comandos do protocolo Track Hex Air / PXL058RV (Pixel TI).
// Fonte: PXL058RV_COMMAND_LIST_PT-BR.pdf (Rev.0, 22/08/2026).
// Cada comando e enviado via TYPE_CUSTOM (payload texto), no formato
// AT+CMD=NOME,val1,val2,...# aceito pelo firmware do rastreador.

class PixelTiCommandField {
  const PixelTiCommandField({
    required this.key,
    required this.label,
    required this.hint,
    this.defaultValue = '',
  });

  final String key;
  final String label;
  final String hint;
  final String defaultValue;
}

class PixelTiCommand {
  const PixelTiCommand({
    required this.name,
    required this.label,
    required this.category,
    required this.fields,
    this.readOnly = false,
  });

  final String name;
  final String label;
  final String category;
  final List<PixelTiCommandField> fields;
  // Comandos de consulta (terminam so com "#", sem parametros) -- usados
  // para LER o valor atual em vez de escrever.
  final bool readOnly;

  String buildPayload(Map<String, String> values) {
    if (readOnly) {
      return 'AT+CMD=$name#';
    }
    final parts = fields.map((f) => values[f.key]?.trim() ?? '').toList();
    return 'AT+CMD=$name,${parts.join(',')}#';
  }

  String buildQueryPayload() => 'AT+CMD=$name#';
}

const List<String> pixelTiCommandCategories = [
  'Rede',
  'Protocolo',
  'Relatorio periodico',
  'Eventos',
  'Watchdog',
  'Localizacao',
  'Reinicializacao',
  'Atualizacao (FOTA)',
  'Bateria',
  'Velocidade',
  'Bloqueio de config',
  'Info do terminal',
  'E/S (GPIO, rele, buzzer)',
  'Imobilizador',
  'Cerca eletronica',
  'Jammer',
  'Movimento indevido',
  'RS232',
  'Seguranca',
];

final List<PixelTiCommand> pixelTiCommands = [
  // ── Rede ──────────────────────────────────────────────────────────────
  const PixelTiCommand(
    name: 'NTWK',
    label: 'Configurar servidor e APN',
    category: 'Rede',
    fields: [
      PixelTiCommandField(key: 'apn1', label: 'APN 1', hint: 'zap.vivo.com.br'),
      PixelTiCommandField(key: 'user1', label: 'Usuario APN 1', hint: 'vivo'),
      PixelTiCommandField(key: 'pwd1', label: 'Senha APN 1', hint: 'vivo'),
      PixelTiCommandField(key: 'apn2', label: 'APN 2 (opcional)', hint: ''),
      PixelTiCommandField(key: 'user2', label: 'Usuario APN 2', hint: ''),
      PixelTiCommandField(key: 'pwd2', label: 'Senha APN 2', hint: ''),
      PixelTiCommandField(
          key: 'autApn', label: 'APN automatico (0/1)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'url1', label: 'Servidor principal', hint: 'track.soutracking.com.br'),
      PixelTiCommandField(key: 'port1', label: 'Porta principal', hint: '6149'),
      PixelTiCommandField(key: 'url2', label: 'Servidor backup (opcional)', hint: ''),
      PixelTiCommandField(key: 'port2', label: 'Porta backup', hint: ''),
      PixelTiCommandField(key: 'urlMdm', label: 'Servidor MDM (opcional)', hint: ''),
      PixelTiCommandField(key: 'portMdm', label: 'Porta MDM', hint: ''),
      PixelTiCommandField(
          key: 'wanPriot1', label: 'Prioridade rede 1', hint: '1 (Automatico)', defaultValue: '1'),
    ],
  ),

  // ── Protocolo ─────────────────────────────────────────────────────────
  const PixelTiCommand(
    name: 'PROT',
    label: 'Configurar versao do protocolo',
    category: 'Protocolo',
    fields: [
      PixelTiCommandField(
          key: 'protVer',
          label: 'Versao protocolo (1-4)',
          hint: '2 (Gen2, padrao)',
          defaultValue: '2'),
      PixelTiCommandField(
          key: 'transProt', label: 'Transporte (0=TCP)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'format', label: 'Formato (0=HEXA)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'srv1Mode', label: 'Modo servidor 1 (0=Principal)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'srv1Encryp', label: 'Cripto servidor 1', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'srv2Mode', label: 'Modo servidor 2 (1=Backup)', hint: '1', defaultValue: '1'),
      PixelTiCommandField(
          key: 'srv2Encryp', label: 'Cripto servidor 2', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'idType', label: 'Identificacao (1=IMEI)', hint: '1', defaultValue: '1'),
      PixelTiCommandField(
          key: 'login', label: 'Login habilitado (1=sim)', hint: '1', defaultValue: '1'),
      PixelTiCommandField(
          key: 'swtSrv', label: 'Tentativas antes do backup', hint: '0', defaultValue: '0'),
    ],
  ),
  PixelTiCommand(
    name: 'PROT',
    label: 'Consultar protocolo atual',
    category: 'Protocolo',
    fields: const [],
    readOnly: true,
  ),

  // ── Relatorio periodico ──────────────────────────────────────────────
  const PixelTiCommand(
    name: 'RTPT',
    label: 'Configurar intervalo de transmissao',
    category: 'Relatorio periodico',
    fields: [
      PixelTiCommandField(
          key: 'igtOnTm', label: 'Intervalo c/ ignicao ligada (s)', hint: '60', defaultValue: '60'),
      PixelTiCommandField(
          key: 'igtOffTm',
          label: 'Intervalo c/ ignicao desligada (s)',
          hint: '3600',
          defaultValue: '3600'),
      PixelTiCommandField(
          key: 'gotSlpTm', label: 'Tempo p/ dormir apos ignicao off (s)', hint: '120', defaultValue: '120'),
      PixelTiCommandField(
          key: 'kpAlvTm', label: 'Keep-alive (s, 0=desabilita)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'alrtTm', label: 'Intervalo durante alerta (s)', hint: '0', defaultValue: '0'),
    ],
  ),
  PixelTiCommand(
    name: 'RTPT',
    label: 'Consultar intervalo atual',
    category: 'Relatorio periodico',
    fields: const [],
    readOnly: true,
  ),

  // ── Eventos ───────────────────────────────────────────────────────────
  PixelTiCommand(
    name: 'UETR',
    label: 'Consultar eventos configurados',
    category: 'Eventos',
    fields: const [],
    readOnly: true,
  ),

  // ── Watchdog ──────────────────────────────────────────────────────────
  const PixelTiCommand(
    name: 'WDOG',
    label: 'Configurar watchdog',
    category: 'Watchdog',
    fields: [
      PixelTiCommandField(
          key: 'schdlTm', label: 'Reinicio diario (HH:MM, vazio=off)', hint: ''),
      PixelTiCommandField(
          key: 'operTm', label: 'Reinicio por tempo de operacao (min)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'toutCellConn', label: 'Timeout conexao celular (min)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'fctrCellConn', label: 'Fator multiplicador celular (1-5)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'toutGnssFix', label: 'Timeout fixacao GNSS (min)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'fctrGnssFix', label: 'Fator multiplicador GNSS (1-5)', hint: '0', defaultValue: '0'),
    ],
  ),
  PixelTiCommand(
    name: 'WDOG',
    label: 'Consultar watchdog atual',
    category: 'Watchdog',
    fields: const [],
    readOnly: true,
  ),

  // ── Localizacao ───────────────────────────────────────────────────────
  PixelTiCommand(
    name: 'LOCA',
    label: 'Solicitar localizacao imediata',
    category: 'Localizacao',
    fields: const [],
    readOnly: true,
  ),

  // ── Reinicializacao ───────────────────────────────────────────────────
  const PixelTiCommand(
    name: 'REBT',
    label: 'Reiniciar terminal',
    category: 'Reinicializacao',
    fields: [
      PixelTiCommandField(
          key: 'tmToRebt', label: 'Tempo ate reiniciar (s, 0=imediato)', hint: '0', defaultValue: '0'),
    ],
  ),

  // ── Atualizacao (FOTA) ────────────────────────────────────────────────
  const PixelTiCommand(
    name: 'FOTA',
    label: 'Atualizar firmware via rede (FOTA)',
    category: 'Atualizacao (FOTA)',
    fields: [
      PixelTiCommandField(
          key: 'urlFt',
          label: 'URL do firmware',
          hint: 'http://servidor/fw_v123.bin:80'),
      PixelTiCommandField(key: 'userFt', label: 'Usuario (se exigido)', hint: ''),
      PixelTiCommandField(key: 'pwFt', label: 'Senha (se exigida)', hint: ''),
      PixelTiCommandField(
          key: 'protFt', label: 'Protocolo (0=HTTP,1=HTTPS,2=FTP,3=SFTP)', hint: '0', defaultValue: '0'),
    ],
  ),

  // ── Bateria ───────────────────────────────────────────────────────────
  const PixelTiCommand(
    name: 'PWMG',
    label: 'Configurar alertas de bateria',
    category: 'Bateria',
    fields: [
      PixelTiCommandField(
          key: 'mainLwTrhs', label: 'Bateria externa - minimo (mV)', hint: '10000', defaultValue: '10000'),
      PixelTiCommandField(
          key: 'mainHgTrhs', label: 'Bateria externa - maximo (mV)', hint: '90000', defaultValue: '90000'),
      PixelTiCommandField(
          key: 'bckLwTrhs', label: 'Bateria interna - minimo (mV)', hint: '3050', defaultValue: '3050'),
      PixelTiCommandField(
          key: 'bckHgTrhs', label: 'Bateria interna - maximo (mV)', hint: '4250', defaultValue: '4250'),
      PixelTiCommandField(
          key: 'trhsBounce', label: 'Debounce (s)', hint: '10', defaultValue: '10'),
      PixelTiCommandField(
          key: 'mainAct', label: 'Acao bateria externa (0/1)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'bckAct', label: 'Acao bateria interna (0-3)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'bckChrg', label: 'Recarga bateria interna (0-3)', hint: '0', defaultValue: '0'),
    ],
  ),

  // ── Velocidade ────────────────────────────────────────────────────────
  const PixelTiCommand(
    name: 'SPDA',
    label: 'Configurar alerta de excesso de velocidade',
    category: 'Velocidade',
    fields: [
      PixelTiCommandField(
          key: 'spdTrhs', label: 'Limite de velocidade (km/h)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'spdBounce', label: 'Debounce (s)', hint: '5', defaultValue: '5'),
      PixelTiCommandField(
          key: 'ioActSpd', label: 'Acao E/S (0-3)', hint: '0', defaultValue: '0'),
    ],
  ),

  // ── Bloqueio de configuracao ──────────────────────────────────────────
  const PixelTiCommand(
    name: 'LCKD',
    label: 'Bloquear/desbloquear configuracao',
    category: 'Bloqueio de config',
    fields: [
      PixelTiCommandField(key: 'apnLk', label: 'Bloquear APN (0/1)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(key: 'urlLk', label: 'Bloquear URL (0/1)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'paramLk', label: 'Bloquear tudo (0/1)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'curPassLk',
          label: 'Senha atual (8 ultimos digitos do IMEI)',
          hint: '62623655'),
    ],
  ),

  // ── Info do terminal ──────────────────────────────────────────────────
  PixelTiCommand(
    name: 'INFO',
    label: 'Consultar informacoes gerais do terminal',
    category: 'Info do terminal',
    fields: const [],
    readOnly: true,
  ),

  // ── E/S (GPIO, rele, buzzer) ─────────────────────────────────────────
  const PixelTiCommand(
    name: 'SDIO',
    label: 'Acionar saida digital (DOUT1/DOUT2)',
    category: 'E/S (GPIO, rele, buzzer)',
    fields: [
      PixelTiCommandField(
          key: 'gpio5Write', label: 'DOUT1 (0=Aberto, 1=Ativado)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'gpio6Write', label: 'DOUT2 (0=Aberto, 1=Ativado)', hint: '0', defaultValue: '0'),
    ],
  ),
  const PixelTiCommand(
    name: 'RELY',
    label: 'Acionar rele',
    category: 'E/S (GPIO, rele, buzzer)',
    fields: [
      PixelTiCommandField(
          key: 'relaySet', label: 'Rele (0=Aberto, 1=Ativado)', hint: '0', defaultValue: '0'),
    ],
  ),
  const PixelTiCommand(
    name: 'BUZR',
    label: 'Acionar buzzer',
    category: 'E/S (GPIO, rele, buzzer)',
    fields: [
      PixelTiCommandField(
          key: 'buzzerSet', label: 'Buzzer (0=Aberto, 1=Ativado)', hint: '0', defaultValue: '0'),
    ],
  ),
  PixelTiCommand(
    name: 'RDIO',
    label: 'Ler status de todas as E/S',
    category: 'E/S (GPIO, rele, buzzer)',
    fields: const [],
    readOnly: true,
  ),

  // ── Imobilizador ──────────────────────────────────────────────────────
  const PixelTiCommand(
    name: 'IMMB',
    label: 'Configurar imobilizador',
    category: 'Imobilizador',
    fields: [
      PixelTiCommandField(
          key: 'imbType',
          label: 'Tipo (0=Imediato,1=Pulsado,2=Baixa vel.,3=Ignicao off)',
          hint: '0',
          defaultValue: '0'),
      PixelTiCommandField(
          key: 'trigLog', label: 'Logica (0=Normal, 1=Invertida)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'tmPlsOn', label: 'Duracao pulso ligado (s)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'tmPlsOff', label: 'Duracao pulso desligado (s)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'totPlsTm', label: 'Duracao total do pulso (s)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'lwSpdThres', label: 'Limite de velocidade p/ bloqueio (km/h)', hint: '5', defaultValue: '5'),
      PixelTiCommandField(
          key: 'lwSpdBounce', label: 'Tempo min. abaixo do limite (s)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'buzAct', label: 'Buzzer antes do bloqueio (s, 255=junto)', hint: '0', defaultValue: '0'),
    ],
  ),

  // ── Cerca eletronica ──────────────────────────────────────────────────
  const PixelTiCommand(
    name: 'CGFS',
    label: 'Configurar cerca eletronica (circulo/retangulo)',
    category: 'Cerca eletronica',
    fields: [
      PixelTiCommandField(
          key: 'idxCoord', label: 'Indice da cerca (0-3, ex: 0:0)', hint: '0:0'),
      PixelTiCommandField(
          key: 'latLst', label: 'Latitude (ex: -23.550520)', hint: '-23.550520'),
      PixelTiCommandField(
          key: 'longLst', label: 'Longitude (ex: -46.633308)', hint: '-46.633308'),
      PixelTiCommandField(key: 'rdsLst', label: 'Raio em metros', hint: '300'),
      PixelTiCommandField(
          key: 'evtTrigLst',
          label: 'Gatilho (0=Off,1=Entrar,2=Sair,3=Ambos)',
          hint: '3',
          defaultValue: '3'),
      PixelTiCommandField(
          key: 'ioActLst', label: 'Acao E/S (0-3)', hint: '0', defaultValue: '0'),
    ],
  ),

  // ── Jammer ────────────────────────────────────────────────────────────
  const PixelTiCommand(
    name: 'JAMM',
    label: 'Configurar deteccao de jammer',
    category: 'Jammer',
    fields: [
      PixelTiCommandField(
          key: 'jamSense',
          label: 'Sensibilidade (0=Off,1=Alta,2=Baixa)',
          hint: '1',
          defaultValue: '1'),
      PixelTiCommandField(
          key: 'atkTm', label: 'Tempo p/ confirmar ataque (s)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'gsenFlag',
          label: 'Ativo quando (0=Movimento,1=Parado,2=Ambos)',
          hint: '2',
          defaultValue: '2'),
      PixelTiCommandField(
          key: 'blkTm', label: 'Duracao do bloqueio (s)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'jamEvt', label: 'Eventos a enviar (0-3)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'jamIoAct', label: 'Acao E/S durante ataque (0-3)', hint: '0', defaultValue: '0'),
    ],
  ),

  // ── Movimento indevido ────────────────────────────────────────────────
  const PixelTiCommand(
    name: 'IPMA',
    label: 'Configurar chacoalhada e reboque',
    category: 'Movimento indevido',
    fields: [
      PixelTiCommandField(
          key: 'shkTm', label: 'Tempo p/ confirmar chacoalhada (s)', hint: '3', defaultValue: '3'),
      PixelTiCommandField(
          key: 'shkIoAct', label: 'Acao E/S chacoalhada (0-3)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'shkRecTm', label: 'Duracao apos parar (s)', hint: '5', defaultValue: '5'),
      PixelTiCommandField(
          key: 'twgRds', label: 'Raio p/ considerar reboque (m)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'twgIoAct', label: 'Acao E/S reboque (0-3)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'twgRecTm', label: 'Duracao apos parar (s)', hint: '30', defaultValue: '30'),
    ],
  ),

  // ── RS232 ─────────────────────────────────────────────────────────────
  const PixelTiCommand(
    name: 'S232',
    label: 'Configurar porta RS232',
    category: 'RS232',
    fields: [
      PixelTiCommandField(
          key: 'baud232', label: 'Baud rate (6=115200)', hint: '6', defaultValue: '6'),
      PixelTiCommandField(
          key: 'data232', label: 'Bits de dados (1=8 bits)', hint: '1', defaultValue: '1'),
      PixelTiCommandField(
          key: 'parit232', label: 'Paridade (0=Nenhum)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'stop232', label: 'Bit de parada (1=1 bit)', hint: '1', defaultValue: '1'),
      PixelTiCommandField(
          key: 'flw232', label: 'Controle de fluxo (0=Nenhum)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'sndCond232', label: 'Condicao de envio (0=Timeout)', hint: '0', defaultValue: '0'),
      PixelTiCommandField(
          key: 'sndConf232', label: 'Valor da condicao (s ou char)', hint: '0'),
    ],
  ),

  // ── Seguranca ─────────────────────────────────────────────────────────
  const PixelTiCommand(
    name: 'SCRT',
    label: 'Trocar senha de bloqueio',
    category: 'Seguranca',
    fields: [
      PixelTiCommandField(
          key: 'curPwLk', label: 'Senha atual (8 ultimos digitos do IMEI)', hint: '62623655'),
      PixelTiCommandField(key: 'newPwLk', label: 'Nova senha (8 caracteres)', hint: ''),
      PixelTiCommandField(key: 'simPin1', label: 'PIN do SIM 1 (opcional)', hint: ''),
      PixelTiCommandField(key: 'simPin2', label: 'PIN do SIM 2 (opcional)', hint: ''),
      PixelTiCommandField(key: 'whtListSms', label: 'Lista branca SMS (opcional)', hint: ''),
      PixelTiCommandField(key: 'indListSms', label: 'Indice da lista (ex: 0:0)', hint: ''),
      PixelTiCommandField(
          key: 'smsMod', label: 'Modo SMS (0=Qualquer,1=Somente lista)', hint: '0', defaultValue: '0'),
    ],
  ),
];
