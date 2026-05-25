import { chromium } from '../tools/playwright/node_modules/playwright/index.mjs';
const url='http://127.0.0.1:8186/?v=20260522-final-4-pontos&panel=map';
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1510,height:860}});
await page.goto(url,{waitUntil:'networkidle',timeout:120000});
await page.waitForTimeout(3000);
const inputs = page.locator('input');
if (await inputs.count() >= 2) {
  await inputs.nth(0).fill('demo@mackflow.com.br');
  await inputs.nth(1).fill('123456');
  await page.getByRole('button', { name: 'Entrar' }).click();
  await page.waitForTimeout(12000);
}
await page.goto(url,{waitUntil:'networkidle',timeout:120000});
await page.waitForTimeout(12000);
await page.screenshot({path:'.tmp_final4_map_longwait.png',fullPage:true});
console.log('done', page.url());
await browser.close();
