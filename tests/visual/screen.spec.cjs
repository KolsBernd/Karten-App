const {test,expect}=require('@playwright/test');
for(const name of ['login','lobby','game-bierkopf','game-schleifer','game-schniffelkopf','game-klopfer','game-backwards','game-schafkopf','game-krawallo'])test(name,async({page},info)=>{
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.route('**/*',route=>new URL(route.request().url()).hostname==='127.0.0.1'?route.continue():route.abort());
 await page.goto('/fixtures/'+name+'.html');await page.evaluate(()=>document.fonts.ready);
 const metrics=await page.evaluate(()=>{
  const visible=n=>{const r=n.getBoundingClientRect(),s=getComputedStyle(n);return r.width>0&&r.height>0&&s.display!=='none'&&s.visibility!=='hidden'};
  const navs=[...document.querySelectorAll('#hhLobbyNav,.bottom-nav,#hhTournamentPlayNav')].filter(n=>visible(n)&&!n.closest('[hidden]'));
  return{width:innerWidth,docWidth:document.documentElement.scrollWidth,navs:navs.map(n=>({bottom:n.getBoundingClientRect().bottom,top:n.getBoundingClientRect().top})),controls:[...document.querySelectorAll('button,input,select')].filter(visible).filter(n=>!n.closest('[hidden],.hide')).filter(n=>{const r=n.getBoundingClientRect();return r.right>innerWidth+2||r.left< -2}).map(n=>({text:n.textContent?.slice(0,30),id:n.id})),stack:[...document.querySelectorAll('#play>.panel')].filter(visible).map(n=>({top:n.getBoundingClientRect().top,left:n.getBoundingClientRect().left}))};
 });
 await info.attach('geometry',{body:JSON.stringify(metrics,null,2),contentType:'application/json'});
 expect(errors).toEqual([]);expect(metrics.docWidth).toBeLessThanOrEqual(metrics.width+2);expect(metrics.controls).toEqual([]);
 if(name!=='login'){
  const nav=page.locator('#hhLobbyNav:visible,.bottom-nav:visible,#hhTournamentPlayNav:visible').first();await expect(nav).toBeVisible();
  const before=await nav.boundingBox();await page.evaluate(()=>window.scrollTo(0,document.documentElement.scrollHeight));const after=await nav.boundingBox();expect(Math.abs(after.y-before.y)).toBeLessThanOrEqual(2);expect(Math.abs(after.y+after.height-page.viewportSize().height)).toBeLessThanOrEqual(2);
 }
 await page.evaluate(()=>window.scrollTo(0,0));await page.screenshot({path:info.outputPath(name+'.png'),fullPage:true});
});
