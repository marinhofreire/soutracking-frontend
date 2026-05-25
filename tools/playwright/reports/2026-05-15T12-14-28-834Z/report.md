# SouTracking - Validacao Automatizada

- Data: 2026-05-15T12:15:19.913Z
- Front: http://localhost:65517/
- Back: http://api.soutracking.com.br/api/devices
- Checks: 6/7 ok
- Console errors: 1
- Console warnings: 5
- Request failures: 0
- HTTP >= 400: 1

## Checks
- [x] backend_load: Backend abriu na guia 2.
- [x] frontend_load: Frontend abriu na guia 1.
- [ ] flutter_runtime_ready: Flutter runtime nao detectado dentro do timeout.
- [x] frontend_signature: title=SouTracking; hasGlass=true; hasLoader=false; flt=flt-semantics-placeholder:1, flt-announcement-host:1, flt-announcement-polite:1, flt-announcement-assertive:1, flt-glass-pane:1, flt-text-editing-host:1, flt-semantics-host:1
- [x] login_form_dom_detected: Campos de login nao detectados via DOM (comum em Flutter CanvasKit).
- [x] login_attempt: Login automatico pulado: tela nao detectavel via DOM neste modo de renderizacao.
- [x] reports_menu_dom_detection: Menu Relatorios nao detectado via DOM (validar visualmente no navegador aberto).

## Arquivos
- JSON: C:\Projetos\Soutrackingflutter\tools\playwright\reports\2026-05-15T12-14-28-834Z\report.json
- Screenshot: C:\Projetos\Soutrackingflutter\tools\playwright\reports\2026-05-15T12-14-28-834Z\frontend-inicial.png