/* Synthetic financial service for UI tests only. The real SQL rules are tested
 * independently in Postgres; this fixture never calls an external service. */
(function(root,factory){if(typeof module==='object'&&module.exports)module.exports=factory;else root.HHEuroFixture=factory;})(typeof window!=='undefined'?window:globalThis,function({rules,writer=true,people=()=>[1,2,3,4].map(id=>({id,name:'Spieler '+id}))}={}){
 let model=null,revision=0,allowed=writer,requests=new Map();
 const copy=x=>structuredClone(x),cfg=()=>Object.fromEntries(Object.entries(rules.defaults()).map(([k,v])=>[k,{enabled:v.enabled,cents:v.cents}]));
 const series=(players,config)=>({id:crypto.randomUUID(),players:[...players],config:copy(config),rounds:[],closed:false,started_at:new Date().toISOString(),totals:[0,0,0,0],transfers:[]});
 function transfers(totals){const b=[...totals],out=[];for(let i=0;i<3;i++){let d=-1,c=-1;for(let j=0;j<4;j++){if(b[j]<0&&(d<0||b[j]<b[d]))d=j;if(b[j]>0&&(c<0||b[j]>b[c]))c=j;}if(d<0||c<0)break;const q=Math.min(-b[d],b[c]);out.push({from:d,to:c,quarters:q});b[d]+=q;b[c]-=q;}return out;}
 const reply=()=>({data:copy(model),revision,can_write:allowed,ended:false,applied_requests:[...requests.keys()]});
 async function rpc(a){try{
  const action=a.p_action;if(action==='capabilities')return{data:{can_write:allowed}};if(action==='list')return{data:model?[{room_id:'room-1',active:model.active,running:model.active&&!model.current.closed&&model.current.rounds.length>0}]:[]};
  if(action==='get')return{data:reply()};if(!allowed&&action!=='deactivate')throw Object.assign(Error('Nur Kolsbernd und Yannik'),{code:'42501'});
  if(requests.has(a.p_request))return{data:reply()};if(a.p_revision!==revision)throw Object.assign(Error('Spielstand wurde geändert'),{code:'40001'});
  if(!model){const ids=people().filter(p=>!p.deleted).slice(0,4).map(p=>p.id),config=cfg();model={active:false,current:series(ids,config),history:[],draft:{players:ids,config},events:[]};}
  const st=model.current,body=a.p_body||{};if(!['activate','deactivate'].includes(action)&&body.series_id!==st.id)throw Object.assign(Error('Abrechnung geändert'),{code:'40001'});
  if(action==='activate')model.active=true;
  if(action==='deactivate'){if(st.rounds.length&&!st.closed)throw Error('Bitte zuerst abrechnen');model.active=false;}
  if(action==='configure'){if(st.rounds.length&&!st.closed)throw Error('Einstellungen sind gesperrt');if(body.players.length!==4||new Set(body.players).size!==4)throw Error('Vier Spieler wählen');model.draft=copy({players:body.players,config:body.config});if(!st.closed){st.players=[...body.players];st.config=copy(body.config)}}
  if(action==='new'){if(st.rounds.length&&!st.closed)throw Error('Bitte zuerst abrechnen');model.current=series(model.draft.players,model.draft.config);model.active=true;}
  if(action==='add'){if(st.closed)throw Error('Abgerechnet');const value=rules.calculate(st.config,body.input),balances=rules.settlement(value.quarters,body.input);st.rounds.push({id:a.p_request,input:copy(body.input),quarters:value.quarters,balances,actor:'test-writer',actor_name:'Testspieler',recorded_at:new Date().toISOString(),duration_seconds:42});st.totals=st.totals.map((n,i)=>n+balances[i]);}
  if(action==='finish'){if(st.closed||!st.rounds.length)throw Error('Keine offene Abrechnung');st.closed=true;st.closed_at=new Date().toISOString();st.transfers=transfers(st.totals);model.history.push(copy(st));}
  if(action==='undo'){if(!st.rounds.length)throw Error('Kein Eintrag');if(st.closed){model.history.pop();st.closed=false;st.transfers=[];delete st.closed_at;}const r=st.rounds.pop();st.totals=st.totals.map((n,i)=>n-r.balances[i]);}
  revision++;requests.set(a.p_request,true);model.events.push({action,actor_name:'Testspieler',at:new Date().toISOString()});return{data:reply()};
 }catch(error){return{error:{message:error.message,code:error.code||'P0001'}}}}
 return{rpc,setWriter(v){allowed=v},state:()=>copy(model),revision:()=>revision,transfers};
});
