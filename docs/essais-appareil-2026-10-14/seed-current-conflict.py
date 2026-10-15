"""Ajoute deux versions financières au seul groupe fictif qa-depart."""
import copy
import uuid
from fixtures import request, PASSWORD, MEMBERS

for username, label, amount in [("tresorier", "Terrain QA", 30), ("vice", "Eau QA", 80)]:
    identity = request("POST", "/auth/login", {"group_id": "qa-depart", "username": username, "password": PASSWORD})
    point = {"played_at": "2026-10-14T18:00:00", "rate": 100, "cancelled": False, "lines": [{"member_id": m["id"], "contribution": 100, "penalty_due": 20 if m["id"] == "a" else 0, "penalty_paid": 10 if m["id"] == "a" else 0, "reason": "Retard QA" if m["id"] == "a" else ""} for m in MEMBERS], "donations": [{"id": "don", "label": "Soutien QA", "amount": 40}], "expenses": [{"id": "expense", "label": label, "amount": amount}]}
    result = request("POST", "/groups/qa-depart/sync", {"operation_id": str(uuid.uuid4()), "occurrence_id": "qa-finance", "domain": "finance", "base_revision": 0, "generation": 0, "payload": copy.deepcopy(point), "reason": "Version QA"}, identity)
    print(username, result["status"])
