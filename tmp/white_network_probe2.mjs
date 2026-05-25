import { chromium } from '../tools/playwright/node_modules/playwright/index.mjs';
const url='http://127.0.0.1:8186/?v=20260522-white-fix&panel=map';
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1510,height:860}});
const started=[]; const done=new Set(); const failed=[]; const statuses=[]; const logs=[];
page.on('request',r=>started.push({u:r.url(),m:r.method()}));
page.on('requestfinished',r=>done.add(r.url()));
page.on('requestfailed',r=>failed.push({u:r.url(),m:r.method(),e:r.failure()?.errorText}));
page.on('response',r=>statuses.push({u:r.url(),s:r.status(),ct:r.headers()['content-type']||''}));
page.on('console',m=>logs.push({t:m.type(),txt:m.text()}));
page.on('pageerror',e=>logs.push({t:'pageerror',txt:e.message}));
await page.goto(url,{waitUntil:'domcontentloaded',timeout:120000});
await page.waitForTimeout(20000);
const pending=started.filter(x=>!done.has(x.u));
const bad=statuses.filter(x=>x.s>=400);
console.log(JSON.stringify({
  started: started.length,
  finished: done.size,
  failed,
  badCount: bad.length,
  bad: bad.slice(0,20),
  pendingCount: pending.length,
  pending: pending.slice(0,20),
  logs: logs.slice(0,80),
  hasGlass: await page.evaluate(()=>!!document.querySelector('flt-glass-pane')),
  bodyChildren: await page.evaluate(()=>document.body.children.length),
},null,2));
await browser.close();
