import { chromium } from '../tools/playwright/node_modules/playwright/index.mjs';
const url='http://127.0.0.1:8186/?v=20260522-white-fix&panel=map';
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1510,height:860}});
const logs=[];
page.on('console',m=>logs.push(`[${m.type()}] ${m.text()}`));
page.on('pageerror',e=>logs.push(`[pageerror] ${e.message}`));
await page.goto(url,{waitUntil:'domcontentloaded',timeout:120000});
await page.waitForTimeout(10000);
const before=await page.evaluate(()=>({glass:!!document.querySelector('flt-glass-pane'),children:document.body.children.length}));
const manual=await page.evaluate(async()=>{
  try{
    if (typeof window.$dartRunMain==='function') {
      window.$dartRunMain();
      return {called:true};
    }
    return {called:false};
  }catch(e){return {called:false,error:String(e),stack:e?.stack||''};}
});
await page.waitForTimeout(6000);
const after=await page.evaluate(()=>({glass:!!document.querySelector('flt-glass-pane'),children:document.body.children.length,inputs:document.querySelectorAll('input').length}));
await page.screenshot({path:'.tmp_white_manual_runmain.png',fullPage:true});
console.log(JSON.stringify({before,manual,after,logs},null,2));
await browser.close();
