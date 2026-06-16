# SouTracking Front Status - 2026-06-12

## Estado geral

- Base operacional: `lib/features/home/home_shell.dart`
- Layout: preservado
- Deploy/producao: nao alterados

## Modulos funcionais

- `Mapa`: funcional com polling leve de 10s para `devices`, `positions` e `latestEvents`
- `Dashboard`: funcional com dados reais do tracking
- `Equipamentos`: funcional
- `Alertas`: funcional/parcial
- `Manutencao`: funcional/parcial
- `Relatorios`: funcional/parcial, com PDF ainda bloqueado

## Modulos parciais

- `Comunicacao`: usa comandos/notificacoes reais do tracking, mas ainda nao e chat bidirecional completo
- `MDVR`: lista/dispositivo ativos, mas player/live/historico dependem de gateway/API especificos
- `Permissoes`: vinculo usuario-dispositivo persiste; matriz completa ainda depende de backend

## Modulos em implantacao

- `Chamados`: repositorio atual ainda em mock
- `Financeiro`: repositorio atual ainda em mock
- `Estoque`: repositorio atual ainda em mock

## Ajustes desta fase

- Polling do mapa em `lib/features/home/home_shell.dart`
- Filtro do menu operacional por perfil/feature flag em `lib/features/home/home_shell.dart`
- Catalogo de RBAC em `lib/features/home/menu/menu_master_config.dart` com regra real por perfil, feature, tenant e backend pendente
- Mensagem honesta para `Esqueceu sua senha?` em `lib/features/login/login_screen.dart`
- Bloqueios honestos em `Permissoes`, `Cercas`, `Comunicacao`, `Chamados`, `Financeiro`, `Estoque`, `MDVR` e `Relatorios PDF`

## Riscos remanescentes

- A sidebar real ainda depende do filtro interno do `HomeShell`; o catalogo tecnico foi alinhado, mas ainda nao e a fonte visual primaria
- `Chamados`, `Financeiro` e `Estoque` precisam backend real antes de demonstracao como produto
- `Permissoes` ainda nao salva matriz completa
