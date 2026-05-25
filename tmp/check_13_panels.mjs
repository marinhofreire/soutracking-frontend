import { chromium } from '../tools/playwright/node_modules/playwright/index.mjs';
import fs from 'node:fs/promises';

const base = 'http://127.0.0.1:8186/?v=20260522-13-telas-final';
const panels = [
  'dashboard','map','vehicles','devices','telemetry','alerts','fences',
  'reports','commands','maintenance','communication','logs','settings'
];

const email = 'demo@mackflow.com.br';
const password = '123456';

const out = { panels: {}, login: {}, globalErrors: [] };

const browser = await chromium.launch({ headless: true, args: ['--disable-web-security'] });
const context = await browser.newContext({ viewport: { width: 1510, height: 860 } });
const page = await context.newPage();

const globalLogs = [];
page.on('console', msg => {
  const t = msg.type();
  const text = msg.text();
  if (t === 'error' || text.includes('RenderFlex') || text.includes('Exception')) {
    globalLogs.push(`[console:${t}] ${text}`);
  }
});
page.on('pageerror', err => globalLogs.push(`[pageerror] ${err.message}`));
page.on('requestfailed', req => globalLogs.push(`[requestfailed] ${req.url()} :: ${req.failure()?.errorText}`));

await page.goto(base, { waitUntil: 'domcontentloaded', timeout: 120000 });

// Tenta login se houver campos.
const emailInput = page.locator('input[type="email"], input[autocomplete="username"], input[placeholder*="e-mail" i]').first();
if (await emailInput.count()) {
  await emailInput.fill(email);
  const passInput = page.locator('input[type="password"]').first();
  await passInput.fill(password);
  const entrarBtn = page.getByRole('button', { name: /entrar/i }).first();
  if (await entrarBtn.count()) {
    await entrarBtn.click();
    await page.waitForTimeout(7000);
  }
}

// Se ainda estiver na tela de login, injeta sessão básica
const bodyTextAfterLogin = await page.locator('body').innerText().catch(() => '');
out.login.bodyTextSnippet = bodyTextAfterLogin.slice(0, 400);
if (/entrar|senha|e-mail/i.test(bodyTextAfterLogin) && !/Dashboard|Mapa|Veículos|Equipamentos|Relatórios/i.test(bodyTextAfterLogin)) {
  const basic = Buffer.from(`${email}:${password}`).toString('base64');
  const now = Date.now();
  const payload = {
    email,
    cookie: '',
    authHeader: `Basic ${basic}`,
    profileCode: 'MA',
    isAdministrator: true,
    lastActivityMs: now,
    tenantConfig: {
      tenantId: 'soutracking',
      companyName: 'SouTracking',
      slug: 'soutracking',
      modules: {
        tracking: true,
        assist: true,
        demand: true,
        admin: true,
        mdvr: true,
        zpro: true,
        finance: true,
        inventory: true,
        ai: true,
        data_log: true,
        automations: true,
      },
      isMasterAdmin: true,
      isCompanyAdmin: true,
      branding: {
        appName: 'SouTracking',
        tagline: 'Operação',
        primaryColor: '#2D7DFF',
        secondaryColor: '#22D3EE',
      },
    },
  };
  await page.evaluate((sessionPayload) => {
    localStorage.setItem('flutter.shared_preferences', JSON.stringify({
      'soutracking.session.v1': JSON.stringify(sessionPayload),
    }));
  }, payload);
  await page.goto(`${base}&panel=dashboard`, { waitUntil: 'networkidle', timeout: 120000 });
  await page.waitForTimeout(3000);
}

for (const panel of panels) {
  const logs = [];
  const onConsole = msg => {
    const t = msg.type();
    const text = msg.text();
    if (t === 'error' || text.includes('RenderFlex') || text.includes('Exception')) {
      logs.push(`[console:${t}] ${text}`);
    }
  };
  const onPageError = err => logs.push(`[pageerror] ${err.message}`);
  const onRequestFailed = req => logs.push(`[requestfailed] ${req.url()} :: ${req.failure()?.errorText}`);
  page.on('console', onConsole);
  page.on('pageerror', onPageError);
  page.on('requestfailed', onRequestFailed);

  const url = `${base}&panel=${panel}`;
  await page.goto(url, { waitUntil: 'networkidle', timeout: 120000 });
  await page.waitForTimeout(3500);

  const text = await page.locator('body').innerText().catch(() => '');
  const html = await page.content();
  const file = `.tmp_13_${panel}.png`;
  await page.screenshot({ path: file, fullPage: true });

  out.panels[panel] = {
    url,
    textLen: text.length,
    htmlLen: html.length,
    textSample: text.slice(0, 800),
    hasLoading: /carregando|loading|sincronizando/i.test(text),
    hasSessaoExpirada: /sess[aã]o expirada/i.test(text),
    hasMojibake: /Ã|�/.test(text),
    logs,
    screenshot: file,
  };

  page.off('console', onConsole);
  page.off('pageerror', onPageError);
  page.off('requestfailed', onRequestFailed);
}

out.globalErrors = globalLogs;
await browser.close();
await fs.writeFile('.tmp_13_panels_report.json', JSON.stringify(out, null, 2), 'utf8');
console.log(JSON.stringify(out, null, 2));

