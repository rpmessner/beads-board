const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');

(async () => {
  const browser = await chromium.launch({headless: true});
  const page = await browser.newPage({viewport: {width: 1440, height: 1000}});
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  const file = 'lib/foreman_web/components/layouts/root.html.heex';
  const original = fs.readFileSync(file, 'utf8');
  try {
    await page.goto(process.env.PREVIEW_URL);
    await page.locator('.phx-connected').first().waitFor();
    await page.screenshot({path: '.preview-check/preview.png', fullPage: true});
    fs.writeFileSync(file, original.replace('<body>', '<body data-preview-reload="checked">'));
    await page.locator('body[data-preview-reload="checked"]').waitFor({timeout: 30000});
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    assert.deepEqual(errors, []);
    console.log('LiveView connected; code edit live-reloaded; no overflow or browser errors');
  } finally {
    fs.writeFileSync(file, original);
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
