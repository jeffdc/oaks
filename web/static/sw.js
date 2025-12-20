// Kill switch service worker - unregisters itself and clears caches
// Users will get fresh content on their next natural page load/refresh

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', async () => {
  // Clear all caches
  const cacheNames = await caches.keys();
  await Promise.all(
    cacheNames.map(cacheName => caches.delete(cacheName))
  );

  // Unregister this service worker
  self.registration.unregister();
});
