const {defineConfig}=require('@playwright/test');
module.exports=defineConfig({testDir:'.',testMatch:['screen.spec.cjs','euro.spec.cjs'],timeout:30000,workers:2,retries:0,reporter:[['list'],['html',{open:'never'}]],outputDir:'test-results',use:{baseURL:'https://127.0.0.1:4173',ignoreHTTPSErrors:true,serviceWorkers:'block',reducedMotion:'reduce',screenshot:'only-on-failure'},projects:[
 {name:'phone-chromium',use:{browserName:'chromium',viewport:{width:390,height:844},isMobile:true,hasTouch:true}},
 {name:'phone-webkit',use:{browserName:'webkit',viewport:{width:375,height:812},isMobile:true,hasTouch:true}},
 {name:'tablet-mini-webkit',use:{browserName:'webkit',viewport:{width:744,height:1133},hasTouch:true}},
 {name:'tablet-landscape-chromium',use:{browserName:'chromium',viewport:{width:1133,height:744},hasTouch:true}}
],webServer:{command:'node tests/visual/server.cjs',cwd:'../..',url:'https://127.0.0.1:4173/fixtures/login.html',ignoreHTTPSErrors:true,reuseExistingServer:false}});
