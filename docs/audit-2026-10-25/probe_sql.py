"""AUD-17 : benchmark SQLite synthétique, sans base utilisateur."""
import json
import re
import sqlite3
import statistics
import time
from pathlib import Path

root = Path(__file__).resolve().parents[2]
source = (root/'mobile/lib/core/data/app_database.dart').read_text()
source = source[source.index('Future<void> _createSchema'):source.index('Future<void> seedDemoData')]
db = sqlite3.connect(':memory:')
db.execute('PRAGMA foreign_keys=ON')
for sql in re.findall("await db.execute\\('''(.*?)'''\\);", source, re.S):
    db.executescript(sql)
db.execute("INSERT INTO teams(id,name,created_at) VALUES('audit','Audit','2026-10-25')")
for i in range(50):
    db.execute("INSERT INTO players(id,team_id,name,created_at,updated_at) VALUES(?, 'audit', ?, '2026-10-25','2026-10-25')",(str(i),'Joueur '+str(i)))
for s in range(500):
    db.execute("INSERT INTO sessions(id,team_id,played_at,status,score_a,score_b,result) VALUES(?,'audit','2026-10-25','CLOSED',0,0,'DRAW')",(str(s),))
    for p in range(10):
        player=(s+p)%50
        db.execute("INSERT INTO participations(id,session_id,player_id,team) VALUES(?,?,?,?)",(f'{s}-{p}',str(s),str(player),'A' if p<5 else 'B'))
db.commit()
results={}
for view in ['v_standings','v_standings_per_match','v_top_scorers','v_top_assists','v_top_cards','v_group_totals']:
    timings=[]
    for _ in range(10):
        start=time.perf_counter()
        rows=db.execute(f'SELECT * FROM {view} WHERE team_id=?',('audit',)).fetchall()
        timings.append((time.perf_counter()-start)*1000)
    results[view]={'rows':len(rows),'median_ms':round(statistics.median(timings),2),'max_ms':round(max(timings),2)}
print(json.dumps({'scope':'Python SQLite memory, 50 players / 500 sessions / 5000 participations; not a device benchmark',
                  'sqlite_version':sqlite3.sqlite_version,'queries':results},indent=2))
