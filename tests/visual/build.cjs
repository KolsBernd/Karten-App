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
  doc.querySelectorAll('*').forEach(n=>{for(const a of [...n.attributes])if(a.name.startsWith('on'))n.removeAttribute(a.name)});
  // Production correctly forbids <base>. Root the local asset URLs explicitly
  // instead, so the unchanged CSP can remain active in these offline fixtures.
  doc.querySelectorAll('[src],[href]').forEach(n=>{for(const a of ['src','href']){const v=n.getAttribute(a);if(v&&!/^(?:[a-z]+:|\/|#)/i.test(v))n.setAttribute(a,'/'+v)}});
  fs.writeFileSync(path.join(output,name+'.html'),'<!doctype html>\n'+doc.documentElement.outerHTML);
 }finally{w.close()}
}
(async()=>{
 await snapshot('login',null,{logged:false});
 await snapshot('lobby');
 for(const type of ['Bierkopf','Schleifer','Schniffelkopf','Klopfer','21 rückwärts','Schafkopf','Krawallo'])
  await snapshot('game-'+({'21 rückwärts':'backwards',Schafkopf:'schafkopf',Krawallo:'krawallo',Bierkopf:'bierkopf',Schleifer:'schleifer',Schniffelkopf:'schniffelkopf',Klopfer:'klopfer'})[type],async w=>{await w.document.querySelector('.hh-room-card').onclick();await tick();w.changeGameType(type)});
 console.log('Built 9 anonymous production-DOM fixtures without executable scripts.');
})().catch(e=>{console.error(e);process.exit(1)});
