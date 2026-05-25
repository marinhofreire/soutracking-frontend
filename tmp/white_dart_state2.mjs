import { chromium } from '../tools/playwright/node_modules/playwright/index.mjs';
const url='http://127.0.0.1:8186/?v=20260522-white-fix&panel=map';
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1510,height:860}});
await page.goto(url,{waitUntil:'domcontentloaded',timeout:120000});
await page.waitForTimeout(12000);
const s=await page.evaluate(()=>({
  dartReadyType: typeof window.$dartReadyToRunMain,
  dartRunType: typeof window.$dartRunMain,
  dartMainTearType: typeof window.$dartMainTearOffs,
  dartMainTearKeys: window.$dartMainTearOffs ? Object.keys(window.$dartMainTearOffs).slice(0,20) : [],
  appId: window.$dartAppId,
  appInstanceId: window.$dartAppInstanceId,
  moduleStrategy: window.$dartModuleStrategy,
  entrypointPath: window.$dartEntrypointPath,
  emitDebug: window.$dartEmitDebugEvents,
  hasInitFlutter: !!window._flutter?.loader,
}));
console.log(JSON.stringify(s,null,2));
await browser.close();
