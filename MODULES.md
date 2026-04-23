# SouAssist (SouInnova) — Módulos

## 1) TrackingModule (preservado)
Status: **mantido sem refactor destrutivo**.

Escopo existente:
- Mapa operacional, dashboard, dispositivos, grupos, motoristas, manutenção.
- Eventos, notificações, comandos, geofences, relatórios, administração de tracking.

Arquivos-chave:
- [lib/features/home/home_shell.dart](lib/features/home/home_shell.dart)
- [lib/features/map/map_screen.dart](lib/features/map/map_screen.dart)
- [lib/widgets/map_background.dart](lib/widgets/map_background.dart)

## 2) AssistModule (SouAssist Demandas)
Status: **ativo**.

Rotas:
- `/assist/requests`
- `/assist/create`
- `/assist/request/:id`

Arquivos:
- [lib/features/assist/assist_requests_screen.dart](lib/features/assist/assist_requests_screen.dart)
- [lib/features/assist/assist_create_request_screen.dart](lib/features/assist/assist_create_request_screen.dart)
- [lib/features/assist/assist_request_detail_screen.dart](lib/features/assist/assist_request_detail_screen.dart)
- [lib/features/assist/assist_dispatch_state.dart](lib/features/assist/assist_dispatch_state.dart)
- [lib/features/assist/assist_demand_api_service.dart](lib/features/assist/assist_demand_api_service.dart)
- [lib/features/assist/assist_demand_api_contract.dart](lib/features/assist/assist_demand_api_contract.dart)
- [docs/openapi/souassist-demands-v1.yaml](docs/openapi/souassist-demands-v1.yaml)

Cobertura funcional atual:
- Tipos de chamado (incluindo vistoria com dossiê/checklist)
- Fluxo de criação/despacho/aceite/status
- Regras operacionais de rodada e parceiro
- Sincronização com backend por tenant (bootstrap + upsert + snapshot com fallback)

## 3) MdvrModule (CMS externo)
Status: **ativo**.

Rotas:
- `/mdvr/devices`
- `/mdvr/device/:id`

Arquivos:
- [lib/features/mdvr/mdvr_devices_screen.dart](lib/features/mdvr/mdvr_devices_screen.dart)
- [lib/features/mdvr/mdvr_device_detail_screen.dart](lib/features/mdvr/mdvr_device_detail_screen.dart)

Cobertura funcional atual:
- Lista de dispositivos
- Acesso a imagem/live por URL
- Detalhe por dispositivo com canais e live/playback
- Aviso RTSP quando exigir gateway

## 4) AdminModule (SaaS)
Status: **ativo (mínimo)**.

Arquivo:
- [lib/features/admin/admin_tenants_screen.dart](lib/features/admin/admin_tenants_screen.dart)

Uso:
- Exibido por feature flag `admin` no tenant.

## 5) Multi-tenant + Feature Flags
Fonte de verdade:
- [lib/state/session_state.dart](lib/state/session_state.dart)
- [lib/core/tenant_config.dart](lib/core/tenant_config.dart)

Comportamento:
- Após login, app busca tenant config.
- Features habilitam/desabilitam itens no menu.
- Branding aplicado dinamicamente (nome, cores, identidade).

## Mudanças desta entrega (arquivos e por quê)
- [lib/core/app_router.dart](lib/core/app_router.dart)
  - Registradas rotas faltantes de Assist e MDVR para suportar deep-link e navegação nomeada.
- [lib/features/mdvr/mdvr_devices_screen.dart](lib/features/mdvr/mdvr_devices_screen.dart)
  - Adicionado botão `Detalhe` para abrir `/mdvr/device/:id`.
- [lib/features/assist/assist_dispatch_state.dart](lib/features/assist/assist_dispatch_state.dart)
  - Integração da camada de estado com API de demandas sem quebrar telas existentes.
- [lib/features/assist/assist_demand_api_service.dart](lib/features/assist/assist_demand_api_service.dart)
  - Cliente de sincronização para endpoints de demandas multi-tenant.
- [lib/features/assist/assist_demand_api_contract.dart](lib/features/assist/assist_demand_api_contract.dart)
  - Centralização de contrato de endpoints v1 + fallback legado controlado.
- [docs/openapi/souassist-demands-v1.yaml](docs/openapi/souassist-demands-v1.yaml)
  - Documento de contrato para backend/app seguirem o mesmo padrão.
- [ARCHITECTURE.md](ARCHITECTURE.md)
  - Documento técnico consolidando arquitetura e decisões.
- [MODULES.md](MODULES.md)
  - Catálogo de módulos, rotas e estado atual.
