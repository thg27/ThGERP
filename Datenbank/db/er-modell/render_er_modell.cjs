// Rendert <modell>.html (nach build_er_modell.py) zu SVG, PNG und PDF.
// Aufruf: NODE_PATH=<npx-Cache>/node_modules node render_er_modell.cjs <modell>
// (Puppeteer aus dem npx-Cache von @mermaid-js/mermaid-cli)
const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

(async () => {
  const name = process.argv[2] || 'kundenstamm_er_modell';
  const html = path.join(__dirname, name + '.html');
  const browser = await puppeteer.launch({ headless: true });
  const page = await browser.newPage();
  await page.goto('file://' + html);
  await page.waitForSelector('body[data-ready="1"]', { timeout: 60000 });

  const svg = await page.$eval('#erd svg', e => e.outerHTML);
  fs.writeFileSync(path.join(__dirname, name + '.svg'), svg);

  // Seite so breit wie das Diagramm (sonst schneidet #erd mit overflow:auto ab)
  const svgW = await page.$eval('#erd svg', e => Math.ceil(e.getBoundingClientRect().width));
  await page.setViewport({ width: svgW + 48, height: 1000 });
  const size = await page.evaluate(() => ({ w: document.body.scrollWidth, h: document.body.scrollHeight }));
  await page.setViewport({ width: size.w, height: size.h });
  await page.screenshot({ path: path.join(__dirname, name + '.png'), fullPage: true });
  await page.pdf({ path: path.join(__dirname, name + '.pdf'), width: size.w + 'px', height: size.h + 'px', printBackground: true });

  await browser.close();
  console.log(`${name}: SVG, PNG, PDF erzeugt (${size.w} x ${size.h})`);
})();
