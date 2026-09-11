// Service worker minimo e proprio (nao gerado pelo Flutter) -- o SW que o
// Flutter 3.41+ gera (flutter_service_worker.js) e apenas um stub que se
// autodesregistra (ver comentario "Flutter's service worker is deprecated").
// Sem um SW ativo com handler de 'fetch', o Chrome nao considera o site
// instalavel como PWA (falha o criterio de installability), entao o botao
// "Instalar app" nunca aparece no mobile. Este arquivo supre isso.
//
// Estrategia: cache-first pro shell (poucos arquivos estaveis), network-first
// pra tudo mais (o app troca de versao com frequencia; nao queremos travar
// o usuario numa build antiga por causa de cache agressivo).

const CACHE_NAME = 'soutracking-shell-v1';
const SHELL_ASSETS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/favicon.png',
];

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(SHELL_ASSETS)).catch(() => {}),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const names = await caches.keys();
      await Promise.all(
        names.filter((n) => n !== CACHE_NAME).map((n) => caches.delete(n)),
      );
      await self.clients.claim();
    })(),
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  // Nunca interceptar chamadas de API/backend (Traccar, Google Maps, etc.)
  // -- so cachear o mesmo-origin (o app estatico).
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;

  event.respondWith(
    fetch(req)
      .then((res) => {
        if (res && res.ok) {
          const copy = res.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(req, copy)).catch(() => {});
        }
        return res;
      })
      .catch(() => caches.match(req).then((cached) => cached || caches.match('/index.html'))),
  );
});
