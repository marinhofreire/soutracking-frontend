import { chromium } from '../tools/playwright/node_modules/playwright/index.mjs';
const url='http://127.0.0.1:8186/?v=20260522-white-fix&panel=map';
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1510,height:860}});
await page.goto(url,{waitUntil:'domcontentloaded',timeout:120000});
await page.waitForTimeout(8000);
const probe=await page.evaluate(async()=>{
  const paths=['/main.dart.js','/main_module.bootstrap.js','/ddc_module_loader.js','/web_entrypoint.dart.lib.js'];
  const out=[];
  for (const p of paths){
    try{
      const r=await fetch(p,{cache:'no-store'});
      const text=await r.text();
      out.push({p,status:r.status,len:text.length,head:text.slice(0,120)});
    }catch(e){out.push({p,error:String(e)})}
  }
  return out;
});
console.log(JSON.stringify(probe,null,2));
await browser.close();
