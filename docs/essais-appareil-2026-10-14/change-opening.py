"""Modification concurrente synthétique pendant le récapitulatif Android."""
import json
from fixtures import request, PASSWORD, ROOT

tr = request("POST", "/auth/login", {"group_id": "qa-depart", "username": "tresorier", "password": PASSWORD})
before = request("GET", "/groups/qa-depart", identity=tr)
proposal = {"cash": 1200, "start_date": "2026-10-01", "members": {"a": {"contribution_balance": 200, "penalty_debt": 30}, "b": {"contribution_balance": -100, "penalty_debt": 0}}}
request("POST", "/groups/qa-depart/opening", proposal, tr)
after = request("GET", "/groups/qa-depart", identity=tr)
proof = {"before": {k:v for k,v in before.items() if k.startswith("opening")}, "after": {k:v for k,v in after.items() if k.startswith("opening")}}
(ROOT / "opening-concurrence.json").write_text(json.dumps(proof, ensure_ascii=False, indent=2), encoding="utf-8")
print("Proposition fictive remplacée : caisse 1 000 -> 1 200 F. Preuve enregistrée.")
