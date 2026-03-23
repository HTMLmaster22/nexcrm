const CACHE_NAME = 'nexcrm-v1';
const STATIC_ASSETS = [
  '/nexcrm/',
  '/nexcrm/index.html',
  'https://fonts.googleapis.com/css2?family=Syne:wght@400;600;700;800&family=DM+Sans:wght@300;400;500&display=swap'
];

// Install - cache static assets
self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE_NAME).then(cache => {
      return cache.addAll(STATIC_ASSETS).catch(() => {});
    })
  );
  self.skipWaiting();
});

// Activate - clean old caches
self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

// Fetch - network first, fallback to cache
self.addEventListener('fetch', (e) => {
  // Skip Supabase API calls - always go to network
  if(e.request.url.includes('supabase.co')) return;

  e.respondWith(
    fetch(e.request)
      .then(res => {
        // Cache successful GET requests
        if(e.request.method === 'GET' && res.status === 200) {
          const clone = res.clone();
          caches.open(CACHE_NAME).then(cache => cache.put(e.request, clone));
        }
        return res;
      })
      .catch(() => caches.match(e.request))
  );
});

// Push notifications
self.addEventListener('push', (e) => {
  const data = e.data ? e.data.json() : { title: 'NexCRM', body: 'New notification' };
  e.waitUntil(
    self.registration.showNotification(data.title || 'NexCRM', {
      body: data.body || 'You have a new lead!',
      icon: '/nexcrm/icon-192.png',
      badge: '/nexcrm/icon-192.png',
      vibrate: [200, 100, 200],
      data: { url: '/nexcrm/' }
    })
  );
});

self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  e.waitUntil(clients.openWindow(e.notification.data.url || '/nexcrm/'));
});
