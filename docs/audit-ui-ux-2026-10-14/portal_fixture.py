"""Serveur de données synthétiques pour audit UI uniquement, aucun accès production."""
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

ROOT = Path(__file__).parent
MEMBERS = [{"id": "a", "name": "Alice Audit", "is_active": 1}, {"id": "b", "name": "Benoît Audit", "is_active": 1}, {"id": "c", "name": "Camille Audit", "is_active": 1}]
SNAPSHOT = {"name": "Groupe de test UI — données fictives", "members": MEMBERS, "documents": {
    "sport:test": {"domain": "sport", "payload": {"session": {"played_at": "2026-10-14T20:00:00", "status": "CLOSED", "session_type": "TOURNAMENT_3", "team_names": {"A": "Les Bleus", "B": "Les Oranges", "C": "Les Verts"}, "wins_a": 2, "wins_b": 1, "wins_c": 0, "is_ranked": True, "result": "A"}, "participations": [{"player_id": m["id"], "team": t, "goals": 0, "assists": 0} for m, t in zip(MEMBERS, ["A", "B", "C"])]}},
}, "finances": {"cash": 0, "members": {}}}

class Handler(BaseHTTPRequestHandler):
    def reply(self, code, value):
        data = json.dumps(value).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "http://127.0.0.1:8087")
        self.send_header("Access-Control-Allow-Headers", "Authorization, Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.end_headers()
        self.wfile.write(data)
    def do_OPTIONS(self): self.reply(200, {})
    def do_POST(self):
        self.rfile.read(int(self.headers.get("Content-Length", 0)))
        self.reply(200, {"token": "synthetic-audit-token"})
    def do_GET(self):
        if (ROOT / "fixture-expired.flag").exists(): self.reply(401, {"detail": "Connexion expirée"})
        else: self.reply(200, SNAPSHOT)

HTTPServer(("127.0.0.1", 8088), Handler).serve_forever()
