// Requires the isolated tools/push-acceptance.exs server and inherited FOREMAN_TOKEN_FILE.
const {chromium} = require('playwright');
const {execFileSync} = require('node:child_process');
const fs = require('node:fs');
const assert = require('node:assert/strict');
const out = 'docs/acceptance/fm-push';
const env = {...process.env, FOREMAN_URL: 'http://127.0.0.1:4773', FOREMAN_ACTOR: 'pi', FOREMAN_SESSION: 'fm-push'};
const transcript = [];
function cli(args) {
  const output = execFileSync('./foreman', args, {env, encoding: 'utf8'}).trim();
  transcript.push({args, output, exit: 0});
  fs.writeFileSync(`${out}/transcript.json`, JSON.stringify(transcript, null, 2) + '\n');
  return output;
}
function remote(branch) {
  const output = execFileSync('gh', ['api', `repos/rpmessner/beads-board-scratch/git/ref/heads/${branch}`], {encoding: 'utf8'});
  const data = JSON.parse(output);
  return {ref: data.ref, sha: data.object.sha};
}
(async () => {
  fs.mkdirSync(out, {recursive: true});
  const sha = execFileSync('git', ['-C', '/tmp/fm-push-scratch', 'rev-parse', 'main'], {encoding: 'utf8'}).trim();
  const branch = `acceptance/fm-push-${Date.now()}`;
  const ask = (ticket, target) => cli(['ask', 'push', ticket, '--project', 'scratch', '--worktree', '/tmp/fm-push-scratch', '--branch', 'main', '--sha', sha, '--remote-branch', target]);
  const browser = await chromium.launch({headless: true, ignoreDefaultArgs: ['--hide-scrollbars']});
  try {
    const page = await browser.newPage({viewport: {width: 1440, height: 1000}});
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.goto(`${env.FOREMAN_URL}/needs-you`);
    await page.locator('.phx-connected').waitFor();
    const id = ask('push-1', branch);
    assert.match(id, /^[a-f0-9-]{36}$/);
    await page.locator(`#request-${id}`).waitFor();
    for (const width of [1440, 390]) {
      await page.setViewportSize({width, height: 1000});
      for (const theme of ['light', 'dark']) {
        await page.locator(`#theme-${theme}`).click();
        await page.waitForFunction(theme => document.documentElement.dataset.theme === theme, theme);
        assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
        assert.equal(await page.locator(`#request-${id} dd`).count(), 5);
        assert.ok(await page.locator(`#request-${id}`).innerText().then(text => text.includes(sha)));
        assert.ok(await page.evaluate(id => Math.abs(document.querySelector(`#submit-approve-${id}`).getBoundingClientRect().top - document.querySelector(`#submit-decline-${id}`).getBoundingClientRect().top) < 1, id));
        await page.screenshot({path: `${out}/push-${width}-${theme}.png`, fullPage: true, animations: 'disabled'});
      }
    }
    await page.locator(`#submit-approve-${id}`).click();
    const result = JSON.parse(cli(['wait', id, '--timeout', '60']));
    assert.equal(result.state, 'done');
    assert.equal(remote(branch).sha, sha);
    const defaultId = ask('push-2', 'main');
    assert.match(defaultId, /^[a-f0-9-]{36}$/);
    await page.locator(`#submit-approve-${defaultId}`).click();
    assert.equal(JSON.parse(cli(['wait', defaultId, '--timeout', '60'])).state, 'done');
    assert.equal(remote('main').sha, sha);
    assert.match(ask('push-e.1', 'main'), /epic_default_branch/);
    await page.locator('#recent-outcomes summary').click();
    await page.screenshot({path: `${out}/outcomes.png`, fullPage: true, animations: 'disabled'});
    assert.deepEqual(errors, []);
    fs.writeFileSync(`${out}/live-result.json`, JSON.stringify({id, defaultId, branch: remote(branch), default: remote('main'), defaultWasAlreadyAtSha: true, errors}, null, 2) + '\n');
    console.log('PASS: exact remote SHA; one-off main push accepted; epic main refused; real CLI and worker; light/dark 390/1440; no overflow or browser errors');
  } finally { await browser.close(); }
})().catch(e => {console.error(e); process.exitCode = 1;});
