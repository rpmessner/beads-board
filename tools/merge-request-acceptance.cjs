const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {execFileSync, spawn} = require('node:child_process');
const out = 'docs/acceptance/fm-mergereq';
const base = 'http://127.0.0.1:4785';
const env = {...process.env, FOREMAN_URL: base};
const transcript = [];
function sql(query) {
  return execFileSync('psql', ['-X','-h','localhost','-U','postgres','-d','foreman_acceptance_fm-mergereq','-Atc',query], {env:{...env,PGPASSWORD:'postgres'}, encoding:'utf8'}).trim();
}
function control(command) {
  assert(['reset','move','fail','retarget-fail','drain','read'].includes(command));
  sql(`SELECT pg_notify('merge_acceptance','${command}')`);
}
function cli(args) {
  const text = execFileSync('./foreman', args, {env, encoding:'utf8'}).trim();
  transcript.push({args, output: text});
  return text;
}
function wait(id) {
  const child = spawn('./foreman', ['wait',id,'--timeout','60'], {env});
  let text = '';
  child.stdout.on('data', chunk => text += chunk);
  return new Promise((resolve,reject) => {
    child.on('error',reject);
    child.on('exit',code => {
      try { assert.equal(code,0); const result = JSON.parse(text); transcript.push({wait:id,result}); resolve(result); } catch(e) { reject(e); }
    });
  });
}
(async () => {
  fs.mkdirSync(out,{recursive:true});
  const browser = await chromium.launch({headless:true});
  const page = await browser.newPage({viewport:{width:1440,height:1000}});
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  async function open(path='/needs-you') {
    await page.goto(base+path);
    await page.locator('[data-phx-main].phx-connected').waitFor();
  }
  async function reset() {
    control('reset');
    await open('/pull-requests?project=sample');
    await page.waitForFunction(() => !document.querySelector('#merge-status') && document.querySelectorAll('#pull-requests article').length === 2);
  }
  function ask() {
    const id = cli(['ask','merge','bb-demo.1','--project','sample','--pr','5','--sha','0123456789abcdef0123456789abcdef01234567']);
    assert.match(id,/^[0-9a-f-]{36}$/);
    return id;
  }
  await reset();
  let id = ask();
  for (const width of [390,1440]) for (const theme of ['light','dark']) {
    await page.setViewportSize({width,height:1000});
    await open();
    await page.click('#theme-'+theme);
    await page.locator('#request-'+id).waitFor();
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth),false);
    await page.screenshot({path:`${out}/card-${width}-${theme}.png`,fullPage:true,animations:'disabled'});
    await page.click('#submit-approve-'+id);
    await page.locator('#merge-confirm[data-open=true]').waitFor();
    await page.evaluate(() => Promise.all(document.getAnimations().map(a => a.finished.catch(()=>{}))));
    assert.equal(sql('SELECT count(*) FROM oban_jobs'),'0');
    assert.equal(JSON.parse(cli(['wait',id,'--timeout','0'])).state,'pending');
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth),false);
    await page.screenshot({path:`${out}/confirm-${width}-${theme}.png`,fullPage:true,animations:'disabled'});
    await page.click('#merge-confirm-cancel');
  }
  const outcomes = [];
  for (const scenario of ['merged','refused','failed','partial']) {
    if (scenario !== 'merged') { await reset(); id = ask(); }
    await open();
    const waiting = wait(id);
    await page.click('#submit-approve-'+id);
    await page.locator('#merge-confirm[data-open=true]').waitFor();
    await page.click('#merge-confirm-submit');
    await page.locator('#merge-status[data-state=merging]').waitFor();
    if (scenario === 'refused') control('move');
    if (scenario === 'failed') control('fail');
    control('drain');
    if (scenario === 'merged' || scenario === 'partial') {
      await page.locator('#merge-status[data-state=retargeting]').waitFor();
      if (scenario === 'partial') control('retarget-fail');
      control('drain');
    }
    const result = await waiting;
    assert.equal(result.state,scenario === 'merged' ? 'done' : 'failed');
    if (scenario === 'partial') assert(result.outcome.result.merge_sha);
    outcomes.push({scenario,result});
    assert.equal(sql(`SELECT count(*) FROM request_events WHERE request_id='${id}' AND event='start'`),'1');
    assert.equal(sql(`SELECT count(*) FROM request_events WHERE request_id='${id}' AND event IN ('succeeded','failed')`),'1');
  }
  assert.deepEqual(errors,[]);
  fs.writeFileSync(`${out}/transcript.json`,JSON.stringify(transcript,null,2)+'\n');
  fs.writeFileSync(`${out}/evidence.json`,JSON.stringify({outcomes,errors,widths:[390,1440],themes:['light','dark'],beforeConfirmationJobs:0},null,2)+'\n');
  await browser.close();
  console.log('PASS: real CLI ask/wait; existing confirmation; cancel remains pending; merged/refused/failed/partial; one start/outcome; light/dark 390/1440; no overflow/errors.');
})().catch(e => {console.error(e);process.exit(1)});
