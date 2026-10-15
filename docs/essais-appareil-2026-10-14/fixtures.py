"""Données synthétiques uniquement : fichiers de sauvegarde et backend QA local."""
import copy
import json
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PASSWORD = "Test-Password-2026"
MEMBERS = [{"id": i, "name": n} for i, n in zip("abcdef", ["Alice QA", "Benoit QA", "Camille QA", "Diane QA", "Eli QA", "Farid QA"])]
NOW = "2026-10-14T10:00:00"


def backup():
    groups = [{"id": "qa-alpha", "name": "QA Alpha", "format": "5v5", "created_at": NOW}, {"id": "qa-beta", "name": "QA Beta", "format": "5v5", "created_at": NOW}]
    players = [{"id": m["id"], "team_id": "qa-alpha", "name": m["name"], "is_active": 1, "created_at": NOW, "updated_at": NOW} for m in MEMBERS]
    sessions = []
    participations = []
    for index, result, wins in [(1, "A", [3, 1, 0]), (2, "DRAW_ALL", [2, 2, 2])]:
        sid = f"qa-tournament-{index}"
        sessions.append({"id": sid, "team_id": "qa-alpha", "played_at": f"2026-10-13T{17+index}:00:00", "status": "CLOSED", "session_type": "TOURNAMENT_3", "is_ranked": 1, "wins_a": wins[0], "wins_b": wins[1], "wins_c": wins[2], "result": result, "score_a": None, "score_b": None, "team_names": json.dumps({"A": "Lions QA", "B": "Aigles QA", "C": "Tigres QA"})})
        for j, m in enumerate(MEMBERS):
            participations.append({"id": f"pt-{sid}-{m['id']}", "session_id": sid, "player_id": m["id"], "team": "ABC"[j // 2], "goals": 0, "assists": 0, "yellow_cards": 0, "red_cards": 0})
    for player in players:
        player['id'] = 'alpha-' + player['id']
    for participation in participations:
        participation['player_id'] = 'alpha-' + participation['player_id']
    return {"app": "statoo_5v5", "version": 2, "exported_at": NOW, "team": groups[0], "teams": groups, "players": players, "sessions": sessions, "participations": participations, "meta": {"active_team_id": "qa-alpha"}, "settings": {"min_players_per_session": 2}}


def request(method, path, body=None, identity=None):
    headers = {"Content-Type": "application/json"}
    if identity:
        headers["Authorization"] = "Bearer " + identity["token"]
    wire = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request("http://127.0.0.1:19091" + path, data=wire, headers=headers, method=method)
    with urllib.request.urlopen(req) as response:
        return json.load(response)


def seed_server():
    identities = {}
    for group in ["qa-depart", "qa-conflits"]:
        admin = request("POST", "/groups", {"group_id": group, "name": group, "username": "admin", "password": PASSWORD, "shared_username": "membres", "shared_password": PASSWORD, "members": MEMBERS})
        identities[group] = {"admin": admin}
        for user, member, roles in [("president", "a", ["PDT"]), ("sport", "b", ["SG"]), ("tresorier", "c", ["TR"]), ("vice", "d", ["VP", "SGA", "TGA"])]:
            request("POST", f"/groups/{group}/accounts", {"username": user, "password": PASSWORD, "member_id": member, "roles": roles}, admin)
            identities[group][user] = request("POST", "/auth/login", {"group_id": group, "username": user, "password": PASSWORD})
        identities[group]["membres"] = request("POST", "/auth/login", {"group_id": group, "username": "membres", "password": PASSWORD})
        proposal = {"cash": 1000, "start_date": "2026-10-01", "members": {"a": {"contribution_balance": 200, "penalty_debt": 30}, "b": {"contribution_balance": -100, "penalty_debt": 0}}}
        request("POST", f"/groups/{group}/opening", proposal, identities[group]["tresorier"])
        if group == "qa-conflits":
            proposal = request("GET", f"/groups/{group}", identity=identities[group]["president"])["opening_proposal"]
            request("POST", f"/groups/{group}/opening/approve", {"proposal": proposal}, identities[group]["president"])
            point = {"played_at": "2026-10-14T18:00:00", "rate": 100, "cancelled": False, "lines": [{"member_id": m["id"], "contribution": 100, "penalty_due": 20 if m["id"] == "a" else 0, "penalty_paid": 10 if m["id"] == "a" else 0, "reason": "Retard QA" if m["id"] == "a" else ""} for m in MEMBERS], "donations": [{"id": "don", "label": "Soutien QA", "amount": 40}], "expenses": [{"id": "terrain", "label": "Terrain QA", "amount": 30}]}
            for author, label, amount in [("tresorier", "Terrain QA", 30), ("vice", "Eau QA", 80)]:
                value = copy.deepcopy(point)
                value["expenses"] = [{"id": "expense", "label": label, "amount": amount}]
                request("POST", f"/groups/{group}/sync", {"operation_id": str(uuid.uuid4()), "occurrence_id": "qa-finance", "domain": "finance", "base_revision": 0, "generation": 0, "payload": value, "reason": "Version QA"}, identities[group][author])
    (ROOT / "identites-test.json").write_text(json.dumps(identities, ensure_ascii=False, indent=2), encoding="utf-8")
    print("Deux groupes et comptes synthétiques créés sur le backend QA en mémoire.")


if __name__ == "__main__":
    payload = backup()
    (ROOT / "qa-tournois.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    (ROOT / "qa-invalide.json").write_text('{"app":', encoding="utf-8")
    if "--server" in __import__("sys").argv:
        seed_server()
    print("Sauvegardes synthétiques générées.")
