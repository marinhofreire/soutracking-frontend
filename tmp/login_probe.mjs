import { chromium } from '../tools/playwright/node_modules/playwright/index.mjs';
const url = 'http://127.0.0.1:8186/?v=20260522-map-pixel-perfect-final&panel=map';
const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1536, height: 864 } });
await page.goto(url, { waitUntil: 'networkidle', timeout: 120000 });
await page.waitForTimeout(1500);
await page.screenshot({ path: '.tmp_login_step_0.png', fullPage: true });

await page.mouse.click(760, 438);
await page.keyboard.type('demo@mackflow.com.br');
await page.waitForTimeout(500);
await page.screenshot({ path: '.tmp_login_step_1_email.png', fullPage: true });

await page.mouse.click(760, 535);
await page.keyboard.type('123456');
await page.waitForTimeout(500);
await page.screenshot({ path: '.tmp_login_step_2_password.png', fullPage: true });

await page.mouse.click(760, 646);
await page.waitForTimeout(10000);
await page.screenshot({ path: '.tmp_login_step_3_after_submit.png', fullPage: true });

console.log(JSON.stringify({ urlAfter: page.url() }, null, 2));
await browser.close();
