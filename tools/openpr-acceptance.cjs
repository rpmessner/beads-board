// Requires isolated tools/openpr-acceptance.exs; no direct GitHub writes.
const {chromium} = require('playwright');
const {execFileSync} = require('node:child_process');
const fs = require('node:fs');
const assert = require('node:assert/strict');
const out = 'docs/acceptance/fm-openpr';
const env = {...process.env, FOREMAN_URL: 'http://127.0.0.1:4774', FOREMAN_ACTOR: 'pi', FOREMAN_SESSION: 'fm-openpr'};
const transcript = [];
const ticket = process.env.FM_OPENPR_TICKET || 'openpr-1';
function cli(args) {
  const output = execFileSync('./foreman', args, {env, encoding: 'utf8'}).trim();
  transcript.push({args, output, exit: 0});
  fs.writeFileSync(`${out}/transcript.json`, JSON.stringify(transcript, null, 2) + '\n');
  return output;
}
(async () => {
  fs.mkdirSync(out, {recursive: true});
  const sha = execFileSync('git', ['-C', '/tmp/fm-openpr-scratch', 'rev-parse', 'openpr-fixture'], {encoding: 'utf8'}).trim();
  const branch = `acceptance/fm-openpr-${Date.now()}`;
  const browser = await chromium.launch({headless: true, ignoreDefaultArgs: ['--hide-scrollbars']});
  try {
    const page = await browser.newPage({viewport: {width: 1440, height: 1000}});
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.goto(`${env.FOREMAN_URL}/needs-you`);
    await page.locator('.phx-connected').waitFor();
    const push = cli(['ask', 'push', ticket, '--project', 'scratch', '--worktree', '/tmp/fm-openpr-scratch', '--branch', 'openpr-fixture', '--sha', sha, '--remote-branch', branch]);
    assert.match(push, /^[a-f0-9-]{36}$/);
    await page.locator(`#submit-approve-${push}`).click();
    assert.equal(JSON.parse(cli(['wait', push, '--timeout', '60'])).state, 'done');
    // Wait for the harness's ordinary forge read, not just the write response.
    const title = `${ticket}: Exact approval title`;
    const body = 'Open PR acceptance.\n\nExact body, including trailing newline.\n';
    const bodyPath = '/tmp/fm-openpr-body.txt';
    fs.writeFileSync(bodyPath, body);
    // Snapshot publication follows the push job asynchronously.
    let id;
    for (let i = 0; i < 30; i++) {
      id = cli(['ask', 'open_pr', ticket, '--project', 'scratch', '--head', branch, '--sha', sha, '--base', 'main', '--title', title, '--body-file', bodyPath]);
      if (/^[a-f0-9-]{36}$/.test(id)) break;
      assert.match(id, /head_missing/);
      await page.waitForTimeout(500);
    }
    assert.match(id, /^[a-f0-9-]{36}$/);
    await page.locator(`#request-${id}`).waitFor();
    for (const width of [1440, 390]) {
      await page.setViewportSize({width, height: 1000});
      for (const theme of ['light', 'dark']) {
        await page.locator(`#theme-${theme}`).click();
        await page.waitForFunction(theme => document.documentElement.dataset.theme === theme, theme);
        assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
        const values = await page.locator(`#request-${id} dd`).allTextContents();
        assert.deepEqual(values, ['rpmessner/beads-board-scratch', branch, sha, 'main', title, body]);
        assert.equal(await page.locator(`#request-${id} textarea`).count(), 1);
        assert.ok(await page.evaluate(id => Math.abs(document.querySelector(`#submit-approve-${id}`).getBoundingClientRect().top - document.querySelector(`#submit-decline-${id}`).getBoundingClientRect().top) < 1, id));
        await page.screenshot({path: `${out}/openpr-${width}-${theme}.png`, fullPage: true, animations: 'disabled'});
      }
    }
    await page.locator(`#submit-approve-${id}`).click();
    const result = JSON.parse(cli(['wait', id, '--timeout', '60']));
    assert.equal(result.state, 'done');
    const number = result.outcome.result.number;
    const remote = JSON.parse(execFileSync('gh', ['api', `repos/rpmessner/beads-board-scratch/pulls/${number}`], {encoding: 'utf8'}));
    assert.equal(remote.head.ref, branch);
    assert.equal(remote.head.sha, sha);
    assert.equal(remote.base.ref, 'main');
    assert.equal(remote.title, title);
    assert.equal(remote.body, body);
    await page.goto(`${env.FOREMAN_URL}/?ticket=scratch:${ticket}`);
    await page.locator('.phx-connected').waitFor();
    await page.getByText('pr_open', {exact: true}).first().waitFor();
    assert.deepEqual(errors, []);
    fs.writeFileSync(`${out}/live-result.json`, JSON.stringify({id, push, number, branch, sha, base: remote.base.ref, title: remote.title, body: remote.body, url: remote.html_url, errors}, null, 2) + '\n');
    console.log('PASS: worker push and open PR; exact base/title/body/head; observed pr_open; light/dark 390/1440; zero overflow/browser errors');
  } finally { await browser.close(); }
})().catch(e => {console.error(e); process.exitCode = 1;});
