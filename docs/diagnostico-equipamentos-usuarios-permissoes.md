# Diagnóstico — Equipamentos, Ícones e Permissões

Documento interno de leitura técnica. Nesta rodada não houve alteração de layout, criação de tela, build ou mudança funcional.

## 1. Equipamentos/Veículos

| recurso | existe hoje? | arquivo/função | observação | o que falta |
|---|---|---|---|---|
| Tela de gestão de equipamentos | sim | `lib/features/devices/devices_screen.dart` / `DevicesScreen` | Tela operacional real com listagem, filtros, exportação, criação e edição. | Consolidar regras de negócio e permissões por ação. |
| Cadastro de equipamento | sim | `devices_screen.dart` / `_openDeviceDialog`, `_createDevice` | Dialog de “Novo equipamento” com gravação real via API. | Campos de negócio adicionais, validações melhores e escolha explícita de ícone. |
| Edição de equipamento | sim | `devices_screen.dart` / `_openDeviceDialog(editing:)`, `_updateDevice` | Edição real via `updateEntityById('/devices/:id')`. | Separar edição operacional de edição comercial e revisar controle de acesso. |
| Botão adicionar equipamento | sim | `devices_screen.dart` / `_TopActionButton('Novo Equipamento')` | Botão abre o dialog de cadastro. | Nada estrutural, apenas permissão por perfil/ação. |
| Botão editar equipamento | sim | `devices_screen.dart` / `_DevicesTable` / `onEdit` | Ações “Ver detalhes”, “Editar” e “Mais” chamam o mesmo fluxo de edição. | Diferenciar visualizar, editar e ações extras. |
| Exclusão de equipamento pela UI | não | sem fluxo específico em `devices_screen.dart` | O cliente HTTP tem `deleteEntity`, mas a tela de equipamentos não usa exclusão. | Criar fluxo específico de exclusão com confirmação e permissão. |
| Chamada API para criar equipamento | sim | `lib/data/traccar_client.dart` / `createDevice` | `POST /api/devices`. | Padronizar payload ampliado para negócio SouTracking. |
| Chamada API para editar equipamento | sim | `traccar_client.dart` / `updateEntityById`; `devices_screen.dart` / `_updateDevice` | `PUT /api/devices/:id`. | Encapsular edição de device em método dedicado se quiser reduzir payload solto. |
| Chamada API para excluir equipamento | parcial | `traccar_client.dart` / `deleteEntity` | Método genérico existe, mas sem uso específico para devices. | Criar fluxo específico e verificar impacto em vínculos/permissões. |
| Associação equipamento → usuário | parcial | `lib/features/permissions/permissions_screen.dart` / `_createBinding`; `traccar_client.dart` / `createEntity` | Cria vínculo real em `/api/permissions` com `userId` e `deviceId`. | Expor isso de forma integrada no cadastro/edição do equipamento. |
| Tela de veículos | parcial | `lib/features/vehicles/vehicles_screen.dart` / `VehiclesScreen` | Tela existe, mas é uma visão operacional da frota, não um CRUD real de veículos. | Decidir se “veículo” será só leitura do device ou um cadastro próprio. |
| Cadastro de veículo | parcial | `vehicles_screen.dart` / `_VehiclesPageHeader` | Botão “Adicionar veículo” existe, mas só mostra snackbar “Cadastro visual de veículo em ajuste.” | Implementar fluxo real ou remover duplicidade com equipamentos. |
| Edição de veículo | não | sem função de edição real em `vehicles_screen.dart` | A tela mostra lista e detalhes inline, sem salvar edição. | Definir se edição será na tela de equipamentos ou em módulo próprio. |
| Campo nome | sim | `devices_screen.dart` / `_nameController` | Gravado em `name`. | Nada estrutural. |
| Campo IMEI / ID / Unique ID | sim | `devices_screen.dart` / `_identifierController` | Gravado em `uniqueId`. | Validar formato por tipo de rastreador. |
| Campo tipo/categoria | sim | `devices_screen.dart` / `_categoryController` | Gravado em `category`. Também é base para leitura de tipo no mapa. | Normalizar taxonomia para não depender de texto livre. |
| Campo telefone/chip | sim | `devices_screen.dart` / `_phoneController` | Gravado em `phone` e `attributes.phone`. | Definir se o campo é obrigatório para certos equipamentos. |
| Campo placa separado | não | `vehicles_screen.dart` / `identifier` | A UI de veículos tenta ler placa de `uniqueId` ou `attributes.plate*`, mas o cadastro atual não tem campo próprio. | Criar campo estruturado de placa se isso for requisito real. |
| Campo ícone escolhido pelo usuário | não | inexistente no CRUD atual | Hoje não há campo persistido para ícone no cadastro/edição. | Adicionar campo estruturado, persistência e leitura no mapa. |
| Campo cliente/usuário vinculado dentro do cadastro | não | inexistente no dialog de device | O vínculo a usuário existe em `PermissionsScreen`, fora do cadastro do equipamento. | Integrar seleção de usuário/cliente no fluxo do equipamento. |
| Campo ativo/inativo | parcial | `TraccarDevice.status`, `TraccarUser.disabled` | Equipamentos leem `status` operacional da API, mas o cadastro não expõe um “ativo/inativo” editável. | Definir se o estado será operacional, cadastral ou ambos. |
| Sensores configuráveis no cadastro | sim | `devices_screen.dart` / `_selectedSensorKeys`, `souSensors` | Já salva lista de sensores em `attributes.souSensors`. | Aproveitar o mesmo padrão para salvar tipo/ícone no futuro. |

## 2. Ícones do mapa

| recurso | existe hoje? | arquivo/função | observação | o que falta |
|---|---|---|---|---|
| Pasta de ícones de mapa | sim | `assets/icons/map/` | PNGs reais para `car`, `motorcycle`, `truck`, `bus`, `van`, `pickup`, `tractor`, `crane`, `offroad`, `bicycle`, `boat`, `ship`, `scooter`, `person`, `default`. | Governança por cliente ou catálogo administrável. |
| Registro no projeto | sim | `pubspec.yaml` / `assets/icons/map/` | Pasta está registrada como asset do Flutter. | Nada estrutural. |
| Enum de tipos de marcador | sim | `lib/features/home/home_shell.dart` / `_VehicleMarkerType` | O tipo do ícone é mapeado para arquivos PNG. | Ligar isso a dado persistido do equipamento. |
| Geração visual do marcador | sim | `home_shell.dart` / `_loadVehicleMarkerIcons`, `_buildVehicleMarkerIconBytes` | O marcador é composto com asset do veículo + borda/ponto de status. | Permitir sobrescrita por preferência do cliente/equipamento. |
| Escolha do ícone por status | sim | `home_shell.dart` / `_VehicleOperationalStatus`, `markerIconKey` | Status influencia borda/cor do marcador. | Centralizar regra de status para evitar divergência com outras telas. |
| Escolha do ícone por tipo | sim | `home_shell.dart` / `_VehicleSnapshot` | O mapa escolhe ícone por categoria/tipo/modelo/nome do equipamento. | Parar de depender só de inferência textual. |
| Campo salvo no equipamento para ícone | não | `TraccarDevice` não expõe `mapIcon` ou equivalente | O modelo tem `category`, `image` e `attributes`, mas o fluxo atual não grava nem lê chave dedicada de ícone do mapa. | Definir chave canônica, por exemplo em `attributes`. |
| Campo `image` no modelo | parcial | `lib/data/models.dart` / `TraccarDevice.image` | O modelo aceita `image/photo`, mas o mapa atual não usa esse campo para escolher marcador. | Decidir se `image` será aproveitado ou se haverá chave própria para ícone de mapa. |
| Escolha manual de ícone pelo usuário | não | inexistente no CRUD atual | Não existe seletor no cadastro/edição. | Criar campo estruturado de seleção e persistência. |
| Detecção automática por nome/tipo | sim | `home_shell.dart` / lógica de `_VehicleSnapshot` | Hoje é a estratégia principal. Funciona, mas depende de textos livres e aliases. | Criar prioridade: escolha manual > categoria padronizada > inferência. |
| Suporte futuro a white-label por cliente | parcial | estrutura atual de assets + white-label geral | O código já separa assets e a geração do ícone está encapsulada. | Falta camada de configuração por tenant/cliente/equipamento. |

## 3. Usuários e permissões

| recurso | existe hoje? | arquivo/função | observação | o que falta |
|---|---|---|---|---|
| Estado do usuário logado | sim | `lib/state/session_state.dart` / `SessionState`, `SessionController` | Guarda `status`, `email`, `cookie`, `authHeader`, `tenantConfig`, `profileCode`, `isAdministrator`. | Expor claims/permissões mais granulares se a API suportar. |
| Sessão persistida localmente | sim | `session_state.dart` / `_persistSession`, `_restoreSession` | Sessão fica em `SharedPreferences`. | Validar expiração e invalidação por mudança de perfil/permissão. |
| Perfil/role | sim | `session_state.dart` / `_inferProfileCode`, `_normalizeProfileCode` | Perfis como `MA`, `AE`, `SO`, `OM`, `SAC`, `TEC`, `COM`, `FIN`, `EST`, `GC`, `CF`. | Garantir que toda UI relevante realmente use `profileCode`. |
| Módulos/permissões vindos da API | parcial | `session_state.dart` / `_extractUserModules`, `_mergeTenantConfigWithUser` | O estado já tenta ler `modules`, `features`, `permissions` e atributos do usuário. | Consumir isso de forma efetiva nos módulos, não só na sessão. |
| Tela de usuários | sim | `lib/features/users/users_screen.dart` | Lista usuários e cria usuário novo via API. | Edição, exclusão e vínculo mais rico. |
| Cadastro de usuário | sim | `users_screen.dart` / `_openCreateUserDialog`, `_createUser` | Cria usuário real via `createUser`. | Revisar permissões para quem pode criar e editar usuários. |
| Edição de usuário | não | sem fluxo real na tela | Há ícones de ação, mas sem implementação funcional. | Implementar edição real. |
| Exclusão de usuário | não | sem fluxo real na tela | Não há ação funcional para excluir. | Implementar exclusão/bloqueio se necessário. |
| Tela de perfis de usuário | parcial | `lib/features/users/user_profiles_screen.dart` | Resume perfis derivados dos usuários e abre diálogo informativo. | Persistência e edição real de perfis/policies. |
| Tela de permissões | parcial | `lib/features/permissions/permissions_screen.dart` | Permite escolher usuário, ver vínculos reais e ajustar uma matriz visual local. | Persistir matriz de ações reais; hoje só o vínculo é salvo. |
| Vínculo usuário → equipamento | sim | `permissions_screen.dart` / `_createBinding`; `permissionsProvider` | Cria relacionamento real em `/permissions`. | Exibir, remover e editar vínculos de forma completa. |
| Remoção de vínculo usuário → equipamento | não | sem fluxo na tela de permissões | Só existe criação do vínculo. | Implementar exclusão em `/permissions/:id` ou rota equivalente. |
| Permissão por menu lateral | parcial | `lib/features/home/home_shell.dart` / `_filterMenuForSession` | O filtro atual é efetivo só para modo Pixel/demo. | Aplicar role/modules/policies também no fluxo real. |
| Permissão por ação (view/create/edit/delete) | parcial | `permissions_screen.dart` / `_PermissionState`, `menu_master_config.dart` / `MenuAction` | Existe estrutura visual e conceitual para ações. | Persistir e aplicar no runtime. |
| Bloqueio real para cadastrar/editar/excluir equipamentos | parcial | `devices_screen.dart` / `_friendlyError` | Hoje o bloqueio real depende do backend responder `403`; a UI não faz guarda preventiva robusta. | Criar guardas locais por perfil/ação antes do submit. |
| Permissões por rota | não/parcial | `lib/core/app_router.dart` | Rotas formais existem só para Assist/MDVR; não há guarda de autorização geral ali. | Centralizar guards se mais módulos passarem a usar rotas. |
| Config declarativa de menu/políticas | parcial | `lib/features/home/menu/menu_master_config.dart`, `assets/config/menu_master.json` | Existe modelo rico com `visibleProfiles`, `actionPolicyRef` e `MenuAction`. | Integrar de fato com a sidebar atual e com as ações da UI. |

## 4. Riscos

- Duplicidade entre “veículos” e “equipamentos”: hoje `vehicles_screen` é leitura operacional e `devices_screen` é o CRUD real. Implementar cadastro em ambos pode criar conflito de fonte da verdade.
- Tipo/categoria ainda é texto livre: a escolha automática de ícone depende de nome, categoria, modelo e aliases. Sem taxonomia fechada, o usuário pode salvar categorias inconsistentes.
- Permissões estão fragmentadas: sessão conhece `profileCode` e módulos, `permissions_screen` salva vínculo real `userId/deviceId`, e a matriz de ações ainda é só visual/local.
- O menu declarativo em `menu_master.json` parece mais maduro que o filtro efetivo atual da sidebar, mas ainda não governa a navegação operacional principal.
- Falta política clara para “ativo/inativo” do equipamento: hoje existe `status` operacional da API, mas não um estado cadastral separado.
- O modelo `TraccarDevice` aceita `image`, mas o mapa atual usa assets locais por inferência. Introduzir seleção de ícone sem decidir a chave oficial pode gerar mais uma fonte paralela.
- A UI de equipamentos já grava `attributes.souSensors`; isso é bom como padrão, mas qualquer nova chave de ícone precisa ser documentada para não virar atributo solto.
- O backend é a barreira real de autorização em várias ações. Sem guardas locais, o usuário pode ver botão de ação que só falha no submit.

## 5. Primeira missão segura

A primeira implementação pequena e segura depois deste diagnóstico deve ser:

**Adicionar um campo estruturado de tipo/ícone no cadastro e edição de equipamentos, sem ainda mexer em permissões complexas.**

Motivo:

- O CRUD real já existe em `devices_screen.dart`.
- O mapa já tem catálogo de ícones e regra de renderização pronta.
- Dá para evoluir com baixo impacto seguindo uma ordem segura:
  1. definir a chave persistida do equipamento para tipo/ícone;
  2. adicionar seleção controlada no dialog de equipamento;
  3. fazer o mapa priorizar essa escolha manual antes da inferência automática.

Isso fecha a lacuna mais direta entre cadastro e mapa sem abrir, no mesmo passo, a complexidade maior de perfis, políticas e remoção de vínculos.
