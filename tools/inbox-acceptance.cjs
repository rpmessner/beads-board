// Start tools/inbox-acceptance.exs; inherit BOARD_TOKEN_FILE; NODE_PATH=<Playwright modules> node this-file.
const {chromium} = require('playwright');
const {execFileSync, spawn} = require('node:child_process');
const fs = require('node:fs');
const assert = require('node:assert/strict');
const out = 'docs/acceptance/bb-inbox';
fs.mkdirSync(out, {recursive: true});
const env = {...process.env, BOARD_URL: 'http://127.0.0.1:4771', BOARD_ACTOR: 'pi', BOARD_SESSION: 'bb-inbox'};
const transcript = [];
function board(args) {
  const output = execFileSync('./board', args, {env, encoding: 'utf8'}).trim();
  transcript.push({command: `board ${args.join(' ')}`, output, exit: 0});
  return output;
}
function wait(id) {
  const child = spawn('./board', ['wait', id, '--timeout', '60'], {env});
  let output = ''; let stderr = '';
  child.stdout.on('data', b => output += b);
  child.stderr.on('data', b => stderr += b);
  return new Promise((resolve, reject) => {
    child.on('error', reject);
    child.on('close', code => {
      transcript.push({command: `board wait ${id} --timeout 60`, output: output.trim(), exit: code});
      try { assert.equal(code, 0, stderr); resolve(JSON.parse(output)); } catch (e) { reject(e); }
    });
  });
}
(async () => {
  const browser = await chromium.launch({headless: true, ignoreDefaultArgs: ['--hide-scrollbars']});
  const errors = [];
  try {
    const page = await browser.newPage({viewport: {width: 1440, height: 1000}});
    const other = await browser.newPage();
    for (const p of [page, other]) p.on('pageerror', e => errors.push(e.message));
    const base = env.BOARD_URL;
    board(['abandon', 'scratch-1', '--project', 'scratch']);
    board(['revive', 'scratch-1', '--project', 'scratch']);
    await page.goto(`${base}/needs-you`);
    await other.goto(`${base}/`);
    await page.locator('.phx-connected').waitFor();
    const id = board(['ask', 'decision', 'scratch-1', '--project', 'scratch', '--question', 'Which layout should the build use?', '--option', 'Wide', '--option', 'Compact', '--recommendation', 'Compact', '--text', 'Keep the existing keyboard shortcuts.']);
    assert.match(id, /^[a-f0-9-]{36}$/);
    await page.locator(`#request-${id}`).waitFor();
    await other.waitForFunction(() => document.title === '(1) beads-board');
    assert.equal(await other.locator('#needs-you-count').innerText(), '1');
    const timeout = JSON.parse(board(['wait', id, '--timeout', '0']));
    assert.equal(timeout.state, 'pending');
    const answerWait = wait(id);
    await page.locator(`#option-${id}-1`).check();
    await page.locator(`#decision-note-${id}`).fill('Keep the shortcuts.');
    const declinedId = board(['ask', 'decision', 'scratch-1', '--project', 'scratch', '--question', 'Include the optional animation?', '--option', 'Include', '--option', 'Skip', '--recommendation', 'Skip']);
    await page.waitForFunction(() => document.title === '(2) beads-board');
    assert.equal(await page.locator(`#option-${id}-1`).isChecked(), true, 'notification preserves in-progress answer');
    assert.equal(await page.locator(`#decision-note-${id}`).inputValue(), 'Keep the shortcuts.');
    assert.deepEqual(await page.locator('#pending-requests article').evaluateAll(es => es.map(e => e.id)), [`request-${id}`, `request-${declinedId}`]);
    for (const width of [1440, 390]) {
      await page.setViewportSize({width, height: 1000});
      for (const theme of ['light', 'dark']) {
        await page.locator(`#theme-${theme}`).click();
        await page.waitForFunction(theme => document.documentElement.dataset.theme === theme, theme);
        assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'no page overflow');
        assert.equal(await page.locator(`#request-${id} textarea, #request-${id} input[type=text]`).count(), 1, 'one optional Note field');
        assert.ok(await page.locator(`#decision-note-${id}`).evaluate(el => parseFloat(getComputedStyle(el).borderTopWidth) > 0), 'note has a visible boundary');
        assert.ok(await page.evaluate(() => Math.abs(document.querySelector('#inbox-heading').getBoundingClientRect().left - document.querySelector('#pending-requests').getBoundingClientRect().left) < 1), 'heading and cards align');
        assert.ok(await page.evaluate(id => Math.abs(document.querySelector(`#submit-answer-${id}`).getBoundingClientRect().top - document.querySelector(`#submit-decline-${id}`).getBoundingClientRect().top) < 1, id), 'actions share one row');
        await page.screenshot({path: `${out}/inbox-${width}-${theme}.png`, fullPage: true, animations: 'disabled'});
      }
    }
    await page.locator(`#submit-answer-${id}`).click();
    const answer = await answerWait;
    assert.equal(answer.state, 'answered');
    assert.deepEqual(answer.outcome, {answer: 'Compact'});
    assert.equal(answer.note, 'Keep the shortcuts.');
    await other.waitForFunction(() => document.title === '(1) beads-board');
    const declineWait = wait(declinedId);
    await page.locator(`#decision-note-${declinedId}`).fill('Keep this slice focused.');
    await page.locator(`#submit-decline-${declinedId}`).click();
    const decline = await declineWait;
    assert.equal(decline.state, 'declined');
    assert.equal(decline.note, 'Keep this slice focused.');
    await page.waitForFunction(() => document.title === 'beads-board');
    await other.waitForFunction(() => document.title === 'beads-board');
    assert.equal(await page.locator('#needs-you-count').count(), 0);
    assert.equal(await page.locator('#recent-outcomes').getAttribute('open'), null);
    await page.locator('#recent-outcomes summary').click();
    await page.screenshot({path: `${out}/outcomes.png`, fullPage: true, animations: 'disabled'});
    for (const width of [1440, 390]) {
      await page.setViewportSize({width, height: 1000});
      for (const theme of ['light', 'dark']) {
        await page.goto(`${base}/?ticket=scratch:scratch-1&tab=requests`);
        await page.locator('.phx-connected').waitFor();
        await page.evaluate(theme => {localStorage.setItem('phx:theme', theme); document.documentElement.dataset.theme = theme;}, theme);
        await page.locator('#ticket-requests-panel:not([hidden])').waitFor();
        await page.waitForFunction(() => Math.abs(document.querySelector('#ticket-sheet [data-part=content]').getBoundingClientRect().right - innerWidth) < 1);
        assert.equal(await page.locator(`#ticket_requests-${id}`).count(), 1);
        assert.equal(await page.locator(`#ticket_requests-${declinedId}`).count(), 1);
        assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
        assert.ok(await page.locator('#ticket-requests-tab').evaluate(el => {const r = el.getBoundingClientRect(); return r.left >= 0 && r.right <= innerWidth;}), 'selected Requests tab is on screen');
        await page.screenshot({path: `${out}/requests-${width}-${theme}.png`, animations: 'disabled'});
      }
    }
    await page.goto(`${base}/needs-you`);
    await page.locator('.phx-connected').waitFor();
    const freeId = board(['ask', 'decision', 'scratch-1', '--project', 'scratch', '--question', 'Which alternative?']);
    await page.locator(`#decision-note-${freeId}`).fill('Use the existing layout.');
    const freeWait = wait(freeId);
    await page.locator(`#submit-answer-${freeId}`).click();
    assert.deepEqual((await freeWait).outcome, {answer: 'Use the existing layout.'});
    const supersededId = board(['ask', 'decision', 'scratch-1', '--project', 'scratch', '--question', 'Continue this build?']);
    const supersededWait = wait(supersededId);
    board(['abandon', 'scratch-1', '--project', 'scratch']);
    assert.equal((await supersededWait).state, 'superseded');
    board(['revive', 'scratch-1', '--project', 'scratch']);
    assert.deepEqual(errors, []);
    fs.writeFileSync(`${out}/transcript.json`, JSON.stringify(transcript, null, 2) + '\n');
    console.log('PASS: real ask/wait, browser answer and decline with note; two live tabs; pending order; draft input preserved; light/dark × 390/1440; Requests tab; no browser errors');
  } finally {await browser.close();}
})().catch(e => { console.error(e); process.exitCode = 1; });
