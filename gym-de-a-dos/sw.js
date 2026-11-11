// Guarda la app en el teléfono para que abra sin internet.
// Al cambiar cualquier archivo de la app, subí el número de CACHE para que los teléfonos bajen la versión nueva.
const CACHE = "gym-de-a-dos-v42";
const SHELL = ["./", "./index.html", "./config.js", "./vendor/supabase.js", "./manifest.webmanifest",
  "./icons/icon-192.png", "./icons/icon-512.png", "./icons/icon-maskable-512.png", "./icons/apple-touch-icon.png", "./icons/favicon-64.png"];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE && k !== "gym-de-a-dos-tecnica").map(k => caches.delete(k)))).then(() => self.clients.claim()));
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
    // Primero la red, así llegan las actualizaciones. Si tarda más de 2,5 s (mala señal) o no hay, abre la copia
    // guardada y la versión nueva se termina de bajar de fondo.
    e.respondWith((async () => {
      const cache = await caches.open(CACHE), cached = await cache.match("./index.html");
      let late = false;
      const net = fetch(req.url, { cache: "no-cache", credentials: "same-origin" }).then(async res => {
        if (!res || !res.ok) return cached || res;
        const was = cached && cached.headers.get("etag"), now = res.headers.get("etag");
        await cache.put("./index.html", res.clone());
        if (late && was && now && was !== now) (await self.clients.matchAll()).forEach(c => c.postMessage({ type: "nueva-version" }));
        // Una navegación no acepta respuestas que vienen de una redirección: se arma una limpia
        return res.redirected ? new Response(res.body, { status: res.status, statusText: res.statusText, headers: res.headers }) : res;
      });
      if (!cached) return net;
      const first = await Promise.race([net.catch(() => null), new Promise(ok => setTimeout(() => ok(null), 2500))]);
      if (first) return first;
      late = true; e.waitUntil(net.catch(() => {}));
      return cached;
    })());
    return;
  }
  // Animaciones de técnica (ExerciseDB): se bajan una sola vez y quedan guardadas
  if (url.host === "static.exercisedb.dev") { e.respondWith(caches.open("gym-de-a-dos-tecnica").then(c => c.match(req).then(hit => hit || fetch(req).then(res => { if (res && (res.ok || res.type === "opaque")) c.put(req, res.clone()); return res; })))); return; }
  if (url.origin === location.origin) e.respondWith(fresh(req));
});
