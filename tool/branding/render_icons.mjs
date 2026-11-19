// Renders the SVG logo into every PNG the app needs (launcher icons, web
// icons, favicon). Run from the repository root:
//   node tool/branding/render_icons.mjs && dart run flutter_launcher_icons
import { createRequire } from 'node:module';

// Playwright may be installed globally (NODE_PATH); resolve it like require().
const { chromium } = createRequire(import.meta.url)('playwright');
import { readFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

const jobs = [
  ['assets/branding/logo.svg', 'assets/branding/icon-1024.png', 1024],
  ['tool/branding/icon-foreground.svg', 'assets/branding/icon-foreground-1024.png', 1024],
  ['tool/branding/icon-monochrome.svg', 'assets/branding/icon-monochrome-1024.png', 1024],
  ['assets/branding/logo.svg', 'web/icons/Icon-192.png', 192],
  ['assets/branding/logo.svg', 'web/icons/Icon-512.png', 512],
  ['tool/branding/icon-maskable.svg', 'web/icons/Icon-maskable-192.png', 192],
  ['tool/branding/icon-maskable.svg', 'web/icons/Icon-maskable-512.png', 512],
  ['assets/branding/logo.svg', 'web/favicon.png', 64],
  ['assets/branding/logo.svg', 'web/icons/apple-touch-icon.png', 180],
];

const browser = await chromium.launch();
const page = await browser.newPage();
for (const [src, out, size] of jobs) {
  const svg = readFileSync(src, 'utf8');
  await page.setViewportSize({ width: size, height: size });
  await page.setContent(
    `<html><body style="margin:0;background:transparent">` +
      `<img src="data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}" ` +
      `width="${size}" height="${size}" style="display:block"></body></html>`,
  );
  mkdirSync(dirname(out), { recursive: true });
  await page.screenshot({ path: out, omitBackground: true, clip: { x: 0, y: 0, width: size, height: size } });
  console.log(`${out} (${size}px)`);
}
await browser.close();
