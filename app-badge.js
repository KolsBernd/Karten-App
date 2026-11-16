/* Only counts and timestamps are persisted here. No credentials or message text. */
(function(root){'use strict';let fallback={count:0,stamp:0,active:true};
function normalize(count,stamp){return {count:Math.min(9999,Math.max(0,Math.floor(Number(count)||0))),stamp:Math.max(0,Number(stamp)||0)}}
async function stateChange(next,reset){
 if(!root.indexedDB){if(reset)fallback={count:0,stamp:0,active:false};else if(next.stamp>=fallback.stamp&&!(next.active===undefined&&fallback.active===false))fallback={...next,active:next.active??fallback.active};return fallback}
 return new Promise((resolve,reject)=>{const request=root.indexedDB.open('kartabend-app-badge',1);request.onupgradeneeded=()=>request.result.createObjectStore('state');request.onerror=()=>reject(request.error);request.onsuccess=()=>{const db=request.result,tx=db.transaction('state','readwrite'),store=tx.objectStore('state'),read=store.get('current');let result;read.onsuccess=()=>{const old=read.result||{count:0,stamp:0,active:true};result=reset?{count:0,stamp:0,active:false}:next.stamp>=old.stamp&&!(next.active===undefined&&old.active===false)?{...next,active:next.active??old.active}:old;store.put(result,'current')};tx.oncomplete=()=>{db.close();resolve(result)};tx.onerror=()=>{db.close();reject(tx.error)}}})
}
async function show(state){const nav=root.navigator;if(!nav)return;if(state.active===false||!state.count){if(nav.clearAppBadge)await nav.clearAppBadge()}else if(nav.setAppBadge)await nav.setAppBadge(state.count)}
root.HHBadge={async update(count,stamp,active){try{const next=normalize(count,stamp);next.active=active;await show(await stateChange(next,false))}catch{}},async clear(){try{await show(await stateChange(null,true))}catch{}}};
})(typeof self!=='undefined'?self:globalThis);
