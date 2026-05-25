import { chromium } from '../tools/playwright/node_modules/playwright/index.mjs';
const base='http://127.0.0.1:8186/?v=20260522-map-devices-status-final';
const browser=await chromium.launch({headless:true});
const ctx=await browser.newContext({viewport:{width:1510,height:860}});
const page=await ctx.newPage();
await page.goto(`${base}&panel=dashboard`,{waitUntil:'networkidle',timeout:120000});
await page.waitForTimeout(2000);
await page.mouse.click(744,435); await page.keyboard.press('Control+A'); await page.keyboard.type('demo@mackflow.com.br');
await page.mouse.click(744,531); await page.keyboard.press('Control+A'); await page.keyboard.type('123456');
await page.mouse.click(744,645); await page.waitForTimeout(8500);
await page.goto(`${base}&panel=map`,{waitUntil:'networkidle',timeout:120000});
await page.waitForTimeout(6000);
const data = await page.evaluate(() => {
  const root = document.querySelector('.gm-style') || document.body;
  const imgs = Array.from(root.querySelectorAll('img')).map(el => ({src: el.getAttribute('src') || '', alt: el.getAttribute('alt') || '', aria: el.getAttribute('aria-label') || ''}));
  const divs = Array.from(root.querySelectorAll('div[aria-label], button[aria-label]')).map(el => ({tag: el.tagName, aria: el.getAttribute('aria-label') || ''}));
  const markerLikeImgs = imgs.filter(it => /marker|maps\.googleapis|gstatic|pin|micons|spotlight-poi/i.test(it.src) || /marker|pin/i.test(it.alt) || /marker|pin/i.test(it.aria));
  const labelLike = divs.filter(it => /PIXELTI|online|offline|movimento|alerta|sem comunicacao|km\/h|mock/i.test(it.aria));
  return {
    imgCount: imgs.length,
    markerLikeImgCount: markerLikeImgs.length,
    markerLikeImgSample: markerLikeImgs.slice(0,40),
    ariaCount: divs.length,
    labelLikeCount: labelLike.length,
    labelLikeSample: labelLike.slice(0,40),
  };
});
console.log(JSON.stringify(data,null,2));
await browser.close();
