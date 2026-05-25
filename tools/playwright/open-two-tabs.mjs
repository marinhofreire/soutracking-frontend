import { chromium } from 'playwright';

const args = process.argv.slice(2);
const hasFlag = (flag) => args.includes(flag);
const readFlagValue = (flag, fallback) => {
  const entry = args.find((item) => item.startsWith(`${flag}=`));
  if (!entry) return fallback;
  const value = entry.slice(flag.length + 1).trim();
  return value.length > 0 ? value : fallback;
};

const frontUrl = process.env.FRONT_URL || 'http://localhost:65517/';
const backendUrl = process.env.BACKEND_URL || 'http://api.soutracking.com.br/';
const headed = !hasFlag('--headless');
const autoCloseMs = Number.parseInt(readFlagValue('--auto-close', '0'), 10) || 0;

const waitForStopSignal = () =>
  new Promise((resolve) => {
    const onSignal = () => resolve();
    process.once('SIGINT', onSignal);
    process.once('SIGTERM', onSignal);
  });

const start = async () => {
  const browser = await chromium.launch({
    headless: !headed,
    slowMo: headed ? 200 : 0,
  });

  const context = await browser.newContext({
    viewport: { width: 1440, height: 900 },
  });

  const frontPage = await context.newPage();
  await frontPage.goto(frontUrl, {
    waitUntil: 'domcontentloaded',
    timeout: 45000,
  });
  await frontPage.bringToFront();

  const backendPage = await context.newPage();
  await backendPage.goto(backendUrl, {
    waitUntil: 'domcontentloaded',
    timeout: 45000,
  });

  console.log('Playwright pronto com 2 guias:');
  console.log(`1) Frontend: ${frontUrl}`);
  console.log(`2) Backend:  ${backendUrl}`);

  if (headed) {
    console.log('Deixe esse terminal aberto durante os testes.');
    console.log('Para encerrar: Ctrl + C');
  }

  if (autoCloseMs > 0) {
    setTimeout(async () => {
      await browser.close();
      process.exit(0);
    }, autoCloseMs);
    return;
  }

  if (!headed) {
    await browser.close();
    return;
  }

  await waitForStopSignal();
  await browser.close();
  process.exit(0);
};

start().catch((error) => {
  console.error('Falha ao abrir as duas guias:', error);
  process.exit(1);
});



