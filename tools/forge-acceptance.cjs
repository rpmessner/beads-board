// NODE_PATH=<Playwright node_modules> node tools/forge-acceptance.cjs
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
(async () => {
  const browser = await chromium.launch({headless: true});
  const page = await browser.newPage({viewport: {width: 1440, height: 1000}});
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  const base = process.env.BOARD_URL || 'http://127.0.0.1:4758';
  const out = 'docs/acceptance/bb-forge';
  fs.mkdirSync(out, {recursive:true});
  await page.goto(base + '/pull-requests?project=form-engine');
  await page.locator('[data-phx-main].phx-connected').waitFor();
  assert.deepEqual(await page.locator('#pull-requests article').evaluateAll(nodes => nodes.map(n => Number(n.dataset.number))),[5,6]);
  assert.equal(await page.locator('#cr-form-engine-6 [data-parent="5"]').innerText(),'Waiting on #5');
  assert.equal(await page.getByRole('button', {name:/merge/i}).count(),0);
  assert.equal(await page.locator('#cr-form-engine-5 [data-bead="fe-813.3"]').count(),1);
  assert.equal(await page.locator('#cr-form-engine-5 [data-bead="fe-lwp.15"]').count(),1);
  assert.equal(await page.locator('#cr-form-engine-5 [data-bead="fe-sched"]').count(),0);
  assert.equal(await page.locator('main header p').count(), 0);
  assert.equal(await page.locator('#forge-panel > p').count(), 0);
  const timestamp = page.locator('#forge-synced time');
  assert.equal(await timestamp.getAttribute('title'), await timestamp.getAttribute('datetime'));
  await page.waitForFunction(() => Date.now() - Date.parse(document.querySelector('#forge-synced time').dateTime) >= 10000);
  const beforeRefresh = await timestamp.getAttribute('datetime');
  await page.click('#forge-refresh');
  await page.waitForFunction(() => document.querySelector('#flash-group').textContent.trim() === 'Updated', null, {timeout:20000});
  assert.notEqual(await timestamp.getAttribute('datetime'), beforeRefresh);
  assert.equal(await timestamp.innerText(), 'just now');
  for (const theme of ['light','dark']) {
    await page.click('#theme-' + theme);
    await page.screenshot({path:`${out}/pull-requests-${theme}.png`, fullPage:true, animations:'disabled'});
  }
  await page.locator('#cr-form-engine-6 [data-bead="fe-813.2"]').click();
  await page.locator('#ticket-sheet[data-open=true]').waitFor();
  assert.equal(await page.locator('#ticket-crs a[href="https://github.com/rpmessner/form-engine/pull/6"]').count(),1);
  await page.goto(base + '/?project=form-engine&q=fe-813&view=');
  await page.locator('[data-phx-main].phx-connected').waitFor();
  await page.locator('[data-bead="fe-813"] [data-cr-count="2"]').waitFor();
  for (const theme of ['light','dark']) {
    await page.click('#theme-' + theme);
    await page.screenshot({path:`${out}/initiatives-${theme}.png`, fullPage:true, animations:'disabled'});
  }
  await page.setViewportSize({width:390,height:844});
  await page.goto(base + '/pull-requests?project=form-engine');
  await page.locator('[data-phx-main].phx-connected').waitFor();
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth),false,'mobile page overflow');
  await page.screenshot({path:`${out}/pull-requests-mobile.png`,fullPage:true,animations:'disabled'});
  assert.deepEqual(errors,[]);
  fs.writeFileSync(`${out}/evidence.json`,JSON.stringify({numbers:[5,6],parent:5,epic:'fe-813',crCount:2,mergeButtons:0,consoleErrors:errors,mobileOverflow:false,manualRefresh:true,humanTimestamp:true,explanatoryCopy:false},null,2)+'\n');
  await browser.close();
  console.log('Forge browser acceptance: stack, bead sheet, CR count, light/dark, mobile and console checks passed');
})().catch(error => {console.error(error);process.exit(1)});
