export function standings(snapshot) {
  const byId = new Map(snapshot.members.map(m => [m.id, {id:m.id,name:m.name,points:0,matches:0,goals:0,assists:0}]));
  for (const doc of Object.values(snapshot.documents)) {
    if (doc.domain !== 'sport') continue;
    const {session:s,participations:parts} = doc.payload;
    if (s.status !== 'CLOSED') continue;
    for (const p of parts) {
      const row = byId.get(p.player_id);
      if (!row) continue;
      row.goals += p.goals; row.assists += p.assists;
      if (!s.is_ranked) continue;
      row.matches++;
      const drawTeams = {DRAW:['A','B'],DRAW_AB:['A','B'],DRAW_BC:['B','C'],DRAW_AC:['A','C'],DRAW_ALL:['A','B','C']};
      if (s.result === p.team) row.points += 3;
      else if (drawTeams[s.result]?.includes(p.team)) row.points += s.result === 'DRAW' ? 1 : (s.draw_points ?? 1);
    }
  }
  return [...byId.values()].sort((a,b) => b.points-a.points || b.matches-a.matches || a.name.localeCompare(b.name,'fr'));
}
