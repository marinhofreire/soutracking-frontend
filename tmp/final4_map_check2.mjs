import { chromium } from '../tools/playwright/node_modules/playwright/index.mjs';

const base = 'http://127.0.0.1:8186/?v=20260522-final-4-pontos';
const mapUrl = `${base}&panel=map`;

const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({ viewport: { width: 1510, height: 860 } });
const page = await context.newPage();

await page.goto(mapUrl, { waitUntil: 'domcontentloaded', timeout: 120000 });
await page.waitForTimeout(3000);

const emailInput = page.locator('input').nth(0);
const passInput = page.locator('input').nth(1);
if (await emailInput.count()) {
  await emailInput.fill('demo@mackflow.com.br');
  await passInput.fill('123456');
  await page.getByRole('button', { name: 'Entrar' }).click();
  await page.waitForTimeout(10000);
}

await page.goto(mapUrl, { waitUntil: 'networkidle', timeout: 120000 });
await page.waitForTimeout(5000);
await page.screenshot({ path: '.tmp_final4_map2.png', fullPage: true });

await page.mouse.click(320, 145);
await page.waitForTimeout(1500);
await page.screenshot({ path: '.tmp_final4_map2_popup.png', fullPage: true });

await page.mouse.click(585, 318);
await page.waitForTimeout(1500);
await page.screenshot({ path: '.tmp_final4_map2_bar.png', fullPage: true });

console.log(JSON.stringify({ url: page.url() }, null, 2));
await browser.close();
