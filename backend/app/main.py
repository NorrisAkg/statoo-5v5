import copy
import hashlib
import json
import os
import secrets
import threading
import time
import uuid
from contextlib import asynccontextmanager
from datetime import date, datetime, timedelta, timezone
from typing import Literal

from fastapi import Depends, FastAPI, Header, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pathlib import Path
from pydantic import BaseModel, Field, StrictInt, field_validator
from sqlalchemy import select
from sqlalchemy.orm import Session

from .finance import Point, totals, validate_point
from .config import load_environment
from .models import Base, Group, Token, database
from .security import password_hash, password_matches, token_digest

ROLES = ["ADMIN", "PDT", "VP", "TR", "TGA", "SG", "SGA", "CENSOR", "MEMBER"]
SINGULAR = set(ROLES) - {"MEMBER"}
AUTHORS = {"sport": {"SG", "SGA"}, "finance": {"TR", "TGA"}}


class Credentials(BaseModel):
    group_id: str = Field(min_length=1, max_length=100)
    username: str = Field(min_length=1, max_length=100)
    password: str = Field(min_length=8, max_length=200)


class Registration(Credentials):
    name: str = Field(min_length=1, max_length=100)
    shared_username: str = Field(min_length=1, max_length=100)
    shared_password: str = Field(min_length=8, max_length=200)
    members: list[dict] = Field(default_factory=list, max_length=1000)


class AccountInput(BaseModel):
    username: str = Field(min_length=1, max_length=100)
    password: str = Field(min_length=8, max_length=200)
    member_id: str
    roles: list[str]


class RoleInput(BaseModel):
    roles: list[str]
    transfer: bool = False
    reason: str = Field(default="", max_length=300)


class VersionInput(BaseModel):
    operation_id: str
    occurrence_id: str = Field(min_length=1, max_length=150)
    domain: Literal["sport", "finance"]
    base_revision: int = Field(ge=0)
    generation: int = Field(default=0, ge=0)
    payload: dict
    reason: str = Field(default="", max_length=300)


class Decision(BaseModel):
    revision: int
    candidate_id: str
    reason: str = Field(min_length=1, max_length=300)


class Transfer(BaseModel):
    account_id: str
    revision: int
    reason: str = Field(min_length=1, max_length=300)


class FinancialSettings(BaseModel):
    contribution: StrictInt = Field(ge=0, le=10**12)
    late_penalty: StrictInt = Field(ge=0, le=10**12)


class Opening(BaseModel):
    cash: StrictInt = Field(ge=0)
    start_date: str | None = None

    @field_validator('start_date')
    @classmethod
    def valid_start(cls, value):
        if value is not None:
            date.fromisoformat(value)
        return value
    members: dict[str, dict[str, StrictInt]]


def fail(code, message):
    raise HTTPException(code, message)


def public_account(account):
    return {key: account[key] for key in ("id", "username", "member_id", "roles", "shared")}


def financial_points(state, exclude=None):
    points = [d['payload'] for key, d in state['documents'].items() if d['domain'] == 'finance' and key != 'finance:' + str(exclude)]
    for occurrence, point in state.get('obligations', {}).items():
        if occurrence != exclude and 'finance:' + occurrence not in state['documents']:
            points.append(point)
    return points


def validate_financial_roster(state, occurrence, payload):
    existing = state['documents'].get('finance:' + occurrence)
    baseline = existing['payload'] if existing else state.get('obligations', {}).get(occurrence)
    expected = {l['member_id'] for l in baseline['lines']} if baseline else {m['id'] for m in state['members'] if m.get('is_active', 1)}
    if {l['member_id'] for l in payload['lines']} != expected:
        fail(422, 'Tous les membres de cette echeance doivent figurer dans le point')
    sport_doc = state['documents'].get('sport:' + occurrence)
    if sport_doc and sport_doc['payload']['session']['status'] == 'CANCELLED' and not payload['cancelled']:
        fail(422, 'Cette seance est annulee : aucun encaissement autorise')


def validate_sport_acceptance(state, occurrence, payload):
    financial = state['documents'].get('finance:' + occurrence)
    if payload['session']['status'] == 'CANCELLED' and financial:
        point = financial['payload']
        if any(l['contribution'] or l['penalty_paid'] or l['penalty_due'] for l in point['lines']) or point['expenses'] or point['donations']:
            fail(409, 'Corrigez le point financier avant annulation')


def create_app(url: str | None = None):
    load_environment()
    if url is None and os.getenv("RENDER") and not os.getenv("DATABASE_URL"):
        raise RuntimeError("DATABASE_URL is required on Render; use persistent Neon PostgreSQL")
    engine = database(url or os.getenv("DATABASE_URL", "sqlite:///statoo.db"))
    @asynccontextmanager
    async def lifespan(app):
        schema_url = os.getenv("DATABASE_URL_UNPOOLED") if url is None else None
        schema_engine = database(schema_url) if schema_url else engine
        try:
            Base.metadata.create_all(schema_engine)
        finally:
            if schema_engine is not engine:
                schema_engine.dispose()
        try:
            yield
        finally:
            engine.dispose()

    app = FastAPI(title="Statoo", version="0.1.0", lifespan=lifespan)
    portal = Path(__file__).resolve().parents[2] / "web"
    if portal.is_dir():
        app.mount("/portal", StaticFiles(directory=portal, html=True), name="portal")
    app.add_middleware(CORSMiddleware, allow_origins=os.getenv("CORS_ORIGINS", "").split(","),
                       allow_methods=["GET", "POST", "PUT"], allow_headers=["Authorization", "Content-Type"])
    # Also serialize SQLite development transactions. PostgreSQL uses row locks across workers.
    lock = threading.RLock()
    attempts = {}

    def db():
        with lock, Session(engine) as session, session.begin():
            yield session

    def authenticate(authorization: str = Header(default=""), session: Session = Depends(db)):
        if not authorization.startswith("Bearer "):
            fail(401, "Connexion requise")
        token = session.get(Token, token_digest(authorization[7:]))
        if token is None or token.expires_at < datetime.now(timezone.utc).replace(tzinfo=None):
            fail(401, "Connexion expirée")
        group = session.scalar(select(Group).where(Group.id == token.group_id).with_for_update())
        state = copy.deepcopy(group.state)
        account = next((a for a in state["accounts"] if a["id"] == token.account_id), None)
        if account is None:
            fail(401, "Compte supprimé")
        return session, group, state, account

    def scoped(group_id, auth):
        session, group, state, account = auth
        if group.id != group_id:
            fail(403, "Autre groupe")
        return session, group, state, account

    def require(account, roles):
        if account["shared"] or not set(account["roles"]) & set(roles):
            fail(403, "Droit insuffisant")

    def audit(state, account, action, reason=""):
        state["audit"].append({"actor": account["id"], "action": action, "reason": reason,
                               "at": datetime.now(timezone.utc).isoformat()})

    def issue(session, group, account):
        token = secrets.token_urlsafe(32)
        expires = datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(days=30)
        session.add(Token(digest=token_digest(token), group_id=group.id, account_id=account["id"], expires_at=expires))
        return {"token": token, "expires_at": expires.isoformat() + "Z", "group_id": group.id, "account": public_account(account)}

    def check_roles(roles):
        if not set(roles).issubset(ROLES) or len(roles) != len(set(roles)):
            fail(422, "Rôle inconnu ou en double")
        return sorted(set(roles) | {"MEMBER"})

    def ready(state):
        assigned = {r for a in state["accounts"] for r in a["roles"]}
        if not {"PDT", "TR"}.issubset(assigned):
            fail(409, "Attribuez un Président et un Trésorier avant de commencer")

    @app.get("/health")
    def health():
        return {"status": "ok"}

    @app.post("/groups", status_code=201)
    def register(body: Registration, session: Session = Depends(db)):
        if session.get(Group, body.group_id):
            fail(409, "Ce groupe existe déjà")
        if body.username.casefold() == body.shared_username.casefold():
            fail(422, "Identifiants individuels et collectifs distincts requis")
        ids = [m.get("id") for m in body.members]
        if any(not isinstance(x, str) or not x.strip() or len(x) > 100 for x in ids):
            fail(422, "Identifiants de membres invalides")
        if None in ids or len(set(ids)) != len(ids) or any(not m.get("name") for m in body.members):
            fail(422, "Membres invalides")
        admin = {"id": str(uuid.uuid4()), "username": body.username.strip(), "password": password_hash(body.password),
                 "roles": ["ADMIN", "MEMBER"], "member_id": None, "shared": False}
        shared = {"id": str(uuid.uuid4()), "username": body.shared_username.strip(),
                  "password": password_hash(body.shared_password), "roles": ["MEMBER"], "member_id": None, "shared": True}
        group = Group(id=body.group_id, state={"name": body.name, "roles": ROLES, "accounts": [admin, shared],
                    "members": body.members, "documents": {}, "operations": {}, "audit": [], "opening": None,
                    "opening_proposal": None, "obligations": {}})
        session.add(group)
        session.flush()
        return issue(session, group, admin)

    @app.post("/auth/login")
    def login(body: Credentials, request: Request, session: Session = Depends(db)):
        key = request.client.host if request.client else "unknown"
        now = time.monotonic()
        recent = [t for t in attempts.get(key, []) if now - t < 60]
        attempts[key] = recent + [now]
        if len(recent) >= 20:
            fail(429, "Trop de tentatives, réessayez dans une minute")
        group = session.get(Group, body.group_id)
        account = None if group is None else next((a for a in group.state["accounts"]
                      if a["username"].casefold() == body.username.strip().casefold()), None)
        if account is None or not password_matches(body.password, account["password"]):
            fail(401, "Identifiants incorrects")
        attempts.pop(key, None)
        return issue(session, group, account)

    @app.post("/auth/logout")
    def logout(authorization: str = Header(default=""), auth=Depends(authenticate)):
        session = auth[0]
        session.delete(session.get(Token, token_digest(authorization[7:])))
        return {"ok": True}

    @app.get("/groups/{group_id}")
    def snapshot(group_id: str, auth=Depends(authenticate)):
        _, group, state, account = scoped(group_id, auth)
        result = {k: state[k] for k in ("name", "roles", "members", "documents", "opening", "audit")}
        result['obligations'] = state.get('obligations', {})
        result['financial_settings'] = state.get('financial_settings', {'contribution': 100, 'late_penalty': 0})
        result["account"] = public_account(account)
        result["leaders"] = [public_account(a) for a in state["accounts"] if not a["shared"]]
        if not set(account["roles"]) & {"PDT", "VP"}:
            result["documents"] = {key: {k: v for k, v in doc.items() if k not in {"history", "candidates"}}
                                   for key, doc in state["documents"].items()}
            for doc in result["documents"].values():
                doc["candidates"] = []
        if "ADMIN" in account["roles"]:
            result["accounts"] = [public_account(a) for a in state["accounts"]]
        if set(account["roles"]) & {"PDT", "VP", "TR", "TGA"}:
            result["opening_proposal"] = state["opening_proposal"]
        points = financial_points(state)
        result["finances"] = totals(points, state["opening"])
        return result

    @app.post("/groups/{group_id}/accounts", status_code=201)
    def add_account(group_id: str, body: AccountInput, auth=Depends(authenticate)):
        _, group, state, actor = scoped(group_id, auth)
        require(actor, {"ADMIN"})
        roles = check_roles(body.roles)
        if body.member_id not in {m["id"] for m in state["members"]}:
            fail(422, "Membre inconnu")
        if any(a["username"].casefold() == body.username.strip().casefold() for a in state["accounts"]):
            fail(409, "Identifiant déjà utilisé")
        if any(set(a["roles"]) & set(roles) & SINGULAR for a in state["accounts"]):
            fail(409, "Un rôle unique est déjà attribué")
        account = {"id": str(uuid.uuid4()), "username": body.username.strip(), "password": password_hash(body.password),
                   "member_id": body.member_id, "roles": roles, "shared": False}
        state["accounts"].append(account)
        audit(state, actor, "account_created")
        group.state = state
        return public_account(account)

    @app.put("/groups/{group_id}/accounts/{account_id}/roles")
    def roles(group_id: str, account_id: str, body: RoleInput, auth=Depends(authenticate)):
        _, group, state, actor = scoped(group_id, auth)
        require(actor, {"ADMIN"})
        target = next((a for a in state["accounts"] if a["id"] == account_id), None)
        if target is None or target["shared"]:
            fail(422, "Compte individuel requis")
        desired = check_roles(body.roles)
        for account in state["accounts"]:
            occupied = set(account["roles"]) & set(desired) & SINGULAR
            if account["id"] != target["id"] and occupied:
                if not body.transfer or not body.reason.strip():
                    fail(409, "Transfert explicite et motif requis")
                account["roles"] = sorted(set(account["roles"]) - occupied)
        previous = set(target["roles"])
        target["roles"] = desired
        assigned = {r for a in state["accounts"] for r in a["roles"]}
        for role in previous & {"ADMIN", "PDT", "TR"}:
            if role not in assigned:
                fail(409, "Transférez le rôle obligatoire avant de le retirer")
        audit(state, actor, "roles_changed", body.reason)
        group.state = state
        return public_account(target)

    @app.put("/groups/{group_id}/members")
    def members(group_id: str, body: list[dict], auth=Depends(authenticate)):
        _, group, state, actor = scoped(group_id, auth)
        require(actor, {"ADMIN"})
        ids = [m.get("id") for m in body]
        if any(not isinstance(x, str) or not x.strip() or len(x) > 100 for x in ids):
            fail(422, "Identifiants de membres invalides")
        if len(body) > 1000 or None in ids or len(set(ids)) != len(ids) or any(not m.get("name") for m in body):
            fail(422, "Membres invalides")
        # Never remove members referenced by accounts or history.
        if not {m["id"] for m in state["members"]}.issubset(ids):
            fail(409, "Archivez les membres au lieu de les supprimer")
        state["members"] = body
        audit(state, actor, "members_updated")
        group.state = state
        return {"ok": True}

    @app.put("/groups/{group_id}/shared-access")
    def rotate_shared(group_id: str, body: Credentials, auth=Depends(authenticate)):
        session, group, state, actor = scoped(group_id, auth)
        require(actor, {"ADMIN"})
        shared = next(a for a in state["accounts"] if a["shared"])
        if any(not a["shared"] and a["username"].casefold() == body.username.strip().casefold() for a in state["accounts"]):
            fail(409, "Identifiant déjà utilisé")
        shared["username"] = body.username.strip()
        shared["password"] = password_hash(body.password)
        for token in session.scalars(select(Token).where(Token.group_id == group.id, Token.account_id == shared["id"])):
            session.delete(token)
        audit(state, actor, "shared_access_rotated")
        group.state = state
        return {"ok": True}

    @app.put('/groups/{group_id}/financial-settings')
    def financial_settings(group_id: str, body: FinancialSettings, auth=Depends(authenticate)):
        _, group, state, actor = scoped(group_id, auth)
        require(actor, {'ADMIN', 'TR', 'TGA'})
        state['financial_settings'] = body.model_dump()
        audit(state, actor, 'financial_settings_updated')
        group.state = state
        return body.model_dump()

    @app.post("/groups/{group_id}/opening")
    def opening(group_id: str, body: Opening, auth=Depends(authenticate)):
        _, group, state, actor = scoped(group_id, auth)
        require(actor, {"TR", "TGA"})
        if state["opening"] is not None:
            fail(409, "Soldes initiaux déjà approuvés")
        if any(d["domain"] == "finance" for d in state["documents"].values()):
            fail(409, "Initialisez les soldes avant le premier point")
        if not set(body.members).issubset({m["id"] for m in state["members"]}):
            fail(422, "Membre inconnu")
        for value in body.members.values():
            if set(value) != {"contribution_balance", "penalty_debt"} or value["penalty_debt"] < 0:
                fail(422, "Solde invalide")
        state["opening_proposal"] = body.model_dump()
        audit(state, actor, "opening_proposed")
        group.state = state
        return {"ok": True}

    @app.post("/groups/{group_id}/opening/approve")
    def approve_opening(group_id: str, auth=Depends(authenticate)):
        _, group, state, actor = scoped(group_id, auth)
        require(actor, {"PDT", "VP"})
        if state["opening"] is not None or state["opening_proposal"] is None:
            fail(409, "Aucun solde à approuver")
        state["opening"] = state["opening_proposal"]
        state["opening_proposal"] = None
        audit(state, actor, "opening_approved")
        group.state = state
        return {"ok": True}

    @app.post("/groups/{group_id}/sync")
    def sync(group_id: str, body: VersionInput, auth=Depends(authenticate)):
        _, group, state, actor = scoped(group_id, auth)
        require(actor, AUTHORS[body.domain])
        ready(state)
        fingerprint = hashlib.sha256(json.dumps(body.model_dump(), sort_keys=True).encode()).hexdigest()
        prior = state["operations"].get(body.operation_id)
        if prior:
            if prior["actor"] != actor["id"] or prior["fingerprint"] != fingerprint:
                fail(409, "Identifiant d'opération réutilisé")
            return prior["result"]
        known = {m["id"] for m in state["members"]}
        if body.domain == "finance":
            if state["opening"] is None:
                fail(409, "Les soldes initiaux doivent être approuvés avant la synchronisation financière")
            try:
                point = Point.model_validate(body.payload)
                validate_point(point, known)
                body.payload = point.model_dump()
                validate_financial_roster(state, body.occurrence_id, body.payload)
                other_points = financial_points(state, body.occurrence_id)
                projected = totals(other_points + [body.payload], state["opening"])
                if any(v["penalty_debt"] < 0 for v in projected["members"].values()):
                    raise ValueError("Le règlement dépasse les pénalités dues ; aucun crédit de pénalité autorisé")
            except ValueError as exc:
                fail(422, str(exc))
        else:
            validate_sport(body.payload, known, group.id)
        key = body.domain + ":" + body.occurrence_id
        document = state["documents"].get(key)
        candidate = {"id": body.operation_id, "actor": actor["id"], "payload": body.payload,
                     "reason": body.reason, "at": datetime.now(timezone.utc).isoformat()}
        if document and (document["owner"] != actor["id"] or document["revision"] != body.base_revision
                         or document["generation"] != body.generation):
            document["candidates"].append(candidate)
            result = {"status": "conflict", "revision": document["revision"]}
        elif document and document["candidates"]:
            document["candidates"].append(candidate)
            result = {"status": "conflict", "revision": document["revision"]}
        else:
            if body.domain == 'sport':
                validate_sport_acceptance(state, body.occurrence_id, body.payload)
            if document and not body.reason.strip():
                fail(422, "Motif de correction requis")
            if document:
                document["history"].append({k: document[k] for k in ("payload", "owner", "revision")})
            state["documents"][key] = {
                "domain": body.domain, "occurrence_id": body.occurrence_id, "owner": actor["id"],
                "generation": document["generation"] if document else 0,
                "revision": (document["revision"] if document else 0) + 1,
                "payload": body.payload, "history": document["history"] if document else [],
                "candidates": [], "updated_at": candidate["at"],
            }
            if body.domain == 'sport':
                native = body.payload['session']
                existing_point = state['documents'].get('finance:' + body.occurrence_id)
                if native['status'] == 'CANCELLED' and existing_point:
                    p = existing_point['payload']
                    if any(l['contribution'] or l['penalty_paid'] or l['penalty_due'] for l in p['lines']) or p['expenses'] or p['donations']:
                        fail(409, 'Le trésorier doit corriger le point financier avant annulation')
                state.setdefault('obligations', {}).setdefault(body.occurrence_id, {
                    'played_at': native['played_at'], 'rate': state.get('financial_settings', {}).get('contribution', 100), 'cancelled': native['status'] == 'CANCELLED',
                    'lines': [{'member_id': m['id'], 'contribution': 0, 'penalty_paid': 0, 'penalty_due': 0, 'reason': ''}
                              for m in state['members'] if m.get('is_active', 1)], 'expenses': [], 'donations': []})
                state['obligations'][body.occurrence_id]['cancelled'] = native['status'] == 'CANCELLED'
            result = {"status": "accepted", "revision": state["documents"][key]["revision"]}
        state["operations"][body.operation_id] = {"actor": actor["id"], "fingerprint": fingerprint, "result": result}
        audit(state, actor, body.domain + "_sync", body.reason)
        group.state = state
        return result

    @app.post("/groups/{group_id}/documents/{domain}/{occurrence_id}/resolve")
    def resolve(group_id: str, domain: str, occurrence_id: str, body: Decision, auth=Depends(authenticate)):
        _, group, state, actor = scoped(group_id, auth)
        require(actor, {"PDT", "VP"})
        document = state["documents"].get(domain + ":" + occurrence_id)
        if document is None or document["revision"] != body.revision or not document["candidates"]:
            fail(409, "Conflit déjà traité ou révision périmée")
        if body.candidate_id == "current":
            selected = {"actor": document["owner"], "payload": document["payload"]}
        else:
            selected = next((c for c in document["candidates"] if c["id"] == body.candidate_id), None)
            if selected is None:
                fail(422, "Version inconnue")
        if domain == 'sport':
            validate_sport_acceptance(state, occurrence_id, selected['payload'])
        if domain == "finance":
            validate_financial_roster(state, occurrence_id, selected['payload'])
            points = [d["payload"] for k, d in state["documents"].items() if d["domain"] == "finance" and k != domain + ":" + occurrence_id]
            balance = totals(points + [selected["payload"]], state["opening"])
            if any(v["penalty_debt"] < 0 for v in balance["members"].values()):
                fail(422, "Cette version règle davantage de pénalités que la dette actuelle")
        document["history"].append({"payload": document["payload"], "owner": document["owner"],
                                     "revision": document["revision"], "discarded_candidates": document["candidates"]})
        document.update(payload=selected["payload"], owner=selected["actor"], revision=document["revision"] + 1,
                        generation=document["generation"] + 1, candidates=[])
        audit(state, actor, domain + "_conflict_resolved", body.reason)
        group.state = state
        return {"ok": True}

    @app.post("/groups/{group_id}/documents/{domain}/{occurrence_id}/transfer")
    def transfer(group_id: str, domain: str, occurrence_id: str, body: Transfer, auth=Depends(authenticate)):
        _, group, state, actor = scoped(group_id, auth)
        if domain not in AUTHORS:
            fail(422, "Domaine inconnu")
        document = state["documents"].get(domain + ":" + occurrence_id)
        if document is None or document["revision"] != body.revision or document["candidates"]:
            fail(409, "Révision périmée ou conflit à résoudre")
        if document["owner"] != actor["id"]:
            require(actor, {"PDT", "VP"})
        else:
            require(actor, AUTHORS[domain])
        target = next((a for a in state["accounts"] if a["id"] == body.account_id), None)
        if target is None:
            fail(422, "Compte inconnu")
        require(target, AUTHORS[domain])
        document.update(owner=body.account_id, generation=document["generation"] + 1, revision=document["revision"] + 1)
        audit(state, actor, domain + "_transferred", body.reason)
        group.state = state
        return {"ok": True}

    return app


def validate_sport(payload, known, group_id):
    session = payload.get("session", {})
    parts = payload.get("participations", [])
    if not isinstance(session, dict) or not isinstance(parts, list) or len(parts) > 1000 or any(not isinstance(p, dict) for p in parts):
        fail(422, "Séance ou participants invalides")
    if not session.get("id") or session.get("team_id") != group_id or session.get("status") not in {"DRAFT", "CLOSED", "CANCELLED"}:
        fail(422, "Séance invalide")
    ids = [p.get("player_id") for p in parts]
    if len(ids) != len(set(ids)) or not set(ids).issubset(known):
        fail(422, "Participants inconnus ou en double")
    for part in parts:
        if part.get("session_id") != session["id"] or part.get("team") not in {"A", "B", "C"}:
            fail(422, "Participation invalide")
        if any(type(part.get(k, 0)) is not int or part.get(k, 0) < 0 for k in ("goals", "assists", "yellow_cards", "red_cards")):
            fail(422, "Statistiques invalides")
    if session["status"] == "CLOSED":
        tournament = session.get("session_type") == "TOURNAMENT_3"
        allowed = {"A", "B", "C", "DRAW_AB", "DRAW_BC", "DRAW_AC", "DRAW_ALL"} if tournament else {"A", "B", "DRAW"}
        if session.get("result") not in allowed:
            fail(422, "Résultat requis")
        if not tournament:
            a, b = session.get("score_a"), session.get("score_b")
            if type(a) is not int or type(b) is not int or min(a, b) < 0:
                fail(422, "Score requis")
            expected = "A" if a > b else "B" if b > a else "DRAW"
            if session["result"] != expected:
                fail(422, "Résultat incohérent")
        teams = ["A", "B", "C"] if tournament else ["A", "B"]
        counts = [sum(p["team"] == team for p in parts) for team in teams]
        if not session.get("allow_uneven_teams") and max(counts) - min(counts) > 1:
            fail(422, "Équipes déséquilibrées")
        for team in teams:
            goals = sum(p.get("goals", 0) for p in parts if p["team"] == team)
            assists = sum(p.get("assists", 0) for p in parts if p["team"] == team)
            score = session.get("score_" + team.lower())
            if score is not None and goals + (session.get("unassigned_goals_" + team.lower()) or 0) != score:
                fail(422, "Buts et score incohérents")
            if assists > goals or any(p.get("goals", 0) + p.get("assists", 0) > goals for p in parts if p["team"] == team):
                fail(422, "Passes incohérentes")


app = create_app()
