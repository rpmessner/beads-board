// Requires tools/push-acceptance.exs and an explicitly authorized fixture commit in the scratch clone.
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
  fs.writeFileSync(`${out}/default-transcript.json`, JSON.stringify(transcript, null, 2) + '\n');
  return output;
}
function remote() {
  const value = JSON.parse(execFileSync('gh', ['api', 'repos/rpmessner/beads-board-scratch/git/ref/heads/main'], {encoding: 'utf8'}));
  return {ref: value.ref, sha: value.object.sha};
}
(async () => {
  const sha = execFileSync('git', ['-C', '/tmp/fm-push-scratch', 'rev-parse', 'main'], {encoding: 'utf8'}).trim();
  const parent = execFileSync('git', ['-C', '/tmp/fm-push-scratch', 'rev-parse', 'main^'], {encoding: 'utf8'}).trim();
  const before = remote();
  assert.equal(before.sha, parent);
  assert.notEqual(sha, before.sha);
  const browser = await chromium.launch({headless: true});
  try {
    const page = await browser.newPage({viewport: {width: 1440, height: 1000}});
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(`${env.FOREMAN_URL}/needs-you`);
    await page.locator('.phx-connected').waitFor();
    const args = ['ask', 'push', 'push-2', '--project', 'scratch', '--worktree', '/tmp/fm-push-scratch', '--branch', 'main', '--sha', sha, '--remote-branch', 'main'];
    const id = cli(args);
    assert.match(id, /^[a-f0-9-]{36}$/);
    await page.locator(`#submit-approve-${id}`).click();
    const result = JSON.parse(cli(['wait', id, '--timeout', '60']));
    assert.equal(result.state, 'done');
    assert.equal(result.outcome.result.sha, sha);
    const after = remote();
    assert.equal(after.sha, sha);
    assert.match(cli(args.map(arg => arg === 'push-2' ? 'push-e.1' : arg)), /epic_default_branch/);
    await page.locator('#recent-outcomes summary').click();
    await page.screenshot({path: `${out}/default-advanced.png`, fullPage: true, animations: 'disabled'});
    assert.deepEqual(errors, []);
    fs.writeFileSync(`${out}/default-advanced.json`, JSON.stringify({id, before, parent, expectedSha: sha, after, result, errors}, null, 2) + '\n');
    console.log(`PASS: worker advanced scratch main ${before.sha} -> ${after.sha}; exact SHA, direct parent, epic refusal, no browser errors; request ${id}`);
  } finally {await browser.close();}
})().catch(error => {console.error(error); process.exitCode = 1;});
