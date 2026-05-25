import { chromium } from '../tools/playwright/node_modules/playwright/index.mjs';

const url = 'http://127.0.0.1:8186/?v=20260522-white-fix&panel=map';
const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({ viewport: { width: 1510, height: 860 } });
const page = await context.newPage();

const logs = [];
page.on('console', msg => logs.push(`[console:${msg.type()}] ${msg.text()}`));
page.on('pageerror', err => logs.push(`[pageerror] ${err.message}`));
page.on('requestfailed', req => logs.push(`[requestfailed] ${req.method()} ${req.url()} :: ${req.failure()?.errorText}`));

const res = await page.goto(url, { waitUntil: 'networkidle', timeout: 120000 });
await page.waitForTimeout(5000);

const title = await page.title();
const html = await page.content();
const inputCount = await page.locator('input').count();
const btnEntrarCount = await page.getByRole('button', { name: 'Entrar' }).count();
const bodyText = (await page.locator('body').innerText()).slice(0, 300);

await page.screenshot({ path: '.tmp_white_fix_probe.png', fullPage: true });

console.log(JSON.stringify({
  status: res?.status(),
  title,
  inputCount,
  btnEntrarCount,
  bodyText,
  htmlLen: html.length,
  logs,
}, null, 2));

await browser.close();
