# Checklist de Ajustes por Menu

Data: 2026-03-08
Objetivo: fechar todos os menus com padrao de entrega (funcional, visual, permissao e teste).

## 1. IA Operacional (Prioridade Alta)
- [ ] Revisar prompt base e respostas por cenario (offline, velocidade, tpms, prioridade)
- [ ] Ajustar tom das respostas para operacao diaria (curto e acionavel)
- [ ] Melhorar sugestoes de acao no final de cada resposta
- [ ] Validar tratamento de erros de API na IA
- [ ] Revisar desempenho da abertura da janela IA
- [ ] Validar permissao de acesso (somente perfis permitidos)
- [ ] Testar no desktop e mobile
- [ ] Homologar com equipe operacional

## 2. Mapa
- [ ] Validar marcador dinamico (status, velocidade, bateria, alerta)
- [ ] Validar halo e destaque de selecionado
- [ ] Revisar card do veiculo (status, categoria, foto, bateria)
- [ ] Validar modo gestor versus usuario comum
- [ ] Testar performance com muitos dispositivos

## 3. Gestao
### Dashboard
- [ ] Revisar KPIs e consistencia dos dados
- [ ] Ajustar cards para leitura rapida

### Dispositivos
- [ ] Validar cadastro/edicao
- [ ] Validar categoria/foto por gestor
- [ ] Revisar estados online/offline/desconhecido

### Grupos
- [ ] Validar CRUD completo
- [ ] Revisar vinculo de dispositivos

### Motoristas
- [ ] Validar cadastro e vinculacao
- [ ] Revisar busca e filtros

### Manutencao
- [ ] Validar fluxo de abertura e acompanhamento
- [ ] Revisar alertas de manutencao

## 4. Operacao
### Eventos
- [ ] Validar filtros por tipo e periodo
- [ ] Revisar exportacao/consulta

### Notificacoes
- [ ] Validar tipos (incluindo cerca)
- [ ] Revisar regras e acionadores

### Comandos
- [ ] Validar envio e retorno de status
- [ ] Revisar mensagens de erro

### Cercas
- [ ] Validar modo circular
- [ ] Validar modo poligono ponto a ponto no mapa
- [ ] Validar salvar e listagem
- [ ] Validar edicao futura (arrastar ponto/editar poligono)

### Jornada / Check-in
- [ ] Validar checklist
- [ ] Revisar conclusao e historico

## 5. Relatorios
### Rotas
- [ ] Validar periodo e dispositivo
- [ ] Validar desempenho da consulta

### Eventos
- [ ] Validar consistencia com tela de eventos

### Resumo
- [ ] Validar agregacoes

### Viagens
- [ ] Validar deteccao de inicio/fim

### Paradas
- [ ] Validar criterio de parada e tempo

## 6. Administracao
### Usuarios
- [ ] Validar CRUD e status

### Permissoes
- [ ] Revisar matriz por perfil
- [ ] Garantir bloqueio de funcoes sensiveis para usuario comum

### Atributos
- [ ] Validar campos customizados

### Calendarios
- [ ] Validar regras e excecoes

### Estatisticas
- [ ] Validar origem dos dados

### Ordens
- [ ] Validar fluxo operacional ponta a ponta

## 7. Configuracao
- [ ] Revisar parametros gerais da plataforma
- [ ] Validar logout e sessao

## 8. Modulos Opcionais (Feature Flag)
### Assistencia
- [ ] SouAssist Demandas
- [ ] Criar Chamado

### Central de Demandas
- [ ] Painel de Controle
- [ ] Chamados Operacionais

### Cameras
- [ ] Mural de Cameras

### Comunicacao
- [ ] WhatsApp (Z-Pro)

### Administracao SaaS
- [ ] SaaS Empresas

## 9. Criterio de Conclusao por Menu
- [ ] Funcional sem erro bloqueante
- [ ] Visual aprovado
- [ ] Permissoes corretas (gestor x usuario)
- [ ] Testado desktop e mobile
- [ ] Validado com operacao
