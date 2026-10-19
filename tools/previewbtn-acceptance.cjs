// Run the isolated tools/previewbtn-acceptance.exs server first.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {execFileSync} = require('node:child_process');
const registry = () => JSON.parse(execFileSync('devserve', ['ls', '--json'], {encoding: 'utf8'})).previews;
const ours = () => registry().filter(p => p.worktree === process.cwd());
const out = 'docs/acceptance/fm-previewbtn';
(async () => {
  fs.mkdirSync(out, {recursive: true});
  const browser = await chromium.launch({headless: true, ignoreDefaultArgs: ['--hide-scrollbars']});
  let database;
  try {
    assert.equal(ours().length, 0, 'no prior preview');
    const page = await browser.newPage({viewport: {width: 1440, height: 900}});
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.goto('http://127.0.0.1:4879/?ticket=preview-check:preview-1');
    await page.locator('[data-phx-main].phx-connected').waitFor();
    await page.locator('#preview-start').click();
    await page.waitForFunction(() => document.querySelector('#preview-state')?.textContent.trim() === 'running', null, {timeout: 240000});
    assert.equal(ours().length, 1);
    database = ours()[0].database;
    const popupPromise = page.waitForEvent('popup');
    await page.locator('#preview-open').click();
    const popup = await popupPromise;
    await popup.waitForLoadState();
    assert.equal(await popup.title(), 'foreman');
    await popup.locator('[data-phx-main].phx-connected').waitFor();
    assert.ok(popup.url().startsWith(ours()[0].url));
    await popup.close();
    await page.locator('#preview-log-panel summary').click();
    await page.waitForFunction(() => document.querySelector('#preview-logs')?.textContent.includes('python3['), null, {timeout: 20000});
    const initialLogs = await page.locator('#preview-logs').textContent();
    await page.waitForFunction(before => document.querySelector('#preview-logs')?.textContent !== before, initialLogs, {timeout: 20000});
    assert.ok(await page.locator('#preview-log-panel').evaluate(el => el.open), 'log panel stays open during tail updates');
    assert.ok(await page.locator('#preview-logs').isVisible(), 'log tail remains visible');
    for (const width of [1440, 390]) {
      await page.setViewportSize({width, height: 900});
      for (const theme of ['light', 'dark']) {
        await page.evaluate(theme => document.documentElement.setAttribute('data-theme', theme), theme);
        assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'no document overflow');
        await page.screenshot({path: `${out}/preview-${width}-${theme}.png`, animations: 'disabled'});
      }
    }
    await page.locator('#preview-stop').click();
    await page.waitForFunction(() => document.querySelector('#preview-state')?.textContent.trim() === 'stopped', null, {timeout: 60000});
    assert.equal(ours().length, 0);
    await page.locator('#preview-start').click();
    await page.waitForFunction(() => document.querySelector('#preview-state')?.textContent.trim() === 'running', null, {timeout: 240000});
    execFileSync('mix', ['run', '--no-start', 'tools/previewbtn-acceptance.exs', 'done'], {
      env: {...process.env, MIX_ENV: 'acceptance', PORT: '4879'}, stdio: 'pipe', timeout: 60000
    });
    await page.waitForFunction(() => document.querySelector('#preview-state')?.textContent.trim() === 'stopped', null, {timeout: 60000});
    assert.equal(await page.locator('#preview-start').count(), 0, 'Done cannot start');
    assert.equal(ours().length, 0);
    assert.deepEqual(errors, []);
    fs.writeFileSync(`${out}/live-result.json`, JSON.stringify({start: true, opened: true, logs: true, stop: true, doneCleanup: true, pageErrors: errors}, null, 2));
    console.log('PASS: sheet start/open/logs/stop; Done cleanup; four viewport/theme screenshots; no browser errors');
  } finally {
    for (const preview of ours()) execFileSync('devserve', ['down', preview.unit, '--drop-db'], {timeout: 180000});
    await browser.close();
  }
  if (database) {
    assert.match(database, /^[a-zA-Z0-9_]+$/);
    const exists = execFileSync('psql', ['-XAt', '-h', 'localhost', '-U', 'postgres', '-d', 'postgres', '-c', `SELECT datname FROM pg_database WHERE datname='${database}'`], {env: {...process.env, PGPASSWORD: 'postgres'}, encoding: 'utf8'}).trim();
    assert.equal(exists, '', 'devserve-owned preview database removed');
    console.log('PASS: registry empty for worktree and preview database absent');
  }
})().catch(e => {console.error(e); process.exitCode = 1;});
