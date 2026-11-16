const CACHE='hannes-huette-shell-v14';
const SHELL=['./index.html','./config.js','./manifest.webmanifest','./kartabend-logo.svg','./favicon.png','./datenschutz.html','./datenschutz.pdf','./impressum.html','./icon-192.png','./icon-512.png','./apple-touch-icon.png','./supabase-2.49.8.min.js'];
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

self.addEventListener('push',event=>{let data={};try{data=event.data?.json()||{}}catch{}const title=typeof data.title==='string'?data.title.slice(0,80):'Kartabend-App';const body=typeof data.body==='string'?data.body.slice(0,220):'Du hast eine neue Mitteilung.';event.waitUntil(self.registration.showNotification(title,{body,icon:new URL('icon-192.png',self.registration.scope).href,badge:new URL('icon-192.png',self.registration.scope).href,tag:'kartabend-'+String(data.id||'mitteilung').slice(0,64),renotify:false,data:{url:new URL('index.html#hh_view=notifications',self.registration.scope).href}}));});
self.addEventListener('notificationclick',event=>{event.notification.close();const url=new URL('index.html#hh_view=notifications',self.registration.scope).href;event.waitUntil((async()=>{const windows=await self.clients.matchAll({type:'window',includeUncontrolled:true});const client=windows.find(c=>new URL(c.url).origin===self.location.origin&&new URL(c.url).pathname.startsWith(new URL(self.registration.scope).pathname));if(client){await client.focus();client.postMessage({type:'hh_show_notifications'});return}await self.clients.openWindow(url)})());});
