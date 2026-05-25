const { test } = require('@playwright/test');

const base = 'http://127.0.0.1:8186/?v=20260522-white-screen-fix';
const panels = ['devices','reports','vehicles','fences'];

for (const panel of panels) {
  test(`panel ${panel}`, async ({ page }) => {
    const logs = [];
    page.on('console', msg => logs.push(`[console:${msg.type()}] ${msg.text()}`));
    page.on('pageerror', err => logs.push(`[pageerror] ${err.message}`));
    page.on('requestfailed', req => logs.push(`[requestfailed] ${req.url()} :: ${req.failure()?.errorText}`));

    const url = `${base}&panel=${panel}`;
    await page.goto(url, { waitUntil: 'networkidle', timeout: 120000 });
    await page.waitForTimeout(10000);

    const html = await page.content();
    const text = await page.locator('body').innerText().catch(() => '');
    await page.screenshot({ path: `.tmp_pw_${panel}.png`, fullPage: true });

    console.log(`\n===== PANEL ${panel} =====`);
    console.log(`URL: ${url}`);
    console.log(`BODY_TEXT_LEN: ${text.length}`);
    console.log(`HTML_LEN: ${html.length}`);
    if (!logs.length) {
      console.log('NO_BROWSER_ERRORS');
    } else {
      for (const line of logs) console.log(line);
    }
  });
}


