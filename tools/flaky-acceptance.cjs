// NODE_PATH=<Playwright node_modules> FOREMAN_URL=http://127.0.0.1:4771 node tools/flaky-acceptance.cjs
// Read-only browser checks; run against an acceptance server without test_helper.exs.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');

(async () => {
  const browser = await chromium.launch({headless: true});
  try {
    const context = await browser.newContext({viewport: {width: 1440, height: 1000}});
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    const base = process.env.FOREMAN_URL || 'http://127.0.0.1:4771';
    const out = 'docs/acceptance/bb-flaky';
    fs.mkdirSync(out, {recursive: true});
    const ready = () => page.locator('[data-phx-main].phx-connected').waitFor();

    // A fresh profile has no remembered query: the connected view stays at /.
    await page.goto(base + '/');
    await ready();
    await page.locator('#view-open[aria-pressed=true]').waitFor();
    assert.equal(new URL(page.url()).pathname, '/');
    assert.equal(new URL(page.url()).search, '');
    assert.equal(await page.inputValue('#filters_q'), '');
    await page.screenshot({path: `${out}/bare-light.png`, fullPage: true, animations: 'disabled'});

    await page.evaluate(() => localStorage.setItem('foreman:initiative-filters:v1',
      JSON.stringify({view: 'all', q: 'Clock'})));
    await page.goto(base + '/');
    await ready();
    await page.waitForURL(url => url.searchParams.get('q') === 'Clock' && url.searchParams.get('view') === 'all');
    await page.locator('#view-all[aria-pressed=true]').waitFor();
    assert.equal(await page.inputValue('#filters_q'), 'Clock');
    await page.click('#theme-dark');
    await page.screenshot({path: `${out}/restored-dark.png`, fullPage: true, animations: 'disabled'});

    // Explicit URL clearing must still beat remembered filters.
    await page.goto(base + '/?view=open&q=');
    await ready();
    await page.locator('#view-open[aria-pressed=true]').waitFor();
    assert.equal(await page.inputValue('#filters_q'), '');
    assert.deepEqual(errors, []);
    fs.writeFileSync(`${out}/browser-result.txt`,
      'PASS: fresh bare route stays put; saved view/search restore into URL; explicit URL wins; no page errors.\n');
    console.log('PASS: bare route without memory, saved-filter restore, explicit URL authority; no page errors');
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exit(1); });
