import { chromium } from '../tools/playwright/node_modules/playwright/index.mjs';
const url='http://127.0.0.1:8186/?v=20260522-white-fix&panel=map';
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1510,height:860}});
const logs=[];
page.on('console',m=>logs.push(`[${m.type()}] ${m.text()}`));
page.on('pageerror',e=>logs.push(`[pageerror] ${e.message}`));
page.on('requestfailed',r=>logs.push(`[requestfailed] ${r.url()} ${r.failure()?.errorText}`));
await page.goto(url,{waitUntil:'domcontentloaded',timeout:120000});
for (let i=0;i<12;i++) { await page.waitForTimeout(5000); logs.push(`-- t=${(i+1)*5}s glass=${await page.evaluate(()=>!!document.querySelector('flt-glass-pane'))} children=${await page.evaluate(()=>document.body.children.length)} --`); }
await page.screenshot({path:'.tmp_white_wait60.png',fullPage:true});
console.log(JSON.stringify({logs},null,2));
await browser.close();
