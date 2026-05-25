# SouTracking - Validacao Automatizada

- Data: 2026-05-23T18:42:26.044Z
- Front: http://127.0.0.1:9005/
- Back: http://api.soutracking.com.br/
- Checks: 6/7 ok
- Console errors: 1
- Console warnings: 1
- Request failures: 0
- HTTP >= 400: 1

## Checks
- [x] backend_load: Backend abriu na guia 2.
- [x] frontend_load: Frontend abriu na guia 1.
- [ ] flutter_runtime_ready: Flutter runtime nao detectado dentro do timeout.
- [x] frontend_signature: title=SouTracking; hasGlass=false; hasLoader=false; flt=
- [x] login_form_dom_detected: Campos de login nao detectados via DOM (comum em Flutter CanvasKit).
- [x] login_attempt: Login automatico pulado: tela nao detectavel via DOM neste modo de renderizacao.
- [x] reports_menu_dom_detection: Menu Relatorios nao detectado via DOM (validar visualmente no navegador aberto).

## Arquivos
- JSON: C:\Projetos\Soutrackingflutter\tools\playwright\reports\2026-05-23T18-41-25-624Z\report.json
- Screenshot: C:\Projetos\Soutrackingflutter\tools\playwright\reports\2026-05-23T18-41-25-624Z\frontend-inicial.png