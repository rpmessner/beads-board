// Requires the explicitly authorized server in merge-live-acceptance.exs.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {execFileSync} = require('node:child_process');
const remote = 'rpmessner/beads-board-scratch';
const out = 'docs/acceptance/bb-merge/live';
const base = 'http://127.0.0.1:4769';
const git = (...args) => execFileSync('git',['-C','/tmp/bb-scratch',...args],{encoding:'utf8'}).trim();
const gh = (...args) => execFileSync('gh',args,{encoding:'utf8'}).trim();
function control(command) {
  assert(['phase:moved','phase:merge','phase:retarget','phase:observed','read','drain'].includes(command));
  execFileSync('psql',['-h','localhost','-U','postgres','-d','beads_board_merge_live_acceptance','-c',`SELECT pg_notify('merge_live_acceptance','${command}')`],{env:{...process.env,PGPASSWORD:'postgres'}});
}
(async () => {
  assert.equal(process.env.BOARD_LIVE_MERGE_APPROVED,remote,'Explicit scratch approval required');
  assert.equal(git('remote','get-url','origin'),`https://github.com/${remote}.git`);
  fs.mkdirSync(out,{recursive:true});
  const browser = await chromium.launch({headless:true});
  const page = await browser.newPage({viewport:{width:1440,height:1000}});
  const capture = async path => {
    await page.evaluate(async () => {
      await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
      await Promise.all(document.getAnimations().filter(a => a.effect.getComputedTiming().iterations !== Infinity).map(a => a.finished.catch(() => {})));
    });
    await page.screenshot({path,fullPage:true,animations:'disabled'});
  };
  const errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.goto(base+'/pull-requests?project=scratch');
  await page.locator('[data-phx-main].phx-connected').waitFor();
  await page.click('#merge-request-2');
  await page.locator('#merge-status').filter({hasText:'Bottom of stack only'}).waitFor();
  assert.equal(await page.locator('#merge-confirm[data-open=true]').count(),0);
  await capture(`${out}/top-refused.png`);
  const initialHead=git('rev-parse','pr/acceptance-bottom');
  await page.click('#merge-request-1');
  await page.locator('#merge-confirm[data-open=true]').waitFor();
  assert((await page.locator('#merge-confirm').innerText()).includes(initialHead));
  git('switch','pr/acceptance-bottom');
  fs.appendFileSync('/tmp/bb-scratch/bottom.txt','Advance the head after confirmation opens.\n');
  git('add','bottom.txt');
  git('-c','user.name=Board acceptance','-c','user.email=acceptance@example.invalid','commit','-m','Advance acceptance head after confirmation');
  git('push','origin','pr/acceptance-bottom');
  const confirmedHead=git('rev-parse','HEAD');
  assert.notEqual(confirmedHead,initialHead);
  let observed;
  for(let i=0;i<40;i++) {
    observed=JSON.parse(gh('pr','view','1','--repo',remote,'--json','mergeable,headRefOid'));
    if(observed.mergeable==='MERGEABLE' && observed.headRefOid===confirmedHead) break;
    await new Promise(resolve=>setTimeout(resolve,500));
  }
  assert.equal(observed.mergeable,'MERGEABLE');
  assert.equal(observed.headRefOid,confirmedHead);
  await page.click('#merge-confirm-submit');
  await page.locator('#merge-status[data-state=merging]').waitFor();
  control('phase:moved'); control('drain');
  await page.locator('#merge-status[data-state=failed]').waitFor();
  assert((await page.locator('#merge-status').innerText()).includes('Head moved'));
  assert.equal(JSON.parse(gh('pr','view','1','--repo',remote,'--json','state')).state,'OPEN');
  assert(!fs.existsSync('test/fixtures/forge/live-merge/moved-merge.json'));
  await capture(`${out}/head-moved-refused.png`);
  control('phase:merge'); control('read');
  await page.waitForFunction(sha=>document.querySelector('#cr-scratch-1').textContent.includes(sha.slice(0,7)),confirmedHead);
  await page.click('#merge-request-1');
  await page.locator('#merge-confirm[data-open=true]').waitFor();
  for(const text of [confirmedHead,'bb-live.1','Retarget #2','main','Merge commit']) assert((await page.locator('#merge-confirm').innerText()).includes(text));
  await capture(`${out}/confirmed-head.png`);
  await page.click('#merge-confirm-submit');
  await page.locator('#merge-status[data-state=merging]').waitFor();
  control('drain');
  await page.locator('#merge-status[data-state=retargeting]').waitFor({timeout:30000});
  await capture(`${out}/retargeting.png`);
  control('phase:retarget'); control('drain');
  await page.locator('#merge-status[data-state=merged]').waitFor({timeout:30000});
  await page.goto(base+'/pull-requests?project=scratch&ticket=scratch%3Abb-live.1');
  await page.locator('#ticket-sheet[data-open=true]').waitFor();
  assert.equal(await page.locator('#ticket-stage').innerText(),'pr_open');
  assert.equal(await page.locator('#ticket-close-suggestion').count(),0);
  await page.click('#ticket-close');
  control('phase:observed'); control('read');
  await page.locator('#cr-scratch-1').waitFor({state:'detached'});
  assert((await page.locator('#cr-scratch-2').innerText()).includes('pr/acceptance-child → main'));
  for(const theme of ['light','dark']) {
    await page.click('#theme-'+theme);
    await capture(`${out}/merged-${theme}.png`);
  }
  await page.goto(base+'/pull-requests?project=scratch&ticket=scratch%3Abb-live.1');
  await page.locator('#ticket-sheet[data-open=true]').waitFor();
  assert.equal(await page.locator('#ticket-stage').innerText(),'merged');
  assert.equal(await page.locator('#ticket-close-suggestion').innerText(),'bd close bb-live.1');
  await capture(`${out}/observed-ticket.png`);
  const merged=JSON.parse(gh('pr','view','1','--repo',remote,'--json','state,mergeCommit,headRefOid,baseRefName'));
  assert.equal(merged.state,'MERGED'); assert.equal(merged.headRefOid,confirmedHead); assert.equal(merged.baseRefName,'main');
  const commit=JSON.parse(gh('api',`repos/${remote}/commits/${merged.mergeCommit.oid}`,'--jq','{sha,parents:[.parents[].sha]}'));
  assert.equal(commit.parents.length,2); assert(commit.parents.includes(confirmedHead));
  const child=JSON.parse(gh('pr','view','2','--repo',remote,'--json','state,baseRefName,headRefOid'));
  assert.equal(child.state,'OPEN'); assert.equal(child.baseRefName,'main');
  const branches={};
  for(const branch of ['pr/acceptance-bottom','pr/acceptance-child']) branches[branch]=gh('api',`repos/${remote}/git/ref/heads/${branch}`,'--jq','.object.sha');
  assert.equal(branches['pr/acceptance-bottom'],confirmedHead);
  assert.equal(branches['pr/acceptance-child'],child.headRefOid);
  assert.deepEqual(errors,[]);
  fs.writeFileSync(`${out}/evidence.json`,JSON.stringify({bottom:1,child:2,initialHead,confirmedHead,mergeCommit:commit,branches,topRefused:true,movedHeadRefused:true,childBase:'main',stageBeforeObservation:'pr_open',stageAfterObservation:'merged',suggestion:'bd close bb-live.1',consoleErrors:errors},null,2)+'\n');
  await browser.close();
  console.log('Live scratch acceptance passed: both refusals, confirmed merge commit, retarget, retained branches, observed ticket and close suggestion.');
})().catch(error=>{console.error(error);process.exit(1)});
