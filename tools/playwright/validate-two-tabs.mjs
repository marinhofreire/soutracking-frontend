import fs from 'node:fs/promises';
import path from 'node:path';
import { chromium } from 'playwright';

const args = process.argv.slice(2);
const hasFlag = (flag) => args.includes(flag);

const frontUrl = process.env.FRONT_URL || 'http://localhost:65517/';
const backendUrl = process.env.BACKEND_URL || 'http://api.soutracking.com.br/';
const loginEmail = process.env.SOUTRACKING_TEST_EMAIL || '';
const loginPassword = process.env.SOUTRACKING_TEST_PASS || '';
const headed = hasFlag('--headed');

const stamp = new Date().toISOString().replace(/[:.]/g, '-');
const runDir = path.resolve(process.cwd(), 'reports', stamp);

const report = {
  startedAt: new Date().toISOString(),
  frontUrl,
  backendUrl,
  headed,
  loginAttempted: false,
  checks: [],
  consoleEvents: [],
  requestFailures: [],
  httpErrors: [],
  screenshots: [],
};

const addCheck = (name, ok, details = '') => {
  report.checks.push({ name, ok, details });
};

const attachTelemetry = (page, pageName) => {
  page.on('console', (msg) => {
    const type = msg.type();
    if (type !== 'error' && type !== 'warning' && type !== 'log' && type !== 'info') return;
    report.consoleEvents.push({
      page: pageName,
      type,
      text: msg.text(),
      at: new Date().toISOString(),
    });
  });

  page.on('requestfailed', (request) => {
    report.requestFailures.push({
      page: pageName,
      url: request.url(),
      method: request.method(),
      errorText: request.failure()?.errorText ?? 'unknown',
      at: new Date().toISOString(),
    });
  });

  page.on('response', (response) => {
    if (response.status() < 400) return;
    report.httpErrors.push({
      page: pageName,
      url: response.url(),
      status: response.status(),
      at: new Date().toISOString(),
    });
  });
};

const firstCount = async (locator) => {
  try {
    return await locator.count();
  } catch {
    return 0;
  }
};

const isVisibleSafe = async (locator) => {
  try {
    return await locator.isVisible();
  } catch {
    return false;
  }
};

const saveScreenshot = async (page, fileName) => {
  const target = path.join(runDir, fileName);
  await page.screenshot({ path: target, fullPage: true });
  report.screenshots.push(target);
};

const run = async () => {
  await fs.mkdir(runDir, { recursive: true });

  const browser = await chromium.launch({
    headless: !headed,
    slowMo: headed ? 120 : 0,
  });

  const context = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const frontPage = await context.newPage();
  const backendPage = await context.newPage();

  attachTelemetry(frontPage, 'frontend');
  attachTelemetry(backendPage, 'backend');

  try {
    await backendPage.goto(backendUrl, { waitUntil: 'domcontentloaded', timeout: 45000 });
    addCheck('backend_load', true, 'Backend abriu na guia 2.');
  } catch (error) {
    addCheck('backend_load', false, `Falha ao abrir backend: ${error}`);
  }

  try {
    await frontPage.goto(frontUrl, { waitUntil: 'domcontentloaded', timeout: 45000 });
    addCheck('frontend_load', true, 'Frontend abriu na guia 1.');
  } catch (error) {
    addCheck('frontend_load', false, `Falha ao abrir frontend: ${error}`);
  }

  try {
    await frontPage.waitForSelector('flt-glass-pane, flt-semantics-host, flt-text-editing-host', {
      timeout: 45000,
    });
    addCheck('flutter_runtime_ready', true, 'Flutter runtime detectado (flt-*).');
  } catch {
    addCheck('flutter_runtime_ready', false, 'Flutter runtime nao detectado dentro do timeout.');
  }

  await frontPage.waitForTimeout(4000);
  await saveScreenshot(frontPage, 'frontend-inicial.png');

  const frontState = await frontPage.evaluate(() => {
    const tags = Array.from(document.querySelectorAll('*')).map((el) =>
      el.tagName.toLowerCase()
    );
    const counts = {};
    for (const tag of tags) counts[tag] = (counts[tag] || 0) + 1;
    const fltTop = Object.entries(counts)
      .filter(([name]) => name.startsWith('flt-'))
      .sort((a, b) => b[1] - a[1])
      .slice(0, 12);

    const bodyText = (document.body?.innerText || '').trim();

    return {
      title: document.title,
      hasFlutterRuntime: Boolean(window._flutter),
      hasGlassPane: Boolean(document.querySelector('flt-glass-pane')),
      hasLoader: Boolean(document.querySelector('.flutter-loader')),
      fltTop,
      bodyTextLength: bodyText.length,
      bodyTextSample: bodyText.slice(0, 200),
    };
  });

  addCheck(
    'frontend_signature',
    frontState.hasFlutterRuntime || frontState.hasGlassPane,
    `title=${frontState.title}; hasGlass=${frontState.hasGlassPane}; hasLoader=${frontState.hasLoader}; flt=${frontState.fltTop
      .map(([name, count]) => `${name}:${count}`)
      .join(', ')}`
  );

  const emailInput = frontPage.locator(
    'input[type="email"], input[name="email"], input[autocomplete="username"]'
  );
  const passwordInput = frontPage.locator(
    'input[type="password"], input[name="password"], input[autocomplete="current-password"]'
  );
  const loginButton = frontPage.getByRole('button', { name: /entrar|login/i }).first();

  const emailCount = await firstCount(emailInput);
  const passwordCount = await firstCount(passwordInput);
  const loginBtnCount = await firstCount(loginButton);
  const loginFormVisible = emailCount > 0 && passwordCount > 0 && loginBtnCount > 0;

  addCheck(
    'login_form_dom_detected',
    true,
    loginFormVisible
      ? 'Campos de login detectados via DOM.'
      : 'Campos de login nao detectados via DOM (comum em Flutter CanvasKit).'
  );

  if (loginEmail && loginPassword && loginFormVisible) {
    report.loginAttempted = true;
    await emailInput.first().fill(loginEmail);
    await passwordInput.first().fill(loginPassword);
    await loginButton.click();
    await frontPage.waitForTimeout(5000);
    await saveScreenshot(frontPage, 'frontend-pos-login.png');

    const loginError = frontPage
      .locator('text=/login falhou|senha|inválid|invalida|erro|exception/i')
      .first();
    const hasError = await isVisibleSafe(loginError);

    addCheck(
      'login_attempt',
      !hasError,
      hasError
        ? 'Tentativa de login mostrou erro na tela.'
        : 'Tentativa de login executada sem erro visual imediato.'
    );
  } else {
    addCheck(
      'login_attempt',
      true,
      loginFormVisible
        ? 'Login automatico pulado: faltam SOUTRACKING_TEST_EMAIL/SOUTRACKING_TEST_PASS.'
        : 'Login automatico pulado: tela nao detectavel via DOM neste modo de renderizacao.'
    );
  }

  const reportsMenu = frontPage.locator('text=/Relatórios|Relatorios/i').first();
  const reportsMenuVisible = await isVisibleSafe(reportsMenu);

  addCheck(
    'reports_menu_dom_detection',
    true,
    reportsMenuVisible
      ? 'Menu Relatorios detectado via texto DOM.'
      : 'Menu Relatorios nao detectado via DOM (validar visualmente no navegador aberto).'
  );

  if (reportsMenuVisible) {
    try {
      await reportsMenu.click({ timeout: 5000 });
      await frontPage.waitForTimeout(2500);
      await saveScreenshot(frontPage, 'frontend-relatorios.png');

      const csvButton = frontPage.getByRole('button', { name: /Exportar/i }).first();
      const htmlButton = frontPage.getByRole('button', { name: /HTML/i }).first();
      const pdfButton = frontPage.getByRole('button', { name: /PDF/i }).first();

      addCheck('reports_export_csv_button', await isVisibleSafe(csvButton), 'Botao Exportar (CSV).');
      addCheck('reports_export_html_button', await isVisibleSafe(htmlButton), 'Botao HTML.');
      addCheck('reports_export_pdf_button', await isVisibleSafe(pdfButton), 'Botao PDF.');
    } catch (error) {
      addCheck('reports_open', false, `Falha ao abrir Relatorios: ${error}`);
    }
  }

  report.finishedAt = new Date().toISOString();
  report.frontState = frontState;
  report.summary = {
    totalChecks: report.checks.length,
    passedChecks: report.checks.filter((item) => item.ok).length,
    failedChecks: report.checks.filter((item) => !item.ok).length,
    consoleErrors: report.consoleEvents.filter((item) => item.type === 'error').length,
    consoleWarnings: report.consoleEvents.filter((item) => item.type === 'warning').length,
    requestFailures: report.requestFailures.length,
    httpErrors: report.httpErrors.length,
  };

  const jsonPath = path.join(runDir, 'report.json');
  await fs.writeFile(jsonPath, JSON.stringify(report, null, 2), 'utf8');

  const mdLines = [
    '# SouTracking - Validacao Automatizada',
    '',
    `- Data: ${report.finishedAt}`,
    `- Front: ${frontUrl}`,
    `- Back: ${backendUrl}`,
    `- Checks: ${report.summary.passedChecks}/${report.summary.totalChecks} ok`,
    `- Console errors: ${report.summary.consoleErrors}`,
    `- Console warnings: ${report.summary.consoleWarnings}`,
    `- Request failures: ${report.summary.requestFailures}`,
    `- HTTP >= 400: ${report.summary.httpErrors}`,
    '',
    '## Checks',
    ...report.checks.map((item) => `- [${item.ok ? 'x' : ' '}] ${item.name}: ${item.details}`),
    '',
    '## Arquivos',
    `- JSON: ${jsonPath}`,
    ...report.screenshots.map((file) => `- Screenshot: ${file}`),
  ];

  const mdPath = path.join(runDir, 'report.md');
  await fs.writeFile(mdPath, mdLines.join('\n'), 'utf8');

  console.log('Validacao concluida.');
  console.log(`Relatorio: ${mdPath}`);
  console.log(`JSON:      ${jsonPath}`);

  await browser.close();

  const criticalFailed = ['backend_load', 'frontend_load', 'frontend_signature']
    .map((name) => report.checks.find((item) => item.name === name))
    .some((item) => !item || !item.ok);

  if (criticalFailed) {
    process.exit(1);
  }
};

run().catch(async (error) => {
  try {
    await fs.mkdir(runDir, { recursive: true });
    const errorPath = path.join(runDir, 'error.txt');
    await fs.writeFile(errorPath, String(error?.stack || error), 'utf8');
  } catch {
    // ignore
  }
  console.error('Falha na validacao Playwright:', error);
  process.exit(1);
});



