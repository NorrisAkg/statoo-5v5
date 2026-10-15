"""Corrige une collision dans les identifiants synthétiques, dans QA uniquement."""
raise SystemExit("Montage retiré : la copie directe de base a invalidé l'état local de test. Utiliser l'import UI avec des identifiants synthétiques uniques ; voir rapport.md.")
import subprocess
import sqlite3
from pathlib import Path

ADB = r"C:\Users\ky-solutions\AppData\Local\Android\Sdk\platform-tools\adb.exe"
BASE = [ADB, "-s", "7522b268"]
PACKAGE = "com.kysolutions.statoo.qa"
ROOT = Path(__file__).resolve().parent
subprocess.run(BASE + ["shell", "am", "force-stop", PACKAGE], check=True)
p = ROOT / "qa-fixture-namespaced.db"
p.write_bytes(subprocess.check_output(BASE + ["exec-out", "run-as", PACKAGE, "cat", "databases/statoo.db"]))
c = sqlite3.connect(p)
c.execute("PRAGMA foreign_keys=OFF")
rows = c.execute("SELECT id FROM players WHERE team_id='qa-alpha'").fetchall()
for (old,) in rows:
    if old not in list("abcdef"):
        continue
    new = "alpha-" + old
    c.execute("UPDATE players SET id=? WHERE id=? AND team_id='qa-alpha'", (new, old))
    c.execute("UPDATE participations SET player_id=? WHERE player_id=? AND session_id IN (SELECT id FROM sessions WHERE team_id='qa-alpha')", (new, old))
c.commit()
assert c.execute("PRAGMA foreign_key_check").fetchall() == []
assert c.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
c.close()
subprocess.run(BASE + ["shell", "run-as", PACKAGE, "sh", "-c", "'cat > databases/statoo.db'"], input=p.read_bytes(), check=True)
print("Identifiants de six joueurs fictifs QA Alpha préfixés ; intégrité et références vérifiées.")
