import { chromium } from '../tools/playwright/node_modules/playwright/index.mjs';

const base = 'http://127.0.0.1:8186/?v=20260522-13-telas-final';
const panel = 'dashboard';
const email = 'demo@mackflow.com.br';
const password = '123456';
const basic = Buffer.from(`${email}:${password}`).toString('base64');

const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({ viewport: { width: 1510, height: 860 } });
const page = await context.newPage();
await page.goto(`${base}&panel=${panel}`, { waitUntil: 'domcontentloaded', timeout: 120000 });

const payload = {
  email,
  cookie: '',
  authHeader: `Basic ${basic}`,
  profileCode: 'MA',
  isAdministrator: true,
  lastActivityMs: Date.now(),
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
      reports_plus: true,
      communication: true,
      settings: true,
      maintenance: true,
      telemetry: true,
      alerts: true,
      commands: true,
      geofences: true,
      devices: true,
      vehicles: true,
      dashboard: true,
    },
    isMasterAdmin: true,
    isCompanyAdmin: true,
    branding: {
      appName: 'SouTracking',
      tagline: 'Operação',
      primaryColor: '#2D7DFF',
      secondaryColor: '#22D3EE'
    }
  }
};

await page.evaluate((sessionJson) => {
  localStorage.setItem('flutter.soutracking.session.v1', sessionJson);
}, JSON.stringify(payload));

await page.goto(`${base}&panel=${panel}`, { waitUntil: 'networkidle', timeout: 120000 });
await page.waitForTimeout(5000);
await page.screenshot({ path: '.tmp_auth_try_dashboard.png', fullPage: true });

const keys = await page.evaluate(() => Object.keys(localStorage));
console.log(keys);

await browser.close();
