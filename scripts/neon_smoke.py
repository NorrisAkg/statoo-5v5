"""Exercise the running API and verify its records in Neon, then remove test data."""
import os
import secrets
import sys
import uuid
from pathlib import Path

import httpx
from sqlalchemy import delete, select, text
from sqlalchemy.orm import Session

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))
from app.config import load_environment
from app.models import Group, Token, database

load_environment()
url = os.environ["DATABASE_URL"]
assert "neon.tech" in url and url.startswith(("postgres://", "postgresql://"))
engine = database(url)
group_id = "neon-smoke-" + str(uuid.uuid4())
password = secrets.token_urlsafe(24)
with httpx.Client(base_url="http://127.0.0.1:" + os.getenv("PORT", "8000"), timeout=30) as client:
    try:
        response = client.get("/health")
        assert response.status_code == 200
        print("PASS GET /health: HTTP 200")
        assert client.get("/portal/").status_code == 200
        for asset in ("app.mjs", "summary.mjs", "styles.css"):
            assert client.get("/portal/" + asset).status_code == 200
        print("PASS portal HTML and all JavaScript/CSS assets: HTTP 200")
        response = client.post("/groups", json={
            "group_id": group_id, "name": "Neon integration smoke test",
            "username": "admin", "password": password,
            "shared_username": "members", "shared_password": password,
            "members": [{"id": "smoke-member", "name": "Smoke member"}],
        })
        assert response.status_code == 201, response.status_code
        print("PASS POST /groups: HTTP 201 (Postgres write)")
        with Session(engine) as session:
            assert session.scalar(text("SELECT version()" )).startswith("PostgreSQL")
            assert session.get(Group, group_id).state["name"] == "Neon integration smoke test"
            assert session.scalar(select(Token).where(Token.group_id == group_id)) is not None
        print("PASS independent PostgreSQL connection: group and auth token persisted")
        response = client.post("/auth/login", json={
            "group_id": group_id, "username": "members", "password": password,
        })
        assert response.status_code == 200, response.status_code
        headers = {"Authorization": "Bearer " + response.json()["token"]}
        response = client.get("/groups/" + group_id, headers=headers)
        assert response.status_code == 200, response.status_code
        assert "smoke-member" in response.text
        print("PASS shared login and authenticated GET /groups/{id}: HTTP 200 (Postgres read)")
        assert client.post("/auth/logout", headers=headers).status_code == 200
        assert client.get("/groups/" + group_id, headers=headers).status_code == 401
        print("PASS logout revokes persisted token: HTTP 401")
    finally:
        with engine.begin() as connection:
            connection.execute(delete(Token).where(Token.group_id == group_id))
            connection.execute(delete(Group).where(Group.id == group_id))
        engine.dispose()
        print("Removed only this run's smoke-test group and tokens.")
