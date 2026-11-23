const {test,expect}=require('@playwright/test');
for(const name of ['login','registration','lobby','settings','profile','request-form','game-bierkopf','game-schleifer','game-schniffelkopf','game-klopfer','game-backwards','game-schafkopf','game-krawallo','krawallo-teams'])test(name,async({page},info)=>{
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.route('**/*',route=>new URL(route.request().url()).hostname==='127.0.0.1'?route.continue():route.abort());
 await page.goto('/fixtures/'+name+'.html');await page.evaluate(()=>document.fonts.ready);
 expect(await page.locator('link[rel=stylesheet]').evaluateAll(links=>links.every(link=>!!link.sheet&&link.sheet.cssRules.length>0))).toBe(true);
 expect(await page.locator('img[src]').evaluateAll(images=>images.filter(img=>img.getAttribute('src')&&!img.naturalWidth).map(img=>img.getAttribute('src')?.slice(0,80)))).toEqual([]);
 if(name.startsWith('game-')){
  const title=page.locator('#hhCurrentRoomTitle');
  if(await title.isVisible())expect(await title.evaluate(n=>getComputedStyle(n).whiteSpace)).toBe('nowrap');
 }
 const metrics=await page.evaluate(()=>{
  const scrolled=n=>{for(let p=n.parentElement;p;p=p.parentElement){const s=getComputedStyle(p),r=p.getBoundingClientRect();if(/auto|scroll/.test(s.overflowX)&&p.scrollWidth>p.clientWidth&&r.left>=-2&&r.right<=innerWidth+2)return true}return false};
  const visible=n=>{const r=n.getBoundingClientRect(),s=getComputedStyle(n);return r.width>0&&r.height>0&&s.display!=='none'&&s.visibility!=='hidden'};
  const navs=[...document.querySelectorAll('#hhLobbyNav,.bottom-nav,#hhTournamentPlayNav')].filter(n=>visible(n)&&!n.closest('[hidden]'));
  return{width:innerWidth,height:innerHeight,visualHeight:visualViewport?.height,docWidth:document.documentElement.scrollWidth,navs:navs.map(n=>({bottom:n.getBoundingClientRect().bottom,top:n.getBoundingClientRect().top})),controls:[...document.querySelectorAll('button,input,select')].filter(visible).filter(n=>!n.closest('[hidden],.hide')).filter(n=>{const r=n.getBoundingClientRect();return (r.right>innerWidth+2||r.left< -2)&&!scrolled(n)}).map(n=>({text:n.textContent?.slice(0,30),id:n.id,cls:n.className,parent:n.parentElement.className})),stack:[...document.querySelectorAll('#play>.panel')].filter(visible).map(n=>({top:n.getBoundingClientRect().top,bottom:n.getBoundingClientRect().bottom,left:n.getBoundingClientRect().left}))};
 });
 if(['game-krawallo','krawallo-teams'].includes(name)&&['phone-webkit','tablet-mini-webkit'].includes(info.project.name)){
  const b64=(await (name==='krawallo-teams'?page.locator('#hhKrawalloTeams').screenshot({type:'jpeg',quality:75}):page.screenshot({type:'jpeg',quality:65}))).toString('base64');
  for(let i=0;i<b64.length;i+=6000)console.log('PREVIEW48|'+name+'|'+info.project.name+'|'+(i/6000)+'|'+b64.slice(i,i+6000));
 }
 await info.attach('geometry',{body:JSON.stringify(metrics,null,2),contentType:'application/json'});
 if(name==='krawallo-teams')expect(await page.locator('.kw-roster .extra-player-choice').evaluateAll(buttons=>buttons.every(b=>{const r=b.getBoundingClientRect(),f=b.querySelector('.hh-selection-face').getBoundingClientRect();return f.left>=r.left-1&&f.right<=r.right+1&&f.width>=55&&f.height>=55}))).toBe(true);
 if(name==='game-krawallo')expect(await page.locator('.kw-person').evaluateAll(people=>people.every(p=>{const r=p.getBoundingClientRect(),a=p.querySelector('.avatar-action').getBoundingClientRect();return a.left>=r.left-1&&a.right<=r.right+1&&a.width>=35&&a.height>=35}))).toBe(true);
 expect(errors).toEqual([]);expect(metrics.docWidth).toBeLessThanOrEqual(metrics.width+2);expect(metrics.controls).toEqual([]);
 if(['game-bierkopf','game-schleifer'].includes(name))for(let i=1;i<metrics.stack.length;i++)expect(metrics.stack[i].top).toBeGreaterThanOrEqual(metrics.stack[i-1].bottom-1);
 if(!['login','registration'].includes(name)){
  const nav=page.locator('#hhLobbyNav:visible,.bottom-nav:visible,#hhTournamentPlayNav:visible').first();await expect(nav).toBeVisible();
  const before=await nav.boundingBox();await page.evaluate(()=>window.scrollTo(0,document.documentElement.scrollHeight));const after=await nav.boundingBox();expect(Math.abs(after.y-before.y)).toBeLessThanOrEqual(2);expect(Math.abs(after.y+after.height-metrics.height)).toBeLessThanOrEqual(2);
 }
 await page.evaluate(()=>window.scrollTo(0,0));await page.screenshot({path:info.outputPath(name+'.png'),fullPage:true});
});
