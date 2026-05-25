import { chromium } from '../tools/playwright/node_modules/playwright/index.mjs';

const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({ viewport: { width: 1510, height: 860 } });
const page = await context.newPage();

const email = 'demo@mackflow.com.br';
const password = '123456';
const basic = Buffer.from(`${email}:${password}`).toString('base64');
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
    modules: { tracking: true, assist: true, demand: true, admin: true },
    isMasterAdmin: true,
    isCompanyAdmin: true,
    branding: { appName: 'SouTracking', tagline: 'Operação', primaryColor: '#2D7DFF', secondaryColor: '#22D3EE' }
  }
};

await page.goto('http://127.0.0.1:8186/?v=probe&panel=dashboard', { waitUntil: 'domcontentloaded', timeout: 120000 });
await page.evaluate((v) => localStorage.setItem('flutter.soutracking.session.v1', v), JSON.stringify(payload));
console.log('set keys', await page.evaluate(() => Object.keys(localStorage)));
console.log('value', await page.evaluate(() => localStorage.getItem('flutter.soutracking.session.v1')));
await page.reload({ waitUntil: 'networkidle', timeout: 120000 });
await page.waitForTimeout(4000);
console.log('after keys', await page.evaluate(() => Object.keys(localStorage)));
console.log('after value', await page.evaluate(() => localStorage.getItem('flutter.soutracking.session.v1')));
await page.screenshot({ path: '.tmp_probe_after_reload.png', fullPage: true });
await browser.close();
