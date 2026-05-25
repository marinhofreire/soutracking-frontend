import { chromium } from '../tools/playwright/node_modules/playwright/index.mjs';
const url='http://127.0.0.1:8186/?v=20260522-white-fix&panel=map';
const browser=await chromium.launch({headless:true});
const context=await browser.newContext({viewport:{width:1510,height:860}});
await context.addInitScript(() => {
  window.__probeErrors=[];
  window.addEventListener('error', (e) => {
    window.__probeErrors.push({kind:'error', message:e.message, filename:e.filename, lineno:e.lineno, colno:e.colno});
  });
  window.addEventListener('unhandledrejection', (e) => {
    window.__probeErrors.push({kind:'unhandledrejection', reason: String(e.reason)});
  });
});
const page=await context.newPage();
await page.goto(url,{waitUntil:'networkidle',timeout:120000});
await page.waitForTimeout(8000);
const probe=await page.evaluate(()=>({
  errors: window.__probeErrors || [],
  hasFlutterLoader: !!window._flutter,
  hasDartMainRunner: !!window.dartMainRunner,
  bodyChildren: document.body.children.length,
  bodyHtml: document.body.innerHTML.slice(0,500),
}));
console.log(JSON.stringify(probe,null,2));
await browser.close();
