import { chromium } from '../tools/playwright/node_modules/playwright/index.mjs';
const url='http://127.0.0.1:8186/?v=20260522-white-fix&panel=map';
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1510,height:860}});
await page.goto(url,{waitUntil:'domcontentloaded',timeout:120000});
await page.waitForTimeout(12000);
const g=await page.evaluate(()=>({
  hasFlutter: !!window._flutter,
  hasLoader: !!window._flutter?.loader,
  hasDartLoader: !!window.$dartLoader,
  dartLoaderKeys: window.$dartLoader ? Object.keys(window.$dartLoader) : [],
  hasRequireLoader: !!window.requireLoader,
  hasDartMainRunner: !!window.dartMainRunner,
  hasDart_sdk: !!window.dart_sdk,
  hasMainModule: !!window.main,
  winKeys: Object.keys(window).filter(k=>k.includes('dart')||k.includes('flutter')).slice(0,80),
}));
console.log(JSON.stringify(g,null,2));
await browser.close();
