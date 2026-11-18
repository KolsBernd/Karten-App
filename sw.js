importScripts('app-badge.js');
const CACHE='hannes-huette-shell-v24';
const SHELL=['./round-details.js','./ui23.js','./ui23.css','./locations.js','./table-names.js','./qrcode-generator-1.4.4.js','./spielstand.html','./spielstand.js','./spielstand.css','./chat-gestures.js','./tournament-play.js','./chat-crypto.js','./evenings.js','./evenings.css','./tournament.js','./tournament.css','./app-badge.js','./index.html','./config.js','./manifest.webmanifest','./kartabend-logo.svg','./favicon.png','./datenschutz.html','./datenschutz.pdf','./impressum.html','./icon-192.png','./icon-512.png','./apple-touch-icon.png','./supabase-2.50.0.min.js'];
self.addEventListener('install',event=>event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(SHELL)).then(()=>self.skipWaiting())));
self.addEventListener('activate',event=>event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(key=>key.startsWith('hannes-huette-shell-')&&key!==CACHE).map(key=>caches.delete(key)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',event=>{
 const url=new URL(event.request.url);
 if(url.origin!==self.location.origin||event.request.method!=='GET')return;
 const isNavigation=event.request.mode==='navigate';
 const isAppNavigation=isNavigation&&[new URL('./',self.registration.scope).pathname,new URL('./index.html',self.registration.scope).pathname].includes(url.pathname);
 const shell=SHELL.map(path=>new URL(path,self.registration.scope).pathname).includes(url.pathname);
 if(!isAppNavigation&&!shell)return;
 event.respondWith((async()=>{
  const cache=await caches.open(CACHE);
  const key=isAppNavigation?new URL('./index.html',self.registration.scope).href:url.href;
  try{const response=await fetch(event.request);if(response.ok&&!url.search)await cache.put(key,response.clone());return response}
  catch(error){const cached=await cache.match(key);if(cached)return cached;throw error}
 })());
});

self.addEventListener('push',event=>{let data={};try{data=event.data?.json()||{}}catch{}const title=typeof data.title==='string'?data.title.slice(0,80):'Kartabend-App';const body=typeof data.body==='string'?data.body.slice(0,220):'Du hast eine neue Mitteilung.';event.waitUntil(Promise.all([self.HHBadge?.update(data.badge_count,Date.parse(data.badge_at)),self.registration.showNotification(title,{body,icon:new URL('icon-192.png',self.registration.scope).href,badge:new URL('icon-192.png',self.registration.scope).href,tag:'kartabend-'+String(data.id||'mitteilung').slice(0,64),renotify:false,data:{url:new URL('index.html#hh_view=notifications',self.registration.scope).href}})]));});
self.addEventListener('notificationclick',event=>{event.notification.close();const url=new URL('index.html#hh_view=notifications',self.registration.scope).href;event.waitUntil((async()=>{const windows=await self.clients.matchAll({type:'window',includeUncontrolled:true});const client=windows.find(c=>{const u=new URL(c.url);return u.origin===self.location.origin&&[new URL('./',self.registration.scope).pathname,new URL('./index.html',self.registration.scope).pathname].includes(u.pathname)});if(client){await client.focus();client.postMessage({type:'hh_show_notifications'});return}await self.clients.openWindow(url)})());});
