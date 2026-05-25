import { chromium } from '../tools/playwright/node_modules/playwright/index.mjs';

const base = 'http://127.0.0.1:8186/?v=20260522-padrao-imagens-13-telas';
const panels = [
  'dashboard','map','vehicles','devices','telemetry','alerts','fences',
  'reports','commands','maintenance','communication','logs','settings'
];

const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({ viewport: { width: 1510, height: 860 } });
const page = await context.newPage();

const report = { login: {}, panels: {}, errors: [] };

page.on('console', msg => {
  if (msg.type() === 'error') report.errors.push(`[console:error] ${msg.text()}`);
});
page.on('pageerror', err => report.errors.push(`[pageerror] ${err.message}`));
page.on('requestfailed', req => report.errors.push(`[requestfailed] ${req.url()} :: ${req.failure()?.errorText}`));

await page.goto(`${base}&panel=dashboard`, { waitUntil: 'networkidle', timeout: 120000 });
await page.waitForTimeout(2000);

await page.mouse.click(744, 435);
await page.keyboard.press('Control+A');
await page.keyboard.type('demo@mackflow.com.br');
await page.waitForTimeout(300);
await page.mouse.click(744, 531);
await page.keyboard.press('Control+A');
await page.keyboard.type('123456');
await page.waitForTimeout(300);
await page.mouse.click(744, 645);
await page.waitForTimeout(9000);

await page.screenshot({ path: '.tmp_13_new_login.png', fullPage: true });
report.login.urlAfter = page.url();

for (const panel of panels) {
  const logs = [];
  const onConsole = msg => {
    if (msg.type() === 'error') logs.push(`[console:error] ${msg.text()}`);
  };
  const onPageError = err => logs.push(`[pageerror] ${err.message}`);
  const onRequestFailed = req => logs.push(`[requestfailed] ${req.url()} :: ${req.failure()?.errorText}`);
  page.on('console', onConsole);
  page.on('pageerror', onPageError);
  page.on('requestfailed', onRequestFailed);

  const url = `${base}&panel=${panel}`;
  await page.goto(url, { waitUntil: 'networkidle', timeout: 120000 });
  await page.waitForTimeout(4500);
  const file = `.tmp_13_new_${panel}.png`;
  await page.screenshot({ path: file, fullPage: true });

  report.panels[panel] = { url, screenshot: file, logs };

  page.off('console', onConsole);
  page.off('pageerror', onPageError);
  page.off('requestfailed', onRequestFailed);
}

console.log(JSON.stringify(report, null, 2));
await browser.close();
