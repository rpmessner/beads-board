// Start tools/tabs-acceptance.exs first. NODE_PATH=<Playwright node_modules> node tools/tabs-acceptance.cjs
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {execFileSync} = require('node:child_process');
(async () => {
  const browser = await chromium.launch({headless: true, ignoreDefaultArgs: ['--hide-scrollbars']});
  try {
    const out = 'docs/acceptance/bb-tabs';
    fs.mkdirSync(out, {recursive: true});
    const page = await browser.newPage();
    await page.addInitScript(() => {
      document.addEventListener('fluxon:dialog:opened', event => {
        if (event.target.id === 'ticket-sheet') window.tabsSheetOpened = true;
      });
      document.addEventListener('fluxon:dialog:closed', event => {
        if (event.target.id === 'ticket-sheet') window.tabsSheetOpened = false;
      });
    });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    const base = process.env.BOARD_URL || 'http://127.0.0.1:4766';
    const tabs = ['overview', 'history', 'sessions', 'notes'];
    const ready = async () => {
      await page.locator('[data-phx-main].phx-connected').waitFor();
      await page.locator('#ticket-sheet [role=dialog]').waitFor({state: 'visible'});
      await page.waitForFunction(() => window.tabsSheetOpened === true);
      await page.waitForFunction(() => Math.abs(document.querySelector('#ticket-sheet [data-part=content]').getBoundingClientRect().right - innerWidth) < 1 && document.querySelector('#ticket-sheet').getAnimations({subtree: true}).every(a => a.playState === 'finished'));
    };
    const selected = async tab => {
      await page.waitForFunction(tab => !window.liveSocket.hasPendingLink() && document.querySelector('[data-phx-main].phx-connected') && document.querySelector(`#ticket-${tab}-tab`)?.getAttribute('aria-selected') === 'true', tab);
      assert.equal(await page.locator('#ticket-tabs [role=tabpanel]:visible').count(), 1);
      assert.ok(await page.locator(`#ticket-${tab}-panel`).isVisible());
    };
    for (const [name, route] of [['initiatives', '/'], ['pull-requests', '/pull-requests']]) {
      for (const width of [1440, 390]) {
        await page.setViewportSize({width, height: 900});
        for (const theme of ['light', 'dark']) {
          const url = `${base}${route}?project=sample&ticket=sample:fe-813.2`;
          await page.goto(url); await ready();
          await page.evaluate(theme => { localStorage.setItem('phx:theme', theme); document.documentElement.setAttribute('data-theme', theme); }, theme);
          await selected('overview');
          for (const tab of tabs) {
            await page.locator(`#ticket-${tab}-tab`).click();
            await page.waitForURL(url => url.searchParams.get('tab') === tab);
            await selected(tab);
            assert.equal(new URL(page.url()).searchParams.get('project'), 'sample');
            assert.equal(new URL(page.url()).searchParams.get('ticket'), 'sample:fe-813.2');
            assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'no document overflow');
            assert.ok(await page.locator('#ticket-tabs [role=tab]').evaluateAll(tabs => tabs.every(tab => {
              const range = document.createRange(); range.selectNodeContents(tab);
              return range.getClientRects().length === 1;
            })), 'tab labels stay on one line, including with the sheet scrollbar');
            await page.screenshot({path: `${out}/${name}-${width}-${theme}-${tab}.png`, animations: 'disabled'});
          }
          await page.reload(); await ready(); await selected('notes');
          await page.goBack(); await selected('sessions'); await ready();
          await page.goForward(); await selected('notes'); await ready();
          // Fluxon uses automatic keyboard activation, including the URL patch.
          await page.locator('#ticket-notes-tab').focus();
          await page.keyboard.press('ArrowRight');
          await page.waitForURL(url => url.searchParams.get('tab') === 'overview');
          await selected('overview');
          assert.equal(await page.locator('#ticket-overview-tab').evaluate(el => el === document.activeElement), true);
          const focus = await page.locator('#ticket-overview-tab').evaluate(el => {
            const style = getComputedStyle(el);
            return {visible: el.matches(':focus-visible'), shadow: style.boxShadow, outline: style.outlineStyle};
          });
          assert.ok(focus.visible && (focus.shadow !== 'none' || focus.outline !== 'none'), 'visible keyboard focus');
          await page.screenshot({path: `${out}/${name}-${width}-${theme}-keyboard.png`, animations: 'disabled'});
          await page.keyboard.press('ArrowLeft');
          await page.waitForURL(url => url.searchParams.get('tab') === 'notes');
          await selected('notes');
          await page.locator('#ticket-close').click();
          await page.waitForURL(url => !url.searchParams.has('ticket') && !url.searchParams.has('tab'));
          assert.equal(new URL(page.url()).searchParams.get('project'), 'sample');
          await page.goto(url + '&tab=unknown'); await ready(); await selected('overview');
          await page.keyboard.press('Escape');
          await page.waitForURL(url => !url.searchParams.has('ticket') && !url.searchParams.has('tab'));
        }
      }
      await page.goto(`${base}${route}?project=sample&ticket=sample:fe-813.2`); await ready();
      const before = {};
      for (const tab of ['history', 'sessions', 'notes']) before[tab] = await page.locator(`#ticket-${tab} article`).count();
      execFileSync('mix', ['run', '--no-start', 'tools/tabs-acceptance.exs', 'update'], {
        env: {...process.env, MIX_ENV: 'test', PORT: '4766', BOARD_ROLE: 'web'}, stdio: 'pipe'
      });
      await page.waitForFunction(before => Object.entries(before).every(([tab, count]) => document.querySelectorAll(`#ticket-${tab} article`).length > count), before);
      for (const tab of ['history', 'sessions', 'notes']) assert.ok(!(await page.locator(`#ticket-${tab}-panel`).isVisible()));
      for (const [tab, content] of [['history', 'dispatch'], ['sessions', 'browser-live-worker'], ['notes', 'Browser hidden-tab update']]) {
        await page.locator(`#ticket-${tab}-tab`).click();
        await selected(tab);
        assert.ok((await page.locator(`#ticket-${tab}-panel`).innerText()).includes(content));
      }
    }
    assert.deepEqual(errors, []);
    console.log('PASS: both pages × light/dark × 390/1440; all tabs, reload/back/forward, keyboard arrows and visible focus, close/Escape, hidden live history/sessions/notes; no page errors');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exit(1); });
