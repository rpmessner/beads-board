// NODE_PATH=<Playwright node_modules> node tools/sheet-acceptance.cjs
// Read-only acceptance against the populated development database.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
(async () => {
  const browser = await chromium.launch({headless: true, ignoreDefaultArgs: ['--hide-scrollbars']});
  const context = await browser.newContext({viewport: {width: 1440, height: 1000}});
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  const base = process.env.BOARD_URL || 'http://127.0.0.1:4758';
  const out = 'docs/acceptance/bb-sheet';
  fs.mkdirSync(out, {recursive: true});
  const ready = () => page.locator('[data-phx-main].phx-connected').waitFor();
  for (const [repo, epic] of [['beads-board', 'bb-c2w'], ['form-engine', 'fe-lwp']]) {
    await page.goto(`${base}/epics/${repo}/${epic}`);
    await ready();
    await page.locator('#epic-title').waitFor();
    assert.ok(await page.locator('#epic-history article').count() > 0);
    assert.ok(await page.locator('#epic-columns').evaluate(el => el.scrollWidth <= el.clientWidth + 1), 'all five columns fit desktop width');
    const emptyPlanned = page.locator('[data-band=planned]').filter({hasNot: page.locator('[data-ticket]')});
    for (const cell of await emptyPlanned.all()) {
      assert.ok((await cell.boundingBox()).height <= 100, 'empty stage cells must not stretch to their populated neighbours');
    }
    assert.equal(await page.locator('[data-band=fallout]').count(), epic === 'fe-lwp' ? 2 : 0);
    const history = await page.locator('#epic-history').innerText();
    assert.doesNotMatch(history, /\d{4}-\d{2}-\d{2}T|\brow\b|emit:|record:/);
    await page.locator('#blocking-graph[tabindex="0"]').waitFor();
    assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'graph must not widen the page');
    assert.ok(await page.locator('#blocking-graph').evaluate(el => el.offsetHeight - el.clientHeight > 2), 'horizontal scrollbar must be visible');
    if (epic === 'fe-lwp') {
      assert.equal(await page.locator('[data-band=fallout] [data-ticket="fe-lwp.15"]').count(), 1);
      assert.equal(await page.locator('[data-band=fallout] [data-ticket="fe-lwp.16"]').count(), 1);
    }
    for (const theme of ['light', 'dark']) {
      await page.click('#theme-' + theme);
      await page.screenshot({path: `${out}/${epic}-${theme}.png`, fullPage: true, animations: 'disabled'});
      const graph = page.locator('#blocking-graph');
      await graph.evaluate(el => { el.scrollLeft = el.scrollWidth; });
      const rightmostVisible = await graph.evaluate(el => {
        const boundary = el.getBoundingClientRect();
        const nodes = [...el.querySelectorAll('#graph-nodes a')];
        const last = nodes.sort((a,b) => b.offsetLeft - a.offsetLeft)[0].getBoundingClientRect();
        return el.scrollLeft > 0 && last.right <= boundary.right && last.left >= boundary.left;
      });
      assert.ok(rightmostVisible, 'rightmost graph nodes must be reachable inside the scroll area');
      await graph.screenshot({path: `${out}/${epic}-graph-right-${theme}.png`, animations: 'disabled'});
      await graph.evaluate(el => { el.scrollLeft = 0; });
    }
  }
  const origin = '/epics/beads-board/bb-c2w?project=beads-board&type=task';
  await page.goto(base + origin);
  await ready();
  await page.locator('[data-ticket="bb-c2w.5"]').click();
  await page.waitForURL(url => url.searchParams.get('ticket') === 'beads-board:bb-c2w.5');
  await page.locator('#ticket-sheet [role=dialog]').waitFor({state: 'visible'});
  assert.equal(await page.getByRole('dialog', {name: 'Initiatives view: epics as the spine'}).count(), 1);
  assert.ok(await page.locator('#ticket-history article').count() > 1);
  assert.doesNotMatch(await page.locator('#ticket-history').innerText(), /\d{4}-\d{2}-\d{2}T|\brow\b|emit:|record:/);
  assert.equal(await page.locator('#ticket-actions').innerText(), '');
  for (const theme of ['light', 'dark']) {
    // Use the application theme's persisted value, then reload to verify direct URL opening.
    await page.evaluate(t => { localStorage.setItem('phx:theme', t); document.documentElement.setAttribute('data-theme', t); }, theme);
    await page.reload(); await ready();
    await page.locator('#ticket-sheet [role=dialog]').waitFor({state: 'visible'});
    await page.waitForFunction(() => Math.abs(document.querySelector('#ticket-sheet [data-part=content]').getBoundingClientRect().right - innerWidth) < 1);
    await page.screenshot({path: `${out}/ticket-${theme}.png`, animations: 'disabled'});
    await page.locator('#ticket-history-section').evaluate(el => el.scrollIntoView({block: 'start'}));
    await page.screenshot({path: `${out}/ticket-history-${theme}.png`, animations: 'disabled'});
  }
  await page.locator('#ticket-close').click();
  await page.waitForURL(base + origin);
  await page.goBack();
  await page.locator('#ticket-sheet[data-open=true] [role=dialog]').waitFor({state: 'visible'});
  await page.goForward();
  await page.locator('#ticket-sheet').waitFor({state: 'hidden'});
  await page.locator('[data-ticket="bb-c2w.5"]').click();
  await page.locator('#ticket-sheet [role=dialog]').waitFor({state: 'visible'});
  await page.keyboard.press('Escape');
  await page.waitForURL(base + origin);
  await page.locator('#epic-back').click();
  await ready();
  assert.equal(new URL(page.url()).searchParams.get('type'), 'task');
  await page.locator('[data-bead="bb-c2w"] button').click();
  await page.locator('[data-bead="bb-c2w.6"] a').click();
  await page.locator('#ticket-sheet [role=dialog]').waitFor({state: 'visible'});
  await page.locator('#ticket-close').click();
  assert.equal(new URL(page.url()).pathname, '/');
  assert.equal(new URL(page.url()).searchParams.get('type'), 'task');
  await page.setViewportSize({width: 390, height: 844});
  await page.goto(base + '/epics/form-engine/fe-lwp?ticket=form-engine:fe-lwp.16');
  await ready();
  await page.locator('#ticket-sheet [role=dialog]').waitFor({state: 'visible'});
  await page.waitForFunction(() => Math.abs(document.querySelector('#ticket-sheet [data-part=content]').getBoundingClientRect().right - innerWidth) < 1);
  await page.screenshot({path: `${out}/mobile.png`, animations: 'disabled'});
  await page.locator('#ticket-close').click();
  await page.waitForURL(url => !url.searchParams.has('ticket'));
  assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'mobile epic must not widen the page');
  assert.ok(await page.locator('#blocking-graph').evaluate(el => el.clientWidth <= innerWidth && el.scrollWidth > el.clientWidth), 'mobile graph has its own horizontal viewport');
  assert.deepEqual(errors, []);
  await browser.close();
  console.log('PASS: real epic/fallout/history screenshots, URL reload/back/forward, close/Escape, Initiatives rows, retained filters, mobile; no page errors');
})().catch(error => { console.error(error); process.exit(1); });
