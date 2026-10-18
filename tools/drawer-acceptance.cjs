const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const {execFileSync} = require('node:child_process');
const fs = require('node:fs');
const out = 'docs/acceptance/fm-drawer';
const fixtureEnv = {...process.env, MIX_ENV: 'acceptance', FOREMAN_ROLE: 'web', PORT: '4784'};
delete fixtureEnv.PHX_SERVER;
const fixture = (...args) => execFileSync('mix', ['run', 'tools/drawer-fixture.exs', ...args], {env: fixtureEnv, encoding: 'utf8'}).trim().split('\n').at(-1);
const base = 'http://127.0.0.1:4783';
(async () => {
  fs.mkdirSync(out, {recursive: true});
  fixture('clear');
  const id = fixture('ask');
  const browser = await chromium.launch({headless: true});
  const errors = [];
  try {
    const context = await browser.newContext();
    context.on('page', page => page.on('pageerror', e => errors.push(e.message)));
    const page = await context.newPage();
    for (const [name, path] of [['initiatives', '/'], ['pull-requests', '/pull-requests'], ['settings', '/settings'], ['documents', '/documents/scratch']]) {
      for (const width of [1440, 390]) {
        for (const theme of ['light', 'dark']) {
          await page.setViewportSize({width, height: 1000});
          await page.goto(base + path);
          await page.locator('.phx-connected').waitFor();
          await page.locator(`#theme-${theme}`).click();
          await page.waitForFunction(theme => document.documentElement.dataset.theme === theme, theme);
          const baseline = await page.evaluate(() => {
            const nav = document.querySelector('nav[aria-label=Main]');
            const reference = nav.cloneNode(true);
            reference.style.cssText = `position:absolute;left:-2000px;top:0;width:${nav.clientWidth}px`;
            reference.innerHTML = `<a class="bb-nav"><span>Needs you</span><span class="ml-auto rounded-full border border-base bg-base px-2 py-0.5 text-xs font-semibold text-foreground">1</span></a>` + [...nav.children].slice(1).map(el => el.outerHTML).join('');
            reference.querySelectorAll('[id]').forEach(el => el.removeAttribute('id'));
            document.body.append(reference);
            const style = el => {
              const s = getComputedStyle(el), r = el.getBoundingClientRect();
              return [r.width, r.height, s.backgroundColor, s.borderColor, s.borderWidth, s.borderRadius, s.fontSize, s.fontWeight, s.paddingTop, s.paddingRight];
            };
            const offsets = el => [...el.children].slice(1, 4).map(child => child.getBoundingClientRect().top - el.getBoundingClientRect().top);
            const result = {badge: style(document.querySelector('#needs-you-badge')), expectedBadge: style(reference.firstElementChild.lastElementChild), offsets: offsets(nav), expectedOffsets: offsets(reference)};
            reference.remove();
            return result;
          });
          assert.deepEqual(baseline.badge, baseline.expectedBadge, 'badge geometry and style match main');
          assert.deepEqual(baseline.offsets, baseline.expectedOffsets, 'nav spacing matches main');
          const url = page.url();
          await page.evaluate(() => {
            window.drawerOpened = false;
            document.querySelector('#request-drawer').addEventListener('fluxon:dialog:opened', () => window.drawerOpened = true, {once: true});
          });
          await page.locator('#needs-you-badge').click();
          const dialog = page.locator('#request-drawer [role=dialog]');
          await dialog.waitFor({state: 'visible'});
          await page.locator(`#drawer-decision-${id}`).waitFor();
          await page.waitForFunction(() => document.querySelector('#needs-you-badge').getAttribute('aria-expanded') === 'true');
          assert.equal(page.url(), url);
          await page.waitForFunction(() => window.drawerOpened);
          assert.equal(await page.evaluate(() => document.activeElement.id), 'request-drawer-title', 'initial focus is the drawer heading');
          assert.equal(await page.locator('#request-drawer a:focus-visible, #request-drawer button:focus-visible, #request-drawer input:focus-visible').count(), 0, 'no control focus ring on open');
          await page.screenshot({path: `${out}/${name}-${width}-${theme}.png`, fullPage: false, animations: 'disabled'});
          for (let i = 0; i < 48; i++) {
            await page.keyboard.press(i < 24 ? 'Tab' : 'Shift+Tab');
            assert.ok(await dialog.evaluate(el => el.contains(document.activeElement)), 'focus stays in drawer');
          }
          assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'no horizontal overflow');
          await page.keyboard.press('Escape');
          await dialog.waitFor({state: 'hidden'});
          await page.waitForFunction(() => document.activeElement.id === 'needs-you-badge');
          assert.equal(page.url(), url);
        }
      }
    }
    console.log('PASS four pages × two widths × two themes; unchanged URL, focus trap, Escape, focus return');
    await page.goto(base + '/needs-you');
    await page.locator('.phx-connected').waitFor();
    await page.locator('#needs-you-badge').click();
    await page.locator(`#drawer-decision-${id}`).waitFor();
    assert.equal(await page.locator(`[id="decision-${id}"]`).count(), 1);
    assert.equal(await page.locator(`[id="drawer-decision-${id}"]`).count(), 1);
    await page.locator(`#drawer-submit-answer-${id}`).click();
    await page.locator('#drawer-error').waitFor({state: 'visible'});
    assert.equal(JSON.parse(fixture('get', id)).state, 'pending');
    await page.locator(`#drawer-decision-${id} input[value=Compact]`).check();
    await page.locator(`#drawer-decision-note-${id}`).fill('Keep shortcuts');
    const incoming = fixture('ask');
    await page.locator(`#drawer-request-${incoming}`).waitFor();
    assert.ok(await page.locator(`#drawer-decision-${id} input[value=Compact]`).isChecked());
    assert.equal(await page.locator(`#drawer-decision-note-${id}`).inputValue(), 'Keep shortcuts');
    await page.locator(`#drawer-submit-answer-${id}`).click();
    await page.locator(`#drawer-request-${id}`).waitFor({state: 'detached'});
    assert.equal(await page.locator('#drawer-error').count(), 0);
    assert.deepEqual(JSON.parse(fixture('get', id)), {state: 'answered', note: 'Keep shortcuts', outcome: {answer: 'Compact'}});
    await page.locator(`#request-${id}`).waitFor({state: 'detached'});
    await page.locator(`#drawer-decision-note-${incoming}`).fill('Not now');
    await page.locator(`#drawer-submit-decline-${incoming}`).click();
    await page.locator(`#drawer-request-${incoming}`).waitFor({state: 'detached'});
    assert.equal(JSON.parse(fixture('get', incoming)).state, 'declined');
    await page.locator('#drawer-empty').waitFor({state: 'visible'});
    await page.keyboard.press('Escape');
    await page.locator('#request-drawer [role=dialog]').waitFor({state: 'hidden'});
    await page.locator('#needs-you-badge').click();
    await page.locator('#drawer-empty').waitFor({state: 'visible'});
    console.log('PASS shared cards; simultaneous page/drawer IDs; incoming request preserves draft; answer, decline and empty reopening');
    for (const action of ['approve', 'decline']) {
      const pr = fixture('open-pr');
      await page.locator(`#drawer-open_pr-${pr}`).waitFor();
      assert.equal(await page.locator(`#drawer-request-${pr} dd`).filter({hasText: 'Review the layout'}).count(), 1);
      await page.locator(`#drawer-open_pr-note-${pr}`).fill('Reviewed in drawer');
      if (action === 'approve') await page.screenshot({path: `${out}/open-pr-390-dark.png`, animations: 'disabled'});
      await page.locator(`#drawer-submit-${action}-${pr}`).click();
      await page.locator(`#drawer-request-${pr}`).waitFor({state: 'detached'});
      const outcome = JSON.parse(fixture('get', pr));
      assert.equal(outcome.state, action === 'approve' ? 'approved' : 'declined');
      assert.equal(outcome.note, 'Reviewed in drawer');
    }
    const merge = fixture('merge');
    await page.locator(`#drawer-merge-${merge}`).waitFor();
    assert.equal(await page.locator(`#drawer-request-${merge} dd`).filter({hasText: '#5'}).count(), 1);
    await page.locator(`#drawer-merge-note-${merge}`).fill('Wait for review');
    await page.screenshot({path: `${out}/merge-390-dark.png`, animations: 'disabled'});
    await page.locator(`#drawer-submit-decline-${merge}`).click();
    await page.locator(`#drawer-request-${merge}`).waitFor({state: 'detached'});
    assert.equal(JSON.parse(fixture('get', merge)).state, 'declined');
    console.log('PASS main badge geometry/nav spacing; heading focus without control ring; open-PR approve/decline; merge card/decline');
    assert.deepEqual(errors, []);
    console.log('PASS zero browser errors');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exit(1); });
