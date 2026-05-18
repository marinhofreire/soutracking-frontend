# Playwright - Duas Guias (Front + Backend)

## Objetivo
Abrir duas guias fixas para homologacao sem confusao:
1. Frontend SouTracking (`http://localhost:65517/`)
2. Backend/API (`http://api.soutracking.com.br/`)

## Instalar (uma vez)
```powershell
cd C:\Projetos\Soutrackingflutter\tools\playwright
npm.cmd install
npx.cmd playwright install chromium
```

## Abrir 2 guias e manter abertas
```powershell
cd C:\Projetos\Soutrackingflutter\tools\playwright
npm.cmd run tabs
```
- As guias ficam abertas ate voce encerrar no terminal (`Ctrl + C`).

## Teste rapido headless
```powershell
cd C:\Projetos\Soutrackingflutter\tools\playwright
npm.cmd run tabs:headless
```

## Validacao automatizada completa
Gera relatorio com:
- disponibilidade front/back
- deteccao de tela (login ou shell)
- erros de console
- falhas de rede
- respostas HTTP >= 400
- screenshots
- deteccao de botoes de exportacao em Relatorios

```powershell
cd C:\Projetos\Soutrackingflutter\tools\playwright
npm.cmd run validate
```

Relatorios sao gerados em:
`C:\Projetos\Soutrackingflutter\tools\playwright\reports\<timestamp>`

## Validacao com tentativa de login automatica (opcional)
```powershell
$env:SOUTRACKING_TEST_EMAIL='pixelti@soutracking.com.br'
$env:SOUTRACKING_TEST_PASS='SUA_SENHA_AQUI'
cd C:\Projetos\Soutrackingflutter\tools\playwright
npm.cmd run validate
```

## Validacao visual (com janela aberta)
```powershell
cd C:\Projetos\Soutrackingflutter\tools\playwright
npm.cmd run validate:ui
```

## URLs personalizadas (opcional)
```powershell
$env:FRONT_URL='http://localhost:65517/'
$env:BACKEND_URL='http://api.soutracking.com.br/'
npm.cmd run tabs
```



