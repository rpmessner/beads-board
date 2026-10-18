// Run with Playwright on NODE_PATH against an already synced, web-only board.
// This records this build session's genuine dispatch/progress in the overlay;
// it never writes to beads or changes config.
const {chromium} = require('playwright');
const {execFileSync} = require('node:child_process');
const fs = require('node:fs');
const out = process.env.BOARD_SCREENSHOTS || 'docs/acceptance/bb-init';

(async () => {
  fs.mkdirSync(out, {recursive: true});
  const browser = await chromium.launch({headless: true});
  const page = await browser.newPage({viewport: {width: 1440, height: 1100}});
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  await page.goto(process.env.BOARD_URL || 'http://127.0.0.1:4753/');
  await page.waitForFunction(() => document.querySelector('[data-phx-main]')?.classList.contains('phx-connected'));
  const epic = id => page.locator(`#epics [data-bead="${id}"]`);
  for (const [id, closed, total] of [['fe-813', 5, 10], ['fe-lwp', 12, 19], ['bb-c2w', 4, 11]]) {
    await epic(id).locator(`[role=progressbar][aria-valuenow="${closed}"][aria-valuemax="${total}"]`).waitFor();
  }
  await epic('bb-c2w').locator('button').click();
  await epic('bb-c2w.5').waitFor();
  const childIds = await page.locator('#epics [data-kind="ticket"][data-bead^="bb-c2w."]').evaluateAll(rows => rows.map(r => r.dataset.bead));
  const expectedIds = Array.from({length: 11}, (_, i) => `bb-c2w.${i + 1}`);
  if (JSON.stringify(childIds) !== JSON.stringify(expectedIds)) throw Error(`Non-natural child order: ${childIds}`);
  await page.locator('#toggle-done[aria-expanded="false"]').waitFor();
  if (await page.locator('#epics [data-kind="epic"][data-stage="done"], #epics [data-kind="epic"][data-stage="shipped"]').count()) throw Error('Finished epic in active list');
  if (!await page.locator('#epics-panel + #done-panel + #unplanned-panel').count()) throw Error('Done group is not above Unplanned');
  execFileSync('mix', ['run', '-e', `
    Logger.configure(level: :warning)
    key = {"beads-board", "bb-c2w.5"}
    if Board.Overlay.get(key).stage == :queued do
      {:ok, _} = Board.Overlay.apply_event(key, {:dispatch, %{window: "bb-init", branch: "bb-init", brief_path: "docs/briefs/bb-init.md"}}, %{actor: "pi"})
    end
    if Board.Overlay.get(key).stage in [:dispatched, :building, :reported] do
      {:ok, _} = Board.Overlay.apply_event(key, {:progress, %{body: "Overlay, initiative tree and home implemented; verifying screenshots and review gates."}}, %{actor: "pi"})
    end
  `], {env: {...process.env, BOARD_ROLE: 'web'}, stdio: 'pipe'});
  await epic('bb-c2w.5').getByText(/^\s*(building|reported)\s*$/, {exact: true}).waitFor({timeout: 10000});
  await page.screenshot({path: `${out}/build-children.png`, fullPage: true, animations: 'disabled'});
  await epic('bb-c2w').locator('button').click();
  for (const theme of ['light', 'dark']) {
    await page.click(`#theme-${theme}`);
    await page.screenshot({path: `${out}/initiatives-${theme}.png`, fullPage: true, animations: 'disabled'});
  }
  await page.click('#toggle-done');
  await page.locator('#done [data-bead="wow-164"]').waitFor();
  const emptyProgress = page.locator('#done [data-bead="wow-164"] .bb-epic-progress');
  if ((await emptyProgress.innerText()).trim() !== '—' || await emptyProgress.locator('[role=progressbar]').count()) throw Error('Empty epic does not show dash-only progress');
  const doneCount = Number(await page.locator('#done-count').innerText());
  if (await page.locator('#done [data-kind="epic"]').count() !== doneCount) throw Error('Done count mismatch');
  for (const theme of ['light', 'dark']) {
    await page.click(`#theme-${theme}`);
    await page.screenshot({path: `${out}/done-${theme}.png`, fullPage: true, animations: 'disabled'});
  }
  await page.click('#toggle-done');
  await page.selectOption('#filters_project', 'form-engine');
  await epic('fe-lwp').locator('button').click();
  const fallout = page.locator('#epics h3').filter({hasText: 'Fallout'});
  await fallout.waitFor();
  for (const id of ['fe-lwp.15', 'fe-lwp.16']) await epic(id).waitFor();
  await page.screenshot({path: `${out}/fallout-dark.png`, fullPage: true, animations: 'disabled'});
  await page.selectOption('#filters_project', 'skills');
  await page.locator('#toggle-unplanned[aria-expanded="false"]').waitFor();
  await page.click('#toggle-unplanned');
  await page.click('#toggle-project-skills');
  await page.locator('#unplanned [data-bead="sk-5o2"]').waitFor();
  await page.screenshot({path: `${out}/unplanned-dark.png`, fullPage: true, animations: 'disabled'});
  await page.setViewportSize({width: 390, height: 844});
  if (await page.evaluate(() => document.documentElement.scrollWidth > innerWidth)) throw Error('Home overflows mobile viewport');
  await page.screenshot({path: `${out}/mobile.png`, fullPage: true, animations: 'disabled'});
  await page.setViewportSize({width: 1440, height: 1100});
  await page.goto(new URL('/settings', page.url()).href);
  await page.locator('#config-preview').waitFor();
  if (await page.locator('#config-preview').evaluate(e => e.scrollWidth > e.clientWidth)) throw Error('TOML panel overflows');
  if (/snapshot · \d{3,} s ago/.test(await page.locator('main').innerText())) throw Error('Raw seconds not humanized');
  for (const theme of ['light', 'dark']) {
    await page.click(`#theme-${theme}`);
    const active = page.locator('a.bb-nav-active[aria-current="page"]');
    if (await active.innerText() !== 'Settings') throw Error('Incorrect active navigation');
    await page.screenshot({path: `${out}/settings-${theme}.png`, fullPage: true, animations: 'disabled'});
  }
  if (errors.length) throw Error(errors.join('\n'));
  console.log('PASS: natural child order, dash-only empty progress, collapsed Done/count, real progress, live overlay events, fallout, Unplanned, themes, Settings polish, mobile width; no page errors');
  await browser.close();
})().catch(e => {console.error(e); process.exit(1);});
