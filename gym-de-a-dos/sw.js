// Guarda la app en el teléfono para que abra sin internet.
// Al cambiar cualquier archivo de la app, subí el número de CACHE para que los teléfonos bajen la versión nueva.
const CACHE = "gym-de-a-dos-v30";
const SHELL = ["./", "./index.html", "./config.js", "./vendor/supabase.js", "./manifest.webmanifest",
  "./icons/icon-192.png", "./icons/icon-512.png", "./icons/apple-touch-icon.png"];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
function fresh(req) {
  return caches.open(CACHE).then(c => c.match(req).then(hit => {
    const net = fetch(req).then(res => { if (res && (res.ok || res.type === "opaque")) c.put(req, res.clone()); return res; }).catch(() => hit);
    return hit || net;
  }));
}
self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  if (req.mode === "navigate" && url.origin === location.origin) {
    // Primero la red, así llegan las actualizaciones; sin señal, la copia guardada.
    e.respondWith(fetch(req).then(res => { const copy = res.clone(); caches.open(CACHE).then(c => c.put("./index.html", copy)); return res; })
      .catch(() => caches.match("./index.html")));
    return;
  }
  if (url.origin === location.origin || url.host === "fonts.googleapis.com" || url.host === "fonts.gstatic.com") e.respondWith(fresh(req));
});
