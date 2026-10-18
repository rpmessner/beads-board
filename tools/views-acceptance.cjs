// NODE_PATH=<Playwright node_modules> node tools/views-acceptance.cjs
// Read-only browser acceptance against a populated web-only server.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');

(async () => {
  const browser = await chromium.launch({headless: true});
  const context = await browser.newContext({viewport: {width: 1440, height: 1000}});
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  const base = process.env.FOREMAN_URL || 'http://127.0.0.1:4756';
  const out = 'docs/acceptance/bb-views';
  fs.mkdirSync(out, {recursive: true});
  const ready = () => page.locator('[data-phx-main].phx-connected').waitFor();
  await page.goto(base + '/');
  await ready();
  await page.locator('#view-open[aria-pressed=true]').waitFor();
  assert.equal(await page.locator('#advanced-filters').isVisible(), false);
  assert.equal(await page.locator('#filters_q').isVisible(), true);
  assert.equal(await page.locator('#filters_project').count(), 0);
  const buttons = await page.locator('#initiative-views').boundingBox();
  const search = await page.locator('#filters_q').boundingBox();
  assert.ok(Math.abs(buttons.y - search.y) < 2, 'search must sit beside views');
  assert.ok(search.x > buttons.x + buttons.width, 'search follows the button group');
  for (const theme of ['light', 'dark']) {
    await page.click('#theme-' + theme);
    await page.screenshot({path: `${out}/default-${theme}.png`, fullPage: true, animations: 'disabled'});
  }
  await page.click('#toggle-filters');
  await page.locator('#toggle-filters[aria-expanded=true]').waitFor();
  for (const theme of ['light', 'dark']) {
    await page.click('#theme-' + theme);
    await page.screenshot({path: `${out}/advanced-${theme}.png`, fullPage: true, animations: 'disabled'});
  }
  await page.click('#view-stale');
  await page.waitForURL(url => url.searchParams.get('view') === 'stale');
  await page.fill('#filters_q', 'board');
  await page.waitForURL(url => url.searchParams.get('q') === 'board');
  assert.equal(new URL(page.url()).searchParams.get('stale'), '');
  assert.equal(new URL(page.url()).searchParams.get('view'), 'stale');
  await page.press('#filters_q', 'Enter');
  await page.locator('#view-stale[aria-pressed=true]').waitFor();
  await page.selectOption('#filters_status', 'closed');
  await page.waitForURL(url => url.searchParams.get('status') === 'closed');
  await page.click('#toggle-filters');
  await page.locator('#toggle-filters[aria-expanded=false]').waitFor();
  assert.equal(await page.locator('#advanced-filter-count').innerText(), '1');
  await page.click('#view-all');
  await page.waitForURL(url => url.searchParams.get('view') === 'all');
  assert.equal(await page.locator('#advanced-filter-count').count(), 0);
  await page.click('#toggle-filters');
  await page.locator('#toggle-filters[aria-expanded=true]').waitFor();
  const savedURL = page.url();
  await page.getByRole('link', {name: 'Settings', exact: true}).click();
  await page.locator('#config-status').waitFor();
  await page.getByRole('link', {name: 'Initiatives', exact: true}).click();
  await ready();
  await page.waitForURL(savedURL);
  await page.locator('#toggle-filters[aria-expanded=true]').waitFor();
  await page.reload();
  await ready();
  await page.locator('#view-all[aria-pressed=true]').waitFor();
  await page.locator('#toggle-filters[aria-expanded=true]').waitFor();
  await page.goto(base + '/?view=open');
  await ready();
  assert.equal(await page.inputValue('#filters_q'), '');
  await page.click('#view-in-flight');
  await page.waitForURL(url => url.searchParams.get('view') === 'in-flight');
  await page.goBack();
  await page.locator('#view-open[aria-pressed=true]').waitFor();
  await page.goForward();
  await page.locator('#view-in-flight[aria-pressed=true]').waitFor();
  await page.goto(base + '/?status=closed');
  await ready();
  assert.equal(await page.locator('#initiative-views [aria-pressed=true]').count(), 0);
  assert.equal(await page.inputValue('#filters_status'), 'closed');
  await page.goto(base + '/?view[]=bad&status[]=bad&q[]=bad');
  await ready();
  await page.locator('#view-open[aria-pressed=true]').waitFor();
  assert.equal(await page.inputValue('#filters_q'), '');
  await page.evaluate(() => {
    localStorage.setItem('foreman:initiative-filters:v1', 'bad json');
    localStorage.setItem('foreman:initiative-filters-open:v1', 'bad json');
  });
  await page.goto(base + '/');
  await ready();
  await page.locator('#view-open[aria-pressed=true]').waitFor();
  await page.locator('#toggle-filters[aria-expanded=false]').waitFor();
  assert.deepEqual(errors, []);
  await browser.close();
  console.log('PASS: default/advanced light and dark screenshots; views, search, overrides/count, Settings restore, disclosure persistence, reload, URL precedence, back/forward, legacy links, malformed params/storage; no page errors');
})().catch(error => { console.error(error); process.exit(1); });
