import { chromium } from '../tools/playwright/node_modules/playwright/index.mjs';

const url = 'http://127.0.0.1:8186/?v=20260522-map-pixel-perfect-final&panel=map';
const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({ viewport: { width: 1536, height: 864 } });
const page = await context.newPage();
const logs = [];
page.on('console', msg => { if (msg.type() === 'error') logs.push(`[console:error] ${msg.text()}`); });
page.on('pageerror', err => logs.push(`[pageerror] ${err.message}`));
page.on('requestfailed', req => logs.push(`[requestfailed] ${req.url()} :: ${req.failure()?.errorText}`));

await page.goto(url, { waitUntil: 'networkidle', timeout: 120000 });
await page.waitForTimeout(1500);

// Login (coords já mapeadas)
await page.mouse.click(744, 435);
await page.keyboard.press('Control+A');
await page.keyboard.type('demo@mackflow.com.br');
await page.waitForTimeout(250);
await page.mouse.click(744, 531);
await page.keyboard.press('Control+A');
await page.keyboard.type('123456');
await page.waitForTimeout(250);
await page.mouse.click(744, 645);
await page.waitForTimeout(9000);

await page.goto(url, { waitUntil: 'networkidle', timeout: 120000 });
await page.waitForTimeout(4500);
await page.screenshot({ path: '.tmp_map_flow_0_initial.png', fullPage: true });

// Clique no primeiro card do mapa
await page.mouse.click(292, 144);
await page.waitForTimeout(1500);
await page.screenshot({ path: '.tmp_map_flow_1_card_click.png', fullPage: true });

// Clique no botao olho/ver (popup)
await page.mouse.click(573, 315);
await page.waitForTimeout(1800);
await page.screenshot({ path: '.tmp_map_flow_2_eye_click.png', fullPage: true });

// Clique em outro card para trocar dispositivo
await page.mouse.click(823, 144);
await page.waitForTimeout(1500);
await page.screenshot({ path: '.tmp_map_flow_3_other_card.png', fullPage: true });

console.log(JSON.stringify({ finalUrl: page.url(), logs }, null, 2));
await browser.close();
