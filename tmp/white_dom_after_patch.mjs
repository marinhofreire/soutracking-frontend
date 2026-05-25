import { chromium } from '../tools/playwright/node_modules/playwright/index.mjs';
const url='http://127.0.0.1:8186/?v=20260522-white-fix&panel=map';
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1510,height:860}});
await page.goto(url,{waitUntil:'networkidle',timeout:120000});
await page.waitForTimeout(8000);
const dom=await page.evaluate(()=>({
  children:[...document.body.children].map(c=>({tag:c.tagName.toLowerCase(),id:c.id,cls:c.className,style:c.getAttribute('style'),w:c.clientWidth,h:c.clientHeight})),
  canvases:[...document.querySelectorAll('canvas')].map(c=>({w:c.width,h:c.height,style:c.getAttribute('style')})),
  hasShadow: !!document.querySelector('flt-glass-pane') || !!document.querySelector('flt-scene-host') || !!document.querySelector('flutter-view'),
  html: document.body.innerHTML.slice(0,1200)
}));
console.log(JSON.stringify(dom,null,2));
await browser.close();
