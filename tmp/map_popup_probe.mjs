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
await page.screenshot({ path: '.tmp_map_before_clicks.png', fullPage: true });

const points = [
  [760, 410],
  [820, 460],
  [690, 370],
  [930, 500],
  [640, 530],
];

for (let i=0;i<points.length;i++) {
  const [x,y] = points[i];
  await page.mouse.click(x,y);
  await page.waitForTimeout(2200);
  await page.screenshot({ path: `.tmp_map_click_${i+1}.png`, fullPage: true });
}

await browser.close();
