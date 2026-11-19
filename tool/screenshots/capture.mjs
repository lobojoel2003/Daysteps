// Captures the README screenshots from a release web build.
//
//   flutter build web --release --no-web-resources-cdn --web-content-hash
//   node tool/screenshots/capture.mjs            # writes docs/screenshots/*.png
//   node tool/screenshots/hero.mjs               # README banner
//
// Each scene runs in a fresh browser profile, so the app starts with its
// example boards. The app is driven through its accessibility tree (button
// labels), the same way a screen reader would use it.
import { createRequire } from 'node:module';
import { createServer } from 'node:http';
import { readFile, mkdir } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';

const { chromium } = createRequire(import.meta.url)('playwright');

const ROOT = new URL('../../build/web/', import.meta.url).pathname;
const OUT = new URL('../../docs/screenshots/', import.meta.url).pathname;
const TYPES = {
  '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json',
  '.wasm': 'application/wasm', '.png': 'image/png', '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf', '.otf': 'font/otf', '.bin': 'application/octet-stream',
};

const server = createServer(async (req, res) => {
  try {
    let path = normalize(decodeURIComponent(new URL(req.url, 'http://x').pathname));
    if (path.endsWith('/')) path += 'index.html';
    const body = await readFile(join(ROOT, path));
    res.writeHead(200, { 'content-type': TYPES[extname(path)] ?? 'application/octet-stream' });
    res.end(body);
  } catch {
    res.writeHead(404).end();
  }
}).listen(0);
const base = `http://localhost:${server.address().port}/`;

const TABLET = { viewport: { width: 1280, height: 800 }, deviceScaleFactor: 2 };
const WIDE = { viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2 };
const PHONE = { viewport: { width: 412, height: 880 }, deviceScaleFactor: 2, hasTouch: true, isMobile: true };

const browser = await chromium.launch();
await mkdir(OUT, { recursive: true });

async function open(device) {
  const context = await browser.newContext(device);
  const page = await context.newPage();
  await page.clock.install();
  await page.goto(base, { waitUntil: 'load' });
  // Flutter draws to a canvas; turn on its accessibility tree to find buttons.
  await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 60000 });
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.getByRole('button', { name: 'New board' }).waitFor({ timeout: 60000 });
  await page.waitForTimeout(800);
  return { context, page };
}

const button = (page, name, nth = 0) => page.getByRole('button', { name, exact: true }).nth(nth);

async function shot(page, name) {
  await page.waitForTimeout(700);
  await page.screenshot({ path: join(OUT, `${name}.png`) });
  console.log(`docs/screenshots/${name}.png`);
}

async function done(page, times = 1) {
  for (let i = 0; i < times; i++) {
    await button(page, 'Done').click();
    await page.waitForTimeout(1500);
  }
}

// Scenes run in order; pass scene names to run only some of them, e.g.
//   node tool/screenshots/capture.mjs phone-timer editor
const scenes = [];
const scene = (name, run) => scenes.push([name, run]);

// --- Tablet: home, schedule, done animation, step timer -----------------------
scene('tablet', async () => {
  const { context, page } = await open(TABLET);
  await shot(page, 'home');

  await button(page, 'Show').click();
  await page.waitForTimeout(1500);
  await done(page, 2);
  await shot(page, 'schedule-tablet');

  // Freeze time mid-celebration to capture the "done" burst.
  const now = await page.evaluate(() => Date.now());
  await page.clock.pauseAt(now + 50);
  await button(page, 'Done').click();
  await page.clock.runFor(420);
  await page.screenshot({ path: join(OUT, 'done.png') });
  console.log('docs/screenshots/done.png');
  await page.clock.resume();
  await page.waitForTimeout(1500);

  await done(page, 2); // → Brush teeth (2 min timer)
  await page.getByRole('button', { name: /Start timer/ }).click();
  await page.clock.fastForward('00:48');
  await shot(page, 'step-timer');
  await context.close();
});

// --- Tablet: first–then board ---------------------------------------------------
scene('first-then', async () => {
  const { context, page } = await open(TABLET);
  await button(page, 'Show', 3).click();
  await page.waitForTimeout(1500);
  await shot(page, 'first-then');
  await context.close();
});

// --- Wide: drag-and-drop editor -------------------------------------------------
scene('editor', async () => {
  const { context, page } = await open(WIDE);
  await button(page, 'Edit').click();
  await page.waitForTimeout(1200);
  await shot(page, 'editor');
  await context.close();
});

// --- Tablet: share as QR code ---------------------------------------------------
scene('share-qr', async () => {
  const { context, page } = await open(TABLET);
  await button(page, 'More').click();
  await page.getByRole('menuitem', { name: 'Share' }).click();
  await page.getByRole('button', { name: /Show a QR code/ }).click();
  await shot(page, 'share-qr');
  await context.close();
});

// --- Phone: home and schedule -------------------------------------------------
scene('phone-schedule', async () => {
  const { context, page } = await open(PHONE);
  await shot(page, 'home-phone');
  await button(page, 'Show').click();
  await page.waitForTimeout(1500);
  await done(page, 1);
  await shot(page, 'schedule-phone');
  await context.close();
});

// --- Phone: quick visual timer ------------------------------------------------
scene('phone-timer', async () => {
  const { context, page } = await open(PHONE);
  await page.mouse.move(206, 500);
  await page.mouse.wheel(0, 2000);
  await page.waitForTimeout(800);
  await page.getByRole('checkbox', { name: '5 min', exact: true }).click();
  await page.waitForTimeout(800);
  await page.clock.fastForward('02:05');
  await shot(page, 'timer-phone');
  await context.close();
});

// --- Phone: editor and picture library ----------------------------------------
scene('phone-library', async () => {
  const { context, page } = await open(PHONE);
  await button(page, 'Edit').click();
  await page.waitForTimeout(800);
  await shot(page, 'editor-phone');
  await button(page, 'Add step').click();
  await page.waitForTimeout(600);
  await page.getByRole('button', { name: /Change picture/ }).click();
  await page.waitForTimeout(1200);
  await shot(page, 'library-phone');
  await context.close();
});

// --- Phone: a step with its visual timer running -------------------------------
scene('phone-step-timer', async () => {
  const { context, page } = await open(PHONE);
  await button(page, 'Show', 1).click(); // After school
  await page.waitForTimeout(1500);
  await done(page, 1); // → Play (20 min)
  await page.getByRole('button', { name: /Start timer/ }).click();
  await page.clock.fastForward('07:30');
  await shot(page, 'step-timer-phone');
  await context.close();
});

const wanted = process.argv.slice(2);
for (const [name, run] of scenes) {
  if (wanted.length === 0 || wanted.includes(name)) await run();
}

await browser.close();
server.close();
