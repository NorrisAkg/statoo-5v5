import copy
import hashlib
import json
import os
import re
import secrets
import threading
import time
import uuid
from contextlib import asynccontextmanager
from datetime import date, datetime, timedelta, timezone
from typing import Literal

from fastapi import Depends, FastAPI, Header, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pathlib import Path
from pydantic import BaseModel, Field, StrictInt, ValidationError, field_validator
from sqlalchemy import select
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError

from .finance import Point, totals, validate_point
from .config import load_environment
from .models import Base, Group, Token, RegistrationOperation, database
from .portal import PortalFiles
from .security import password_hash, password_matches, token_digest

ROLES = ["ADMIN", "PDT", "VP", "TR", "TGA", "SG", "SGA", "CENSOR", "MEMBER"]
SINGULAR = set(ROLES) - {"MEMBER"}
AUTHORS = {"sport": {"ADMIN", "PDT", "VP", "SG", "SGA"}, "finance": {"TR", "TGA"}}
VALIDATION_MESSAGE = "Les données saisies sont invalides. Vérifiez les champs requis et leur format."


class SharedPasswordCheck(BaseModel):
    password: str


class PasswordChange(BaseModel):
    current_password: str = Field(min_length=1, max_length=200)
    new_password: str = Field(min_length=1, max_length=200)


class Credentials(BaseModel):
    group_id: str = Field(min_length=1, max_length=100)
    username: str = Field(min_length=1, max_length=100)
    password: str = Field(min_length=8, max_length=200)

    @field_validator('username')
    @classmethod
    def non_blank_username(cls, value):
        if not value.strip():
            raise ValueError('Identifiant de connexion requis')
        # Keep the original value for historical registration fingerprints.
        return value


class Registration(Credentials):
    operation_id: str | None = Field(default=None, min_length=1, max_length=100)
    group_id: str | None = Field(default=None, max_length=100)
    name: str = Field(min_length=1, max_length=100)
    short_name: str = Field(default="", max_length=30)

    @field_validator('short_name', mode='before')
    @classmethod
    def clean_short_name(cls, value):
        return value.strip() if isinstance(value, str) else value
    shared_username: str = Field(min_length=1, max_length=100)
    shared_password: str = Field(min_length=8, max_length=200)
    members: list[dict] = Field(default_factory=list, max_length=1000)

    @field_validator('shared_username')
    @classmethod
    def non_blank_shared_username(cls, value):
        if not value.strip():
            raise ValueError('Identifiant collectif requis')
        return value


class AccountInput(BaseModel):
    username: str = Field(min_length=1, max_length=100)
    password: str = Field(min_length=8, max_length=200)
    member_id: str
    roles: list[str]

    @field_validator('username')
    @classmethod
    def non_blank_username(cls, value):
        if not value.strip():
            raise ValueError('Identifiant de connexion requis')
        return value


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


class SportSettings(BaseModel):
    min_players_per_session: StrictInt = Field(ge=2, le=30)


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


class OpeningApproval(BaseModel):
    proposal: Opening


def fail(code, message):
    raise HTTPException(code, message)


def validate_user_password(password: str, username: str | None = None):
    if len(password) < 8 or len(password) > 200:
        fail(422, "Le mot de passe doit contenir entre 8 et 200 caractères.")
    if not any(c.islower() for c in password):
        fail(422, "Le mot de passe doit contenir au moins une lettre minuscule.")
    if not any(c.isupper() for c in password):
        fail(422, "Le mot de passe doit contenir au moins une lettre majuscule.")
    if not any(c.isdigit() for c in password):
        fail(422, "Le mot de passe doit contenir au moins un chiffre.")
    if any(ord(c) < 32 or ord(c) == 127 for c in password):
        fail(422, "Le mot de passe contient des caractères non autorisés.")
    if username and password.strip().casefold() == username.strip().casefold():
        fail(422, "Le mot de passe ne doit pas être identique à votre identifiant.")


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

    @app.exception_handler(RequestValidationError)
    async def invalid_request(_request: Request, _error: RequestValidationError):
        return JSONResponse(status_code=422, content={"detail": VALIDATION_MESSAGE})
    @app.get("/portal/config.json")
    def portal_config():
        # Explicit public allowlist: never serialize the server environment.
        return {"api_url": os.getenv("STATOO_PUBLIC_API_URL", "").strip()}

    portal = Path(__file__).resolve().parents[2] / "web"
    if portal.is_dir():
        app.mount("/portal", PortalFiles(directory=portal, html=True), name="portal")
    origins = [origin.strip() for origin in os.getenv("CORS_ORIGINS", "").split(",") if origin.strip()]
    if os.getenv("RENDER") == "true" and os.getenv("RENDER_GIT_BRANCH") == "staging":
        origins.extend(["http://127.0.0.1:18085", "http://localhost:18085",
                        "http://127.0.0.1:19095", "http://localhost:19095"])
    app.add_middleware(CORSMiddleware, allow_origins=origins,
                       allow_methods=["GET", "POST", "PUT"], allow_headers=["Authorization", "Content-Type"])
    # Also serialize SQLite development transactions. PostgreSQL uses row locks across workers.
    # FastAPI can enter and exit this dependency on different worker threads.
    lock = threading.Lock()
    attempts = {}
    password_change_attempts = {}

    def throttle(bucket, key, limit, window=60.0):
        now = time.monotonic()
        recent = [t for t in bucket.get(key, []) if now - t < window]
        if len(recent) >= limit:
            bucket[key] = recent
            fail(429, "Trop de tentatives, réessayez dans une minute")
        bucket[key] = recent + [now]

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
        canonical_body = body.model_dump(exclude={'operation_id', 'group_id'})
        # Preserve fingerprints of attempts started before short names existed.
        if not canonical_body['short_name']:
            canonical_body.pop('short_name')
        canonical = json.dumps(canonical_body, sort_keys=True, ensure_ascii=False)

        def replay():
            previous = session.get(RegistrationOperation, body.operation_id) if body.operation_id else None
            if previous is None:
                return None
            if not password_matches(canonical, previous.fingerprint):
                fail(409, "Cette tentative existe déjà. Reprenez les mêmes informations et les mêmes accès.")
            group = session.get(Group, previous.group_id)
            account = next(a for a in group.state['accounts'] if a['username'] == body.username.strip() and not a['shared'])
            if not password_matches(body.password, account['password']):
                fail(409, "Les accès ont changé. Connectez-vous au groupe existant.")
            return issue(session, group, account)

        previous = replay()
        if previous:
            return previous
        validate_user_password(body.password, username=body.username)
        validate_user_password(body.shared_password, username=body.shared_username)
        if body.username.strip().casefold() == body.shared_username.strip().casefold():
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
        state = {"name": body.name, "short_name": body.short_name, "roles": ROLES, "accounts": [admin, shared],
                    "members": body.members, "documents": {}, "operations": {}, "audit": [], "opening": None,
                    "opening_proposal": None, "obligations": {}}
        for _ in range(20):
            group_id = f"#{secrets.randbelow(100_000_000):08d}"
            if session.get(Group, group_id):
                continue
            group = Group(id=group_id, state=state)
            try:
                # The primary key arbitrates collisions between server workers.
                with session.begin_nested():
                    session.add(group)
                    session.flush()
                    if body.operation_id:
                        session.add(RegistrationOperation(id=body.operation_id, group_id=group_id, fingerprint=password_hash(canonical)))
                        session.flush()
            except IntegrityError:
                previous = replay()
                if previous:
                    return previous
                continue
            return issue(session, group, admin)
        fail(503, "Impossible d’attribuer un identifiant de groupe. Réessayez.")

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
        result['short_name'] = state.get('short_name', '')
        if 'active_session_id' in state:
            result['active_session_id'] = state['active_session_id']
        result['financial_settings'] = state.get('financial_settings', {'contribution': 100, 'late_penalty': 0})
        result['sport_settings'] = state.get('sport_settings', {'min_players_per_session': 6})
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
        if not set(roles) & SINGULAR:
            fail(422, "Un compte individuel nécessite au moins un rôle de responsable. Les membres utilisent l’accès collectif.")
        if body.member_id not in {m["id"] for m in state["members"]}:
            fail(422, "Membre inconnu")
        if any(a["username"].casefold() == body.username.strip().casefold() for a in state["accounts"]):
            fail(409, "Identifiant déjà utilisé")
        if any(set(a["roles"]) & set(roles) & SINGULAR for a in state["accounts"]):
            fail(409, "Un rôle unique est déjà attribué")
        validate_user_password(body.password, username=body.username)
        account = {"id": str(uuid.uuid4()), "username": body.username.strip(), "password": password_hash(body.password),
                   "member_id": body.member_id, "roles": roles, "shared": False}
        state["accounts"].append(account)
        audit(state, actor, "account_created")
        group.state = state
        return public_account(account)

    def individual_access(group_id, account_id, auth):
        session, group, state, actor = scoped(group_id, auth)
        require(actor, {"ADMIN"})
        target = next((a for a in state["accounts"] if a["id"] == account_id), None)
        if target is None:
            fail(404, "Compte introuvable")
        if target["shared"]:
            fail(422, "Compte individuel requis")
        return session, group, state, actor, target

    @app.post('/groups/{group_id}/accounts/{account_id}/password/verify')
    def verify_manager_password(group_id: str, account_id: str, body: SharedPasswordCheck, auth=Depends(authenticate)):
        _, group, _, _, target = individual_access(group_id, account_id, auth)
        if not 8 <= len(body.password) <= 200:
            fail(422, "Le mot de passe doit contenir entre 8 et 200 caractères.")
        if not password_matches(body.password, target['password']):
            fail(400, "Le mot de passe du gestionnaire est incorrect.")
        return {'verified': True, 'group_id': group.id, 'username': target['username']}

    @app.post('/groups/{group_id}/accounts/{account_id}/password')
    def reset_manager_password(group_id: str, account_id: str, body: SharedPasswordCheck, auth=Depends(authenticate)):
        session, group, state, actor, target = individual_access(group_id, account_id, auth)
        if target['id'] == actor['id']:
            fail(409, "Cette action ne peut pas remplacer votre propre mot de passe Admin.")
        validate_user_password(body.password, username=target['username'])
        target['password'] = password_hash(body.password)
        for token in session.scalars(select(Token).where(Token.group_id == group.id, Token.account_id == account_id)):
            session.delete(token)
        audit(state, actor, 'manager_password_reset')
        group.state = state
        return {'ok': True}

    @app.post('/groups/{group_id}/account/password')
    def change_own_password(group_id: str, body: PasswordChange, authorization: str = Header(default=''), auth=Depends(authenticate)):
        session, group, state, actor = scoped(group_id, auth)
        if actor.get('shared', False):
            fail(422, 'Compte individuel requis')
        throttle(password_change_attempts, actor['id'], limit=5, window=60.0)
        if not password_matches(body.current_password, actor['password']):
            fail(400, 'Mot de passe actuel incorrect')
        validate_user_password(body.new_password, username=actor.get('username'))
        if password_matches(body.new_password, actor['password']):
            fail(422, "Le nouveau mot de passe doit être différent de l'ancien")
        target_account = next(a for a in state['accounts'] if a['id'] == actor['id'])
        target_account['password'] = password_hash(body.new_password)
        actor['password'] = target_account['password']
        current_digest = token_digest(authorization[7:])
        for token in session.scalars(select(Token).where(Token.group_id == group.id, Token.account_id == actor['id'])):
            if token.digest != current_digest:
                session.delete(token)
        audit(state, actor, 'password_changed')
        group.state = state
        return {'ok': True}

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

    @app.post("/groups/{group_id}/shared-access/verify")
    def verify_shared(group_id: str, body: SharedPasswordCheck, auth=Depends(authenticate)):
        _, group, state, actor = scoped(group_id, auth)
        require(actor, {"ADMIN"})
        if not 8 <= len(body.password) <= 200:
            fail(422, "Le mot de passe doit contenir entre 8 et 200 caractères.")
        shared = next(a for a in state["accounts"] if a["shared"])
        if not password_matches(body.password, shared["password"]):
            fail(400, "Le mot de passe commun est incorrect.")
        return {"verified": True, "group_id": group.id, "username": shared["username"]}

    @app.put("/groups/{group_id}/shared-access")
    def rotate_shared(group_id: str, body: Credentials, auth=Depends(authenticate)):
        session, group, state, actor = scoped(group_id, auth)
        require(actor, {"ADMIN"})
        shared = next(a for a in state["accounts"] if a["shared"])
        if any(not a["shared"] and a["username"].casefold() == body.username.strip().casefold() for a in state["accounts"]):
            fail(409, "Identifiant déjà utilisé")
        validate_user_password(body.password, username=body.username)
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

    @app.put('/groups/{group_id}/sport-settings')
    def sport_settings(group_id: str, body: SportSettings, auth=Depends(authenticate)):
        _, group, state, actor = scoped(group_id, auth)
        require(actor, {'ADMIN'})
        state['sport_settings'] = body.model_dump()
        audit(state, actor, 'sport_settings_updated')
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
    def approve_opening(group_id: str, body: OpeningApproval, auth=Depends(authenticate)):
        _, group, state, actor = scoped(group_id, auth)
        require(actor, {"PDT", "VP"})
        if state["opening"] is not None or state["opening_proposal"] is None:
            fail(409, "Aucun solde à approuver")
        if body.proposal.model_dump() != state["opening_proposal"]:
            fail(409, "La proposition a changé. Actualisez et vérifiez les nouveaux soldes avant approbation.")
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
            except ValidationError:
                fail(422, VALIDATION_MESSAGE)
            except ValueError as exc:
                fail(422, str(exc))
        else:
            validate_sport(body.payload, known, group.id,
                           state.get('sport_settings', {}).get('min_players_per_session', 6))
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
                apply_sport_lifecycle(state, body.payload)
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
            if body.candidate_id != 'current':
                validate_sport(selected['payload'], {m['id'] for m in state['members']}, group.id,
                               state.get('sport_settings', {}).get('min_players_per_session', 6))
            validate_sport_acceptance(state, occurrence_id, selected['payload'])
            apply_sport_lifecycle(state, selected['payload'])
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


def apply_sport_lifecycle(state, payload):
    session = payload['session']
    identifier = session['id']
    active = state.get('active_session_id')
    if session['status'] != 'DRAFT':
        if active == identifier:
            state['active_session_id'] = None
        return
    if 'is_active' not in payload:
        return  # Legacy clients keep their existing lifecycle semantics.
    if payload['is_active']:
        if active and active != identifier:
            fail(409, {'code': 'active_session_conflict', 'active_session_id': active,
                       'message': 'Une séance est déjà en cours. Votre séance reste en brouillon ; clôturez la séance en cours avant de la démarrer.'})
        state['active_session_id'] = identifier
    elif active == identifier:
        state['active_session_id'] = None


def validate_sport(payload, known, group_id, minimum=6):
    session = payload.get("session", {})
    parts = payload.get("participations", [])
    if not isinstance(session, dict) or not isinstance(parts, list) or len(parts) > 1000 or any(not isinstance(p, dict) for p in parts):
        fail(422, "Séance ou participants invalides")
    def identifier(value):
        return isinstance(value, str) and bool(value.strip())

    if not identifier(session.get('id')) or session.get("team_id") != group_id or session.get("status") not in ("DRAFT", "CLOSED", "CANCELLED"):
        fail(422, "Séance invalide")
    played_at = session.get('played_at')
    if not isinstance(played_at, str) or not re.fullmatch(
        r'\d{4}-\d{2}-\d{2}(?:[T ]\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})?)?', played_at
    ):
        fail(422, 'Date de séance invalide')
    try:
        datetime.fromisoformat(played_at)
    except ValueError:
        fail(422, 'Date de séance invalide')
    kind = session.get('session_type', 'CLASSIC_2')
    if kind not in ('CLASSIC_2', 'TOURNAMENT_3'):
        fail(422, 'Format de séance invalide')
    tournament = kind == 'TOURNAMENT_3'
    teams = ('A', 'B', 'C') if tournament else ('A', 'B')
    allowed = ('A', 'B', 'C', 'DRAW_AB', 'DRAW_BC', 'DRAW_AC', 'DRAW_ALL') if tournament else ('A', 'B', 'DRAW')
    if session.get('result') is not None and session['result'] not in allowed:
        fail(422, 'Résultat invalide')
    if session.get('split_mode') not in (None, 'RANDOM', 'RANDOM_ADJUSTED', 'MANUAL'):
        fail(422, 'Mode de répartition invalide')
    for flag in ('allow_uneven_teams', 'is_ranked'):
        if flag in session and (type(session[flag]) is not int or session[flag] not in (0, 1)):
            fail(422, 'Option de séance invalide')
    for field in ('score_a', 'score_b', 'score_c', 'wins_a', 'wins_b', 'wins_c',
                  'draw_points', 'unassigned_goals_a', 'unassigned_goals_b', 'unassigned_goals_c'):
        value = session.get(field, 0)
        if field.startswith('score_') and value is None:
            continue
        if type(value) is not int or value < 0:
            fail(422, 'Chiffres de séance invalides')
    if 'is_active' in payload and type(payload['is_active']) is not bool:
        fail(422, 'État de séance actif invalide')
    ids = [p.get("player_id") for p in parts]
    participation_ids = [p.get('id') for p in parts]
    if (any(not identifier(value) for value in ids + participation_ids)
            or len(participation_ids) != len(set(participation_ids))
            or len(ids) != len(set(ids)) or not set(ids).issubset(known)):
        fail(422, "Participants inconnus ou en double")
    for part in parts:
        if part.get("session_id") != session["id"] or part.get("team") not in teams:
            fail(422, "Participation invalide")
        if any(type(part.get(k, 0)) is not int or part.get(k, 0) < 0 for k in ("goals", "assists", "yellow_cards", "red_cards")):
            fail(422, "Statistiques invalides")
    if payload.get('is_active') and session['status'] == 'DRAFT':
        if len(parts) < minimum:
            fail(422, f'Sélectionnez au minimum {minimum} joueurs pour débuter la séance')
        if any(p['team'] not in teams for p in parts):
            fail(422, 'Tous les présents doivent être affectés à une équipe valide')
        counts = [sum(p['team'] == team for p in parts) for team in teams]
        if not session.get('allow_uneven_teams') and max(counts) - min(counts) > 1:
            fail(422, 'Équipes déséquilibrées')
    if session["status"] == "CLOSED":
        if len(parts) < minimum:
            fail(422, f"Sélectionnez au minimum {minimum} joueurs pour clôturer la séance")
        if session.get("result") not in allowed:
            fail(422, "Résultat requis")
        if tournament:
            wins = [session.get('wins_' + team.lower(), 0) for team in teams]
            if max(wins) == 0:
                fail(422, 'Victoires requises pour clôturer le tournoi')
            leaders = ''.join(team for team, count in zip(teams, wins) if count == max(wins))
            expected = leaders if len(leaders) == 1 else 'DRAW_ALL' if len(leaders) == 3 else 'DRAW_' + leaders
            if session['result'] != expected:
                fail(422, 'Résultat du tournoi incohérent')
        else:
            a, b = session.get("score_a"), session.get("score_b")
            if type(a) is not int or type(b) is not int or min(a, b) < 0:
                fail(422, "Score requis")
            expected = "A" if a > b else "B" if b > a else "DRAW"
            if session["result"] != expected:
                fail(422, "Résultat incohérent")
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
