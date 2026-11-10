// AvA offline service worker.
//
//  - App files (same origin): network first, so a new deployment shows
//    up on the next load; the cached copy is used when offline or when
//    the network is slower than NETWORK_TIMEOUT_MS (weak ward Wi-Fi).
//  - Flutter engine / fonts from Google's CDN: cache first (their URLs
//    contain a version hash, so they never change).
//
// Bump CACHE_VERSION to drop everything cached by an older version.
const CACHE_VERSION = 'v3';
const CACHE = 'ava-offline-' + CACHE_VERSION;
const NETWORK_TIMEOUT_MS = 4000;
const CDN_HOSTS = ['www.gstatic.com', 'fonts.gstatic.com', 'fonts.googleapis.com'];

// The app shell, cached on install.
const PRECACHE = [
  './',
  'index.html',
  'flutter_bootstrap.js',
  'manifest.json',
  'favicon.png',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) =>
      // One missing file must not stop the whole install.
      Promise.all(PRECACHE.map((url) => cache.add(url).catch(() => {}))),
    ),
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      // Remove older AvA caches and Flutter's old service-worker caches.
      for (const key of await caches.keys()) {
        if (key !== CACHE) await caches.delete(key);
      }
      await self.clients.claim();
    })(),
  );
});

// The page sends the files it loaded before this worker took over.
self.addEventListener('message', (event) => {
  const data = event.data || {};
  if (data.type !== 'cache-urls' || !Array.isArray(data.urls)) return;
  event.waitUntil(
    caches.open(CACHE).then((cache) =>
      Promise.all(
        data.urls
          .filter(isCacheable)
          .map((url) =>
            cache.match(url).then((hit) => hit || cache.add(url).catch(() => {})),
          ),
      ),
    ),
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET' || !isCacheable(request.url)) return;
  const url = new URL(request.url);

  if (url.origin === self.location.origin) {
    event.respondWith(networkFirst(request));
  } else if (CDN_HOSTS.includes(url.hostname)) {
    event.respondWith(cacheFirst(request));
  }
});

function isCacheable(url) {
  try {
    const u = new URL(url, self.location.href);
    if (u.protocol !== 'https:' && u.protocol !== 'http:') return false;
    if (u.pathname.endsWith('ava_sw.js')) return false;
    // Never cache the API (account data, sessions), even if it is
    // served from the same domain as the app.
    if (u.pathname.startsWith('/v1/') || u.pathname.includes('/v1/')) return false;
    return u.origin === self.location.origin || CDN_HOSTS.includes(u.hostname);
  } catch (_) {
    return false;
  }
}

// Ask the server every time (a cheap 304 when nothing changed). Without
// this the browser may answer from its own HTTP cache: files like
// assets/fonts/MaterialIcons-Regular.otf keep the same name in every
// build, so an old copy (missing newly used icons) could be reused for
// a long time when the server sends no Cache-Control header.
function fetchFresh(request) {
  if (request.mode === 'navigate') {
    // A navigate Request can't be re-issued with options; use its URL.
    return fetch(request.url, { cache: 'no-cache', credentials: 'same-origin' });
  }
  return fetch(request, { cache: 'no-cache' });
}

async function networkFirst(request) {
  const cache = await caches.open(CACHE);
  const network = fetchFresh(request).then((response) => {
    if (response.ok) cache.put(request, response.clone());
    return response;
  });
  network.catch(() => {}); // handled below; avoid "unhandled rejection"

  const timeout = new Promise((resolve) =>
    setTimeout(resolve, NETWORK_TIMEOUT_MS, null),
  );
  try {
    const response = await Promise.race([network, timeout]);
    if (response) return response;
    // Slow network: answer from the cache, keep the download going.
    const cached = await cachedFor(cache, request);
    return cached || (await network);
  } catch (_) {
    // Offline.
    const cached = await cachedFor(cache, request);
    if (cached) return cached;
    throw _;
  }
}

async function cacheFirst(request) {
  const cache = await caches.open(CACHE);
  const cached = await cache.match(request);
  if (cached) return cached;
  const response = await fetch(request);
  if (response.ok || response.type === 'opaque') {
    cache.put(request, response.clone());
  }
  return response;
}

// Pages (any route) fall back to the cached app shell.
async function cachedFor(cache, request) {
  const hit = await cache.match(request, { ignoreSearch: true });
  if (hit) return hit;
  if (request.mode === 'navigate') {
    return (await cache.match('./')) || (await cache.match('index.html'));
  }
  return undefined;
}
