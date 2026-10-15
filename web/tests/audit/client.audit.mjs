import test, {after} from 'node:test';
import assert from 'node:assert/strict';
import {mkdirSync,writeFileSync} from 'node:fs';
import {PortalClient} from '../../client.mjs';
import {prepareSport,palette} from '../../domain.mjs';
import {standings} from '../../summary.mjs';
const results=[];
after(()=>{const dir=new URL('../../../docs/audit-pwa-2026-10-15/',import.meta.url);mkdirSync(dir,{recursive:true});writeFileSync(new URL('client-results.json',dir),JSON.stringify(results,null,2)+'\n');});
function memory(){const data=new Map();return {get length(){return data.size;},key:i=>[...data.keys()][i],getItem:k=>data.get(k)??null,setItem:(k,v)=>data.set(k,v),removeItem:k=>data.delete(k)};}
const json=(value,status=200)=>new Response(JSON.stringify(value),{status,headers:{'Content-Type':'application/json'}});
const account={id:'me',roles:['ADMIN','SG','TR'],shared:false};
async function setup(){const c=new PortalClient({storage:memory(),session:memory(),fetch:async url=>url.endsWith('/auth/login')?json({group_id:'g',token:'synthetic-test',expires_at:'2099-01-01T00:00:00Z',account}):json({name:'Fixture audit',account,members:[],documents:{},finances:{cash:0,members:{}}})});await c.connect('https://example.test','g','admin','synthetic-password');return c;}

test('AUD-03 accepted administrative write remains a success if refresh fails',async()=>{
  const c=await setup();let writes=0;c.fetch=async(url,options)=>{if(options.method==='POST'){writes++;return json({ok:true});}throw Error('Lecture indisponible');};
  let result,error;try{result=await c.mutate('/opening',{cash:100,members:{}});}catch(e){error=e.message;}
  results.push({id:'AUD-03',writes,result:result??null,error:error??null});assert.equal(result?.ok,true,'Écriture acceptée mais présentée comme échouée : '+error);
});
test('AUD-04 out-of-order refresh does not roll back displayed data',async()=>{
  const c=await setup();const resolve=[];c.fetch=()=>new Promise(done=>resolve.push(done));const older=c.refresh(),newer=c.refresh();
  resolve[1](json({name:'Révision récente',account,members:[],documents:{},finances:{cash:500,members:{}}}));await newer;
  resolve[0](json({name:'Ancienne révision',account,members:[],documents:{},finances:{cash:100,members:{}}}));await older;
  results.push({id:'AUD-04',expectedCash:500,actualCash:c.snapshot.finances.cash});assert.equal(c.snapshot.finances.cash,500);
});
test('AUD-05 standings tie-break follows the mobile win priority',()=>{
  const doc=(id,result,players)=>({domain:'sport',payload:{session:{id,status:'CLOSED',is_ranked:1,result},participations:players.map(([player_id,team])=>({player_id,team,goals:0,assists:0}))}});
  const data={members:[{id:'win',name:'Zaki'},{id:'draw',name:'Amine'}],documents:{win:doc('win','A',[['win','A']]),d1:doc('d1','DRAW',[['draw','A']]),d2:doc('d2','DRAW',[['draw','A']]),d3:doc('d3','DRAW',[['draw','A']])}};
  const order=standings(data).map(m=>m.name);results.push({id:'AUD-05',expected:['Zaki','Amine'],actual:order});assert.deepEqual(order,['Zaki','Amine']);
});
test('AUD-06 web does not silently close a one-player match below mobile default minimum',()=>{
  const p={session:{id:'s',team_id:'g',played_at:'2026-10-15T20:00',session_type:'CLASSIC_2',score_a:0,score_b:0,team_colors:{A:palette.Bleu,B:palette.Orange}},participations:[{id:'p',player_id:'a',session_id:'s',team:'A',goals:0,assists:0}]};
  let rejected=false;try{prepareSport(p,[{id:'a',name:'Alice'}],'CLOSED');}catch{rejected=true;}
  results.push({id:'AUD-06',mobileDefaultMinimum:6,webAcceptedSinglePlayer:!rejected});assert.equal(rejected,true,'Le web accepte une clôture à un joueur. Le minimum de groupe n’est pas transmis par l’API.');
});
test('AUD-11 non-JSON proxy error is translated into a user-facing service message',async()=>{
  const c=await setup();c.fetch=async()=>new Response('<html>Service unavailable</html>',{status:503,headers:{'Content-Type':'text/html'}});
  let error;try{await c.refresh();}catch(e){error=e.message;}
  results.push({id:'AUD-11',message:error});assert.match(error,/serveur|indisponible|réessay/i);
});
