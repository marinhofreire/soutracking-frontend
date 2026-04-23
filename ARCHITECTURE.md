# SouAssist (SouInnova) — Arquitetura

## Objetivo
Evoluir o app Flutter existente do Soutracking para plataforma SaaS white-label **sem refazer o módulo de tracking**.

## Princípios não negociáveis aplicados
- O tracking atual foi preservado (telas, fluxo e navegação base).
- O `MapBackground` continua como plano de fundo da aplicação.
- A sidebar lateral (abre/fecha) continua no `HomeShell`.
- Menus e submenus do tracking continuam ativos.

## Onde está cada peça principal
- Menu/sidebar/drawer: [lib/features/home/home_shell.dart](lib/features/home/home_shell.dart)
- Rotas: [lib/core/app_router.dart](lib/core/app_router.dart)
- Mapa principal: [lib/widgets/map_background.dart](lib/widgets/map_background.dart) + uso em [lib/features/home/home_shell.dart](lib/features/home/home_shell.dart)
- Sessão + tenant + feature flags: [lib/state/session_state.dart](lib/state/session_state.dart) e [lib/core/tenant_config.dart](lib/core/tenant_config.dart)
- White-label dinâmico: [lib/core/white_label.dart](lib/core/white_label.dart), aplicado em [lib/main.dart](lib/main.dart)

## Refatoração mínima aplicada
Sem reescrever tracking, a organização segue por módulos funcionais em `lib/features`:
- `tracking` (existente, preservado): `map`, `dashboard`, `vehicles`, `events`, `reports`, etc.
- `assist` (novo SaaS): chamados, criação, detalhe e controle operacional.
- `mdvr` (novo SaaS): dispositivos e detalhe de câmeras.
- `admin` (novo SaaS): gestão de empresas/tenant.

No módulo `assist`, o estado local agora possui sincronização com backend multi-tenant via serviço dedicado (`AssistDemandApiService`) com fallback seguro.

A composição dos menus ocorre em `HomeShell` usando feature flags por tenant.

## Feature Flags por tenant (em produção SaaS)
No login:
1. App autentica no backend/Traccar.
2. Busca config do tenant (`getTenantConfig`).
3. Carrega `TenantConfig.modules`.
4. Sidebar mostra/esconde seções por `tenant.isFeatureEnabled(...)`.

Módulos esperados:
- `tracking`
- `assist`
- `demand`
- `mdvr`
- `zpro`
- `admin`

## Rotas SaaS implementadas
- `/assist/requests`
- `/assist/create`
- `/assist/request/:id`
- `/mdvr/devices`
- `/mdvr/device/:id`

Todas registradas em `appOnGenerateRoute`.

## Integração MDVR/CMS externo
Estratégia atual no Flutter:
- Lista dispositivos e links de câmera.
- Abertura de imagem/live via URL.
- Detalhe por dispositivo com canais e aviso para RTSP quando necessário gateway HLS/WebRTC.

## Arquivos alterados nesta evolução
- [lib/core/app_router.dart](lib/core/app_router.dart)
  - Inclusão de rotas nomeadas faltantes para Assist/MDVR.
  - Surface padrão para telas acessadas por rota (`_RoutedSurface`).
  - Ajuste de PIN padrão privado para `souassist123`.
- [lib/features/mdvr/mdvr_devices_screen.dart](lib/features/mdvr/mdvr_devices_screen.dart)
  - Navegação para detalhe dinâmico `/mdvr/device/:id`.
- [lib/features/assist/assist_dispatch_state.dart](lib/features/assist/assist_dispatch_state.dart)
  - Controller passou a sincronizar demandas com backend (bootstrap, upsert e snapshot), preservando a UI.
- [lib/features/assist/assist_demand_api_service.dart](lib/features/assist/assist_demand_api_service.dart)
  - Serviço de integração API para listar/sincronizar chamados por tenant.
- [lib/features/assist/assist_demand_api_contract.dart](lib/features/assist/assist_demand_api_contract.dart)
  - Contrato de paths/versionamento v1 consumido pelo app.
- [docs/openapi/souassist-demands-v1.yaml](docs/openapi/souassist-demands-v1.yaml)
  - Especificação OpenAPI do módulo de demandas (produção).

## Estrutura de pastas sugerida (incremental)
```text
lib/
  core/
    app_router.dart
    tenant_config.dart
    white_label.dart
  state/
    session_state.dart
  features/
    tracking/            # (gradual) wrappers dos módulos atuais de rastreamento
    assist/
    mdvr/
    admin/
    home/
```

## Riscos e mitigação
- Risco: regressão de navegação no tracking.
  - Mitigação: nenhuma remoção de tela/fluxo existente; alterações isoladas em rotas extras.
- Risco: tenant sem config.
  - Mitigação: fallback seguro em `TenantConfig.fallback`.
