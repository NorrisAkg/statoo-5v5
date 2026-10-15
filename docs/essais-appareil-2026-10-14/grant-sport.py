"""Transfert temporaire et explicite du rôle sportif, données fictives seules."""
import json
from fixtures import request, PASSWORD, ROOT

admin = request("POST", "/auth/login", {"group_id": "qa-depart", "username": "admin", "password": PASSWORD})
state = request("GET", "/groups/qa-depart", identity=admin)
president = next(a for a in state["accounts"] if a["username"] == "president")
result = request("PUT", f"/groups/qa-depart/accounts/{president['id']}/roles", {"roles": ["PDT", "SG"], "transfer": True, "reason": "Essai QA du contrôle des rôles"}, admin)
(ROOT / "role-sport-test.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
print("Rôle SG attribué au président fictif ; ADMIN conservé par admin.")
