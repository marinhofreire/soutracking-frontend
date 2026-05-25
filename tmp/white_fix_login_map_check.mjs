import { chromium } from '../tools/playwright/node_modules/playwright/index.mjs';
const url='http://127.0.0.1:8186/?v=20260522-white-fix&panel=map';
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1510,height:860}});
const logs=[];
page.on('console',m=>logs.push(`[${m.type()}] ${m.text()}`));
page.on('pageerror',e=>logs.push(`[pageerror] ${e.message}`));
await page.goto(url,{waitUntil:'networkidle',timeout:120000});
await page.waitForTimeout(3000);
const inputs=page.locator('input');
if(await inputs.count()>=2){
  await inputs.nth(0).fill('demo@mackflow.com.br');
  await inputs.nth(1).fill('123456');
  await page.getByRole('button',{name:'Entrar'}).click();
  await page.waitForTimeout(12000);
}
await page.goto(url,{waitUntil:'networkidle',timeout:120000});
await page.waitForTimeout(12000);
await page.screenshot({path:'.tmp_white_fix_logged_map.png',fullPage:true});
const state=await page.evaluate(()=>({
  hasGlass: !!document.querySelector('flt-glass-pane'),
  inputCount: document.querySelectorAll('input').length,
  textSample: document.body.innerText.slice(0,160),
  canvasCount: document.querySelectorAll('canvas').length,
}));
console.log(JSON.stringify({url:page.url(),state,logs:logs.slice(0,30)},null,2));
await browser.close();
