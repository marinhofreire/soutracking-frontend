import { chromium } from '../tools/playwright/node_modules/playwright/index.mjs';
const url='http://127.0.0.1:8186/?v=20260522-white-fix&panel=map';
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1510,height:860}});
const logs=[];
page.on('console',m=>logs.push(`[${m.type()}] ${m.text()}`));
page.on('pageerror',e=>logs.push(`[pageerror] ${e.message}`));
page.on('requestfailed',r=>logs.push(`[requestfailed] ${r.url()} :: ${r.failure()?.errorText}`));
await page.goto(url,{waitUntil:'networkidle',timeout:120000});
await page.waitForTimeout(12000);
const state=await page.evaluate(()=>({
  hasGlass: !!document.querySelector('flt-glass-pane'),
  bodyChildren: document.body.children.length,
  inputCount: document.querySelectorAll('input').length,
  readyType: typeof window.$dartReadyToRunMain,
  runType: typeof window.$dartRunMain,
}));
await page.screenshot({path:'.tmp_white_fix_after_patch2.png',fullPage:true});
console.log(JSON.stringify({state,logs},null,2));
await browser.close();
