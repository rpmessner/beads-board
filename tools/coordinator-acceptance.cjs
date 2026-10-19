const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');

(async () => {
  const browser = await chromium.launch({headless: true});
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  fs.mkdirSync('docs/acceptance/fm-coordinator', {recursive: true});
  try {
    await page.goto(process.env.PREVIEW_URL);
    await page.locator('.phx-connected').first().waitFor();
    await page.locator('#coordinator-state').filter({hasText: 'ended'}).waitFor();
    for (const width of [1440, 390]) {
      await page.setViewportSize({width, height: 1000});
      for (const theme of ['light', 'dark']) {
        await page.evaluate(theme => {
          localStorage.setItem('phx:theme', theme);
          document.documentElement.setAttribute('data-theme', theme);
        }, theme);
        for (const id of ['coordinator-focus', 'coordinator-relaunch', 'coordinator-fresh']) {
          assert(await page.locator(`#${id}`).isVisible());
          assert(await page.locator(`#${id}`).isEnabled());
        }
        assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
        await page.screenshot({path: `docs/acceptance/fm-coordinator/board-${width}-${theme}.png`, fullPage: true, animations: 'disabled'});
      }
    }
    assert.deepEqual(errors, []);
    console.log('Coordinator controls visible/enabled, light/dark at 1440/390; no overflow or browser errors.');
  } finally {
    await browser.close();
  }
})().catch(error => {console.error(error); process.exitCode = 1;});
