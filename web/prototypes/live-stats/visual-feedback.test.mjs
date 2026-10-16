import test from 'node:test';
import assert from 'node:assert/strict';
import {chromium} from 'playwright';
import {createDemo,record} from './model.mjs';
test('LIVE-28/29 empty scorer camps stay blank and match keeps team gradient',async()=>{
 const b=await chromium.launch({channel:'chrome',headless:true});
 try {
  for(const colorScheme of ['light','dark']){
   const p=await b.newPage({viewport:{width:393,height:852},colorScheme});
   await p.goto('http://127.0.0.1:19094/prototypes/live-stats/');
   assert.doesNotMatch(await p.locator('#scorers').innerText(),/Aucun but/);
   await p.getByRole('button',{name:'Match · 2 équipes',exact:true}).click();
   assert.equal(await p.locator('#scorers').isVisible(),false);
   const bg=await p.locator('.context').evaluate(n=>getComputedStyle(n).backgroundImage);
   assert.match(bg,/linear-gradient/);
   await p.getByRole('button',{name:'Ajouter un but',exact:true}).click();
   await p.getByRole('button',{name:'Karim Benali',exact:true}).click();
   await p.getByRole('button',{name:'Aucun passeur',exact:true}).click();
   assert.equal(await p.locator('#scorers').isVisible(),true);
   assert.equal(await p.locator('.scorer-grid > section').nth(1).innerText(),'');
   await p.getByRole('button',{name:'Annuler la dernière action',exact:true}).click();
   assert.equal(await p.locator('#scorers').isVisible(),false);
   assert.equal(await p.locator('#match-score').innerText(),'0 – 0');
   await p.close();
  }
 }finally{await b.close();}
});
test('LIVE-23/24/25 restore identities and compact scorer notation',async()=>{
 const b=await chromium.launch({channel:'chrome',headless:true});
 try {
  const p=await b.newPage();
  let s=createDemo('classic');
  for(const player of ['a1','a1','a2',null]) s=record(s,{type:'goal',team:'A',player});
  await p.addInitScript(s=>localStorage.setItem('statoo-live-prototype:classic',JSON.stringify(s)),s);
  await p.goto('http://127.0.0.1:19094/prototypes/live-stats/');
  await p.getByRole('button',{name:'Match · 2 équipes',exact:true}).click();
  assert.equal(await p.locator('.classic-scoreboard .team-crest').count(),2);
  assert.equal(await p.locator('#scorers h3, #scorers h4').count(),0);
  const rows=p.locator('#scorers .scorer-row');
  assert.equal(await rows.count(),3);
  assert.match(await rows.nth(0).innerText(),/Karim Benali.*x2/s);
  assert.doesNotMatch(await rows.nth(1).innerText(),/x1/);
  assert.equal(await rows.nth(1).locator('svg').count(),1);
  assert.match(await rows.nth(0).getAttribute('aria-label'),/2 buts/);
  assert.equal(await p.locator('#match-score').innerText(),'4 – 0');
 }finally{await b.close();}
});
test('LIVE-26 active tab has a unique visible marker that follows selection',async()=>{
 const b=await chromium.launch({channel:'chrome',headless:true});
 try{
  const p=await b.newPage({viewport:{width:393,height:852}});
  await p.goto('http://127.0.0.1:19094/prototypes/live-stats/');
  assert.equal(await p.locator('#teams .active-marker').count(),1);
  for(const name of ['Union des Cèdres','Sporting du Port','Racing Atlas']){
   await p.getByRole('tab',{name,exact:true}).click();
   assert.equal(await p.locator('#selected-name').innerText(),name);
   assert.match(await p.locator('#teams [aria-selected="true"]').innerText(),/✓ Actif/);
  }
 }finally{await b.close();}
});
