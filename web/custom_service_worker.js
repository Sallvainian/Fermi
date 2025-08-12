// Custom Service Worker for Teacher Dashboard PWA
// Handles auto-updates and version tracking

const APP_VERSION = '1.0.0'; // Increment this with each deployment
const CACHE_NAME = `teacher-dashboard-v${APP_VERSION}`;
const urlsToCache = [
  '/',
  '/index.html',
  '/manifest.json',
  '/flutter.js',
  '/main.dart.js',
  '/favicon.png',
];

// Install event - cache essential files
self.addEventListener('install', (event) => {
  console.log(`[Service Worker] Installing version ${APP_VERSION}`);
  
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE_NAME);
      console.log('[Service Worker] Caching app shell');
      await cache.addAll(urlsToCache);
      
      // Only skip waiting if this is an update (not first install)
      const keys = await caches.keys();
      const isUpdate = keys.some(key => key.startsWith('teacher-dashboard-') && key !== CACHE_NAME);
      
      if (isUpdate) {
        console.log('[Service Worker] Update detected, skipping wait');
        self.skipWaiting();
      }
    })()
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  console.log(`[Service Worker] Activating version ${APP_VERSION}`);
  
  event.waitUntil(
    (async () => {
      // Clean old caches
      const keys = await caches.keys();
      await Promise.all(
        keys
          .filter(k => k.startsWith('teacher-dashboard-') && k !== CACHE_NAME)
          .map(k => {
            console.log('[Service Worker] Deleting old cache:', k);
            return caches.delete(k);
          })
      );
      
      // Claim clients so the updated SW controls pages
      await self.clients.claim();
    })()
  );
});

// Fetch event - serve from cache, then network
self.addEventListener('fetch', (event) => {
  // Skip non-GET requests
  if (event.request.method !== 'GET') {
    return;
  }

  event.respondWith(
    caches.match(event.request)
      .then((response) => {
        // Cache hit - return response
        if (response) {
          // Also fetch from network to update cache
          fetch(event.request).then((networkResponse) => {
            if (networkResponse && networkResponse.status === 200) {
              const responseToCache = networkResponse.clone();
              caches.open(CACHE_NAME).then((cache) => {
                cache.put(event.request, responseToCache);
              });
            }
          }).catch(() => {
            // Network fetch failed, but we already returned from cache
          });
          
          return response;
        }

        // No cache match - fetch from network
        return fetch(event.request).then((response) => {
          // Check if valid response
          if (!response || response.status !== 200 || response.type !== 'basic') {
            return response;
          }

          // Clone the response
          const responseToCache = response.clone();

          // Add to cache
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, responseToCache);
          });

          return response;
        });
      })
  );
});

// Version check is handled by browser's update mechanism
// No need for manual polling in service worker