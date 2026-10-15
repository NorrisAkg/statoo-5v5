import uuid
import pytest
from fastapi.testclient import TestClient
from app.main import create_app
from app.finance import totals

PASSWORD = "Test-Password-2026"

@pytest.fixture
def system():
    with TestClient(create_app("sqlite:///:memory:")) as client:
        body = {"group_id": "g", "name": "Group", "username": "admin", "password": PASSWORD,
                "shared_username": "members", "shared_password": PASSWORD,
                "members": [{"id": "a", "name": "Alice"}, {"id": "b", "name": "Bob"},
                            {"id": "c", "name": "Charlie"}, {"id": "d", "name": "Diane"}]}
        response = client.post("/groups", json=body)
        assert response.status_code == 201, response.text
        admin = {"Authorization": "Bearer " + response.json()["token"]}
        tokens = {"admin": admin}
        accounts = {}
        for username, member, roles in [("president", "a", ["PDT"]), ("sport", "b", ["SG"]),
                                        ("finance", "c", ["TR"]), ("vice", "d", ["VP", "SGA", "TGA"])]:
            r = client.post("/groups/g/accounts", headers=admin, json={"username": username,
                            "password": PASSWORD, "member_id": member, "roles": roles})
            assert r.status_code == 201, r.text
            accounts[username] = r.json()["id"]
            login = client.post("/auth/login", json={"group_id": "g", "username": username, "password": PASSWORD})
            tokens[username] = {"Authorization": "Bearer " + login.json()["token"]}
        r = client.post("/auth/login", json={"group_id": "g", "username": "members", "password": PASSWORD})
        tokens["members"] = {"Authorization": "Bearer " + r.json()["token"]}
        yield client, tokens, accounts

def initialize(c, t):
    assert c.post('/groups/g/opening', headers=t['finance'], json={'cash': 0, 'members': {}}).status_code == 200
    proposal = c.get('/groups/g', headers=t['president']).json()['opening_proposal']
    assert c.post('/groups/g/opening/approve', json={'proposal': proposal}, headers=t['president']).status_code == 200


def sport(status="DRAFT"):
    return {"session": {"id": "s", "team_id": "g", "played_at": "2026-10-10T20:00:00",
                         "status": status, "score_a": 0, "score_b": 0, "result": "DRAW"},
            "participations": []}

def point(cancelled=False):
    return {"played_at": "2026-10-10T20:00:00", "rate": 100, "cancelled": cancelled,
            "lines": [{"member_id": x, "contribution": 0, "penalty_paid": 0,
                       "penalty_due": 0, "reason": ""} for x in "abcd"],
            "expenses": [], "donations": []}

def event(domain, payload, revision=0, generation=0):
    return {"operation_id": str(uuid.uuid4()), "occurrence_id": "saturday-2026-10-10",
            "domain": domain, "base_revision": revision, "generation": generation,
            "payload": payload, "reason": "Correction"}

def test_shared_members_are_read_only_and_isolated(system):
    c, t, _ = system
    assert c.get("/groups/g", headers=t["members"]).status_code == 200
    assert c.get("/groups/other", headers=t["members"]).status_code == 403
    for domain, payload in [("sport", sport()), ("finance", point())]:
        assert c.post("/groups/g/sync", json=event(domain, payload), headers=t["members"]).status_code == 403
    assert c.post("/groups/g/sync", json=event("sport", sport()), headers=t["admin"]).status_code == 403


@pytest.mark.parametrize("roles", [[], ["MEMBER"]])
def test_individual_account_requires_responsibility(system, roles):
    c, t, _ = system
    before = c.get('/groups/g', headers=t['admin']).json()['accounts']
    response = c.post('/groups/g/accounts', headers=t['admin'], json={
        'username': 'simple-member', 'password': PASSWORD, 'member_id': 'a', 'roles': roles})
    assert response.status_code == 422
    assert 'responsable' in response.json()['detail']
    assert c.get('/groups/g', headers=t['admin']).json()['accounts'] == before


@pytest.mark.parametrize('role', ['ADMIN', 'PDT', 'VP', 'TR', 'TGA', 'SG', 'SGA', 'CENSOR'])
def test_responsible_individual_account_keeps_member_role(role):
    with TestClient(create_app('sqlite:///:memory:')) as c:
        response = c.post('/groups', json={
            'group_id': 'g', 'name': 'Group', 'username': 'admin', 'password': PASSWORD,
            'shared_username': 'members', 'shared_password': PASSWORD,
            'members': [{'id': 'a', 'name': 'Alice'}]})
        admin = {'Authorization': 'Bearer ' + response.json()['token']}
        response = c.post('/groups/g/accounts', headers=admin, json={
            'username': 'responsible', 'password': PASSWORD, 'member_id': 'a', 'roles': [role]})
        assert response.status_code == (409 if role == 'ADMIN' else 201)
        if role != 'ADMIN':
            assert set(response.json()['roles']) == {role, 'MEMBER'}
            assert response.json()['member_id'] == 'a'


@pytest.mark.parametrize('roles', [['UNKNOWN'], ['CENSOR', 'CENSOR']])
def test_invalid_responsibility_remains_rejected(system, roles):
    c, t, _ = system
    assert c.post('/groups/g/accounts', headers=t['admin'], json={
        'username': 'invalid', 'password': PASSWORD, 'member_id': 'a', 'roles': roles}).status_code == 422


def test_collective_cannot_create_individual_accounts(system):
    c, t, _ = system
    assert c.post('/groups/g/accounts', headers=t['members'], json={
        'username': 'forbidden', 'password': PASSWORD, 'member_id': 'a', 'roles': ['CENSOR']}).status_code == 403


def test_former_responsible_keeps_read_only_account_after_transfer(system):
    c, t, accounts = system
    response = c.put(f"/groups/g/accounts/{accounts['vice']}/roles", headers=t['admin'],
                     json={'roles': ['VP', 'SGA', 'TGA', 'SG'], 'transfer': True, 'reason': 'Remplacement'})
    assert response.status_code == 200
    state = c.get('/groups/g', headers=t['admin']).json()
    former = next(a for a in state['accounts'] if a['id'] == accounts['sport'])
    assert former['roles'] == ['MEMBER']
    assert c.get('/groups/g', headers=t['sport']).status_code == 200
    assert c.post('/groups/g/sync', headers=t['sport'], json=event('sport', sport())).status_code == 403

def test_single_roles_and_explicit_atomic_transfer(system):
    c, t, accounts = system
    r = c.post("/groups/g/accounts", headers=t["admin"], json={"username": "another", "password": PASSWORD,
              "member_id": "b", "roles": ["PDT"]})
    assert r.status_code == 409
    r = c.put(f"/groups/g/accounts/{accounts['vice']}/roles", headers=t["admin"], json={"roles": ["VP", "PDT"]})
    assert r.status_code == 409
    r = c.put(f"/groups/g/accounts/{accounts['vice']}/roles", headers=t["admin"],
              json={"roles": ["VP", "PDT"], "transfer": True, "reason": "Election"})
    assert r.status_code == 200
    state = c.get("/groups/g", headers=t["admin"]).json()
    assert sum("PDT" in a["roles"] for a in state["accounts"]) == 1

def test_idempotent_sync_and_payload_reuse_rejected(system):
    c, t, _ = system
    initialize(c, t)
    e = event("finance", point())
    assert c.post("/groups/g/sync", json=e, headers=t["finance"]).json()["revision"] == 1
    assert c.post("/groups/g/sync", json=e, headers=t["finance"]).json()["revision"] == 1
    e["payload"]["rate"] = 200
    assert c.post("/groups/g/sync", json=e, headers=t["finance"]).status_code == 409
    assert c.get("/groups/g", headers=t["members"]).json()["finances"]["cash"] == 0

def test_conflict_preserves_versions_and_president_decides_once(system):
    c, t, accounts = system
    assert c.post("/groups/g/sync", json=event("sport", sport()), headers=t["sport"]).json()["status"] == "accepted"
    e = event("sport", sport("CLOSED"))
    assert c.post("/groups/g/sync", json=e, headers=t["vice"]).json()["status"] == "conflict"
    url = "/groups/g/documents/sport/saturday-2026-10-10/resolve"
    decision = {"revision": 1, "candidate_id": e["operation_id"], "reason": "Version checked"}
    assert c.post(url, json=decision, headers=t["sport"]).status_code == 403
    assert c.post(url, json=decision, headers=t["president"]).status_code == 200
    assert c.post(url, json=decision, headers=t["vice"]).status_code == 409
    doc = c.get("/groups/g", headers=t["president"]).json()["documents"]["sport:saturday-2026-10-10"]
    assert doc["owner"] == accounts["vice"]
    assert len(doc["history"]) == 1
    assert doc["history"][0]["discarded_candidates"]
    # A stale former owner's data never overwrites the retained version.
    assert c.post("/groups/g/sync", json=event("sport", sport(), 1), headers=t["sport"]).json()["status"] == "conflict"

def test_finance_and_sport_have_independent_owners(system):
    c, t, _ = system
    initialize(c, t)
    assert c.post("/groups/g/sync", json=event("sport", sport("CLOSED")), headers=t["sport"]).status_code == 200
    assert c.post("/groups/g/sync", json=event("finance", point()), headers=t["finance"]).status_code == 200
    assert c.post("/groups/g/sync", json=event("finance", point()), headers=t["sport"]).status_code == 403

def test_cancelled_period_debt_without_cash(system):
    c, t, _ = system
    initialize(c, t)
    p = point(True)
    r = c.post("/groups/g/sync", json=event("finance", p), headers=t["finance"])
    assert r.status_code == 200, r.text
    balance = c.get("/groups/g", headers=t["members"]).json()["finances"]
    assert balance["cash"] == 0
    assert balance["members"]["a"]["contribution_balance"] == -100
    p["lines"][0]["contribution"] = 100
    assert c.post("/groups/g/sync", json=event("finance", p, 1), headers=t["finance"]).status_code == 422

def test_cash_and_penalties_do_not_consume_contribution_advance(system):
    c, t, _ = system
    initialize(c, t)
    p = point()
    p["lines"][0].update(contribution=500, penalty_due=100)
    p["expenses"] = [{"id": "water", "label": "Water", "amount": 200}]
    p["donations"] = [{"id": "gift", "label": "Gift", "amount": 50}]
    assert c.post("/groups/g/sync", json=event("finance", p), headers=t["finance"]).status_code == 200
    balance = c.get("/groups/g", headers=t["members"]).json()["finances"]
    assert balance["cash"] == 350
    assert balance["members"]["a"] == {"contribution_balance": 400, "penalty_debt": 100}

def test_opening_requires_approval_and_is_not_a_receipt(system):
    c, t, _ = system
    opening = {"cash": 1000, "members": {"a": {"contribution_balance": 500, "penalty_debt": 100}}}
    assert c.post("/groups/g/opening", json=opening, headers=t["sport"]).status_code == 403
    assert c.post("/groups/g/opening", json=opening, headers=t["finance"]).status_code == 200
    assert c.get("/groups/g", headers=t["members"]).json()["finances"]["cash"] == 0
    proposal = c.get('/groups/g', headers=t['vice']).json()['opening_proposal']
    assert c.post("/groups/g/opening/approve", json={'proposal': proposal}, headers=t["vice"]).status_code == 200
    assert c.get("/groups/g", headers=t["members"]).json()["finances"]["cash"] == 1000
    assert c.post("/groups/g/opening", json=opening, headers=t["finance"]).status_code == 409

def test_rotation_revokes_existing_shared_sessions(system):
    c, t, _ = system
    r = c.put("/groups/g/shared-access", headers=t["admin"], json={
      "group_id": "g", "username": "members", "password": "Changed-Password"})
    assert r.status_code == 200
    assert c.get("/groups/g", headers=t["members"]).status_code == 401

def test_unknown_member_and_negative_amount_rejected(system):
    c, t, _ = system
    initialize(c, t)
    p = point()
    p["lines"][0]["member_id"] = "foreign"
    assert c.post("/groups/g/sync", json=event("finance", p), headers=t["finance"]).status_code == 422
    p = point()
    p["lines"][0]["contribution"] = -1
    assert c.post("/groups/g/sync", json=event("finance", p), headers=t["finance"]).status_code == 422


def test_sport_creates_dues_for_absent_members_without_double_counting(system):
    c, t, _ = system
    initialize(c, t)
    assert c.post('/groups/g/sync', headers=t['sport'], json=event('sport', sport())).status_code == 200
    balance = c.get('/groups/g', headers=t['members']).json()['finances']
    assert balance['cash'] == 0
    assert balance['members']['a']['contribution_balance'] == -100
    assert c.post('/groups/g/sync', headers=t['finance'], json=event('finance', point())).status_code == 200
    balance = c.get('/groups/g', headers=t['members']).json()['finances']
    assert balance['members']['a']['contribution_balance'] == -100


def test_finance_cannot_omit_members_or_collect_after_sport_cancelled(system):
    c, t, _ = system
    initialize(c, t)
    p = point()
    p['lines'] = []
    assert c.post('/groups/g/sync', headers=t['finance'], json=event('finance', p)).status_code == 422
    assert c.post('/groups/g/sync', headers=t['sport'], json=event('sport', sport('CANCELLED'))).status_code == 200
    p = point()
    p['lines'][0]['contribution'] = 500
    assert c.post('/groups/g/sync', headers=t['finance'], json=event('finance', p)).status_code == 422


def test_arbitration_cannot_cancel_a_period_with_receipts(system):
    c, t, _ = system
    initialize(c, t)
    assert c.post('/groups/g/sync', headers=t['sport'], json=event('sport', sport())).status_code == 200
    p = point()
    p['lines'][0]['contribution'] = 500
    assert c.post('/groups/g/sync', headers=t['finance'], json=event('finance', p)).status_code == 200
    candidate = event('sport', sport('CANCELLED'))
    assert c.post('/groups/g/sync', headers=t['vice'], json=candidate).json()['status'] == 'conflict'
    url = '/groups/g/documents/sport/saturday-2026-10-10/resolve'
    assert c.post(url, headers=t['president'], json={'revision': 1, 'candidate_id': candidate['operation_id'], 'reason':'Verified'}).status_code == 409


def test_group_financial_defaults_permissions_and_frozen_previous_dues(system):
    c, t, _ = system
    endpoint='/groups/g/financial-settings'
    settings={'contribution':200,'late_penalty':50}
    assert c.put(endpoint,headers=t['members'],json=settings).status_code == 403
    assert c.put(endpoint,headers=t['sport'],json=settings).status_code == 403
    assert c.put(endpoint,headers=t['finance'],json=settings).status_code == 200
    assert c.get('/groups/g',headers=t['members']).json()['financial_settings'] == settings
    assert c.post('/groups/g/sync',headers=t['sport'],json=event('sport',sport())).status_code == 200
    assert c.put(endpoint,headers=t['admin'],json={'contribution':300,'late_penalty':100}).status_code == 200
    snapshot=c.get('/groups/g',headers=t['members']).json()
    assert snapshot['obligations']['saturday-2026-10-10']['rate']==200
    assert c.put(endpoint,headers=t['finance'],json={'contribution':-1,'late_penalty':100}).status_code == 422
