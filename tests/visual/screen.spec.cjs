const {test,expect}=require('@playwright/test');
for(const name of ['login','registration','lobby','settings','profile','request-form','game-bierkopf','game-schleifer','game-schniffelkopf','game-klopfer','game-backwards','game-schafkopf','game-krawallo'])test(name,async({page},info)=>{
 const assets=[];page.on('requestfailed',r=>assets.push({url:r.url(),failure:r.failure()?.errorText}));
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.route('**/*',route=>new URL(route.request().url()).hostname==='127.0.0.1'?route.continue():route.abort());
 await page.goto('/fixtures/'+name+'.html');await page.evaluate(()=>document.fonts.ready);
 expect(await page.locator('link[rel=stylesheet]').evaluateAll(links=>links.every(link=>!!link.sheet))).toBe(true);
 console.log('ASSETS47 '+name+' '+info.project.name+' '+JSON.stringify(await page.evaluate(()=>({images:[...document.querySelectorAll('img[src]')].filter(n=>n.getAttribute('src')&&!n.naturalWidth).map(n=>({src:n.getAttribute('src')?.slice(0,80),complete:n.complete,visible:!!n.getClientRects().length})),host:(()=>{const n=document.getElementById('hhNavigationHost');if(!n)return null;const s=getComputedStyle(n);return {display:s.display,position:s.position,top:s.top,bottom:s.bottom,height:s.height,inset:s.inset,rect:n.getBoundingClientRect().toJSON()}})()}))));
 const metrics=await page.evaluate(()=>{
  const scrolled=n=>{for(let p=n.parentElement;p;p=p.parentElement){const s=getComputedStyle(p),r=p.getBoundingClientRect();if(/auto|scroll/.test(s.overflowX)&&p.scrollWidth>p.clientWidth&&r.left>=-2&&r.right<=innerWidth+2)return true}return false};
  const visible=n=>{const r=n.getBoundingClientRect(),s=getComputedStyle(n);return r.width>0&&r.height>0&&s.display!=='none'&&s.visibility!=='hidden'};
  const navs=[...document.querySelectorAll('#hhLobbyNav,.bottom-nav,#hhTournamentPlayNav')].filter(n=>visible(n)&&!n.closest('[hidden]'));
  return{width:innerWidth,height:innerHeight,visualHeight:visualViewport?.height,docWidth:document.documentElement.scrollWidth,navs:navs.map(n=>({bottom:n.getBoundingClientRect().bottom,top:n.getBoundingClientRect().top})),controls:[...document.querySelectorAll('button,input,select')].filter(visible).filter(n=>!n.closest('[hidden],.hide')).filter(n=>{const r=n.getBoundingClientRect();return (r.right>innerWidth+2||r.left< -2)&&!scrolled(n)}).map(n=>({text:n.textContent?.slice(0,30),id:n.id,cls:n.className,parent:n.parentElement.className})),stack:[...document.querySelectorAll('#play>.panel')].filter(visible).map(n=>({top:n.getBoundingClientRect().top,left:n.getBoundingClientRect().left}))};
 });
 console.log('GEOMETRY '+name+' '+info.project.name+' '+JSON.stringify(metrics));
 if((name==='lobby'&&info.project.name==='phone-chromium')||(name==='game-schafkopf'&&info.project.name==='tablet-mini-webkit')||(name==='game-backwards'&&info.project.name==='phone-webkit')){
  const b64=(await page.screenshot({type:'jpeg',quality:60})).toString('base64');
  for(let i=0;i<b64.length;i+=6000)console.log('PREVIEW47|'+name+'|'+info.project.name+'|'+(i/6000)+'|'+b64.slice(i,i+6000));
 }
 console.log('REQUESTS47 '+name+' '+info.project.name+' '+JSON.stringify(assets));
 await info.attach('geometry',{body:JSON.stringify(metrics,null,2),contentType:'application/json'});
 expect(errors).toEqual([]);expect(metrics.docWidth).toBeLessThanOrEqual(metrics.width+2);expect(metrics.controls).toEqual([]);
 if(!['login','registration'].includes(name)){
  const nav=page.locator('#hhLobbyNav:visible,.bottom-nav:visible,#hhTournamentPlayNav:visible').first();await expect(nav).toBeVisible();
  const before=await nav.boundingBox();await page.evaluate(()=>window.scrollTo(0,document.documentElement.scrollHeight));const after=await nav.boundingBox();expect(Math.abs(after.y-before.y)).toBeLessThanOrEqual(2);expect(Math.abs(after.y+after.height-metrics.height)).toBeLessThanOrEqual(2);
 }
 await page.evaluate(()=>window.scrollTo(0,0));await page.screenshot({path:info.outputPath(name+'.png'),fullPage:true});
});
