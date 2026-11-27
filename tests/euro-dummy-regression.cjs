const assert=require('node:assert/strict');
const calc=require('../schafkopf-euro.js');
const cfg=calc.defaults(),base={game:'Solo',spikes:[],result:'normal',tout:false,light:false,announcement:1,laid:0};
for(const [letters,cents] of [['',20],['A',20],['AB',30],['ABC',35],['ABCD',40],['CD',35],['D',40]])assert.equal(calc.calculate(cfg,{...base,spikes:[...letters]}).cents,cents);
assert.equal(calc.calculate(cfg,{...base,result:'schneider'}).cents,25);assert.equal(calc.calculate(cfg,{...base,result:'durch'}).cents,30);
assert.equal(calc.calculate(cfg,{...base,spikes:['A','B'],result:'durch',tout:true,announcement:4,laid:2}).cents,960);
const ten=structuredClone(cfg);ten.Solo.cents=10;assert.equal(calc.calculate(ten,{...base,spikes:['A','B']}).cents,15);assert(calc.calculate(ten,{...base,spikes:['A','B','C']}).fractionalCent);
assert.equal(calc.calculate(cfg,{...base,spikes:['B']}).cents,20);assert.equal(calc.calculate(cfg,{...base,spikes:['A','C']}).cents,20);assert.throws(()=>calc.calculate(cfg,{...base,spikes:['E']}));assert.throws(()=>calc.calculate(cfg,{...base,tout:true,light:true}));assert.throws(()=>calc.calculate(cfg,{...base,announcement:3}));cfg.Solo.enabled=false;assert.throws(()=>calc.calculate(cfg,base));cfg.Solo.enabled=true;
assert.equal(calc.parseCents('0,20'),20);assert.equal(calc.parseCents('1.25'),125);for(const bad of ['-1','0,001','Infinity','1e3','1001','<script>'])assert.throws(()=>calc.parseCents(bad));
assert.deepEqual(calc.settlement(80,{game:'Solo',seat:0,won:true}),[240,-80,-80,-80]);assert.deepEqual(calc.settlement(80,{game:'Solo',seat:0,won:false}),[-240,80,80,80]);assert.deepEqual(calc.settlement(5,{game:'Sau',seat:0,partner:1,won:true}),[5,5,-5,-5]);assert.deepEqual(calc.settlement(5,{game:'Kreuzspiel',seat:0,partner:2,won:false}),[-5,5,-5,5]);assert.throws(()=>calc.settlement(5,{game:'Kreuzspiel',seat:0,partner:1,won:true}));
const ramsch=calc.defaults();ramsch.Ramsch.enabled=true;assert.equal(calc.calculate(ramsch,{...base,game:'Ramsch'}).cents,10);assert.deepEqual(calc.settlement(40,{game:'Ramsch',seat:0,won:false,jungfrauen:[1]}),[-160,80,40,40]);assert.deepEqual(calc.settlement(70,{game:'Solo',seat:0,won:true}),[210,-70,-70,-70]);
// V51: ignored hidden controls, exact Bettel-Tout and independent Ramsch doublings.
assert.equal(calc.calculate(cfg,{...base,tout:true,result:'durch'}).cents,40);
assert.equal(calc.calculate(cfg,{...base,light:true,spikes:['A','B','C'],result:'durch'}).cents,40);
assert.equal(calc.calculate(cfg,{...base,game:'Bettel',tout:true,result:'durch',spikes:['A','B','C','D']}).cents,22.5);
assert.equal(calc.calculate(cfg,{...base,game:'Bettel',spikes:['A','B','C']}).cents,15);
assert.equal(calc.spikesAllowed('Solo',true),false);
for(const game of ['Ramsch','Bagga','Bettel','Spitz'])assert.equal(calc.spikesAllowed(game),false);
assert.throws(()=>calc.calculate(cfg,{...base,game:'Bettel',light:true}));assert.throws(()=>calc.calculate(cfg,{...base,game:'Bagga',light:true}));
for(let n=0;n<=4;n++)assert.equal(calc.calculate(ramsch,{...base,game:'Ramsch',knockers:n}).cents,10*2**n);
assert.equal(calc.calculate(ramsch,{...base,game:'Ramsch',knockers:2,laid:1,announcement:2}).cents,160);
assert.throws(()=>calc.calculate(ramsch,{...base,game:'Ramsch',knockers:5}));
const noBonus=structuredClone(cfg);noBonus.Schneider.enabled=false;noBonus.Durch.enabled=false;assert.equal(calc.calculate(noBonus,{...base,tout:true,result:'durch'}).cents,40);
for(const game of ['Spitz','Bagga','Bettel']){assert.equal(calc.resultAllowed(game),false);for(const result of ['normal','schneider','durch'])assert.equal(calc.calculate(cfg,{...base,game,result}).cents,cfg[game].cents);const disabled=structuredClone(cfg);disabled.Schneider.enabled=false;disabled.Durch.enabled=false;assert.equal(calc.calculate(disabled,{...base,game,result:'durch'}).cents,cfg[game].cents)}
const {boot,tick}=require('./app-fixture.cjs');
const find=(root,text)=>[...root.querySelectorAll('button')].find(b=>b.textContent.trim()===text);
async function openRoom(f){await f.w.document.querySelector('.hh-room-card').onclick();await tick();await tick();}
(async()=>{
 for(const [name,admin,creator,allowed]of [['tester',true,false,true],['yannik',false,true,true],['Yannik',false,true,true],['yannik',false,false,false],['someone',false,true,false]]){
  const f=await boot({canonicalUsername:name,resetAdmin:admin,tournamentCreator:creator,euroWriter:allowed});await openRoom(f);const {w}=f;const b=w.document.getElementById('hhEuroDummy');assert.equal(b.hidden,!allowed);assert.equal(!!w.document.getElementById('hhEuroDummyDialog'),false);
  await b.onclick();await tick();const host=w.document.getElementById('hhEuroRoom');assert(host.shadowRoot);assert.equal(host.classList.contains('hide'),!allowed);
  assert.equal(w.document.getElementById('hhAdminResetPanel').classList.contains('hide'),!admin);
  if(allowed){const before=w.eval('JSON.stringify(data)');const view=host.shadowRoot;assert(find(view,'Einstellungen'));await find(view,'Partie eintragen').onclick();assert(!find(view,'Einstellungen'));assert.equal(w.eval('JSON.stringify(data)'),before);assert(!f.calls.some(c=>c.name==='hh_update_state'));
   const finish=find(view,'Abrechnung').onclick();await tick();w.document.getElementById('hhConfirmNo').click();await finish;assert.equal(f.getEuro().state().current.closed,false);
   const yes=find(view,'Abrechnung').onclick();await tick();w.document.getElementById('hhConfirmYes').click();await yes;assert.equal(f.getEuro().state().current.closed,true);assert(find(view,'Einstellungen'));assert.equal(f.getEuro().state().current.transfers.length,3);
  }w.close();
 }
 const login=await boot({logged:false});login.w.document.getElementById('hhUsername').value='Tester';login.w.document.getElementById('hhPassword').value='test-password-not-real';await login.w.document.getElementById('hhSendLogin').onclick();assert(login.calls.some(c=>c.name==='username-login'&&c.args.body.username==='tester'));assert.equal(login.w.document.getElementById('hhPassword').value,'');login.w.close();
 console.log('PASS V54: pure Euro rules, inline room UI, settings lock, confirmed settlement, pinned writer visibility, no ordinary/global room-state writes.');
})().catch(e=>{console.error(e);process.exit(1)});
