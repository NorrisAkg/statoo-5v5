"""Preuves filtrées du groupe synthétique, sans jeton ni donnée de l'app réelle."""
import json
import sqlite3
import subprocess
from fixtures import request, PASSWORD, ROOT

adb = [r"C:\Users\ky-solutions\AppData\Local\Android\Sdk\platform-tools\adb.exe", "-s", "7522b268"]
identity = request("POST", "/auth/login", {"group_id": "qa-depart", "username": "admin", "password": PASSWORD})
snapshot = request("GET", "/groups/qa-depart", identity=identity)
proof = {"backend": {k:v for k,v in snapshot.items() if k in ["opening_approved", "opening_proposal", "opening", "documents", "audit"]}}
p = ROOT / "qa-final-readonly.db"
p.write_bytes(subprocess.check_output(adb + ["exec-out", "run-as", "com.kysolutions.statoo.qa", "cat", "databases/statoo.db"]))
c = sqlite3.connect(p)
c.row_factory = sqlite3.Row
proof["device"] = {
    "font_scale": subprocess.check_output(adb + ["shell", "settings", "get", "system", "font_scale"]).decode().strip(),
    "sessions": [dict(r) for r in c.execute("SELECT id,team_id,played_at,status FROM sessions WHERE team_id='qa-depart'")],
    "occurrences": [dict(r) for r in c.execute("SELECT key,value FROM meta WHERE key LIKE 'shared_occurrence_%' OR key LIKE 'shared_finance_alias_qa-depart_%'")],
}
c.close()
(ROOT / "preuves-filtres.json").write_text(json.dumps(proof, ensure_ascii=False, indent=2), encoding="utf-8")
print("Preuves synthétiques enregistrées ; font_scale=" + proof["device"]["font_scale"])
print("Séances du seul groupe qa-depart : " + str(len(proof["device"]["sessions"])))
