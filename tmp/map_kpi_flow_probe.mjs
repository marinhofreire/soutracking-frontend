import { chromium } from '../tools/playwright/node_modules/playwright/index.mjs';

const base = 'http://127.0.0.1:8186/?v=20260522-13-telas-final';

const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({ viewport: { width: 1510, height: 860 } });
const page = await context.newPage();

await page.goto(`${base}&panel=dashboard`, { waitUntil: 'networkidle', timeout: 120000 });
await page.waitForTimeout(2000);
await page.mouse.click(744, 435);
await page.keyboard.press('Control+A');
await page.keyboard.type('demo@mackflow.com.br');
await page.mouse.click(744, 531);
await page.keyboard.press('Control+A');
await page.keyboard.type('123456');
await page.mouse.click(744, 645);
await page.waitForTimeout(9000);

await page.goto(`${base}&panel=map`, { waitUntil: 'networkidle', timeout: 120000 });
await page.waitForTimeout(4000);
await page.screenshot({ path: '.tmp_map_kpi_0.png', fullPage: true });

// Click offline KPI card.
await page.mouse.click(560, 35);
await page.waitForTimeout(2500);
await page.screenshot({ path: '.tmp_map_kpi_1_offline_click.png', fullPage: true });

// Try clicking first row from possible vehicle list.
await page.mouse.click(430, 150);
await page.waitForTimeout(2500);
await page.screenshot({ path: '.tmp_map_kpi_2_first_vehicle_click.png', fullPage: true });

// Try clicking around where eye/details action may appear.
await page.mouse.click(655, 152);
await page.waitForTimeout(2500);
await page.screenshot({ path: '.tmp_map_kpi_3_eye_click.png', fullPage: true });

await browser.close();
