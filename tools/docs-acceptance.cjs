const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const out = 'docs/acceptance/fm-docs';
fs.mkdirSync(out, {recursive: true});
async function assertLocalScrolling(page, scope, width) {
  assert.ok(await page.evaluate(() => document.scrollingElement.scrollWidth <= innerWidth), scope + ': no page overflow');
  if (width !== 390) return;
  for (const tag of ['table', 'pre']) {
    const box = page.locator(scope + ' ' + tag).first();
    const metrics = await box.evaluate(el => {
      el.scrollLeft = 0;
      const before = el.querySelector('tr, code').getBoundingClientRect().left;
      el.scrollLeft = el.scrollWidth;
      const after = el.querySelector('tr, code').getBoundingClientRect().left;
      const result = {
        width: el.clientWidth, total: el.scrollWidth, scrolled: el.scrollLeft,
        moved: before - after, right: el.getBoundingClientRect().right,
        viewport: innerWidth, overflow: getComputedStyle(el).overflowX,
        barHeight: getComputedStyle(el, '::-webkit-scrollbar').height,
        gutter: el.offsetHeight - el.clientHeight - parseFloat(getComputedStyle(el).borderTopWidth) - parseFloat(getComputedStyle(el).borderBottomWidth)
      };
      el.scrollLeft = 0;
      return result;
    });
    assert.ok(metrics.total > metrics.width, scope + ' ' + tag + ': fixture must overflow locally');
    assert.ok(metrics.scrolled > 0 && metrics.moved > 0, scope + ' ' + tag + ': content moves horizontally');
    assert.ok(Math.abs(metrics.total - metrics.width - metrics.scrolled) <= 1, scope + ' ' + tag + ': reaches the right edge');
    assert.ok(metrics.right <= metrics.viewport, scope + ' ' + tag + ': box stays inside viewport');
    assert.ok(['auto', 'scroll'].includes(metrics.overflow));
    assert.equal(metrics.barHeight, '10px', scope + ' ' + tag + ': visible scroll affordance');
    assert.ok(metrics.gutter >= 10, scope + ' ' + tag + ': scrollbar occupies visible space');
    console.log(scope + ' ' + tag + ': ' + metrics.width + 'px box / ' + metrics.total + 'px content; scrolled ' + metrics.scrolled + 'px');
  }
}
(async () => {
  const browser = await chromium.launch({headless: true, ignoreDefaultArgs: ['--hide-scrollbars']});
  const errors = [];
  for (const width of [390, 1440]) {
    for (const theme of ['light', 'dark']) {
      const context = await browser.newContext({viewport: {width, height: 1000}});
      await context.addInitScript(theme => localStorage.setItem('phx:theme', theme), theme);
      const page = await context.newPage();
      page.on('pageerror', e => errors.push(String(e)));
      await page.goto('http://127.0.0.1:4781/documents/meridian?path=docs%2Fspec.md');
      await page.waitForSelector('.phx-connected');
      await page.locator(`#theme-${theme}`).click();
      await page.waitForFunction(t => document.documentElement.dataset.theme === t, theme);
      assert.equal(await page.locator('#document-content table tbody tr').count(), 3);
      assert.equal(await page.locator('#document-content input[type=checkbox]:disabled').count(), 3);
      assert.ok(await page.locator('#document-content pre span').count() > 4);
      const color = await page.locator('#document-content pre span').first().evaluate(el => getComputedStyle(el).color);
      assert.equal(color, theme === 'dark' ? 'rgb(255, 123, 114)' : 'rgb(207, 34, 46)');
      assert.ok(await page.locator('#document-content h1').evaluate(el => parseFloat(getComputedStyle(el).fontSize) >= 24));
      await assertLocalScrolling(page, '#document-content', width);
      await page.evaluate(() => scrollTo(0, 0));
      await page.screenshot({path: `${out}/documents-${width}-${theme}.png`});
      await page.locator('#document-content h1').evaluate(el => el.scrollIntoView({block: 'start'}));
      await page.screenshot({path: `${out}/document-detail-${width}-${theme}.png`});
      if (width === 390) {
        await page.locator('#document-content table, #document-content pre').evaluateAll(els => els.forEach(el => { el.scrollLeft = el.scrollWidth; }));
        await page.screenshot({path: `${out}/document-scrolled-${width}-${theme}.png`});
      }
      await page.locator('#document-content a', {hasText: 'Storage decision'}).click();
      await page.waitForSelector('#document-content h1:text("Storage")');
      assert.ok(page.url().includes('/documents/meridian?path=docs%2Fdecisions%2Fstorage.md'));
      await page.goBack();
      await page.waitForSelector('#document-content h1:text("Release orchestration")');
      await page.goto('http://127.0.0.1:4781/?ticket=meridian:release-1');
      await page.waitForSelector('.phx-connected');
      await page.waitForSelector('#ticket-sheet [role=dialog]');
      await page.waitForFunction(() => Math.abs(document.querySelector('#ticket-sheet [data-part=content]').getBoundingClientRect().right - innerWidth) < 1 && document.querySelector('#ticket-sheet').getAnimations({subtree: true}).every(a => a.playState === 'finished'));
      assert.equal(await page.locator('#ticket-overview input[type=checkbox]:disabled').count(), 3);
      const titleSize = await page.locator('#ticket-title').evaluate(el => parseFloat(getComputedStyle(el).fontSize));
      for (const tag of ['h1', 'h2', 'h3']) {
        const sizes = await page.locator('#ticket-overview .fm-markdown ' + tag).evaluateAll(els => els.map(el => parseFloat(getComputedStyle(el).fontSize)));
        assert.ok(sizes.length > 0, 'fixture includes ' + tag);
        assert.ok(sizes.every(size => size <= 16 && size < titleSize), 'ticket ' + tag + ' is a subheading below the sheet title');
      }
      await assertLocalScrolling(page, '#ticket-overview', width);
      await page.screenshot({path: `${out}/ticket-${width}-${theme}.png`});
      if (width === 390) {
        await page.locator('#ticket-overview table, #ticket-overview pre').evaluateAll(els => els.forEach(el => { el.scrollLeft = el.scrollWidth; }));
        await page.screenshot({path: `${out}/ticket-scrolled-${width}-${theme}.png`});
      }
      await page.locator('#ticket-history-tab').click();
      const report = page.locator('#ticket-history a', {hasText: 'docs/report.md'}).last();
      await report.click();
      await page.waitForSelector('#document-content h1:text("Release report")');
      assert.equal(await page.locator('#document-content input[checked]').count(), 2);
      await page.goto('http://127.0.0.1:4781/');
      await page.waitForSelector('.phx-connected');
      await page.locator('#drafts a', {hasText: 'docs/spec.md'}).click();
      await page.waitForSelector('#document-content h1:text("Release orchestration")');
      await context.close();
    }
  }
  assert.deepEqual(errors, []);
  await browser.close();
  console.log('PASS: documents and tickets, 390/1440 × light/dark; scoped ticket headings, unchanged document headings, no page overflow, visible local scrolling to the right edge at 390px; theme colors, relative navigation/back, removed-worktree report and draft spec; no page errors.');
})().catch(e => {console.error(e); process.exit(1)});
