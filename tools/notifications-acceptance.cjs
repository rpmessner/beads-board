// Run the checkout-local tools/inbox-acceptance.exs server on 4771 first.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {execFileSync} = require('node:child_process');
const env = {...process.env, FOREMAN_URL: 'http://127.0.0.1:4771', FOREMAN_ACTOR: 'pi', FOREMAN_SESSION: 'fm-notify'};
const board = args => execFileSync('./foreman', args, {env, encoding: 'utf8'}).trim();
const ask = () => board(['ask', 'decision', 'scratch-1', '--project', 'scratch', '--question', 'Continue?']);
const out = 'docs/acceptance/fm-notify';
fs.mkdirSync(out, {recursive: true});
(async () => {
  // Full Chromium honors Notification.permission; headless-shell reports denied
  // even when navigator.permissions reports granted.
  const browser = await chromium.launch({channel: 'chromium', headless: true});
  try {
    const errors = [];
    const watch = context => context.on('page', page => page.on('pageerror', error => errors.push(error.message)));
    board(['abandon', 'scratch-1', '--project', 'scratch']);
    board(['revive', 'scratch-1', '--project', 'scratch']);
    ask();
    const context = await browser.newContext();
    watch(context);
    await context.addInitScript(() => {
      window.promptCount = 0;
      Notification.requestPermission = () => {
        window.promptCount++;
        return new Promise(resolve => { window.finishPrompt = () => resolve('default'); });
      };
    });
    const page = await context.newPage();
    await page.goto('http://127.0.0.1:4771/needs-you');
    await page.locator('.phx-connected').waitFor();
    await page.locator('#enable-notifications').waitFor({timeout: 5000});
    assert.equal(await page.evaluate(() => window.promptCount), 0);
    for (const width of [1440, 390]) {
      await page.setViewportSize({width, height: 1000});
      for (const theme of ['light', 'dark']) {
        await page.locator(`#theme-${theme}`).click();
        await page.waitForFunction(theme => document.documentElement.dataset.theme === theme, theme);
        assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
        assert.ok(await page.locator('#enable-notifications .hero-bell').count(), 'opt-in has a bell icon');
        const navStyle = await page.evaluate(() => {
          const settings = document.querySelector('nav a[href="/settings"]');
          const previous = settings.previousElementSibling;
          const control = document.querySelector('#enable-notifications');
          const a = settings.getBoundingClientRect();
          const b = control.getBoundingClientRect();
          const style = el => {
            const s = getComputedStyle(el);
            return [s.fontSize, s.fontWeight, s.color, s.paddingLeft, s.borderRadius];
          };
          return {settings: style(settings), control: style(control),
            aligned: a.left === b.left && a.width === b.width && a.height === b.height,
            gap: b.top - a.bottom, expectedGap: a.top - previous.getBoundingClientRect().bottom};
        });
        assert.deepEqual(navStyle.control, navStyle.settings, 'opt-in matches nav typography and shape');
        assert.ok(navStyle.aligned, 'opt-in aligns with full-width nav rows');
        assert.equal(navStyle.gap, navStyle.expectedGap, 'opt-in uses the same spacing after Settings');
        await page.screenshot({path: `${out}/control-${width}-${theme}.png`, fullPage: true, animations: 'disabled'});
      }
    }
    const settingsLink = page.locator('nav a[href="/settings"]');
    const optIn = page.locator('#enable-notifications');
    const hoverColor = async locator => {
      await locator.hover();
      return locator.evaluate(el => {
        el.getAnimations().forEach(animation => animation.finish());
        return getComputedStyle(el).backgroundColor;
      });
    };
    assert.equal(await hoverColor(optIn), await hoverColor(settingsLink), 'same nav hover background');
    await settingsLink.focus();
    await page.keyboard.press('Tab');
    assert.equal(await optIn.evaluate(el => el.matches(':focus-visible')), true);
    const focusStyle = locator => locator.evaluate(el => {
      const style = getComputedStyle(el);
      return [style.outlineStyle, style.outlineWidth, style.outlineColor, style.outlineOffset];
    });
    const controlFocus = await focusStyle(optIn);
    assert.equal(controlFocus[1], '2px', 'visible keyboard focus ring');
    await settingsLink.focus();
    assert.deepEqual(controlFocus, await focusStyle(settingsLink), 'same nav keyboard focus');
    await page.locator('#enable-notifications').click();
    assert.equal(await page.evaluate(() => window.promptCount), 1);
    ask();
    await page.waitForFunction(() => document.title === '(2) foreman');
    assert.equal(await page.locator('#enable-notifications').isVisible(), false, 'pending prompt cannot be requested again on reconciliation');
    await page.evaluate(() => window.finishPrompt());
    await page.locator('#enable-notifications').waitFor();
    console.log('PASS default permission: explicit control, no prompt before click');
    await context.close();

    board(['abandon', 'scratch-1', '--project', 'scratch']);
    board(['revive', 'scratch-1', '--project', 'scratch']);
    const granted = await browser.newContext({permissions: ['notifications']});
    watch(granted);
    const notifications = [];
    await granted.exposeBinding('recordNotification', (_, entry) => notifications.push(entry));
    await granted.addInitScript(() => {
      const Native = Notification;
      window.sentNotifications = [];
      window.promptCount = 0;
      window.Notification = class extends Native {
        static requestPermission() { window.promptCount++; return Native.requestPermission(); }
        constructor(title, options) {
          super(title, options);
          window.sentNotifications.push(this);
          window.recordNotification({title, tag: options.tag});
        }
      };
    });
    const tabs = [await granted.newPage(), await granted.newPage()];
    for (const tab of tabs) {
      await tab.goto('http://127.0.0.1:4771/');
      await tab.locator('.phx-connected').waitFor();
      assert.equal(await tab.locator('#enable-notifications').isVisible(), false);
      assert.equal(await tab.evaluate(() => Notification.permission), 'granted');
      await tab.waitForFunction(() => localStorage.getItem('foreman:notifications:v1') !== null);
    }
    const id = ask();
    for (const tab of tabs) {
      await tab.waitForFunction(() => document.title === '(1) foreman');
      assert.equal(await tab.locator('#needs-you-count').innerText(), '1');
    }
    await Promise.any(tabs.map(tab => tab.waitForFunction(() => window.sentNotifications.length === 1, null, {timeout: 5000})));
    assert.deepEqual(notifications, [{title: 'Decision · scratch-1', tag: `foreman-request-${id}`}]);
    console.log('PASS granted permission: two tabs, one native notification and consistent counts');

    // Repeated snapshots and navigation must not replay an existing request.
    for (const tab of tabs) {
      await tab.reload();
      await tab.locator('.phx-connected').waitFor();
    }
    const second = ask();
    for (const tab of tabs) await tab.waitForFunction(() => document.title === '(2) foreman');
    await Promise.any(tabs.map(tab => tab.waitForFunction(() => window.sentNotifications.length === 1)));
    assert.equal(notifications.length, 2);
    assert.equal(notifications[1].tag, `foreman-request-${second}`);
    const winner = (await tabs[0].evaluate(() => window.sentNotifications.length)) ? tabs[0] : tabs[1];
    await winner.evaluate(() => window.sentNotifications[0].onclick());
    await winner.waitForURL('**/needs-you');
    console.log('PASS navigation/reload deduplication and notification click opens Needs you');

    // Both sockets miss the broadcast. Reconnect must recover the durable pending request.
    for (const tab of tabs) await tab.evaluate(() => window.liveSocket.disconnect());
    const missed = ask();
    for (const tab of tabs) await tab.evaluate(() => window.liveSocket.connect());
    for (const tab of tabs) await tab.waitForFunction(() => document.title === '(3) foreman');
    await Promise.any(tabs.map(tab => tab.waitForFunction(id => window.sentNotifications.some(n => n.tag === `foreman-request-${id}`), missed)));
    assert.equal(notifications.length, 3);
    assert.equal(notifications[2].tag, `foreman-request-${missed}`);
    console.log('PASS request arriving while disconnected is delivered once after reconnect');

    // If durable claiming is unavailable, do not toast repeatedly on every tick.
    for (const tab of tabs) await tab.evaluate(() => {
      window.originalSetItem = Storage.prototype.setItem;
      Storage.prototype.setItem = function(key, value) {
        if (key === 'foreman:notifications:v1') throw new DOMException('Quota exceeded', 'QuotaExceededError');
        return window.originalSetItem.call(this, key, value);
      };
    });
    const blocked = ask();
    for (const tab of tabs) await tab.waitForFunction(() => document.title === '(4) foreman');
    // A lock barrier waits for the snapshot's synchronous delivery attempt.
    for (const tab of tabs) await tab.evaluate(() => navigator.locks.request('foreman:notifications:v1', () => {}));
    assert.equal(notifications.length, 3, 'storage failure must not cause duplicate native notifications');
    for (const tab of tabs) await tab.evaluate(() => {Storage.prototype.setItem = window.originalSetItem;});
    await Promise.any(tabs.map(tab => tab.waitForFunction(id => window.sentNotifications.some(n => n.tag === `foreman-request-${id}`), blocked)));
    assert.equal(notifications.length, 4);
    assert.equal(notifications[3].tag, `foreman-request-${blocked}`);
    console.log('PASS storage failure fails closed; reconciliation recovers once storage returns');
    await tabs[0].close();
    const surviving = ask();
    await tabs[1].waitForFunction(id => window.sentNotifications.some(n => n.tag === `foreman-request-${id}`), surviving);
    assert.equal(notifications.length, 5);
    assert.equal(await tabs[1].evaluate(() => window.promptCount), 0);
    console.log('PASS surviving tab delivers after peer closes; granted permission never prompts');
    await granted.close();

    const denied = await browser.newContext();
    watch(denied);
    const deniedPage = await denied.newPage();
    const cdp = await denied.newCDPSession(deniedPage);
    const {targetInfo} = await cdp.send('Target.getTargetInfo');
    await cdp.send('Browser.setPermission', {permission: {name: 'notifications'}, setting: 'denied', origin: env.FOREMAN_URL, browserContextId: targetInfo.browserContextId});
    await denied.addInitScript(() => {
      window.promptCount = 0;
      window.notificationCount = 0;
      const Native = Notification;
      window.Notification = class extends Native {
        static requestPermission() { window.promptCount++; return Promise.resolve('denied'); }
        constructor(...args) { super(...args); window.notificationCount++; }
      };
    });
    await deniedPage.goto(`${env.FOREMAN_URL}/needs-you`);
    await deniedPage.locator('.phx-connected').waitFor();
    assert.equal(await deniedPage.evaluate(() => Notification.permission), 'denied');
    assert.equal(await deniedPage.locator('#enable-notifications').isVisible(), false);
    ask();
    await deniedPage.waitForFunction(() => document.title === '(6) foreman');
    assert.equal(await deniedPage.locator('#needs-you-count').innerText(), '6');
    await deniedPage.evaluate(() => navigator.locks.request('foreman:notifications:v1', () => {}));
    assert.equal(await deniedPage.evaluate(() => window.notificationCount), 0);
    assert.equal(await deniedPage.evaluate(() => window.promptCount), 0);
    console.log('PASS denied permission: hidden control, no prompt, live count unchanged');
    await denied.close();
    const unsupported = await browser.newContext();
    watch(unsupported);
    await unsupported.addInitScript(() => { window.Notification = undefined; });
    const unsupportedPage = await unsupported.newPage();
    await unsupportedPage.goto(`${env.FOREMAN_URL}/`);
    await unsupportedPage.locator('.phx-connected').waitFor();
    assert.equal(await unsupportedPage.locator('#enable-notifications').isVisible(), false);
    await unsupported.close();
    console.log('PASS sidebar styling, hover/focus and unsupported permission visibility');
    assert.deepEqual(errors, [], 'no browser errors');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
