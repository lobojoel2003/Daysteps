// Composes docs/screenshots/hero.png (the README banner) from the captured
// screenshots: a tablet and a phone showing the child's view.
//   node tool/screenshots/capture.mjs && node tool/screenshots/hero.mjs
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';

const { chromium } = createRequire(import.meta.url)('playwright');
const dir = new URL('../../docs/screenshots/', import.meta.url).pathname;
const img = (name) => `data:image/png;base64,${readFileSync(dir + name).toString('base64')}`;

const html = `<!doctype html><html><head><style>
  * { box-sizing: border-box; }
  body { margin: 0; width: 1600px; height: 860px; overflow: hidden;
         background: radial-gradient(circle at 15% 10%, #FFF8EE 0%, #FCEBD2 55%, #F6DDBA 100%);
         font-family: system-ui, sans-serif; }
  .tablet { position: absolute; left: 70px; top: 70px; width: 1160px; height: 728px;
            background: #1E2A30; border-radius: 44px; padding: 24px;
            box-shadow: 0 40px 80px rgba(33, 50, 58, .28), inset 0 0 0 2px #33444c; }
  .tablet img { width: 100%; height: 100%; border-radius: 22px; display: block; }
  .phone { position: absolute; right: 90px; top: 150px; width: 330px; height: 690px;
           background: #1E2A30; border-radius: 48px; padding: 14px;
           box-shadow: 0 40px 80px rgba(33, 50, 58, .32), inset 0 0 0 2px #33444c; }
  .phone img { width: 100%; height: 100%; object-fit: cover; object-position: top;
               border-radius: 36px; display: block; }
</style></head><body>
  <div class="tablet"><img src="${img('schedule-tablet.png')}"></div>
  <div class="phone"><img src="${img('step-timer-phone.png')}"></div>
</body></html>`;

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1600, height: 860 }, deviceScaleFactor: 1.5 });
await page.setContent(html, { waitUntil: 'load' });
await page.screenshot({ path: dir + 'hero.png' });
await browser.close();
console.log('docs/screenshots/hero.png');
