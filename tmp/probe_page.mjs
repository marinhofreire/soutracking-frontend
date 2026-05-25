import { chromium } from '../tools/playwright/node_modules/playwright/index.mjs';
const url='http://127.0.0.1:8186/?v=20260522-final-4-pontos&panel=map';
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1510,height:860}});
try{
  const resp=await page.goto(url,{waitUntil:'domcontentloaded',timeout:120000});
  await page.waitForTimeout(3000);
  const html=await page.content();
  const title=await page.title();
  console.log(JSON.stringify({status:resp?.status(),title,htmlLen:html.length,url:page.url()},null,2));
}catch(e){console.log('ERR',e.message)}
await browser.close();
