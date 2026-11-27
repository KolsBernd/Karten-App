// Loopback only; the fixture service has no route for backend writes or secrets.
const https=require('node:https'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),{execFileSync}=require('node:child_process');
const root=process.cwd(),fixtures=path.join(root,'tests/visual/fixtures');
// WebKit upgrades insecure scripts under the production CSP. Serve the fixture
// over HTTPS too; only this ephemeral loopback certificate is trusted by tests.
const certDir=fs.mkdtempSync(path.join(os.tmpdir(),'kartabend-test-https-'));
const key=path.join(certDir,'key.pem'),cert=path.join(certDir,'cert.pem');
execFileSync('openssl',['req','-x509','-newkey','rsa:2048','-nodes','-keyout',key,'-out',cert,'-days','1','-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost,IP:127.0.0.1'],{stdio:'ignore'});
process.on('exit',()=>fs.rmSync(certDir,{recursive:true,force:true}));
https.createServer({key:fs.readFileSync(key),cert:fs.readFileSync(cert)},(req,res)=>{
 const pathname=decodeURIComponent(new URL(req.url,'http://127.0.0.1').pathname);
 const financial=pathname==='/fixtures/euro-room.html';const base=pathname.startsWith('/fixtures/')&&!financial?fixtures:root;
 const relative=financial?'tests/visual/euro-room-shell.html':pathname.startsWith('/fixtures/')?pathname.slice(10):pathname.slice(1);
 const file=path.resolve(base,relative);const appEntry=pathname==='/index.html';const experiment=financial||pathname==='/schafkopf-euro.html'||pathname==='/schafkopf-euro.js';
 if(req.method!=='GET'||!file.startsWith(base+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile()||(!['.js','.html','.pdf','.css','.svg','.png','.jpg','.jpeg','.webp'].includes(path.extname(file))&&pathname!=='/schafkopf-euro.js')){res.writeHead(404);res.end();return}
 res.setHeader('Content-Type',({'.pdf':'application/pdf','.js':'application/javascript','.html':'text/html','.css':'text/css','.svg':'image/svg+xml','.png':'image/png','.jpg':'image/jpeg','.jpeg':'image/jpeg','.webp':'image/webp'})[path.extname(file)]);
 res.setHeader('Content-Security-Policy',"default-src 'self' data:; script-src "+(appEntry?"'self' 'unsafe-inline'":experiment?"'self'":"'none'")+"; connect-src 'none'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; frame-src "+(pathname==='/fixtures/euro-frame.html'?"'self'":"'none'")+"");
 fs.createReadStream(file).pipe(res);
}).listen(4173,'127.0.0.1');
