// Generated only inside the isolated test workflow, never from real room data.
const fs=require('node:fs'),rules=require('../schafkopf-euro.js');
const clean=cfg=>Object.fromEntries(Object.entries(cfg).map(([k,v])=>[k,{enabled:v.enabled,cents:v.cents}]));
const lines=[],base={seat:0,partner:2,spikes:[],result:'normal',tout:false,light:false,won:true,announcement:1,laid:0,knockers:0,jungfrauen:[]};
function vector(cfg,input){const v=rules.calculate(cfg,input),balances=rules.settlement(v.quarters,input);lines.push(JSON.stringify({cfg:clean(cfg),input,quarters:v.quarters,balances}));}
for(const game of ['King','Wenz','Geier','Solo'])for(let mask=0;mask<16;mask++)for(const mode of ['none','tout','light'])for(const result of ['normal','durch'])for(const announcement of [1,2,4,8]){
 const cfg=rules.defaults();cfg[game].cents=[1,10,20,100000][mask%4];vector(cfg,{...base,game,spikes:['A','B','C','D'].filter((_,i)=>mask&(1<<i)),tout:mode==='tout',light:mode==='light',result,announcement,laid:mask%5});}
for(const game of ['Sau','Kreuzspiel','Bettel','Bagga','Spitz'])for(const result of ['normal','schneider','durch'])for(const won of [false,true])for(const announcement of [1,2,4,8])vector(rules.defaults(),{...base,game,result,won,announcement,laid:2});
for(const game of ['Bettel','Bagga'])for(let laid=0;laid<=4;laid++)vector(rules.defaults(),{...base,game,tout:true,result:'durch',laid});
for(let knockers=0;knockers<=4;knockers++)for(let mask=0;mask<8;mask++)for(const won of [false,true]){
 const cfg=rules.defaults();cfg.Ramsch.enabled=true;cfg.Kreuzspiel.enabled=false;vector(cfg,{...base,game:'Ramsch',knockers,laid:mask%5,announcement:[1,2,4,8][mask%4],won,jungfrauen:won?[]:[1,2,3].filter((_,i)=>mask&(1<<i))});}
fs.writeFileSync('tests/euro-vectors.ndjson',lines.join('\n')+'\n');console.log('Generated '+lines.length+' independent JS/SQL parity cases.');
