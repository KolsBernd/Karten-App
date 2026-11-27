// Browser harness: anonymous local-only room, real UI and real pure calculator.
(async()=>{
 const names=['Anna Beispiel','Ben Muster','Clara Test','David Beispiel'];const people=names.map((name,i)=>({id:i+1,name}));
 const fake=window.HHEuroFixture({rules:window.HHEuroDummy,writer:true,people:()=>people});let view='play';
 const host=document.getElementById('testRoot');const status=document.getElementById('testStatus');
 function confirm(title,text){return new Promise(resolve=>{const d=document.getElementById('testConfirm');d.querySelector('h2').textContent=title;d.querySelector('p').textContent=text;for(const [id,value]of [['testYes',true],['testNo',false]])document.getElementById(id).onclick=()=>{d.close();resolve(value)};d.showModal()})}
 const app=window.HHEuroRoom.create({client:()=>({rpc:(_name,args)=>fake.rpc(args)}),room:()=> 'room-1',user:()=>({id:'test-writer'}),people:()=>people,name:id=>names[id-1],view:()=>view,tournament:()=>false,ranks:()=>document.getElementById('ranks'),history:()=>document.getElementById('history'),modeButton:()=>document.getElementById('testEuro'),canSelect:()=>true,showPlay:()=>show('play'),confirm,notice:async(title,text)=>{const d=document.getElementById('testInfo');d.querySelector('h2').textContent=title;d.querySelector('p').textContent=text;d.showModal()},fail:error=>status.textContent=error.message});
 function show(next){view=next;for(const id of ['play','ranks','history'])document.getElementById(id).classList.toggle('hide',next!==id);app.sync();}
 for(const [id,next]of [['testPlay','play'],['testRanks','ranks'],['testHistory','history']])document.getElementById(id).onclick=()=>show(next);
 document.getElementById('testEuro').onclick=()=>app.open();document.getElementById('testTheme').onclick=()=>{document.documentElement.dataset.theme=document.documentElement.dataset.theme==='dark'?'light':'dark';app.sync()};document.getElementById('testInfoClose').onclick=()=>document.getElementById('testInfo').close();
 if(location.hash.includes('reader')){let reply=await fake.rpc({p_action:'activate',p_revision:0,p_request:crypto.randomUUID(),p_body:{}});await fake.rpc({p_action:'add',p_revision:reply.data.revision,p_request:crypto.randomUUID(),p_body:{series_id:reply.data.data.current.id,input:{game:'Solo',seat:0,partner:null,spikes:[],result:'normal',tout:false,light:false,won:true,announcement:1,laid:0,knockers:0,jungfrauen:[]}}});fake.setWriter(false);}
 window.testEuroState=()=>fake.state();await app.open();window.testEuroReady=true;
})();
