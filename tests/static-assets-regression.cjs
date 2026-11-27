const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const html=fs.readFileSync('index.html','utf8');let count=0;
for(const m of html.matchAll(/<(?:script|link)\b[^>]*>/gi)){
 const a=/\b(?:src|href)=["']([^"']+)["']/.exec(m[0]);if(!a||/^(?:https?:|data:|#)/.test(a[1]))continue;
 const file=decodeURIComponent(a[1].split(/[?#]/)[0]);if(!file)continue;assert(fs.statSync(path.resolve(file)).isFile(),'Missing local dependency: '+file);count++;
}
assert(html.includes('src="supabase-2.50.0.min.js"'));assert(!/supabase-2\.(?:51|52|53)\.0/.test(html));
console.log('PASS real local scripts and styles exist; vendor version is independent of app version ('+count+' paths).');
