import {standings} from './summary.mjs';
const $ = id => document.getElementById(id);
let connection = null;
const initial = sessionStorage.getItem('statoo-connection');
if (initial) { try { connection = JSON.parse(initial); } catch { sessionStorage.removeItem('statoo-connection'); } }
function textNode(tag,text,className) { const node=document.createElement(tag); node.textContent=text; if(className)node.className=className; return node; }
function message(text) { $('message').textContent=text; }
async function request(path,body) {
  const controller = new AbortController(); const timer=setTimeout(()=>controller.abort(),90000);
  try {
    const response=await fetch(connection.api+path,{method:body?'POST':'GET',signal:controller.signal,
      headers:{'Content-Type':'application/json',...(connection.token?{Authorization:'Bearer '+connection.token}:{})},
      ...(body?{body:JSON.stringify(body)}:{})});
    const result=await response.json();
    if(!response.ok)throw new Error(typeof result.detail === 'string' ? result.detail : 'La demande n’a pas pu être traitée.');
    return result;
  } finally { clearTimeout(timer); }
}
function card(title, lines) {
  const node=textNode('article','', 'card'); node.append(textNode('h3',title));
  for(const line of lines) node.append(textNode('p',line));
  return node;
}
function tableRow(values) { const tr=document.createElement('tr'); for(const value of values)tr.append(textNode('td',String(value)));return tr; }
function date(value) { return new Intl.DateTimeFormat('fr-FR',{dateStyle:'medium',timeStyle:'short'}).format(new Date(value)); }
function render(data) {
  $('group-name').textContent=data.name; $('updated').textContent='Consultation actualisée à '+new Intl.DateTimeFormat('fr-FR',{timeStyle:'short'}).format(new Date());
  $('session-list').replaceChildren(); $('point-list').replaceChildren(); $('balance-list').replaceChildren(); $('standing-list').replaceChildren();
  const docs=Object.values(data.documents).sort((a,b)=>String(b.payload.played_at??b.payload.session?.played_at).localeCompare(String(a.payload.played_at??a.payload.session?.played_at)));
  for(const doc of docs) {
    if(doc.domain==='sport') {
      const s=doc.payload.session;
      if(s.status==='CANCELLED')continue;
      let names={};try{names=typeof s.team_names==='string'?JSON.parse(s.team_names):s.team_names??{};}catch{}
      const label=(names.A||'Équipe A')+' · '+(names.B||'Équipe B');
      const score=s.session_type==='TOURNAMENT_3'?('Victoires A/B/C : '+[s.wins_a,s.wins_b,s.wins_c].join(' / ')):(s.score_a??'–')+' – '+(s.score_b??'–');
      $('session-list').append(card(date(s.played_at),[label,score,s.status==='CLOSED'?'Terminée':'En cours / brouillon']));
    }else{
      const p=doc.payload,received=p.lines.reduce((n,l)=>n+l.contribution+l.penalty_paid,0)+p.donations.reduce((n,l)=>n+l.amount,0),spent=p.expenses.reduce((n,l)=>n+l.amount,0);
      $('point-list').append(card(date(p.played_at),[p.cancelled?'Annulée · Cotisations dues':'Point financier',
        'Encaissé : '+received+' F · Dépensé : '+spent+' F','Variation de caisse : '+(received-spent)+' F']));
    }
  }
  $('cash').textContent=data.finances.cash+' F';
  for(const m of data.members) {
    const balance=data.finances.members[m.id]??{contribution_balance:0,penalty_debt:0};
    $('balance-list').append(tableRow([m.name,Math.max(0,-balance.contribution_balance)+' F',Math.max(0,balance.contribution_balance)+' F',balance.penalty_debt+' F']));
  }
  for(const m of standings(data))$('standing-list').append(tableRow([m.name,m.points,m.matches,m.goals,m.assists]));
  if(!$('session-list').children.length)$('session-list').append(textNode('p','Aucune séance synchronisée pour le moment.'));
  $('login').hidden=true;$('dashboard').hidden=false;
}
async function refresh() {
  $('refresh').disabled=true;
  try { render(await request('/groups/'+encodeURIComponent(connection.group)));message(''); }
  catch(e){message(e.name==='AbortError'?'Le serveur ne répond pas encore. Réessayez dans une minute.':e.message);}
  finally{$('refresh').disabled=false;}
}
$('login-form').addEventListener('submit',async e=>{
  e.preventDefault(); $('connect').disabled=true;
  try {
    const uri=new URL($('api').value.trim());
    if(uri.protocol!=='https:' && !(uri.protocol==='http:'&&['localhost','127.0.0.1'].includes(uri.hostname)))throw new Error('Utilisez une API HTTPS.');
    connection={api:uri.href.replace(/\/$/,''),group:$('group').value.trim()};
    const login=await request('/auth/login',{group_id:connection.group,username:$('username').value.trim(),password:$('password').value});
    connection.token=login.token; sessionStorage.setItem('statoo-connection',JSON.stringify(connection));$('password').value='';
    await refresh();
  }catch(e){message(e.message);}
  finally{$('connect').disabled=false;}
});
$('refresh').addEventListener('click',refresh);
$('logout').addEventListener('click',async()=>{
  try{await request('/auth/logout',{});}catch{}
  sessionStorage.removeItem('statoo-connection');connection=null;$('dashboard').hidden=true;$('login').hidden=false;message('');
});
document.querySelectorAll('[data-tab]').forEach(button=>button.addEventListener('click',()=>{
  document.querySelectorAll('.panel').forEach(p=>p.hidden=p.id!==button.dataset.tab);
  document.querySelectorAll('[data-tab]').forEach(b=>b.classList.toggle('selected',b===button));
}));
if(connection)refresh();
