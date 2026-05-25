import { chromium } from '../tools/playwright/node_modules/playwright/index.mjs';

const url = 'http://127.0.0.1:8186/?v=20260522-final-4-pontos&panel=map';
const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({ viewport: { width: 1510, height: 860 } });
const page = await context.newPage();

await page.goto(url, { waitUntil: 'networkidle', timeout: 120000 });
await page.waitForTimeout(2000);

// tenta login apenas se botao Entrar estiver visivel
const loginButton = page.getByRole('button', { name: 'Entrar' });
if (await loginButton.count()) {
  await page.mouse.click(744, 435);
  await page.keyboard.press('Control+A');
  await page.keyboard.type('demo@mackflow.com.br');
  await page.mouse.click(744, 531);
  await page.keyboard.press('Control+A');
  await page.keyboard.type('123456');
  await loginButton.click();
  await page.waitForTimeout(9000);
  await page.goto(url, { waitUntil: 'networkidle', timeout: 120000 });
  await page.waitForTimeout(3500);
}

await page.screenshot({ path: '.tmp_final4_map.png', fullPage: true });

// tenta fluxo card -> popup -> olho
await page.mouse.click(300, 144);
await page.waitForTimeout(1200);
await page.screenshot({ path: '.tmp_final4_map_popup.png', fullPage: true });
await page.mouse.click(575, 316);
await page.waitForTimeout(1500);
await page.screenshot({ path: '.tmp_final4_map_bar.png', fullPage: true });

console.log(JSON.stringify({url: page.url()}, null, 2));
await browser.close();
