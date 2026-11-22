/* Device selection is the primary action. The TV receives a revocable viewer
 * capability, never the phone's authentication session. */
(() => {
 'use strict';let context,current=null,busy=false;
 const el=(tag,text)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;return n;};
 async function show(){
  if(!context||busy)return;const target=context.target(),identity=context.user();
  let d=document.getElementById('hhTVShare');if(!d){d=el('dialog');d.id='hhTVShare';d.className='hh-confirm-dialog';document.body.append(d);}
  d.replaceChildren(el('h2','Ergebnisse teilen'));
  const note=el('p','Fernseher im selben WLAN auswählen. Google Cast benötigt einen Cast-fähigen Fernseher oder Empfänger. Die Aufteilung mit dem Fernsehprogramm wird am TV eingestellt.');note.className='small muted';d.append(note);
  const button=(text,action)=>{const b=el('button',text);b.type='button';b.className='ghost hh-wide-button';b.onclick=()=>Promise.resolve().then(action).catch(error=>{status.textContent=error.message||'Teilen fehlgeschlagen.';});return b;};
  const status=el('p');status.className='small muted';status.setAttribute('role','status');d.append(status);
  if(!target.id||!target.owner){status.textContent='Nur der Raum- beziehungsweise Turnierersteller kann Ergebnisse übertragen.';}
  else{
   const select=button('Fernseher auswählen · Google Cast',async()=>{
    if(busy)return;busy=true;select.disabled=true;let ticket=null,session=null;
    try{
     session=await window.HHCasting.choose();
     if(context.user()!==identity||context.target().id!==target.id||!d.open){window.HHCasting.stop();return;}
     const r=await context.client().rpc('hh_tv_control',{p_action:'create',p_target:target.id,p_kind:target.kind});if(r.error)throw r.error;ticket=r.data;
     if(context.user()!==identity||context.target().id!==target.id||!d.open)throw Error('Raum gewechselt. Bitte erneut teilen.');
     await window.HHCasting.send(session,ticket);current={id:ticket.id,target:target.id,kind:target.kind};status.textContent='Live-Ergebnisse werden übertragen. Das Handy kann unabhängig weiterbenutzt werden.';stop.hidden=false;
    }catch(error){if(ticket?.id){const revoked=await context.client().rpc('hh_tv_control',{p_action:'stop',p_target:ticket.id});if(revoked.error){context.fail(revoked.error);status.textContent='TV-Zugang bitte über TV-Freigabe beenden sperren.';current={id:ticket.id,target:target.id,kind:target.kind};stop.hidden=false;}}if(session)window.HHCasting.stop();throw error;}
    finally{busy=false;select.disabled=false;}
   });select.className='primary hh-wide-button';select.disabled=true;d.append(select);
   const stop=button('TV-Freigabe beenden',async()=>{
    if(!current||!await context.confirm('TV-Freigabe beenden?','Die Live-Ergebnisse auf dem TV werden gesperrt. Die Bildschirmteilung beendest du mit der Fernbedienung.'))return;
    const r=await context.client().rpc('hh_tv_control',{p_action:'stop',p_target:current.id});if(r.error)throw r.error;current=null;window.HHCasting.stop();stop.hidden=true;status.textContent='TV-Freigabe beendet.';
   });stop.hidden=true;d.append(stop);
   if(window.HHCasting.configured()){
    status.textContent='Google Cast wird vorbereitet …';window.HHCasting.prepare().then(()=>{if(context.user()===identity&&context.target().id===target.id){select.disabled=false;status.textContent='Bereit zur Fernseherauswahl.';}}).catch(e=>{if(d.open)status.textContent=e.message;});
   }else{select.textContent='Google Cast · Einrichtung erforderlich';status.textContent='Die Cast-App-ID ist noch nicht hinterlegt. Die direkte Geräteauswahl ist deshalb noch nicht aktiv.';}
   const state=await context.client().rpc('hh_tv_control',{p_action:'status',p_target:target.id,p_kind:target.kind});
   if(context.user()===identity&&context.target().id===target.id&&!state.error&&state.data){current={...state.data,target:target.id,kind:target.kind};stop.hidden=false;}
  }
  const airplay=el('details'),summary=el('summary','AirPlay auf dem iPhone');airplay.append(summary,el('p','Die aktuelle Web-App kann keine eigenständige AirPlay-Spielstandsanzeige mit Geräteauswahl starten. Über das iPhone-Kontrollzentrum → Bildschirm synchronisieren lässt sich der Bildschirm spiegeln; dabei werden auch andere Handy-Apps sichtbar. Unabhängige AirPlay-Übertragung benötigt eine native Erweiterung.'));d.append(airplay,button('Schließen',()=>d.close()));if(!d.open)d.showModal();
 }
 function decorate(){const target=context?.target();let b=document.getElementById('hhResultShare');if(!target?.id){b?.remove();return;}if(!b){b=el('button','Teilen');b.type='button';b.id='hhResultShare';b.className='ghost hh-result-share';b.setAttribute('aria-label','Ergebnisse auf einem Fernseher teilen');b.onclick=()=>show().catch(context.fail);}const host=document.querySelector('.tt-schaf-heading:not(.hide)')||document.querySelector('.club-header');if(host&&!host.contains(b))host.append(b);}
 window.HHTVShare={bind(c){context=c;},decorate,clear(){current=null;document.getElementById('hhTVShare')?.close();}};
})();
