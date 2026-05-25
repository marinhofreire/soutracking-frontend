import { chromium } from '../tools/playwright/node_modules/playwright/index.mjs';
const url='http://127.0.0.1:8186/?v=20260522-white-fix&panel=map';
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1510,height:860}});
await page.goto(url,{waitUntil:'domcontentloaded',timeout:120000});
await page.waitForTimeout(12000);
const d=await page.evaluate(()=>{
  const l=window.$dartLoader?.loader;
  if(!l) return null;
  const out={};
  for (const k of Object.keys(l)) {
    const v=l[k];
    if (typeof v==='function') continue;
    if (v && typeof v==='object') {
      if (Array.isArray(v)) out[k]={type:'array',len:v.length};
      else out[k]={type:'object',keys:Object.keys(v).slice(0,20),len:Object.keys(v).length};
    } else out[k]=v;
  }
  const maybeErr=[];
  for (const [k,v] of Object.entries(l)) {
    if (typeof v==='string' && v.toLowerCase().includes('error')) maybeErr.push([k,v]);
  }
  return {out, maybeErr};
});
console.log(JSON.stringify(d,null,2));
await browser.close();
