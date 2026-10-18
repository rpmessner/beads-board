const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {execFileSync} = require('node:child_process');
const out = 'docs/acceptance/fm-launch';
const socket = process.env.LAUNCH_SCRATCH_SOCKET;
assert.ok(socket?.startsWith('fm-launch-'));
const tmux = args => execFileSync('tmux', ['-L', socket, ...args], {encoding: 'utf8'}).trim();
(async () => {
  fs.mkdirSync(out, {recursive:true});
  const browser = await chromium.launch({headless:true, ignoreDefaultArgs:['--hide-scrollbars']});
  try {
    const context = await browser.newContext({permissions:['clipboard-read','clipboard-write']});
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    for (const width of [1440,390]) {
      await page.setViewportSize({width,height:1000});
      for (const theme of ['light','dark']) {
        for (const [name,path,selector] of [
          ['list','/','#drafts [phx-click=launch-session]'],
          ['epic','/epics/scratch/draft:greeting','#epic-launch'],
          ['sheet','/?ticket=scratch:scratch-1','#ticket-launch']
        ]) {
          await page.goto('http://127.0.0.1:4784'+path);
          await page.locator('.phx-connected').waitFor();
          await page.evaluate(theme => {localStorage.setItem('theme', theme); document.documentElement.dataset.theme=theme},theme);
          const button = page.locator(selector);
          await button.waitFor({state:'visible'});
          if (process.env.LAUNCH_EXPECT_FOCUS === '1') assert.equal((await button.innerText()).trim(), 'Focus');
          if (name === 'sheet') assert.equal((await page.locator('#ticket-status').innerText()).trim(), 'open');
          if (name === 'sheet') await page.waitForFunction(() => {
            const box = document.querySelector('#ticket-launch')?.getBoundingClientRect();
            return box && box.right <= innerWidth;
          });
          const box = await button.boundingBox();
          assert.ok(box.x >= 0 && box.x+box.width <= width, `${name} Launch clipped at ${width}`);
          assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
          if (name !== 'list' && await page.locator(`[id='${name === 'sheet' ? 'ticket' : 'epic'}-attach']`).count()) {
            const prefix = name === 'sheet' ? 'ticket' : 'epic';
            const input = await page.locator(`#${prefix}-attach`).boundingBox();
            const copy = await page.locator(`#${prefix}-copy-attach`).boundingBox();
            assert.ok(Math.abs(input.y - copy.y) < 1, 'Attach input and Copy must align');
          }
          await page.screenshot({path:`${out}/${name}-${width}-${theme}.png`,fullPage:true,animations:'disabled'});
        }
      }
    }
    await page.setViewportSize({width:1440,height:1000});
    await page.goto('http://127.0.0.1:4784/?ticket=scratch:scratch-1');
    await page.locator('.phx-connected').waitFor();
    await page.locator('#ticket-launch').click();
    await page.locator('#ticket-planning-state').waitFor();
    await page.waitForFunction(() => document.querySelector('#ticket-launch').textContent.trim() === 'Focus');
    const windows = tmux(['list-windows','-a','-F','#{session_name}:#{window_name}:#{window_id}']);
    assert.match(windows,/scratch:scratch-1:@\d+/);
    await page.locator('#ticket-launch').click();
    assert.equal(tmux(['list-windows','-a','-F','#{session_name}:#{window_name}:#{window_id}']),windows);
    await page.locator('#ticket-copy-attach').click();
    assert.equal(await page.evaluate(() => navigator.clipboard.readText()),await page.locator('#ticket-attach').inputValue());
    await page.screenshot({path:`${out}/launched.png`,fullPage:true});
    // These are scratch-only launches, through both additional controls.
    await page.goto('http://127.0.0.1:4784/');
    await page.locator('.phx-connected').waitFor();
    await page.locator('#drafts [phx-click=launch-session]').click();
    await page.goto('http://127.0.0.1:4784/epics/scratch/draft:greeting');
    await page.locator('.phx-connected').waitFor();
    await page.locator('#epic-planning-state').waitFor();
    assert.equal((await page.locator('#epic-launch').innerText()).trim(), 'Focus');
    const before = tmux(['list-windows','-a','-F','#{window_id}']);
    await page.locator('#epic-launch').click();
    assert.equal(tmux(['list-windows','-a','-F','#{window_id}']),before);
    await page.goto('http://127.0.0.1:4784/?ticket=scratch:scratch-bug');
    await page.locator('.phx-connected').waitFor();
    await page.locator('#ticket-launch').click();
    await page.locator('#ticket-planning-state').waitFor();
    assert.deepEqual(errors,[]);
    fs.writeFileSync(`${out}/browser.json`,JSON.stringify({windows:tmux(['list-windows','-a','-F','#{session_name}:#{window_name}:#{window_id}']),errors},null,2)+'\n');
    console.log('PASS: Launch sheet/detail/rows, repeat focuses, copy attach, 390/1440 light/dark; no overflow or browser errors');
  } finally {await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
