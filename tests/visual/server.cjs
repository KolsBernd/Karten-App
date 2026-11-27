// Loopback only; the fixture service has no route for backend writes or secrets.
const http=require('node:http'),fs=require('node:fs'),path=require('node:path');
const root=process.cwd(),fixtures=path.join(root,'tests/visual/fixtures');
http.createServer((req,res)=>{
 const pathname=decodeURIComponent(new URL(req.url,'http://127.0.0.1').pathname);
 const base=pathname.startsWith('/fixtures/')?fixtures:root;
 const relative=pathname.startsWith('/fixtures/')?pathname.slice(10):pathname.slice(1);
 const file=path.resolve(base,relative);const experiment=pathname==='/schafkopf-euro.html'||pathname==='/schafkopf-euro.js';
 if(req.method!=='GET'||!file.startsWith(base+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile()||(!['.html','.pdf','.css','.svg','.png','.jpg','.jpeg','.webp'].includes(path.extname(file))&&pathname!=='/schafkopf-euro.js')){res.writeHead(404);res.end();return}
 res.setHeader('Content-Type',({'.pdf':'application/pdf','.js':'application/javascript','.html':'text/html','.css':'text/css','.svg':'image/svg+xml','.png':'image/png','.jpg':'image/jpeg','.jpeg':'image/jpeg','.webp':'image/webp'})[path.extname(file)]);
 res.setHeader('Content-Security-Policy',"default-src 'self' data:; script-src "+(experiment?"'self'":"'none'")+"; connect-src 'none'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; frame-src "+(pathname==='/fixtures/euro-frame.html'?"'self'":"'none'")+"");
 fs.createReadStream(file).pipe(res);
}).listen(4173,'127.0.0.1');
