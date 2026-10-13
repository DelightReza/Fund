// PWA Service Worker for Fund - Group Expense Tracker
const CACHE_NAME = 'fund-pwa-v1';

// Core shell assets to precache for instant startup
const PRECACHE_ASSETS = [
  './',
  'index.html',
  'manifest.json',
  'favicon.png',
  'flutter_bootstrap.js'
];

self.addEventListener('install', (event) => {
  // Activate immediately after installing
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(PRECACHE_ASSETS).catch((err) => {
        // Precache failures for non-existent files should not fail installation
        console.warn('Some precache assets could not be cached:', err);
      });
    })
  );
});

self.addEventListener('activate', (event) => {
  // Claim all connected clients so they start using the service worker immediately
  event.waitUntil(
    Promise.all([
      self.clients.claim(),
      // Clean up previous caches if cache version changed
      caches.keys().then((cacheNames) => {
        return Promise.all(
          cacheNames.map((name) => {
            if (name !== CACHE_NAME) {
              console.log('Clearing old cache:', name);
              return caches.delete(name);
            }
          })
        );
      })
    ])
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);

  // 1. Bypass non-GET requests and external API requests (e.g. GitHub API)
  if (request.method !== 'GET' || url.hostname.includes('api.github.com')) {
    return;
  }

  // 2. Data and Config files (config.json, data.json)
  // Strategy: Network-First with Cache Fallback for fresh data
  const isDataOrConfigFile = url.pathname.endsWith('.json') && 
    (url.pathname.endsWith('config.json') || url.pathname.endsWith('data.json'));

  if (isDataOrConfigFile) {
    event.respondWith(
      fetch(request)
        .then((networkResponse) => {
          if (networkResponse && networkResponse.status === 200) {
            const responseClone = networkResponse.clone();
            caches.open(CACHE_NAME).then((cache) => {
              cache.put(request, responseClone);
            });
          }
          return networkResponse;
        })
        .catch(() => {
          // Fall back to cached copy when offline or network fails
          return caches.match(request);
        })
    );
    return;
  }

  // 3. Static App Shell Assets (HTML, JS, CSS, WASM, Fonts, Images)
  // Strategy: Stale-While-Revalidate / Cache-First for instant loads
  event.respondWith(
    caches.match(request).then((cachedResponse) => {
      // Revalidate in background to keep cache up to date with new UI changes
      const fetchPromise = fetch(request)
        .then((networkResponse) => {
          if (networkResponse && networkResponse.status === 200) {
            const responseClone = networkResponse.clone();
            caches.open(CACHE_NAME).then((cache) => {
              cache.put(request, responseClone);
            });
          }
          return networkResponse;
        })
        .catch(() => {
          // Network failure is fine if we have cached response
        });

      // Return cached asset immediately for instantaneous launch
      return cachedResponse || fetchPromise;
    })
  );
});
