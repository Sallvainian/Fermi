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
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('[Service Worker] Caching app shell');
        return cache.addAll(urlsToCache);
      })
      .then(() => {
        // Skip waiting to activate immediately
        self.skipWaiting();
      })
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  console.log(`[Service Worker] Activating version ${APP_VERSION}`);
  
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME && cacheName.startsWith('teacher-dashboard-')) {
            console.log('[Service Worker] Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    }).then(() => {
      // Take control of all clients immediately
      return self.clients.claim();
    }).then(() => {
      // Notify all clients about the update
      return self.clients.matchAll().then(clients => {
        clients.forEach(client => {
          client.postMessage({
            type: 'SERVICE_WORKER_UPDATED',
            version: APP_VERSION
          });
        });
      });
    })
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

// Check for updates every 5 minutes
setInterval(() => {
  console.log('[Service Worker] Checking for updates...');
  
  // Check if there's a new version available
  fetch('/version.json?t=' + Date.now())
    .then(response => response.json())
    .then(data => {
      if (data.version && data.version !== APP_VERSION) {
        console.log(`[Service Worker] New version available: ${data.version}`);
        
        // Notify clients about available update
        self.clients.matchAll().then(clients => {
          clients.forEach(client => {
            client.postMessage({
              type: 'UPDATE_AVAILABLE',
              currentVersion: APP_VERSION,
              newVersion: data.version
            });
          });
        });
      }
    })
    .catch(err => {
      console.log('[Service Worker] Update check failed:', err);
    });
}, 5 * 60 * 1000); // 5 minutes