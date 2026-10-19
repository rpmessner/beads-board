const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {execFileSync, spawnSync} = require('node:child_process');
const out = 'docs/acceptance/fm-waiting';
const url = 'http://127.0.0.1:4786';
const env = {...process.env, FOREMAN_URL: url};
const tmux = args => execFileSync('tmux', ['-L', 'fm-waiting-live', ...args], {encoding:'utf8'});
const sql = query => execFileSync('psql', ['-X','-h','localhost','-U','postgres','-d','foreman_acceptance_fm-waiting','-Atc',query], {encoding:'utf8', env:{...process.env,PGPASSWORD:'postgres'}}).trim();
const board = args => execFileSync('./foreman', args, {encoding:'utf8',env}).trim();
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
(async () => {
  const browser = await chromium.launch({channel:'chromium',headless:true});
  try {
    const context = await browser.newContext({permissions:['notifications']});
    const notifications = [], errors = [];
    await context.exposeBinding('recordNotification', (_, entry) => notifications.push(entry));
    await context.addInitScript(() => { const Native = Notification; window.Notification = class extends Native {constructor(title, options) {super(title, options); window.recordNotification({title,tag:options.tag});}}; });
    const page = await context.newPage();
    page.on('pageerror', e => errors.push(e.message));
    await page.goto(url+'/?ticket=scratch:scratch-1');
    await page.locator('.phx-connected').waitFor();
    await page.waitForFunction(() => localStorage.getItem('foreman:notifications:v1'));
    await page.locator('#ticket-launch').click();
    await page.locator('#ticket-planning-state').waitFor();
    await page.goto(url+'/needs-you');
    await page.locator('.phx-connected').waitFor();
    let pane, observed, permissionId;
    const deadline = Date.now()+120000;
    while(Date.now()<deadline) {
      pane = tmux(['capture-pane','-p','-t','scratch:scratch-1']);
      if(pane.includes('Yes, I trust this folder')) tmux(['send-keys','-t','scratch:scratch-1','Down','Enter']);
      if(pane.includes('Do you want to proceed?')) {
        observed ||= Date.now();
        permissionId = sql("select id from approval_requests where state='pending' and facts->>'reason'='permission'");
        if(permissionId) break;
      }
      await delay(100);
    }
    assert.ok(permissionId, 'permission prompt produces a pending request');
    const elapsed = Date.now()-observed;
    assert.ok(elapsed<10000);
    await page.locator(`#request-${permissionId}`).waitFor();
    // A parallel Read must not resolve the still-blocked Bash request.
    await delay(2500);
    assert.equal(sql(`select state from approval_requests where id='${permissionId}'`),'pending');
    assert.ok(tmux(['capture-pane','-p','-t','scratch:scratch-1']).includes('Do you want to proceed?'));
    assert.equal(notifications.filter(n=>n.tag===`foreman-request-${permissionId}`).length,1);
    fs.writeFileSync(`${out}/permission-pane.txt`,pane);
    fs.writeFileSync(`${out}/permission-timing.json`,JSON.stringify({milliseconds_after_prompt_observed:elapsed,pending_permission_requests:1,notification_count:1},null,2));
    tmux(['send-keys','-t','scratch:scratch-1','Enter']);
    await page.locator(`#pending-requests #request-${permissionId}`).waitFor({state:'detached',timeout:10000});
    assert.equal(sql(`select state from approval_requests where id='${permissionId}'`),'superseded');
    console.log('PASS real Claude permission, one request <10s, parallel-tool isolation, one browser notification, answer clears');

    const inputDeadline = Date.now()+90000;
    let answeredQuestion = false, inputReady = false;
    while(Date.now()<inputDeadline) {
      const shown = tmux(['capture-pane','-p','-t','scratch:scratch-1']);
      if(!answeredQuestion && /❯\s*1\. (Stop here|Yes)/.test(shown) && shown.includes('Enter to select')) {
        tmux(['send-keys','-t','scratch:scratch-1','Enter']);
        answeredQuestion = true;
      }
      if(sql("select count(*) from approval_requests where state='pending' and facts->>'reason'='input' and facts->>'tool' is null") === '1') { inputReady = true; break; }
      await delay(200);
    }
    assert.ok(inputReady, 'Claude is at the ordinary input prompt before simulating a provider stop');
    const session = sql("select session_id from planning_sessions where ticket='scratch-1'");
    let settings;
    for(const pid of fs.readdirSync('/proc').filter(p=>/^\d+$/.test(p))) {
      try { const args = fs.readFileSync(`/proc/${pid}/cmdline`,'utf8').split('\0');
        if(args.includes(session) && args.includes('--settings')) settings = JSON.parse(args[args.indexOf('--settings')+1]);
      } catch {}
    }
    assert.ok(settings, 'read the actual launched --settings');
    const simulated = spawnSync('sh',['-c',settings.hooks.StopFailure[0].hooks[0].command], {input:JSON.stringify({error:'rate_limit',last_assistant_message:'Usage limit reached; resets 14:00'}),env,encoding:'utf8'});
    assert.equal(simulated.status,0);
    const planningLimit = sql("select id from approval_requests where state='pending' and bead_id='scratch-1' and facts->>'reason'='usage_limit'");
    assert.ok(planningLimit);
    await page.locator(`#continue-${planningLimit}`).waitFor();
    await page.locator(`#continue-${planningLimit}`).click();
    await page.locator(`#pending-requests #request-${planningLimit}`).waitFor({state:'detached',timeout:10000});
    let continuedPane;
    const renderedDeadline = Date.now()+10000;
    do {
      continuedPane = tmux(['capture-pane','-p','-S','-100','-t','scratch:scratch-1']);
      if(/❯\s*continue/.test(continuedPane)) break;
      await delay(100);
    } while(Date.now()<renderedDeadline);
    assert.match(continuedPane,/❯\s*continue/);
    fs.writeFileSync(`${out}/continued-planning-pane.txt`,continuedPane);
    console.log('PASS actual per-launch StopFailure command, Anthropic/reset facts, planning Continue and resume hook');

    const receiver = '/tmp/fm-waiting-live/receiver.sh';
    fs.writeFileSync(receiver, '#!/bin/sh\nstty -echo\nprintf "Error: Codex error: The usage limit has been reached; resets 14:00\\n"\nIFS= read -r line\nprintf "%s" "$line" > /tmp/fm-waiting-live/received\nprintf "working again\\n"\nread more\n', {mode:0o700});
    execFileSync('tmux',['-L','fm-waiting-external','new-session','-d','-s','scratch-pi','-n','pi-limit',receiver]);
    await delay(300);
    const id = board(['ask','session_waiting','scratch-pi','--project','scratch','--session','pi-scratch','--reason','usage_limit','--window','pi-limit','--provider','Codex','--reset-at','14:00']);
    assert.match(id,/^[0-9a-f-]{36}$/);
    await page.locator(`#continue-${id}`).waitFor();
    assert.ok(!fs.existsSync('/tmp/fm-waiting-live/received'));
    for(const width of [1440,390]) {
      await page.setViewportSize({width,height:1000});
      for(const theme of ['light','dark']) {
        await page.evaluate(theme=>{localStorage.setItem('theme',theme);document.documentElement.dataset.theme=theme},theme);
        assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
        await page.screenshot({path:`${out}/waiting-${width}-${theme}.png`,fullPage:true,animations:'disabled'});
        await page.locator('#needs-you-badge').click();
        await page.locator(`#drawer-continue-${id}`).waitFor();
        await page.screenshot({path:`${out}/drawer-${width}-${theme}.png`,fullPage:true,animations:'disabled'});
        await page.keyboard.press('Escape');
        await page.locator('#request-drawer').waitFor({state:'hidden'});
      }
    }
    await page.locator(`#continue-${id}`).click();
    await page.locator(`#pending-requests #request-${id}`).waitFor({state:'detached',timeout:10000});
    assert.equal(fs.readFileSync('/tmp/fm-waiting-live/received','utf8'),'continue');
    assert.equal(sql(`select state from approval_requests where id='${id}'`),'superseded');
    assert.deepEqual(errors,[]);
    fs.writeFileSync(`${out}/browser.json`,JSON.stringify({permissionId,planningLimit,usageLimitId:id,notifications,errors,received:'continue'},null,2));
    console.log('PASS coordinator usage limit, page/drawer light/dark 390/1440, click sends exactly continue+Enter, output clears, no browser errors');
  } finally {await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
