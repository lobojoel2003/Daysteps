// Daysteps offline service worker.
//
// After the first visit the whole app works without a network connection:
// - on install it caches the app shell and every content-hashed file listed
//   in precache_manifest.json (code, pictograms, fonts);
// - the page then reports which other files it actually loaded (e.g. the
//   CanvasKit variant this browser uses) so those are cached too;
// - pages and bootstrap files are fetched network-first so new releases are
//   picked up; everything else is served cache-first.
//
// BUILD_ID is replaced by tool/web/finalize_build.py after `flutter build web`,
// so each release installs a fresh cache and removes the old one.
const BUILD_ID = 'cb0cab7d7eba';
const CACHE = `daysteps-${BUILD_ID}`;

const SHELL = [
  './',
  'index.html',
  'flutter_bootstrap.js',
  'flutter.js',
  'manifest.json',
  'favicon.png',
  'drift_worker.js',
  'sqlite3.wasm',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
  'icons/apple-touch-icon.png',
];

const NETWORK_FIRST = new Set(['', 'index.html', 'flutter_bootstrap.js', 'manifest.json', 'version.json', 'precache_manifest.json']);

const scopeUrl = new URL(self.registration.scope);

function relativePath(url) {
  const u = new URL(url);
  if (u.origin !== scopeUrl.origin || !u.pathname.startsWith(scopeUrl.pathname)) return null;
  return u.pathname.slice(scopeUrl.pathname.length);
}

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    let hashed = [];
    try {
      const res = await fetch('precache_manifest.json', { cache: 'no-cache' });
      const manifest = await res.json();
      hashed = manifest.entries.filter((e) => e.urlHashed).map((e) => e.url);
    } catch (e) {
      console.warn('Daysteps: no precache manifest', e);
    }
    await cache.addAll(SHELL.map((u) => new Request(u, { cache: 'reload' })));
    // Add hashed files one by one so a single failure doesn't abort install.
    await Promise.all(hashed.map((u) => cache.add(u).catch(() => {})));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(
      keys.filter((k) => k.startsWith('daysteps-') && k !== CACHE).map((k) => caches.delete(k)),
    );
    await self.clients.claim();
  })());
});

// The page sends the list of files it loaded before this worker took over.
self.addEventListener('message', (event) => {
  const data = event.data || {};
  if (data.type !== 'cache-urls' || !Array.isArray(data.urls)) return;
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    for (const url of data.urls) {
      if (relativePath(url) === null) continue;
      if (await cache.match(url, { ignoreSearch: true })) continue;
      try { await cache.add(url); } catch (_) { /* best effort */ }
    }
  })());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const path = relativePath(request.url);
  if (path === null) return; // other origins (e.g. optional ARASAAC) go to the network

  if (request.mode === 'navigate' || NETWORK_FIRST.has(path)) {
    event.respondWith(networkFirst(request, request.mode === 'navigate'));
  } else {
    event.respondWith(cacheFirst(request));
  }
});

async function networkFirst(request, isNavigation) {
  const cache = await caches.open(CACHE);
  try {
    const response = await fetch(request, { cache: 'no-cache' });
    if (response.ok) cache.put(isNavigation ? 'index.html' : request, response.clone());
    return response;
  } catch (e) {
    const cached = await cache.match(isNavigation ? 'index.html' : request, { ignoreSearch: true });
    if (cached) return cached;
    throw e;
  }
}

async function cacheFirst(request) {
  const cache = await caches.open(CACHE);
  const cached = await cache.match(request, { ignoreSearch: true });
  if (cached) return cached;
  const response = await fetch(request);
  if (response.ok && response.type === 'basic') cache.put(request, response.clone());
  return response;
}
