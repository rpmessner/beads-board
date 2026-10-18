// Requires Playwright on NODE_PATH; uses only the isolated acceptance config.
const {chromium} = require('playwright');
const fs = require('node:fs');
const file = '/tmp/bb-exec/config/foreman.toml';

(async () => {
  const original = fs.readFileSync(file, 'utf8');
  const browser = await chromium.launch({headless: true});
  const page = await browser.newPage({viewport: {width: 1440, height: 1240}});
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(process.env.FOREMAN_URL || 'http://127.0.0.1:4751/settings');
  await page.waitForSelector('#repo-form-engine');
  await page.waitForFunction(() => document.querySelector('[data-phx-main]')?.classList.contains('phx-connected'));
  try {
    fs.writeFileSync(file, original + '\n[[columns]]\ntitle = "Acceptance column"\nstages = ["queued"]\n');
    await page.getByText('Acceptance column', {exact: true}).waitFor({timeout: 5000});
    fs.writeFileSync(file, original + '\n[[columns]]\ntitle = "Invalid"\nstages = ["speccing"]\n');
    await page.locator('#config-error').waitFor({timeout: 5000});
    if (!await page.getByText('Acceptance column', {exact: true}).isVisible()) throw Error('Last good config lost');
  } finally {
    fs.writeFileSync(file, original);
    await page.locator('#config-error').waitFor({state: 'hidden', timeout: 10000});
  }
  for (const theme of ['light', 'dark']) {
    await page.click(`#theme-${theme}`);
    await page.screenshot({path: `/tmp/bb-exec/settings-${theme}.png`, fullPage: true, animations: 'disabled'});
  }
  await page.setViewportSize({width: 390, height: 844});
  if (await page.evaluate(() => document.documentElement.scrollWidth > innerWidth)) throw Error('Mobile page overflows');
  await page.screenshot({path: '/tmp/bb-exec/settings-mobile.png', fullPage: true, animations: 'disabled'});
  if (errors.length) throw Error(errors.join('\n'));
  console.log('Live config reload, last-good retention, light/dark screenshots, mobile width: PASS');
  await browser.close();
})().catch(error => { console.error(error); process.exit(1); });
