/* Hannes Hütte Online: authenticated room sync with optimistic revisions. */
(()=>{
'use strict';
const $=id=>document.getElementById(id);
const cfg=window.HH_CONFIG||{};
let client=null, user=null, room=null, rev=null, pending=false, dirty=false, realtime=null, admin=false;
let committed=null;
const status=(msg,bad=false)=>{ $('hhStatus').textContent=msg;$('hhStatus').style.color=bad?'#ff8993':'#a8e6c0';};
const fail=e=>{console.error(e);status(e?.message||String(e),true)};
const snapshot=()=>JSON.parse(JSON.stringify(data));
function adopt(value){if(!value||!Array.isArray(value.people)||!Array.isArray(value.sessions)||!value.sessions.length)throw Error('Ungültiger Online-Datensatz');data=structuredClone(value);render();}
function gate(show){$('hhGate').classList.toggle('hide',!show);$('hhGate').setAttribute('aria-hidden',String(!show));document.body.classList.toggle('hh-locked',show)}
function setupState(){ $('hhEmail').textContent=user?.email||'Nicht angemeldet';$('hhAdmin').textContent=admin?'Administrator':'Mitspieler';$('hhRoom').textContent=room||'Noch kein Raum';$('hhCreateRoom').classList.toggle('hide',!admin);$('hhRestoreButton').classList.toggle('hide',!admin);$('hhRoomActions').classList.toggle('hide',!user);$('hhLogout').classList.toggle('hide',!user);$('hhLogin').classList.toggle('hide',!!user);}
async function fetchState(){const {data:rows,error}=await client.from('hh_states').select('payload,revision').eq('room_id',room).single();if(error)throw error;return rows}
async function loadRoom(id){if(realtime){await client.removeChannel(realtime);realtime=null}room=id;localStorage.setItem('hh_last_room',id);const st=await fetchState();rev=Number(st.revision);committed=structuredClone(st.payload);adopt(st.payload);gate(false);setupState();status('Verbunden · Revision '+rev);realtime=client.channel('hh-'+id).on('postgres_changes',{event:'UPDATE',schema:'public',table:'hh_states',filter:'room_id=eq.'+id},async event=>{if(Number(event.new.revision)<=rev)return;if(pending||dirty){status('Neue Änderungen vorhanden – Synchronisierung läuft …');return}try{const fresh=await fetchState();if(Number(fresh.revision)>rev){rev=Number(fresh.revision);committed=structuredClone(fresh.payload);adopt(fresh.payload);status('Live aktualisiert · Revision '+rev)}}catch(e){fail(e)}}).subscribe();}
function exportConflict(local){const blob=new Blob([JSON.stringify(local,null,2)],{type:'application/json'});const a=document.createElement('a');const u=URL.createObjectURL(blob);a.href=u;a.download='hannes-konflikt-'+Date.now()+'.json';a.click();setTimeout(()=>URL.revokeObjectURL(u),1000)}
async function flush(){if(pending||!dirty||!room)return;pending=true;dirty=false;const payload=snapshot();const expected=rev;status('Speichere …');try{const {data:next,error}=await client.rpc('hh_update_state',{p_room:room,p_revision:expected,p_payload:payload});if(error)throw error;rev=Number(next);committed=structuredClone(payload);status('Gespeichert · Revision '+rev);if(dirty)queueMicrotask(flush)}catch(e){dirty=false;exportConflict(payload);try{const fresh=await fetchState();rev=Number(fresh.revision);committed=structuredClone(fresh.payload);adopt(fresh.payload)}catch(loadErr){fail(loadErr);gate(true)}alert('Online-Speicherung fehlgeschlagen. Deine Änderungen wurden als JSON-Datei gesichert. Die aktuelle Serverversion wird angezeigt. Ursache: '+(e.message||e));fail(e)}finally{pending=false;if(dirty)queueMicrotask(flush)}}
const localSave=save;
save=function(){if(!room){alert('Bitte zuerst anmelden und einen Spielraum öffnen.');return}render();dirty=true;queueMicrotask(flush)};
// Import and destructive reset are administrator-only; enforce UI AND database permissions separately.
const oldImport=importData;
importData=async function(e){if(!admin){alert('Nur der Administrator darf ein Backup importieren.');e.target.value='';return}if(!confirm('Achtung: Das Backup ersetzt den gemeinsamen Online-Stand für ALLE Mitglieder. Fortfahren?')){e.target.value='';return}return oldImport(e)};
const oldReset=resetStatistics;
resetStatistics=function(){if(!admin){alert('Nur der Administrator darf Statistiken zurücksetzen.');return}oldReset()};
async function login(){const email=$('hhLoginEmail').value.trim().toLowerCase();if(!/^\S+@\S+\.\S+$/.test(email)){status('Bitte gültige E-Mail eingeben',true);return}const {error}=await client.auth.signInWithOtp({email,options:{emailRedirectTo:location.origin+location.pathname}});if(error)throw error;status('Prüfe dein E-Mail-Postfach und bestätige den Anmeldelink.');}
async function createRoom(){if(!admin)throw Error('Nur Admin');const invite=$('hhInvite').value.trim();if(invite.length<20)throw Error('Bitte Einladungscode mit mindestens 20 Zeichen verwenden');const initial=confirm('Bisherige lokale Spielstände in den neuen Raum übernehmen?\nOK = lokale Daten importieren; Abbrechen = leerer Raum')?snapshot():fresh();const {data:id,error}=await client.rpc('hh_create_room',{p_invite:invite,p_initial:initial});if(error)throw error;await loadRoom(id);$('hhInvite').value='';}
async function joinRoom(){const code=$('hhInvite').value.trim();const {data:id,error}=await client.rpc('hh_join_room',{p_invite:code});if(error)throw error;await loadRoom(id);$('hhInvite').value='';}
async function restore(){if(!admin)return;const n=Number(prompt('Welche Revisionsnummer wiederherstellen? (siehe Änderungsverlauf)',String(Math.max(1,rev-1))));if(!Number.isInteger(n)||n<1)return;if(!confirm('Revision '+n+' für alle wiederherstellen?'))return;const {error}=await client.rpc('hh_restore_revision',{p_room:room,p_revision:n});if(error)throw error;const st=await fetchState();rev=Number(st.revision);adopt(st.payload);status('Revision wiederhergestellt')}
async function showAudit(){if(!room)return;const {data:rows,error}=await client.from('hh_audit').select('revision,changed_at,action,actor').eq('room_id',room).order('revision',{ascending:false}).limit(25);if(error)throw error;$('hhAudit').textContent=rows.length?rows.map(r=>'Revision '+r.revision+' · '+new Date(r.changed_at).toLocaleString('de-DE')+' · '+r.actor).join('\n'):'Noch keine Änderungen';}
async function init(){try{if(!cfg.supabaseUrl?.startsWith('https://')||!cfg.supabaseAnonKey||cfg.supabaseAnonKey.startsWith('DEIN-')){status('Noch nicht eingerichtet: config.js ausfüllen',true);return}if(!window.supabase){status('Supabase-Bibliothek nicht geladen. Internetverbindung prüfen.',true);return}client=window.supabase.createClient(cfg.supabaseUrl,cfg.supabaseAnonKey,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});const {data:session,error}=await client.auth.getUser();if(error&&error.name!=='AuthSessionMissingError')throw error;user=session.user;admin=!!user&&user.email?.toLowerCase()==='bernd.dinkel@gmx.de'&&!!user.email_confirmed_at;setupState();if(!user){status('Bitte anmelden.');return}const last=localStorage.getItem('hh_last_room');if(last){try{await loadRoom(last)}catch{localStorage.removeItem('hh_last_room');status('Bitte Spielraum erstellen oder Einladungscode eingeben.')}}else status('Angemeldet · Spielraum auswählen');}catch(e){fail(e)}}
$('hhSendLogin').onclick=()=>login().catch(fail);
$('hhCreateRoom').onclick=()=>createRoom().catch(fail);
$('hhJoinRoom').onclick=()=>joinRoom().catch(fail);
$('hhLogout').onclick=async()=>{if(client)await client.auth.signOut();room=null;rev=null;user=null;admin=false;localStorage.removeItem('hh_last_room');setupState();gate(true);status('Abgemeldet')};
$('hhOpenGate').onclick=()=>{gate(true);setupState()};
$('hhCloseGate').onclick=()=>{if(room)gate(false)};
$('hhAuditButton').onclick=()=>showAudit().catch(fail);
$('hhRestoreButton').onclick=()=>restore().catch(fail);
window.addEventListener('online',()=>{if(room){status('Wieder online');if(dirty)flush();else fetchState().then(st=>{if(Number(st.revision)>rev){rev=Number(st.revision);adopt(st.payload)}}).catch(fail)}});
window.addEventListener('offline',()=>{status('Offline – keine neuen Eingaben möglich',true);gate(true)});
window.addEventListener('beforeunload',e=>{if(pending||dirty){e.preventDefault();e.returnValue=''}});
// Prevent the main UI from being usable before authenticated room data is loaded.
gate(true);init();
})();
