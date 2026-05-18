# SouTracking - Auditoria Geral Frontend/API

Data da auditoria: 2026-05-14
Escopo: leitura de codigo + comandos de analise/build + checagem API somente leitura

## Regras aplicadas
- Nao alterado codigo de app.
- Nao alterado backend/Traccar.
- Nao executado comando destrutivo (delete real nao testado na API).
- Nao criado usuario real.
- Nao enviados comandos reais para rastreador durante esta auditoria.

## Evidencias de execucao

### 1) Flutter analyze (geral)
Comando:
`C:\src\flutter\bin\flutter.bat analyze`

Resultado: FALHOU (38 issues).
Principais erros bloqueantes (preexistentes):
- `lib/main-MARINHO-OFFICE.dart` com experimento `dot-shorthands` nao habilitado.
- `test/widget_test-MARINHO-OFFICE.dart` import invalido (`package:mackflutter/main.dart`).
- `test/widget_test.dart` referencia `SoutrackingApp` indefinida.

### 2) Build web producao
Comando:
`C:\src\flutter\bin\flutter.bat build web --target lib/main.dart --dart-define=USE_MOCK_API=false --dart-define=PRESENTATION_MODE=false --dart-define=PIXELTI_PILOT=false --dart-define=API_ORIGIN=http://api.soutracking.com.br`

Resultado: PASSOU (`Built build\\web`).

### 3) Build web PixelTI
Comando:
`C:\src\flutter\bin\flutter.bat build web --target lib/main.dart --dart-define=USE_MOCK_API=false --dart-define=PRESENTATION_MODE=false --dart-define=PIXELTI_PILOT=true --dart-define=API_ORIGIN=http://api.soutracking.com.br`

Resultado: PASSOU (`Built build\\web`).

## Validacao API somente leitura

### Bloco autenticado solicitado
Comando falhou por credenciais de ambiente ausentes:
- `SOUTRACKING_ADMIN_EMAIL`
- `SOUTRACKING_ADMIN_PASS`

Mensagem retornada:
`Defina SOUTRACKING_ADMIN_EMAIL e SOUTRACKING_ADMIN_PASS antes de rodar.`

### Checagem de superficie sem credenciais
- `GET /api/devices` => 401
- `GET /api/positions` => 401
- `GET /api/reports/events` => 401
- `GET /api/commands/types` => 401
- `GET /api/geofences` => 401
- `GET /api/users` => 401
- `POST /api/session` com credenciais invalidas => 401

Leitura: endpoints estao publicados e protegidos por autenticacao.

## Mapeamento de menus/submenus
A matriz detalhada esta em:
- `docs/soutracking-matriz-funcional.csv`

## Endpoints reais encontrados no frontend
- `/api/session`
- `/api/devices`
- `/api/positions`
- `/api/users`
- `/api/groups`
- `/api/geofences`
- `/api/notifications`
- `/api/permissions`
- `/api/maintenance`
- `/api/commands`
- `/api/commands/types`
- `/api/commands/send`
- `/api/reports/events`
- `/api/reports/route`
- `/api/reports/trips`
- `/api/reports/stops`
- `/api/reports/summary`
- `/api/server`
- `/api/server/timezones`
- `/api/server/geocode`
- `/api/attributes/computed`
- `/api/statistics`
- `/api/orders`
- `/api/calendars`

## Foco Alertas (telemetria real)
Implementacao atual em `alerts_screen.dart` + `alert_models.dart`:
- Exibe no card/tabela:
  - tipo do evento
  - veiculo
  - data/hora
  - severidade/status
  - lat/lng
  - velocidade (knots -> km/h)
  - ignicao
  - bateria
  - endereco
  - resumo de `attributes`
- `attributes` prioriza chaves:
  - `alarm`, `motion`, `result`, `odometer`, `totalDistance`, `sat`, `rssi`, `geofenceName`, `geofence`, `fuel`, `temperature`

Gaps para telemetria de alerta (ainda nao dedicado por campo):
- `gsm/rssi` aparece apenas se vier em attributes summary.
- `engineHours`, `inputs`, `outputs`, `externalPower`, `blocked` nao possuem coluna dedicada.
- endereco depende de payload (`address`/`geocoder`), sem reverse lookup complementar no modulo Alertas.

## Foco Comandos (sem envio real na auditoria)
Existente no front:
- Lista de comandos: `/api/commands` (provider `commandsProvider`).
- Envio de comando: `/api/commands/send` (CommandsScreen + aba de veiculo no HomeShell).
- Tipos de comando da API: `/api/commands/types` (provider existe, mas nao esta plugado na tela de envio).

Campos obrigatorios observados para envio atual:
- `deviceId`
- `type`
- `attributes.data` apenas para `custom`

Controles de seguranca atuais:
- Existe confirmacao modal antes do envio em ambas as telas.

Gaps/riscos:
- Tipos exibidos na UI sao estaticos, nao dinamicos da API.
- Historico de envio/resultado nao esta consolidado (sem trilha dedicada de commandResult).
- Risco operacional de envio acidental permanece (apenas 1 confirmacao).

## Foco Relatorios
Relatorios com chamada real:
- Eventos: `/api/reports/events`
- Rotas: `/api/reports/route`
- Viagens: `/api/reports/trips`
- Paradas: `/api/reports/stops`
- Resumo: `/api/reports/summary`

Filtros existentes:
- periodo
- tipo
- veiculo
- motorista
- status

Exportacoes:
- Botao "Exportar" apenas feedback de UI (nao gera arquivo).
- Icone PDF e icone Excel na tabela sem implementacao de download.
- Exportacao HTML inexistente.

## Duplicidades de menu observadas
- `Rotas` aparece como menu proprio e tambem em `Relatorios` (entrada "Rotas").
- `Dispositivos` aparece no menu lateral e tambem em `Configuracoes`.
- `Usuarios` e `Permissoes` aparecem como submenus de `Configuracoes` apesar de uso operacional proprio.
- Funcionalidades reais ja existentes em telas entram como "placeholder" em alguns paineis (ex.: Cercas/Relatorios).

## Classificacao geral (resumo)

### P0 (impede piloto/cliente)
1. Relatorios sem exportacao real (PDF/Excel/HTML).
2. Modulos mock expostos no modo completo (Chamados/Financeiro/Estoque/Drivers/Clients) podem confundir cliente.
3. Permissoes: botao "Salvar Permissoes" sem persistencia real (apenas feedback visual).
4. Comandos: envio real com lista de tipos estatica e sem trilha robusta de historico.

### P1 (importante operacional)
1. Cercas: editar ainda placeholder; cria/exclui existem.
2. Manutencao: tela existe com CRUD parcial, mas nao esta ligada no menu.
3. MDVR: menu principal aponta para demo; telas reais de MDVR existem em rotas separadas.
4. Alertas: varias telemetrias aparecem apenas no summary de attributes, sem colunas dedicadas.

### P2 (visual/usabilidade)
1. Textos com encoding quebrado em alguns labels (mojibake).
2. Inconsistencia entre card placeholder e funcionalidade real em telas internas.

### P3 (futuro)
1. IA Operacional inteira placeholder.
2. Demo Telemetria com fallback snapshot e proposta demonstrativa.

## Menus prontos (minimo funcional)
- Rotas (historico + replay visual)
- Alertas (eventos reais + telemetria principal)
- Dispositivos (listar + criar)
- Usuarios (listar + criar)
- Grupos (listar + criar + excluir)
- Notificacoes (listar + criar + excluir)
- Cercas (listar + criar + excluir)
- MDVR (rotas dedicadas: listar/detalhar dispositivo)

## Menus casca/mock (predominante)
- IA Operacional
- Chamados (CallsRepository mock + Bridge mock)
- Financeiro (repository mock)
- Estoque (repository mock)
- Motoristas/Clientes (repositories mock)
- Submenus placeholders em Dashboard/Mapa/Veiculos/Rotas/Relatorios/Comunicacao

## Primeiro menu recomendado para correcao
Relatorios.
Motivo: impacto direto em cliente (exportacao PDF/Excel/HTML), dependencia de entrega comercial e alto valor de homologacao.
