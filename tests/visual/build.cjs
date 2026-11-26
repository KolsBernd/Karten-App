// Render the production DOM with the existing regression-test adapters, then
// remove all executable content. The browser sees anonymous local documents
// only: no login, external request, telemetry, production key or state write.
const fs=require('node:fs'),path=require('node:path');
const {boot,tick}=require('../app-fixture.cjs');
const output=path.resolve('tests/visual/fixtures');fs.mkdirSync(output,{recursive:true});
async function snapshot(name,setup,options={}){
 const {w}=await boot(options);
 try{
  if(setup)await setup(w);await tick();await tick();
  const doc=w.document;doc.querySelectorAll('script').forEach(n=>n.remove());
  // The sandbox server is loopback HTTP, never the public deployment. WebKit
  // would otherwise upgrade local CSS/images to TLS. Keep every other policy
  // and add a stricter no-script/no-connect response policy on the test server.
  doc.querySelectorAll('meta[http-equiv="Content-Security-Policy"]').forEach(n=>n.content=n.content.replace(/upgrade-insecure-requests;?/g,''));
  doc.querySelectorAll('link[rel=manifest]').forEach(n=>n.remove());
  doc.querySelectorAll('*').forEach(n=>{for(const a of [...n.attributes])if(a.name.startsWith('on'))n.removeAttribute(a.name)});
  // Production correctly forbids <base>. Root the local asset URLs explicitly
  // instead, so the unchanged CSP can remain active in these offline fixtures.
  doc.querySelectorAll('[src],[href]').forEach(n=>{for(const a of ['src','href']){const v=n.getAttribute(a);if(v&&!/^(?:[a-z]+:|\/|#)/i.test(v))n.setAttribute(a,'/'+v)}});
  // Freeze current control properties into attributes for script-free screenshots.
  doc.querySelectorAll('input').forEach(n=>{n.setAttribute('value',n.value);if(n.type==='checkbox'||n.type==='radio')n.toggleAttribute('checked',n.checked)});
  doc.querySelectorAll('option').forEach(n=>n.toggleAttribute('selected',n.selected));
  fs.writeFileSync(path.join(output,name+'.html'),'<!doctype html>\n'+doc.documentElement.outerHTML);
 }finally{w.close()}
}
(async()=>{
 await snapshot('login',null,{logged:false});
 await snapshot('lobby');
 await snapshot('registration',async w=>{w.document.getElementById('hhRegisterEmail').closest('details').querySelector('summary').click()},{logged:false});
 await snapshot('settings',async w=>{w.document.getElementById('hhNavSettings').click()});
 await snapshot('profile',async w=>{w.document.getElementById('hhNavProfile').click()});
 await snapshot('request-form',async w=>{
  w.eval(fs.readFileSync('evenings.js','utf8'));
  await w.HHEvenings.refresh({user:{id:'test'},client:{rpc:async(name)=>({data:name==='hh_evening_preferences'?false:[]})},display:x=>x,confirm:async()=>true,fail:e=>{throw e},renderMessages(){},renderFriends(){},refreshSocial:async()=>{},refreshNotifications:async()=>{},refreshRooms:async()=>{}});
  w.document.getElementById('hhNewRoomPlus').click();const type=w.document.getElementById('evCreateType');type.value='plan';type.onchange();
 });
 for(const type of ['Bierkopf','Schleifer','Schniffelkopf','Klopfer','21 rückwärts','Schafkopf','Krawallo'])
  await snapshot('game-'+({'21 rückwärts':'backwards',Schafkopf:'schafkopf',Krawallo:'krawallo',Bierkopf:'bierkopf',Schleifer:'schleifer',Schniffelkopf:'schniffelkopf',Klopfer:'klopfer'})[type],async w=>{await w.document.querySelector('.hh-room-card').onclick();await tick();w.changeGameType(type)}, {longNames:type==='Krawallo'});
 await snapshot('krawallo-teams',async w=>{await w.document.querySelector('.hh-room-card').onclick();await tick();w.changeGameType('Krawallo');w.tab('people')},{longNames:true});
 await snapshot('schafkopf-settings',async w=>{await w.document.querySelector('.hh-room-card').onclick();await tick();w.tab('roomsettings')});
 console.log('Built 15 anonymous production-DOM fixtures without executable scripts.');
})().catch(e=>{console.error(e);process.exit(1)});
