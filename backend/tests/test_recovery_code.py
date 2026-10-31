import pytest
from fastapi.testclient import TestClient
from app.main import create_app
from test_api import PASSWORD, system

CODE1 = 'ABCD-EFGH-JKLM-NPQR'
CODE2 = 'WXYZ-2345-6789-ABCD'
CODE3 = 'KLMN-OPQR-STUV-WXYZ'


@pytest.fixture
def recovery_system(monkeypatch):
    monkeypatch.setattr("app.main.secrets.randbelow", lambda _: 1)
    with TestClient(create_app("sqlite:///:memory:")) as client:
        body = {
            "group_id": "#00000001",
            "name": "Group",
            "username": "admin",
            "password": PASSWORD,
            "shared_username": "members",
            "shared_password": PASSWORD,
            "recovery_code": CODE1,
            "members": [
                {"id": "a", "name": "Alice"},
                {"id": "b", "name": "Bob"},
            ],
        }
        res = client.post("/groups", json=body)
        assert res.status_code == 201, res.text
        admin_token = {"Authorization": "Bearer " + res.json()["token"]}
        # Create sport manager
        r = client.post(
            "/groups/%2300000001/accounts",
            headers=admin_token,
            json={"username": "sport", "password": PASSWORD, "member_id": "b", "roles": ["SG"]},
        )
        assert r.status_code == 201
        sport_login = client.post("/auth/login", json={"group_id": "#00000001", "username": "sport", "password": PASSWORD})
        sport_token = {"Authorization": "Bearer " + sport_login.json()["token"]}
        member_login = client.post("/auth/login", json={"group_id": "#00000001", "username": "members", "password": PASSWORD})
        member_token = {"Authorization": "Bearer " + member_login.json()["token"]}
        yield client, {"admin": admin_token, "sport": sport_token, "members": member_token}


# --- C. Inscription & Snapshot ---

def test_registration_with_recovery_code_stores_hash_only(recovery_system):
    c, t = recovery_system
    # Snapshot shows configured=True for admin, but never the plaintext code or hash
    snap = c.get("/groups/%2300000001", headers=t["admin"]).json()
    assert "recovery" in snap
    assert snap["recovery"]["configured"] is True
    assert "hash" not in str(snap)
    assert CODE1 not in str(snap)

    # Sport manager and collective member snapshot does not expose recovery
    sport_snap = c.get("/groups/%2300000001", headers=t["sport"]).json()
    assert "recovery" not in sport_snap or sport_snap.get("recovery") is None
    member_snap = c.get("/groups/%2300000001", headers=t["members"]).json()
    assert "recovery" not in member_snap or member_snap.get("recovery") is None


def test_registration_without_recovery_code_backward_compatible():
    with TestClient(create_app("sqlite:///:memory:")) as client:
        body = {
            "group_id": "#00000002",
            "name": "Legacy Group",
            "username": "legacyadmin",
            "password": PASSWORD,
            "shared_username": "legacymembers",
            "shared_password": PASSWORD,
            "members": [{"id": "m1", "name": "M1"}],
        }
        res = client.post("/groups", json=body)
        assert res.status_code == 201
        gid = res.json()["group_id"].replace("#", "%23")
        admin_token = {"Authorization": "Bearer " + res.json()["token"]}
        snap = client.get(f"/groups/{gid}", headers=admin_token).json()
        assert snap["recovery"]["configured"] is False


def test_registration_invalid_recovery_code():
    with TestClient(create_app("sqlite:///:memory:")) as client:
        # Too short (< 16 alphanumeric characters)
        body = {
            "group_id": "#00000003",
            "name": "Invalid Group",
            "username": "admin3",
            "password": PASSWORD,
            "shared_username": "members3",
            "shared_password": PASSWORD,
            "recovery_code": "SHORT-CODE",
            "members": [{"id": "m1", "name": "M1"}],
        }
        res = client.post("/groups", json=body)
        assert res.status_code == 422


# --- D. Récupération via POST /auth/recover ---

def test_recover_success_and_rotation(recovery_system):
    c, t = recovery_system
    new_pw = "Recovered-Pass-2026"

    # Admin session is active
    assert c.get("/groups/%2300000001", headers=t["admin"]).status_code == 200

    # 1. Recover account with CODE1, rotating to CODE2
    res = c.post("/auth/recover", json={
        "group_id": "#00000001",
        "username": "admin",
        "recovery_code": CODE1,
        "new_password": new_pw,
        "new_recovery_code": CODE2,
    })
    assert res.status_code == 200, res.text
    data = res.json()
    assert "token" in data
    assert data.get("recovery_rotated") is True
    new_admin_token = {"Authorization": "Bearer " + data["token"]}

    # 2. Old token is revoked
    assert c.get("/groups/%2300000001", headers=t["admin"]).status_code == 401

    # 3. New token works
    assert c.get("/groups/%2300000001", headers=new_admin_token).status_code == 200

    # 4. Old password fails, new password succeeds
    assert c.post("/auth/login", json={"group_id": "#00000001", "username": "admin", "password": PASSWORD}).status_code == 401
    assert c.post("/auth/login", json={"group_id": "#00000001", "username": "admin", "password": new_pw}).status_code == 200

    # 5. Old recovery code cannot be reused (one-time use)
    res_reuse = c.post("/auth/recover", json={
        "group_id": "#00000001",
        "username": "admin",
        "recovery_code": CODE1,
        "new_password": "Another-Password-2026",
        "new_recovery_code": CODE3,
    })
    assert res_reuse.status_code == 401

    # 6. New recovery code works for a subsequent recovery
    res_next = c.post("/auth/recover", json={
        "group_id": "#00000001",
        "username": "admin",
        "recovery_code": CODE2,
        "new_password": "Third-Password-2026",
        "new_recovery_code": CODE3,
    })
    assert res_next.status_code == 200


def test_recover_code_normalization(recovery_system):
    c, _ = recovery_system
    # CODE1 is 'ABCD-EFGH-JKLM-NPQR'. Test lowercase without dashes.
    raw_code = "abcdefghjklmnpqr"
    res = c.post("/auth/recover", json={
        "group_id": "#00000001",
        "username": "admin",
        "recovery_code": raw_code,
        "new_password": "Normalized-Pass-2026",
        "new_recovery_code": CODE2,
    })
    assert res.status_code == 200


def test_recover_generic_401_on_all_failures(recovery_system):
    c, _ = recovery_system
    expected_msg = "Récupération impossible. Vérifiez vos informations."

    cases = [
        ("nonexistent-group", "admin", CODE1),
        ("#00000001", "nonexistent-user", CODE1),
        ("#00000001", "members", CODE1),        # shared account
        ("#00000001", "sport", CODE1),          # non-admin manager
        ("#00000001", "admin", "WRONG-CODE-1234567"), # wrong code
    ]
    for gid, uname, code in cases:
        res = c.post("/auth/recover", json={
            "group_id": gid,
            "username": uname,
            "recovery_code": code,
            "new_password": "Valid-Pass-2026",
            "new_recovery_code": CODE2,
        })
        assert res.status_code == 401
        assert res.json().get("detail") == expected_msg


def test_recover_validation_errors_do_not_consume_code(recovery_system):
    c, _ = recovery_system

    # 1. Weak new password (no uppercase)
    res_weak = c.post("/auth/recover", json={
        "group_id": "#00000001",
        "username": "admin",
        "recovery_code": CODE1,
        "new_password": "weakpassword1",
        "new_recovery_code": CODE2,
    })
    assert res_weak.status_code == 422

    # 2. New recovery code identical to old recovery code
    res_same = c.post("/auth/recover", json={
        "group_id": "#00000001",
        "username": "admin",
        "recovery_code": CODE1,
        "new_password": "Valid-Pass-2026",
        "new_recovery_code": CODE1,
    })
    assert res_same.status_code == 422

    # 3. CODE1 was NOT consumed, can still be used successfully
    res_valid = c.post("/auth/recover", json={
        "group_id": "#00000001",
        "username": "admin",
        "recovery_code": CODE1,
        "new_password": "Valid-Pass-2026",
        "new_recovery_code": CODE2,
    })
    assert res_valid.status_code == 200


def test_recover_rate_limiting(recovery_system):
    c, _ = recovery_system
    # 5 failed attempts on (group, username)
    for _ in range(5):
        r = c.post("/auth/recover", json={
            "group_id": "#00000001",
            "username": "admin",
            "recovery_code": "WRONG-CODE-1234567",
            "new_password": "Valid-Pass-2026",
            "new_recovery_code": CODE2,
        })
        assert r.status_code == 401

    # 6th attempt should be rate limited with 429 even with correct code
    r_limited = c.post("/auth/recover", json={
        "group_id": "#00000001",
        "username": "admin",
        "recovery_code": CODE1,
        "new_password": "Valid-Pass-2026",
        "new_recovery_code": CODE2,
    })
    assert r_limited.status_code == 429
    assert "Trop de tentatives" in r_limited.text


# --- E. Régénération de code (PUT /groups/{id}/account/recovery-code) ---

def test_regenerate_recovery_code_success(recovery_system):
    c, t = recovery_system
    # Admin regenerates recovery code to CODE2
    res = c.put("/groups/%2300000001/account/recovery-code", headers=t["admin"], json={
        "current_password": PASSWORD,
        "recovery_code": CODE2,
    })
    assert res.status_code == 200
    assert res.json() == {"ok": True}

    # Old code CODE1 no longer works
    assert c.post("/auth/recover", json={
        "group_id": "#00000001",
        "username": "admin",
        "recovery_code": CODE1,
        "new_password": "New-Password-2026",
        "new_recovery_code": CODE3,
    }).status_code == 401

    # New code CODE2 works
    assert c.post("/auth/recover", json={
        "group_id": "#00000001",
        "username": "admin",
        "recovery_code": CODE2,
        "new_password": "New-Password-2026",
        "new_recovery_code": CODE3,
    }).status_code == 200


def test_regenerate_recovery_code_permissions_and_checks(recovery_system):
    c, t = recovery_system

    # Wrong current password -> 400
    r_pw = c.put("/groups/%2300000001/account/recovery-code", headers=t["admin"], json={
        "current_password": "WrongPassword123",
        "recovery_code": CODE2,
    })
    assert r_pw.status_code == 400
    assert "Mot de passe actuel incorrect" in r_pw.text

    # Non-admin manager -> 403
    r_sport = c.put("/groups/%2300000001/account/recovery-code", headers=t["sport"], json={
        "current_password": PASSWORD,
        "recovery_code": CODE2,
    })
    assert r_sport.status_code == 403

    # Shared member -> 403
    r_members = c.put("/groups/%2300000001/account/recovery-code", headers=t["members"], json={
        "current_password": PASSWORD,
        "recovery_code": CODE2,
    })
    assert r_members.status_code == 403
