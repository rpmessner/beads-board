// NODE_PATH=<Playwright node_modules> node tools/merge-acceptance.cjs
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {execFileSync} = require('node:child_process');
const out = 'docs/acceptance/bb-merge';
const base = process.env.BOARD_URL || 'http://127.0.0.1:4768';
function control(command) {
  assert(['reset','move','fail','retarget-fail','drain','read'].includes(command));
  execFileSync('psql', ['-h','localhost','-U','postgres','-d','beads_board_merge_acceptance','-c',`SELECT pg_notify('merge_acceptance', '${command}')`], {env:{...process.env,PGPASSWORD:'postgres'}});
}
(async () => {
  fs.mkdirSync(out,{recursive:true});
  const browser = await chromium.launch({headless:true});
  const page = await browser.newPage({viewport:{width:1440,height:1000}});
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  async function open() {
    await page.goto(base+'/pull-requests?project=sample');
    await page.locator('[data-phx-main].phx-connected').waitFor();
  }
  async function confirm() {
    await page.click('#merge-request-5');
    await page.locator('#merge-confirm[data-open=true]').waitFor();
    await page.click('#merge-confirm-submit');
    await page.locator('#merge-status[data-state=merging]').waitFor();
  }
  async function reset() {
    control('reset');
    // Poll the actual UI until the reset snapshot and cleared audit are visible.
    await open();
    await page.waitForFunction(() => !document.querySelector('#merge-status') && document.querySelectorAll('#pull-requests article').length===2);
  }
  await reset();
  await page.click('#merge-request-6');
  await page.getByText('Bottom of stack only',{exact:true}).waitFor();
  assert.equal(await page.locator('#merge-confirm[data-open=true]').count(),0);
  await page.click('#merge-request-5');
  await page.locator('#merge-confirm[data-open=true]').waitFor();
  const dialog = page.locator('#merge-confirm');
  for(const text of ['0123456789abcdef0123456789abcdef01234567','bb-demo.1','Retarget #6','main','Merge commit']) assert((await dialog.innerText()).includes(text));
  // Theme controls sit behind a modal; choose theme before reopening it.
  await page.click('#merge-confirm-cancel');
  for(const theme of ['light','dark']) {
    await page.click('#theme-'+theme);
    await page.click('#merge-request-5');
    await page.locator('#merge-confirm[data-open=true]').waitFor();
    await page.screenshot({path:`${out}/confirm-${theme}.png`,fullPage:true,animations:'disabled'});
    await page.click('#merge-confirm-cancel');
  }
  await confirm();
  control('move'); control('drain');
  await page.locator('#merge-status[data-state=failed]').waitFor();
  assert((await page.locator('#merge-status').innerText()).includes('Head moved'));
  await page.screenshot({path:`${out}/head-moved.png`,fullPage:true,animations:'disabled'});
  await reset();
  await confirm(); control('fail'); control('drain');
  await page.locator('#merge-status[data-state=failed]').waitFor();
  assert((await page.locator('#merge-status').innerText()).includes('Unavailable'));
  await reset();
  await confirm(); control('drain');
  await page.locator('#merge-status[data-state=retargeting]').waitFor();
  control('retarget-fail'); control('drain');
  await page.locator('#merge-status[data-state=failed]').waitFor();
  assert((await page.locator('#merge-status').innerText()).includes('Merged · Manual retarget #6'));
  await page.screenshot({path:`${out}/partial-failure.png`,fullPage:true,animations:'disabled'});
  await reset();
  await confirm();
  await page.screenshot({path:`${out}/merging.png`,fullPage:true,animations:'disabled'});
  control('drain');
  await page.locator('#merge-status[data-state=retargeting]').waitFor();
  await page.screenshot({path:`${out}/retargeting.png`,fullPage:true,animations:'disabled'});
  control('drain');
  await page.locator('#merge-status[data-state=merged]').waitFor();
  await page.goto(base+'/pull-requests?project=sample&ticket=sample%3Abb-demo.1');
  await page.locator('#ticket-sheet[data-open=true]').waitFor();
  assert.equal(await page.locator('#ticket-stage').innerText(),'pr_open');
  assert.equal(await page.locator('#ticket-close-suggestion').count(),0);
  await page.click('#ticket-close');
  control('read');
  await page.locator('#cr-sample-5').waitFor({state:'detached'});
  assert((await page.locator('#cr-sample-6').innerText()).includes('pr/child → main'));
  for(const theme of ['light','dark']) {
    await page.click('#theme-'+theme);
    await page.screenshot({path:`${out}/merged-${theme}.png`,fullPage:true,animations:'disabled'});
  }
  await page.goto(base+'/pull-requests?project=sample&ticket=sample%3Abb-demo.1');
  await page.locator('#ticket-sheet[data-open=true]').waitFor();
  assert.equal(await page.locator('#ticket-stage').innerText(),'merged');
  assert.equal(await page.locator('#ticket-close-suggestion').innerText(),'bd close bb-demo.1');
  await page.screenshot({path:`${out}/merged-ticket.png`,fullPage:true,animations:'disabled'});
  await page.click('#ticket-close');
  await page.setViewportSize({width:390,height:844});
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth),false);
  await page.screenshot({path:`${out}/mobile.png`,fullPage:true,animations:'disabled'});
  assert.deepEqual(errors,[]);
  fs.writeFileSync(`${out}/evidence.json`,JSON.stringify({forge:'fake only',outOfOrderRefused:true,confirmedFacts:true,movedHeadRefused:true,mergeFailure:true,partialFailure:true,phases:['confirming','merging','retargeting','merged'],childBase:'main',observedTicketStage:'merged',suggestion:'bd close bb-demo.1',consoleErrors:errors,mobileOverflow:false},null,2)+'\n');
  await browser.close();
  console.log('Fake forge browser acceptance passed: refusal, confirmation, moved head, failure, partial failure, merge, retarget, observed stage, close suggestion, light/dark and mobile.');
})().catch(e => {console.error(e);process.exit(1)});
