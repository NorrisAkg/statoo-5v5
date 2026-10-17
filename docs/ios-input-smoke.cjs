const {createServer}=require('node:http');
const {readFileSync}=require('node:fs');
const {join,extname}=require('node:path');
const {chromium}=require('playwright');
(async()=>{
const root=join(process.cwd(),'mobile/build/web');
const mime={'.html':'text/html','.js':'application/javascript','.css':'text/css','.wasm':'application/wasm','.json':'application/json','.png':'image/png','.ttf':'font/ttf'};
const server=createServer((req,res)=>{try{const path=join(root,new URL(req.url,'http://localhost').pathname==='/'?'index.html':new URL(req.url,'http://localhost').pathname);let data=readFileSync(path);if(path.endsWith('pwa-shell.css'))data=Buffer.from(data.toString().replace(/@supports\s*\(-webkit-touch-callout:\s*none\)/g,'@media all'));res.setHeader('Content-Type',mime[extname(path)]||'application/octet-stream');res.end(data);}catch{res.writeHead(404).end();}});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const b=await chromium.launch({channel:'chrome',headless:true});
try{const p=await b.newPage({viewport:{width:390,height:844},deviceScaleFactor:3});p.setDefaultTimeout(45000);await p.goto('http://127.0.0.1:'+server.address().port);await p.getByRole('button',{name:'Passer',exact:true}).click();await p.getByRole('button',{name:'Créer un groupe',exact:true}).click();const input=p.locator('input[data-semantics-role="text-field"]').first();await input.waitFor();await input.fill('Équipe QA iPhone');await p.keyboard.press('Tab');console.log(await input.evaluate(e=>({font:getComputedStyle(e).fontSize,value:e.value,semantic:e.dataset.semanticsRole,width:innerWidth,scale:visualViewport.scale})));await p.screenshot({path:'docs/ios-input-flutter.png'});if(await input.evaluate(e=>getComputedStyle(e).fontSize)!=='16px')throw Error('unsafe font');if(await input.inputValue()!=='Équipe QA iPhone')throw Error('value lost');}finally{await b.close();server.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
