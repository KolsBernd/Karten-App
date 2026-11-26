const {boot,tick}=require('./app-fixture.cjs');
const assert=require('node:assert/strict');
(async()=>{
 const {w}=await boot();await w.document.querySelector('.hh-room-card').onclick();await tick();
 const session=w.eval('s()');session.schafSettings={variants:['Solo','Sau','Tout'],capture_colors:false,target:3};
 w.changeGameType('Schafkopf');await tick();await tick();
 const api=w.HHRoomGames,record={id:49,gameType:'Schafkopf',players:[1,2,3,4],closed:true,rounds:[{results:[{id:1,points:6},{id:2,points:0},{id:3,points:0},{id:4,points:0}]},{results:[{id:1,points:0},{id:2,points:6},{id:3,points:0},{id:4,points:0}]},{results:[{id:1,points:6},{id:2,points:0},{id:3,points:0},{id:4,points:0}]}]};
 assert.equal(api.records(record).length,3);assert.deepEqual(Array.from(api.statistics(record),p=>p.points),[12,6,0,0]);assert.equal(api.records({...record,gameType:'Krawallo'}).length,1);
 w.tab('roomsettings');await tick();const target=w.document.getElementById('hhRoomSchafTarget');assert(target);assert.equal(target.options.length,50);assert.equal(target.value,'3');
 assert.equal(w.document.querySelector('link[href="ui49.css"]')!==null,true);w.close();
 console.log('PASS V49: 1–50 room setting; per-hand statistics; summed Schafkopf series; other game histories preserved.');
})().catch(e=>{console.error(e);process.exit(1)});
