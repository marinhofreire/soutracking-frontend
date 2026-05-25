import { chromium } from '../tools/playwright/node_modules/playwright/index.mjs';
const url='http://127.0.0.1:8186/?v=20260522-white-fix&panel=map';
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1510,height:860}});
const logs=[];
page.on('console',m=>logs.push(`[${m.type()}] ${m.text()}`));
page.on('pageerror',e=>logs.push(`[pageerror] ${e.message}`));
await page.goto(url,{waitUntil:'domcontentloaded',timeout:120000});
await page.waitForTimeout(12000);
const before=await page.evaluate(()=>({readyType:typeof window.$dartReadyToRunMain,runType:typeof window.$dartRunMain,glass:!!document.querySelector('flt-glass-pane'),children:document.body.children.length}));
const invoke=await page.evaluate(()=>{
  const out={};
  try{ if(typeof window.$dartReadyToRunMain==='function'){ window.$dartReadyToRunMain(); out.readyCalled=true;} else out.readyCalled=false; }
  catch(e){ out.readyErr=String(e); }
  try{ if(typeof window.$dartRunMain==='function'){ window.$dartRunMain(); out.runCalled=true;} else out.runCalled=false; }
  catch(e){ out.runErr=String(e); }
  return out;
});
await page.waitForTimeout(8000);
const after=await page.evaluate(()=>({glass:!!document.querySelector('flt-glass-pane'),children:document.body.children.length,inputs:document.querySelectorAll('input').length,bodyText:document.body.innerText.slice(0,200)}));
await page.screenshot({path:'.tmp_white_call_ready_run.png',fullPage:true});
console.log(JSON.stringify({before,invoke,after,logs},null,2));
await browser.close();
