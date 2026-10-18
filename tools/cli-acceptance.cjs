// Start tools/cli-acceptance-server.exs with MIX_ENV=acceptance first.
const {chromium} = require('playwright');
const {spawnSync} = require('node:child_process');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const base = 'http://127.0.0.1:4759';
const env = {...process.env, FOREMAN_URL: base, FOREMAN_TOKEN_FILE: `${process.cwd()}/tmp/cli-token`,
  FOREMAN_DATABASE_URL: '', DATABASE_URL: '',
  PGDATABASE: `foreman_acceptance_${require('node:path').basename(process.cwd())}`};
const evidence = [];
function cli(...args) {
  const r = spawnSync('./foreman', [...args, '--json'], {env, encoding: 'utf8', timeout: 15000});
  assert.ifError(r.error);
  const body = JSON.parse(r.stdout);
  evidence.push({args, exit: r.status, body});
  return {exit: r.status, body};
}
(async () => {
  // Make repeated acceptance runs possible without deleting authoritative history.
  const current = cli('show', 'scratch-1').body.stage;
  if (current !== 'queued') {
    if (current !== 'abandoned') cli('abandon', 'scratch-1');
    cli('revive', 'scratch-1');
  }
  const browser = await chromium.launch({headless: true, ignoreDefaultArgs: ['--hide-scrollbars']});
  const page = await browser.newPage({viewport: {width: 1440, height: 1000}});
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  await page.goto(`${base}/epics/scratch/scratch-epic`);
  await page.locator('[data-phx-main].phx-connected').waitFor();
  fs.mkdirSync('docs/acceptance/bb-cli', {recursive: true});
  for (const [args, stage] of [
    [['dispatch', 'scratch-1', '--window', 'cli-build', '--branch', 'scratch', '--actor', 'pi'], 'dispatched'],
    [['progress', 'scratch-1', 'API and CLI connected'], 'building'],
    [['report', 'scratch-1', '--path', 'docs/sessions/bb-cli.md'], 'reported'],
    [['review', 'scratch-1'], 'in_review'],
    [['commit', 'scratch-1', '--sha', 'test-evidence'], 'committed']
  ]) {
    const result = cli(...args);
    assert.equal(result.exit, 0);
    assert.equal(result.body.stage, stage);
    await page.locator(`[data-ticket="scratch-1"][data-stage="${stage}"]`).waitFor();
    await page.screenshot({path: `docs/acceptance/bb-cli/${stage}.png`, fullPage: true, animations: 'disabled'});
  }
  const invalid = cli('review', 'scratch-2');
  assert.equal(invalid.exit, 3);
  assert.equal(invalid.body.stage, 'queued');
  assert.deepEqual(invalid.body.allowed, ['dispatch', 'abandon']);
  assert.equal(cli('show', 'scratch-2').body.history.at(-1).outcome, 'invalid');
  assert.deepEqual(errors, []);
  fs.writeFileSync('docs/acceptance/bb-cli/workflow.json', JSON.stringify(evidence, null, 2) + '\n');
  await browser.close();
  console.log('PASS: escript dispatch/progress/report/review/commit; live card moved without reload; 409 exits 3 and is audited; no browser errors');
})().catch(e => { console.error(e); process.exit(1); });
