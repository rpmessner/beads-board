// NODE_PATH=/path/to/playwright/node_modules node tools/reader-acceptance.cjs
const {chromium} = require('playwright');
const fs = require('node:fs');
const {execFileSync} = require('node:child_process');
(async () => {
  const root = fs.readFileSync('/tmp/fm-reader-browser-root', 'utf8');
  const file = `${root}/tickets/demo-abc.md`;
  const browser = await chromium.launch({headless: true});
  const page = await browser.newPage({viewport: {width: 1440, height: 1000}});
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  await page.goto('http://127.0.0.1:4779/?ticket=reader:demo-abc');
  await page.waitForFunction(() => document.querySelector('[data-phx-main]')?.classList.contains('phx-connected'));
  await page.locator('#ticket-title').filter({hasText: 'Browser initial'}).waitFor();
  const original = fs.readFileSync(file, 'utf8');
  let start = performance.now();
  fs.writeFileSync(file, original.replace('Browser initial', 'Hand edited'));
  await page.locator('#ticket-title').filter({hasText: 'Hand edited'}).waitFor({timeout: 2000});
  console.log(`hand edit visible: ${Math.round(performance.now()-start)} ms`);
  start = performance.now();
  execFileSync(`${process.cwd()}/foreman`, ['update', 'demo-abc', '--title', 'CLI edited', '--json'], {cwd: root, env: {...process.env, FOREMAN_CONFIG_DIR: `${root}/config`, FOREMAN_URL: 'http://127.0.0.1:1'}});
  await page.locator('#ticket-title').filter({hasText: 'CLI edited'}).waitFor({timeout: 2000});
  const elapsed = Math.round(performance.now()-start);
  if(elapsed > 2000) throw Error(`CLI edit exceeded 2s: ${elapsed}`);
  console.log(`CLI edit visible: ${elapsed} ms`);
  if(!(await page.locator('#ticket-acceptance-progress').innerText()).includes('1/2')) throw Error('Missing progress');
  for (const label of ['close reason', 'labels', 'closed at']) {
    if(await page.locator('#ticket-overview dt').filter({hasText: label}).count()) throw Error(`Empty field: ${label}`);
  }
  for (const label of ['Dependencies', 'Linked CRs']) {
    if(await page.locator('#ticket-overview h3').filter({hasText: label}).count()) throw Error(`Empty section: ${label}`);
  }
  const tallFields = await page.locator('#ticket-overview dd').evaluateAll(nodes => nodes.some(node => node.getBoundingClientRect().height > 40));
  if(tallFields) throw Error('Ticket fields have excessive whitespace');
  await page.screenshot({path: '/tmp/fm-reader-ticket.png', fullPage: true});
  fs.writeFileSync(file, 'malformed');
  await page.goto('http://127.0.0.1:4779/settings');
  await page.locator('#repo-reader').filter({hasText: 'tickets/demo-abc.md: malformed frontmatter'}).waitFor({timeout: 2000});
  await page.locator('#repo-reader [data-health=warning]').filter({hasText: '1 file error'}).waitFor();
  if((await page.locator('#sidebar-project-reader').innerText()).includes('down')) throw Error('Parse error mislabeled as outage');
  await page.screenshot({path: '/tmp/fm-reader-settings.png', fullPage: true});
  await page.goto('http://127.0.0.1:4779/?ticket=reader:demo-abc');
  await page.locator('#ticket-title').filter({hasText: 'CLI edited'}).waitFor();
  fs.writeFileSync(file, original);
  await page.locator('#ticket-title').filter({hasText: 'Browser initial'}).waitFor({timeout: 2000});
  await page.goto('http://127.0.0.1:4779/settings');
  fs.renameSync(`${root}/tickets`, `${root}/tickets-hidden`);
  try {
    await page.locator('#repo-reader [data-health=unreachable]').waitFor({timeout: 65000});
    await page.locator('#sidebar-project-reader').filter({hasText: 'down'}).waitFor({timeout: 2000});
    await page.screenshot({path: '/tmp/fm-reader-unreachable.png', fullPage: true});
  } finally {
    fs.renameSync(`${root}/tickets-hidden`, `${root}/tickets`);
  }
  await page.locator('#repo-reader [data-health=synced]').waitFor({timeout: 2000});
  if(errors.length) throw Error(errors.join('\n'));
  await browser.close();
  console.log('Reader browser acceptance PASS; screenshots in /tmp/fm-reader-{ticket,settings}.png');
})().catch(e => {console.error(e); process.exit(1)});
