import { chromium } from '../tools/playwright/node_modules/playwright/index.mjs';
const url='http://127.0.0.1:8186/?v=20260522-white-fix&panel=map';
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1510,height:860}});
const logs=[];
page.on('console',m=>logs.push(`[${m.type()}] ${m.text()}`));
page.on('pageerror',e=>logs.push(`[pageerror] ${e.message}`));
await page.goto(url,{waitUntil:'domcontentloaded',timeout:120000});
await page.waitForTimeout(6000);
const data=await page.evaluate(()=>{
  const b=document.body;
  const html=document.documentElement;
  const glass=document.querySelector('flt-glass-pane');
  const scene=document.querySelector('flt-scene-host');
  const canvases=[...document.querySelectorAll('canvas')].map(c=>({w:c.width,h:c.height,style:c.getAttribute('style')}));
  const fltEls=[...document.querySelectorAll('[class^="flt-"], flt-glass-pane, flt-scene-host, flt-platform-view')].slice(0,40).map(el=>({tag:el.tagName.toLowerCase(),cls:el.className||'',w:el.clientWidth,h:el.clientHeight,style:el.getAttribute('style')}));
  return {
    bodyBg:getComputedStyle(b).backgroundColor,
    bodyW:b.clientWidth,bodyH:b.clientHeight,
    htmlW:html.clientWidth,htmlH:html.clientHeight,
    childCount:b.children.length,
    glass: glass?{w:glass.clientWidth,h:glass.clientHeight,style:glass.getAttribute('style')}:null,
    scene: scene?{w:scene.clientWidth,h:scene.clientHeight,style:scene.getAttribute('style')}:null,
    canvases,
    fltEls,
  };
});
console.log(JSON.stringify({data,logs},null,2));
await browser.close();
