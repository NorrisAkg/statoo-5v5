import { chromium } from '../node_modules/playwright/index.mjs';
import { mkdirSync, writeFileSync } from 'node:fs';
const out = new URL('./comparaison-web-mobile-2026-10-15/', import.meta.url);
mkdirSync(out, {recursive:true});
const results=[];
const browser=await chromium.launch({channel:'chrome',headless:true});
try {
 for(const width of [390,1440]) {
  const context=await browser.newContext({viewport:{width,height:900}});
  const page=await context.newPage();
  const account={id:'me',roles:['ADMIN','SG','TR'],shared:false};
  const snapshot={name:'Les amis du terrain',account,members:Array.from({length:24},(_,i)=>({id:'m'+i,name:'Joueur '+String(i+1).padStart(2,'0'),is_active:1})),leaders:[],accounts:[],opening:null,opening_proposal:null,documents:{},obligations:{},finances:{cash:0,members:{}},financial_settings:{contribution:100,late_penalty:0}};
  await page.route('**/groups/g',r=>r.fulfill({json:snapshot}));
  await page.addInitScript(({account})=>{
   sessionStorage.setItem('statoo-connection',JSON.stringify({api:location.origin,group:'g',token:'synthetic',expires_at:'2099-01-01T00:00:00Z',account}));
   const original=window.setInterval;
   window.setInterval=(fn,ms,...args)=>{if(ms===45000)window.auditRefresh=fn;return original(fn,ms,...args)};
  },{account});
  await page.goto('http://127.0.0.1:18085/portal/');
  await page.getByRole('heading',{name:snapshot.name,exact:true}).waitFor();
  await page.screenshot({path:new URL(`home-${width}.png`,out).pathname,fullPage:true});
  results.push({id:'CMP-01',width,bodyWidth:await page.evaluate(()=>document.body.scrollWidth),viewport:width});
  await page.getByRole('button',{name:'Séances',exact:true}).click();
  const search=page.getByLabel('Rechercher une séance',{exact:true});
  await search.fill('Tournoi recherché');
  await page.evaluate(()=>window.auditRefresh());
  await page.waitForTimeout(200);
  results.push({id:'CMP-02',width,searchAfter:await page.getByLabel('Rechercher une séance',{exact:true}).inputValue(),focusAfter:await page.evaluate(()=>document.activeElement.tagName)});
  await page.reload();await page.getByRole('heading',{name:snapshot.name,exact:true}).waitFor();
  results.push({id:'CMP-05',width,currentTab:await page.locator('nav [aria-current]').innerText()});
  await page.getByRole('button',{name:'Membres',exact:true}).click();
  await page.screenshot({path:new URL(`members-${width}.png`,out).pathname,fullPage:true});
  await page.getByRole('button',{name:'Nouvelle séance',exact:true}).click();
  const dialog=page.getByRole('dialog');
  results.push({id:'CMP-04',width,ariaLabel:await dialog.getAttribute('aria-label'),ariaLabelledby:await dialog.getAttribute('aria-labelledby')});
  const present=page.getByLabel('Présent : Joueur 01',{exact:true});
  await present.focus();await present.press('Space');
  results.push({id:'CMP-03',width,focusAfter:await page.evaluate(()=>({tag:document.activeElement.tagName,label:document.activeElement.getAttribute('aria-label')}))});
  results.push({id:'CMP-07',width,inputCount:await dialog.locator('input,select,textarea').count(),searchCount:await dialog.locator('input[type=search]').count(),selectAllButtons:await dialog.getByRole('button',{name:/tout sélectionner|sélectionner tous/i}).count()});
  await page.screenshot({path:new URL(`sport-${width}.png`,out).pathname,fullPage:true});
  await page.getByRole('button',{name:'Fermer',exact:true}).click();
  await page.getByRole('button',{name:'Finances',exact:true}).click();
  await page.getByRole('button',{name:'Proposer les soldes initiaux',exact:true}).click();
  await page.getByLabel('Caisse initiale',{exact:true}).fill('450');
  await page.getByRole('button',{name:'Fermer',exact:true}).click();
  await page.getByRole('button',{name:'Proposer les soldes initiaux',exact:true}).click();
  results.push({id:'CMP-06',width,reopenedCash:await page.getByLabel('Caisse initiale',{exact:true}).inputValue()});
  await context.close();
 }
} finally {await browser.close();writeFileSync(new URL('results.json',out),JSON.stringify(results,null,2)+'\n');}
