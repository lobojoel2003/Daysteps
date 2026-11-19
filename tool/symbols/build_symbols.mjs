#!/usr/bin/env node
// Rebuilds the bundled pictograms from tool/symbols/selection.json:
//   assets/symbols/{mulberry,openmoji}/<id>.svg  (downloaded, then optimised with svgo)
//   assets/symbols/catalog.json
//   assets/symbols/ATTRIBUTION.md
//
// Usage: node tool/symbols/build_symbols.mjs [--check] [--cache=DIR]
//   --check      also compile every SVG with Flutter's vector_graphics_compiler
//                (the parser flutter_svg uses) and fail on any warning.
//   --cache=DIR  download cache (default: $SYMBOLS_CACHE or <os tmp>/daysteps-symbols-cache).
//
// Needs Node 18+ and network access to raw.githubusercontent.com and registry.npmjs.org.
// svgo is installed into the cache directory (never into the repo) on first run.
// Downloaded files are treated as data only: nothing from them is executed.

import { createHash } from 'node:crypto';
import { execFileSync, spawnSync } from 'node:child_process';
import {
  existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { gunzipSync } from 'node:zlib';

const TOOL_DIR = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(TOOL_DIR, '..', '..');
const OUT_DIR = join(ROOT, 'assets', 'symbols');
const SVGO_VERSION = '4.1.0';
const IS_WINDOWS = process.platform === 'win32';

const args = process.argv.slice(2);
const option = (name) => args.find((a) => a.startsWith(`--${name}=`))?.slice(name.length + 3);
if (args.includes('--help') || args.includes('-h')) {
  console.log('Usage: node tool/symbols/build_symbols.mjs [--check] [--cache=DIR]');
  process.exit(0);
}
const CHECK = args.includes('--check');
const CACHE_DIR = resolve(option('cache') ?? process.env.SYMBOLS_CACHE ?? join(tmpdir(), 'daysteps-symbols-cache'));

// svgo config: inline <style> CSS into presentation attributes (flutter_svg ignores <style>),
// keep the viewBox (svgo 4 no longer removes it by default), drop width/height when a viewBox
// exists, and strip metadata, comments, titles and editor data.
const SVGO_CONFIG = {
  multipass: true,
  plugins: [
    { name: 'inlineStyles', params: { onlyMatchedOnce: false } },
    'convertStyleToAttrs',
    'preset-default',
    'removeTitle',
    'removeDimensions',
  ],
};

// Things flutter_svg / vector_graphics cannot render (or that would make the asset depend on
// something outside the file). Any match after optimisation fails the build.
const FORBIDDEN = [
  [/<style[\s>/]/i, '<style> element'],
  [/<text[\s>/]|<tspan[\s>/]/i, '<text> element'],
  [/<image[\s>/]/i, '<image> element'],
  [/<script[\s>/]|<foreignObject[\s>/]/i, 'script/foreignObject'],
  [/<filter[\s>/]|\sfilter="/i, 'filter'],
  [/\sstyle="/i, 'style attribute'],
  [/\s(?:xlink:)?href="(?!#)/i, 'external reference'],
  [/url\(\s*['"]?(?!#)/i, 'external url()'],
  [/@import|<!DOCTYPE|<!ENTITY/i, 'import/DTD'],
];

const ID_RE = /^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$/;
const KEYWORD_RE = /^[a-z0-9][a-z0-9' -]*$/;

function fail(message) {
  console.error(`\nERROR: ${message}`);
  process.exit(1);
}

// ---------------------------------------------------------------------------------------------
// Selection

function loadSelection() {
  const selection = JSON.parse(readFileSync(join(TOOL_DIR, 'selection.json'), 'utf8'));
  const { sets, sources, categories, symbols } = selection;
  const categoryIndex = new Map(categories.map((c, i) => [c.id, i]));
  const errors = [];
  const seen = new Set();
  for (const s of symbols) {
    const where = `${s.set}/${s.id}`;
    if (!sets[s.set] || !sources[s.set]) errors.push(`${where}: unknown set`);
    if (!ID_RE.test(s.id)) errors.push(`${where}: id must be lower_snake_case ASCII`);
    if (seen.has(where)) errors.push(`${where}: duplicate id`);
    seen.add(where);
    if (!categoryIndex.has(s.category)) errors.push(`${where}: unknown category ${s.category}`);
    if (!s.label || s.label[0] !== s.label[0].toUpperCase()) errors.push(`${where}: label must be sentence case`);
    if (!s.source) errors.push(`${where}: missing source`);
    const kw = s.keywords ?? [];
    if (kw.length < 2 || kw.length > 6) errors.push(`${where}: needs 2-6 keywords`);
    if (kw.some((k) => !KEYWORD_RE.test(k))) errors.push(`${where}: keywords must be lowercase`);
    if (new Set(kw).size !== kw.length) errors.push(`${where}: duplicate keywords`);
  }
  for (const c of categories) {
    const cover = symbols.find((s) => `${s.set}/${s.id}` === c.cover);
    if (!cover || cover.category !== c.id) errors.push(`category ${c.id}: cover ${c.cover} is not in that category`);
  }
  if (errors.length) fail(`selection.json is invalid:\n  ${errors.join('\n  ')}`);
  // Order by category (as listed), keeping the curated order inside each category.
  const ordered = symbols
    .map((s, i) => ({ s, i }))
    .sort((a, b) => categoryIndex.get(a.s.category) - categoryIndex.get(b.s.category) || a.i - b.i)
    .map(({ s }) => s);
  return { ...selection, symbols: ordered };
}

// ---------------------------------------------------------------------------------------------
// Downloads (cached)

async function fetchBuffer(url) {
  for (let attempt = 1; ; attempt++) {
    let res;
    try {
      res = await fetch(url, { redirect: 'follow' });
    } catch (err) {
      if (attempt >= 4) throw new Error(`GET ${url} failed: ${err.cause?.code ?? err.message}`);
      await new Promise((r) => setTimeout(r, 1000 * attempt));
      continue;
    }
    if (res.ok) return Buffer.from(await res.arrayBuffer());
    if (res.status < 500 || attempt >= 4) throw new Error(`GET ${url} failed: HTTP ${res.status}`);
    await new Promise((r) => setTimeout(r, 1000 * attempt));
  }
}

async function cachedDownload(file, url) {
  if (existsSync(file)) return readFileSync(file);
  const buf = await fetchBuffer(url);
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, buf);
  return buf;
}

async function mapLimit(items, limit, fn) {
  const results = new Array(items.length);
  let next = 0;
  const worker = async () => {
    while (next < items.length) {
      const i = next++;
      results[i] = await fn(items[i], i);
    }
  };
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return results;
}

async function fetchMulberry(symbols, source) {
  const dir = join(CACHE_DIR, `mulberry-${source.ref}`);
  const out = new Map();
  await mapLimit(symbols, 8, async (s) => {
    const name = encodeURIComponent(s.source);
    const url = source.svgUrl.replace('{ref}', source.ref).replace('{source}', name);
    out.set(s, (await cachedDownload(join(dir, `${name}.svg`), url)).toString('utf8'));
  });
  return out;
}

// Minimal tar reader (ustar + GNU long names + pax path records): enough for npm tarballs.
function* readTar(buf) {
  let offset = 0;
  let longName = null;
  while (offset + 512 <= buf.length) {
    const header = buf.subarray(offset, offset + 512);
    if (header.every((b) => b === 0)) return;
    const field = (start, len) => header.subarray(start, start + len).toString('utf8').replace(/\0[\s\S]*$/, '');
    const size = parseInt(field(124, 12).trim() || '0', 8);
    const type = header[156] === 0 ? '0' : String.fromCharCode(header[156]);
    const prefix = header.toString('latin1', 257, 263) === 'ustar\0' ? field(345, 155) : '';
    const name = prefix ? `${prefix}/${field(0, 100)}` : field(0, 100);
    const data = buf.subarray(offset + 512, offset + 512 + size);
    offset += 512 + Math.ceil(size / 512) * 512;
    if (type === 'L') {
      longName = data.toString('utf8').replace(/\0[\s\S]*$/, '');
    } else if (type === 'x') {
      longName = /(?:^|\n)\d+ path=([^\n]*)\n/.exec(data.toString('utf8'))?.[1] ?? longName;
    } else if (type === '0' || type === '7') {
      yield { path: longName ?? name, data };
      longName = null;
    } else {
      longName = null;
    }
  }
}

async function fetchOpenMoji(symbols, source) {
  const file = join(CACHE_DIR, `openmoji-${source.version}.tgz`);
  const tgz = await cachedDownload(file, source.tarball);
  const integrity = `sha512-${createHash('sha512').update(tgz).digest('base64')}`;
  if (integrity !== source.integrity) {
    rmSync(file, { force: true });
    fail(`OpenMoji tarball integrity mismatch (got ${integrity}); deleted the cached copy`);
  }
  const wanted = new Map(symbols.map((s) => [source.svgPath.replace('{source}', s.source), s]));
  const out = new Map();
  for (const entry of readTar(gunzipSync(tgz))) {
    const s = wanted.get(entry.path);
    if (s) out.set(s, entry.data.toString('utf8'));
  }
  const missing = symbols.filter((s) => !out.has(s)).map((s) => s.source);
  if (missing.length) fail(`OpenMoji ${source.version} has no colour SVG for: ${missing.join(', ')}`);
  return out;
}

// ---------------------------------------------------------------------------------------------
// svgo

async function loadSvgo() {
  const dir = join(CACHE_DIR, `svgo-${SVGO_VERSION}`);
  const pkg = join(dir, 'node_modules', 'svgo', 'package.json');
  const installed = existsSync(pkg) && JSON.parse(readFileSync(pkg, 'utf8')).version === SVGO_VERSION;
  if (!installed) {
    console.log(`Installing svgo@${SVGO_VERSION} into ${dir}`);
    mkdirSync(dir, { recursive: true });
    execFileSync('npm', ['install', '--prefix', dir, '--no-audit', '--no-fund', '--ignore-scripts', `svgo@${SVGO_VERSION}`], {
      stdio: 'inherit',
      shell: IS_WINDOWS,
    });
  }
  return import(pathToFileURL(join(dir, 'node_modules', 'svgo', 'lib', 'svgo-node.js')).href);
}

function optimizeSymbol(svgo, symbol, raw) {
  const where = `${symbol.set}/${symbol.id} (${symbol.source})`;
  const rawRoot = /<svg\b[^>]*>/i.exec(raw)?.[0];
  if (!rawRoot || !/\sviewBox=/.test(rawRoot)) fail(`${where}: source SVG has no viewBox`);
  const svg = svgo.optimize(raw, SVGO_CONFIG).data;
  const problems = FORBIDDEN.filter(([re]) => re.test(svg)).map(([, what]) => what);
  const root = /^<svg\b[^>]*>/.exec(svg)?.[0];
  if (!root) problems.push('output does not start with <svg>');
  else if (!/\sviewBox="/.test(root)) problems.push('viewBox was lost');
  else if (/\s(?:width|height)="/.test(root)) problems.push('width/height left on <svg>');
  if (problems.length) fail(`${where}: unsupported SVG content after optimisation: ${problems.join(', ')}`);
  return svg;
}

// ---------------------------------------------------------------------------------------------
// Outputs

function attributionMarkdown({ sets, sources }) {
  const m = sets.mulberry;
  const o = sets.openmoji;
  return `# Pictogram attribution

The pictograms in this folder come from two open symbol sets. They are used under, and these
copies are shared under, the Creative Commons Attribution-ShareAlike licences named below.

## ${m.name} (\`mulberry/\`)

- ${m.name} by ${m.author} — ${m.url}
- Licence: ${m.license} — ${m.licenseUrl}
- Source: https://github.com/${sources.mulberry.repo} (release ${sources.mulberry.ref}, folder \`EN/\`)

"Mulberry Symbols by Steve Lee are licenced under the Creative Commons Attribution-ShareAlike
4.0 License. See https://mulberrysymbols.org for details."

## ${o.name} (\`openmoji/\`)

- ${o.name} by ${o.author} — ${o.url}
- Licence: ${o.license} — ${o.licenseUrl}
- Source: npm package \`${sources.openmoji.package}@${sources.openmoji.version}\` (\`color/svg/\`)

"All emojis designed by OpenMoji – the open-source emoji and icon project.
License: CC BY-SA 4.0"

## Changes made

These files are modified versions of the originals: they were optimised and converted with
svgo (CSS styles inlined into presentation attributes, metadata, comments, titles and editor
data removed, width/height removed in favour of the viewBox, path data simplified) and renamed
to readable file names. The original Mulberry symbol name or OpenMoji hexcode of every file is
recorded in the \`source\` field of \`catalog.json\`. The modified files are shared under the
same licence as their originals (CC BY-SA 4.0).

Generated by \`tool/symbols/build_symbols.mjs\`.
`;
}

function writeSetDir(set, files) {
  const dir = join(OUT_DIR, set);
  mkdirSync(dir, { recursive: true });
  for (const name of readdirSync(dir)) {
    if (name.endsWith('.svg') && !files.has(name)) rmSync(join(dir, name));
  }
  for (const [name, svg] of files) writeFileSync(join(dir, name), svg);
}

function dirSize(dir) {
  return readdirSync(dir, { withFileTypes: true }).reduce(
    (sum, e) => sum + (e.isDirectory() ? dirSize(join(dir, e.name)) : statSync(join(dir, e.name)).size),
    0,
  );
}

function checkWithFlutter(setNames) {
  // Same parser as flutter_svg. --enable-asserts makes it report unhandled elements.
  const tmp = mkdtempSync(join(tmpdir(), 'daysteps-vgc-'));
  try {
    for (const set of setNames) {
      mkdirSync(join(tmp, set));
      const res = spawnSync('dart', [
        'run', '--enable-asserts', 'vector_graphics_compiler',
        '--input-dir', join(OUT_DIR, set), '--out-dir', join(tmp, set),
      ], { cwd: ROOT, encoding: 'utf8', shell: IS_WINDOWS });
      if (res.error) fail(`could not run dart (is the Flutter SDK on PATH?): ${res.error.message}`);
      const output = `${res.stdout}\n${res.stderr}`;
      const warnings = output.split('\n').filter((l) => /unhandled|warning|unsupported|error|failed|XXXX/i.test(l));
      const compiled = readdirSync(join(tmp, set)).length;
      const expected = readdirSync(join(OUT_DIR, set)).filter((n) => n.endsWith('.svg')).length;
      if (res.status !== 0 || warnings.length || compiled !== expected) {
        fail(`vector_graphics_compiler problems in ${set} (exit ${res.status}, ${compiled}/${expected} compiled):\n${warnings.join('\n') || output}`);
      }
      console.log(`vector_graphics_compiler: ${compiled}/${expected} ${set} SVGs compiled without warnings`);
    }
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}

// ---------------------------------------------------------------------------------------------

async function main() {
  const selection = loadSelection();
  const { symbols, sources, sets, categories } = selection;
  console.log(`${symbols.length} symbols selected; cache: ${CACHE_DIR}`);

  const svgo = await loadSvgo();
  const raw = new Map();
  const bySet = (set) => symbols.filter((s) => s.set === set);
  for (const [s, svg] of await fetchMulberry(bySet('mulberry'), sources.mulberry)) raw.set(s, svg);
  for (const [s, svg] of await fetchOpenMoji(bySet('openmoji'), sources.openmoji)) raw.set(s, svg);

  const files = new Map(Object.keys(sets).map((set) => [set, new Map()]));
  for (const s of symbols) files.get(s.set).set(`${s.id}.svg`, optimizeSymbol(svgo, s, raw.get(s)));
  for (const [set, setFiles] of files) writeSetDir(set, setFiles);

  const catalog = {
    version: 1,
    sets,
    categories,
    symbols: symbols.map((s) => ({
      id: `${s.set}/${s.id}`,
      set: s.set,
      asset: `assets/symbols/${s.set}/${s.id}.svg`,
      label: s.label,
      category: s.category,
      keywords: s.keywords,
      source: s.source,
    })),
  };
  writeFileSync(join(OUT_DIR, 'catalog.json'), `${JSON.stringify(catalog, null, 2)}\n`);
  writeFileSync(join(OUT_DIR, 'ATTRIBUTION.md'), attributionMarkdown(selection));

  for (const c of categories) {
    const n = symbols.filter((s) => s.category === c.id).length;
    console.log(`  ${c.id.padEnd(9)} ${String(n).padStart(3)}  ${c.label}`);
  }
  for (const set of files.keys()) console.log(`  ${set}: ${files.get(set).size} files`);
  console.log(`Wrote ${symbols.length} symbols; assets/symbols is ${(dirSize(OUT_DIR) / 1024).toFixed(0)} KiB`);

  if (CHECK) checkWithFlutter([...files.keys()]);
}

main().catch((err) => fail(err.stack ?? String(err)));
