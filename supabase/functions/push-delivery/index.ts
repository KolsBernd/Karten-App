import * as webpush from 'npm:web-push@4.0.0';
// Authenticated by a 256-bit server-only webhook secret from Vault. No user-supplied recipient or payload is accepted.
const project = Deno.env.get('SUPABASE_URL')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const app = 'https://kolsbernd.github.io/Karten-App/';
async function rpc(name: string, body: Record<string, unknown> = {}) {
 const response = await fetch(project + '/rest/v1/rpc/' + name, {method:'POST',headers:{apikey:serviceKey,Authorization:'Bearer '+serviceKey,'Content-Type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(12000)});
 if(!response.ok)throw new Error('Push-Speicher nicht verfügbar');
 const text=await response.text();return text?JSON.parse(text):null;
}
function allowedEndpoint(endpoint: string) {
 try{const u=new URL(endpoint);return u.protocol==='https:'&&!u.username&&!u.password&&!u.port&&(u.hostname==='fcm.googleapis.com'||u.hostname==='updates.push.services.mozilla.com'||u.hostname==='push.apple.com'||u.hostname.endsWith('.push.apple.com')||/^[a-z0-9-]+\.notify\.windows\.com$/.test(u.hostname));}catch{return false;}
}
async function secretMatches(given:string,expected:string){const a=new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(given)));const b=new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(expected)));let different=0;for(let i=0;i<a.length;i++)different|=a[i]^b[i];return different===0;}
Deno.serve(async request=>{
 if(request.method!=='POST')return new Response('Method not allowed',{status:405,headers:{'Cache-Control':'no-store'}});
 try{
  const token=request.headers.get('x-kartabend-push')||'';if(!/^[a-f0-9]{64}$/.test(token))return new Response('Unauthorized',{status:401});
  const expected=await rpc('hh_push_worker_secret');if(!expected||!await secretMatches(token,expected))return new Response('Unauthorized',{status:401});
  let keys=await rpc('hh_push_keys_init');
  if(!keys){const generated=webpush.generateVAPIDKeys();keys=await rpc('hh_push_keys_init',{p_public:generated.publicKey,p_private:generated.privateKey});}
  if(!keys?.publicKey||!keys?.privateKey)throw new Error('Push-Schlüssel nicht verfügbar');
  const jobs=await rpc('hh_claim_push');
  await Promise.all((jobs||[]).map(async(job: any)=>{
   let status=0;
   try{
    if(!allowedEndpoint(job.subscription?.endpoint)){await rpc('hh_finish_push',{p_job:job.job_id,p_status:410});return;}
    const payload=JSON.stringify({id:job.notification_id,badge_count:Math.min(9999,Math.max(0,Number(job.badge_count)||0)),badge_at:job.badge_at,title:job.kind==='new_user'?'Neue Registrierung':job.kind==='evening_cancelled'?'Kartabend abgesagt':job.kind==='friend_request'?'Neue Freundschaftsanfrage':'Neuer Kartabend',body:job.kind==='new_user'?'Ein neues Konto wurde registriert. Öffne die Kartabend-App.':job.kind==='evening_cancelled'?'Ein bestätigter Kartabend findet nicht statt. Öffne die Kartabend-App.':job.kind==='friend_request'?'Du hast eine neue Anfrage. Öffne die Kartabend-App.':'Ein Freund hat einen Kartabend eröffnet. Öffne die Kartabend-App.'});
    const details=webpush.generateRequestDetails(job.subscription,payload,{TTL:3600,urgency:'normal',contentEncoding:'aes128gcm',vapidDetails:{subject:app,publicKey:keys.publicKey,privateKey:keys.privateKey}});
    const response=await fetch(details.endpoint,{method:details.method,headers:details.headers,body:new Uint8Array(details.body!),redirect:'error',signal:AbortSignal.timeout(8000)});
    status=response.status;await response.body?.cancel();
   }catch{status=0;}
   await rpc('hh_finish_push',{p_job:job.job_id,p_status:status});
  }));
  return Response.json({ready:true},{headers:{'Cache-Control':'no-store'}});
 }catch{
  // Neither keys, subscription URLs nor private account data are logged or returned.
  return Response.json({ready:false,error:'Push-Dienst vorübergehend nicht verfügbar'},{status:503,headers:{'Cache-Control':'no-store'}});
 }
});
