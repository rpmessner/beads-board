// Run with PREVIEW_URL and Playwright available on NODE_PATH.
const {chromium} = require('playwright');
const fs = require('node:fs');
const path = require('node:path');

(async () => {
  if (!process.env.PREVIEW_URL) throw Error('Set PREVIEW_URL to the registered preview URL');
  const base = process.env.PREVIEW_URL;
  const browser = await chromium.launch({headless: true});
  const results = [];
  for (const theme of ['light', 'dark']) {
    const page = await browser.newPage({viewport: {width: 1440, height: 1080}, colorScheme: theme});
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(`${base}/?ticket=wow-addons:wa-x0z.5`);
    await page.waitForSelector('.phx-connected');
    await page.evaluate(theme => {
      document.documentElement.classList.toggle('dark', theme === 'dark');
      document.documentElement.dataset.theme = theme;
    }, theme);
    await page.locator('#ticket-documents').waitFor({state: 'visible'});
    const links = await page.locator('#ticket-documents a').evaluateAll(anchors =>
      anchors.map(anchor => ({text: anchor.textContent.trim(), href: anchor.getAttribute('href')})));
    if (links.length !== 2 || links[0].text !== 'docs/research/addon-ideas.md' || links[1].text !== 'docs/briefs/wa-ideas.md') {
      throw Error(`Unexpected Documents list: ${JSON.stringify(links)}`);
    }
    if ((await page.locator('#ticket-overview').innerText()).includes('Documents:')) {
      throw Error('Handwritten Documents note still present');
    }
    await page.locator('#ticket-documents').scrollIntoViewIfNeeded();
    await page.screenshot({path: path.join(__dirname, `documents-${theme}.png`)});
    for (const [tab, container, name] of [
      ['history', 'ticket-history', 'history'], ['notes', 'ticket-notes', 'notes']
    ]) {
      await page.locator(`#ticket-${tab}-tab`).click();
      await page.locator(`#${container} a[href='/documents/wow-addons?path=docs%2Fresearch%2Faddon-ideas.md']`).first().waitFor({state: 'visible'});
      await page.screenshot({path: path.join(__dirname, `${name}-${theme}.png`)});
    }
    await page.locator('#ticket-overview-tab').click();
    await page.locator('#ticket-documents a').first().click();
    await page.locator('#document-content').waitFor({state: 'visible'});
    if (new URL(page.url()).pathname !== '/documents/wow-addons') throw Error('Did not open full viewer');
    if (errors.length) throw Error(JSON.stringify(errors));
    results.push({theme, links, handwrittenNote: false, historyLinked: true, notesLinked: true, fullViewer: true, errors});
    await page.close();
  }
  const mobile = await browser.newPage({viewport: {width: 390, height: 844}, colorScheme: 'light'});
  await mobile.goto(`${base}/?ticket=wow-addons:wa-x0z.5`);
  await mobile.waitForSelector('.phx-connected');
  await mobile.locator('#ticket-documents').scrollIntoViewIfNeeded();
  const bounds = await mobile.locator('#ticket-documents').boundingBox();
  const overflow = await mobile.locator('#ticket-documents').evaluate(element => element.scrollWidth > element.clientWidth);
  if (overflow || bounds.x < 0 || bounds.x + bounds.width > 391) throw Error('Mobile Documents clipped');
  await mobile.screenshot({path: path.join(__dirname, 'documents-mobile.png')});
  results.push({viewport: 390, documentsOverflow: overflow});
  await browser.close();
  fs.writeFileSync(path.join(__dirname, 'browser.json'), JSON.stringify(results, null, 2) + '\n');
  console.log(JSON.stringify(results, null, 2));
})().catch(error => {console.error(error); process.exit(1);});
