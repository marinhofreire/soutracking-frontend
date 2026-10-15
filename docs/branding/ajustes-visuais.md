# Ajustes visuais da marca — 15/10/2026

Apenas apresentação. Originais preservados; upload, persistência e autenticação existentes mantidos. Edição com ferramenta integrada image_gen, sem CLI.

Assets salvos:

- assets/branding/soutracking_logo_transparent.png
- assets/branding/soutracking_symbol_transparent.png
- assets/branding/soutracking_logo_dark.png

## Especificação dos prompts finais

1. Remover somente o fundo quadriculado da referência horizontal, preservar texto SOU TRACKING, lâmpada, formas, espaçamento, proporções e preto/amarelo; fundo transparente, sem novos elementos.
2. Extrair símbolo/lâmpada da referência em fundo transparente, preservar forma, cores e proporções; sem texto adicional.
3. Na versão horizontal transparente, trocar somente o preto por branco para fundo escuro; preservar amarelo, lâmpada, alinhamento e transparência.

## Limites

Variante escura e símbolo separados são da marca padrão. Logos personalizados são exibidos como recebidos. Não inclui favicon por empresa, seletor de cores, novo campo de logo escuro nem integrações. Revisão visual final pelo cliente.

## Complemento — identidade visual white-label (15/10/2026)

Agora o front oferece logo principal, símbolo e variante para fundo escuro, incluindo SVG; seletor RGB/hexadecimal; cores nos controles; favicon e título da aba. A escolha explícita de cor é preservada na leitura da configuração existente. Meu perfil reutiliza a tela de perfil existente sem apresentar abas administrativas. Layout, ações e regras operacionais foram preservados.

Validação: build release, 72 testes de regressão e quatro testes direcionados de identidade/configuração. Conferência de navegador com sessão e APIs simuladas: logos SVG, título, favicon, salvar/recarregar, perfil e login configurado. Não grava dados de clientes.

Limite: a sessão existente restaura a marca padrão no logout. Persistência por empresa/servidor e manutenção após sair dependem do responsável pela lógica; não foram alteradas. O teste de login preserva a configuração e remove somente a sessão de teste, não comprova retenção após logout real.

Revisão manual: Configurações > Geral, carregar as três variantes e alterar cores; salvar e recarregar; conferir sidebar aberta/recolhida, título/favicon, formulários, menu do perfil e contraste. Usar uma conta de teste; confirmar também que os botões mantêm suas ações.
