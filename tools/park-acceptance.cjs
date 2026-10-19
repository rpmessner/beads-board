const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {execFileSync} = require('node:child_process');
const out = 'docs/acceptance/fm-park';
const tmux = args => execFileSync('tmux', ['-L','fm-park-live',...args], {encoding:'utf8'}).trim();
(async () => {
  fs.mkdirSync(out,{recursive:true});
  const browser = await chromium.launch({headless:true});
  try {
    const page = await browser.newPage();
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    for (const width of [390,1440]) {
      await page.setViewportSize({width,height:1000});
      for (const theme of ['light','dark']) {
        for (const [name,path,selector] of [
          ['list','/','#drafts [phx-click=launch-session]'],
          ['epic','/epics/scratch/draft:greeting','#epic-launch'],
          ['sheet','/?ticket=scratch:scratch-1','#ticket-launch']
        ]) {
          await page.goto('http://127.0.0.1:4788'+path);
          await page.locator('.phx-connected').waitFor();
          await page.evaluate(t => {localStorage.setItem('theme',t); document.documentElement.dataset.theme=t},theme);
          const button = page.locator(selector);
          await button.waitFor({state:'visible'});
          assert.equal((await button.innerText()).trim(),'Relaunch');
          await page.waitForFunction(sel => {
            const r = document.querySelector(sel).getBoundingClientRect();
            return r.x >= 0 && r.right <= innerWidth;
          },selector);
          assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
          await page.screenshot({path:`${out}/${name}-${width}-${theme}.png`,fullPage:true,animations:'disabled'});
        }
      }
    }
    await page.goto('http://127.0.0.1:4788/?ticket=scratch:scratch-1');
    await page.locator('.phx-connected').waitFor();
    await page.locator('#ticket-launch').click();
    await page.waitForFunction(() => document.querySelector('#ticket-launch').textContent.trim() === 'Focus');
    fs.writeFileSync(`${out}/browser.json`,JSON.stringify({errors,windows:tmux(['list-windows','-a','-F','#{window_id} #{window_name} #{@foreman-session}'])},null,2)+'\n');
    assert.deepEqual(errors,[]);
    console.log('PASS: Relaunch on sheet/detail/list, 390/1440 light/dark, no clipping; sheet reopens a window');
  } finally { await browser.close() }
})().catch(e=>{console.error(e);process.exitCode=1});
