import {standings} from '../../web/summary.mjs';
const members=[{id:'a',name:'Alice'},{id:'b',name:'Benoît'}];
const documents={};
// Alice : une victoire, une défaite = 3 points, 2 matchs.
// Benoît : trois nuls = 3 points, 3 matchs. Le départage mobile privilégie les victoires.
for (const [id,player,result] of [['a1','a','A'],['a2','a','B'],['b1','b','DRAW'],['b2','b','DRAW'],['b3','b','DRAW']]) {
  documents[id]={domain:'sport',payload:{session:{status:'CLOSED',is_ranked:true,result},participations:[{player_id:player,team:'A',goals:0,assists:0}]}};
}
console.log(JSON.stringify({observed:standings({members,documents}),expectedOrderMatchingMobile:['Alice','Benoît']},null,2));
