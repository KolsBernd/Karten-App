const CACHE='hannes-huette-shell-v5-2';
const SHELL=['./index.html','./config.js','./manifest.webmanifest','./kartabend-logo.jpg'];
self.addEventListener('install',event=>event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(SHELL)).then(()=>self.skipWaiting())));
self.addEventListener('activate',event=>event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(key=>key.startsWith('hannes-huette-shell-')&&key!==CACHE).map(key=>caches.delete(key)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',event=>{
 const url=new URL(event.request.url);
 if(url.origin!==self.location.origin||event.request.method!=='GET')return;
 const isNavigation=event.request.mode==='navigate';
 const shell=SHELL.map(path=>new URL(path,self.registration.scope).pathname).includes(url.pathname);
 if(!isNavigation&&!shell)return;
 event.respondWith((async()=>{
  const cache=await caches.open(CACHE);
  const key=isNavigation?new URL('./index.html',self.registration.scope).href:url.href;
  try{const response=await fetch(event.request);if(response.ok&&!url.search)await cache.put(key,response.clone());return response}
  catch(error){const cached=await cache.match(key);if(cached)return cached;throw error}
 })());
});
