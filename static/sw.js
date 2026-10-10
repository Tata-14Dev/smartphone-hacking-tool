/* WATCHDOG service worker.
   Objetivo: que la app abra al instante y OFFLINE (modo avion), cacheando el
   "shell" (HTML + fuentes + iconos). NUNCA toca las llamadas al backend:
   - POST (scan/ataques) se ignoran por completo.
   - /api/ y /stream (SSE) van siempre a la red, jamas se cachean (datos frescos).
*/
const CACHE = 'watchdog-v2';   // subir la version cuando cambian assets (iconos/fuentes) para invalidar cache
const SHELL = [
  '/',
  '/static/manifest.json',
  '/static/fonts/chakra-petch-latin-400-normal.woff2',
  '/static/fonts/chakra-petch-latin-500-normal.woff2',
  '/static/fonts/chakra-petch-latin-600-normal.woff2',
  '/static/fonts/chakra-petch-latin-700-normal.woff2',
  '/static/fonts/share-tech-mono-latin-400-normal.woff2',
  '/static/icons/icon-192.png',
  '/static/icons/icon-512.png',
  '/static/icons/icon-180.png'
];

self.addEventListener('install', (e) => {
  self.skipWaiting();
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)).catch(() => {}));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;                       // ataques/scan son POST: no tocar
  const url = new URL(req.url);
  if (url.origin !== location.origin) return;             // solo same-origin
  if (url.pathname.startsWith('/api/') || url.pathname.startsWith('/stream')) return; // backend: red directa

  // HTML (navegacion): network-first para ver cambios, con fallback offline al shell cacheado.
  if (req.mode === 'navigate') {
    e.respondWith(
      fetch(req)
        .then((r) => { const cp = r.clone(); caches.open(CACHE).then((c) => c.put('/', cp)); return r; })
        .catch(() => caches.match('/'))
    );
    return;
  }

  // Assets estaticos (/static/...): cache-first, y si no esta, red + guardar.
  if (url.pathname.startsWith('/static/')) {
    e.respondWith(
      caches.match(req).then((hit) => hit || fetch(req).then((r) => {
        const cp = r.clone(); caches.open(CACHE).then((c) => c.put(req, cp)); return r;
      }))
    );
  }
});
