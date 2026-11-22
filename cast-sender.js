/* Custom Cast receiver, loaded only after an explicit request to share.
 * Register cast-receiver.html in Google's Cast SDK Console and configure the
 * returned public app ID in config.js. A generic media receiver cannot render
 * an interactive scoreboard. No credentials are written to URLs or logs. */
(() => {
 'use strict';
 const NAMESPACE='urn:x-cast:de.kartabend.scores';let ready=null;
 const appId=()=>String(window.HH_CONFIG?.googleCastAppId||'').trim();
 function configured(){return /^[A-F0-9]{8}$/i.test(appId());}
 function prepare(){
  if(!configured())return Promise.reject(Error('Google Cast ist noch nicht eingerichtet. Der Betreiber muss den TV-Empfänger registrieren.'));
  if(ready)return ready;
  ready=new Promise((resolve,reject)=>{
   let timer=setTimeout(()=>{ready=null;reject(Error('Google Cast konnte nicht geladen werden. Bitte mit einem unterstützten Chrome-Browser erneut versuchen.'));},20000);
   window.__onGCastApiAvailable=(available)=>{clearTimeout(timer);if(!available){ready=null;reject(Error('Google Cast ist in diesem Browser nicht verfügbar.'));return;}
    try{const ctx=cast.framework.CastContext.getInstance();ctx.setOptions({receiverApplicationId:appId(),autoJoinPolicy:chrome.cast.AutoJoinPolicy.ORIGIN_SCOPED});resolve(ctx);}catch(error){ready=null;reject(error);}};
   const script=document.createElement('script');script.src='https://www.gstatic.com/cv/js/sender/v1/cast_sender.js?loadCastFramework=1';script.async=true;script.onerror=()=>{clearTimeout(timer);ready=null;script.remove();reject(Error('Google Cast konnte nicht geladen werden.'));};document.head.append(script);
  });return ready;
 }
 function choose(){if(!configured())throw Error('Google Cast ist noch nicht eingerichtet.');const ctx=cast.framework.CastContext.getInstance();return ctx.requestSession().then(()=>{const session=ctx.getCurrentSession();if(!session)throw Error('Kein Fernseher verbunden.');return session;});}
 async function send(session,ticket){await session.sendMessage(NAMESPACE,{type:'scores',session:ticket.id,code:ticket.token});}
 function stop(){try{cast.framework.CastContext.getInstance().endCurrentSession(true);}catch(error){/* No local Cast session after reload. Server revocation still applies. */}}
 window.HHCasting={configured,prepare,choose,send,stop};
})();
