import pytest
from fastapi.testclient import TestClient
from app.main import create_app
from test_api import PASSWORD

PASSWORD2 = "CoAdmin-Pass-2026"
NEW_PASSWORD = "New-Admin-Pass-2026"


@pytest.fixture
def co_admin_system(monkeypatch):
    monkeypatch.setattr("app.main.secrets.randbelow", lambda _: 1)
    with TestClient(create_app("sqlite:///:memory:")) as client:
        body = {
            "group_id": "#00000001",
            "name": "CoAdmin Group",
            "username": "admin1",
            "password": PASSWORD,
            "shared_username": "members",
            "shared_password": PASSWORD,
            "members": [
                {"id": "m1", "name": "Alice"},
                {"id": "m2", "name": "Bob"},
                {"id": "m3", "name": "Charlie"},
            ],
        }
        res = client.post("/groups", json=body)
        assert res.status_code == 201, res.text
        admin1_token = {"Authorization": "Bearer " + res.json()["token"]}
        admin1_id = res.json()["account"]["id"]

        # Also create a regular manager (SG)
        r_sg = client.post(
            "/groups/%2300000001/accounts",
            headers=admin1_token,
            json={"username": "sg_user", "password": PASSWORD, "member_id": "m2", "roles": ["SG"]},
        )
        assert r_sg.status_code == 201
        sg_id = r_sg.json()["id"]
        sg_login = client.post("/auth/login", json={"group_id": "#00000001", "username": "sg_user", "password": PASSWORD})
        sg_token = {"Authorization": "Bearer " + sg_login.json()["token"]}

        yield client, {
            "admin1": admin1_token,
            "admin1_id": admin1_id,
            "sg": sg_token,
            "sg_id": sg_id,
        }


def test_multiple_admins_can_be_created_via_add_account(co_admin_system):
    c, t = co_admin_system
    # Admin 1 creates a second ADMIN
    res = c.post(
        "/groups/%2300000001/accounts",
        headers=t["admin1"],
        json={"username": "admin2", "password": PASSWORD2, "member_id": "m3", "roles": ["ADMIN"]},
    )
    assert res.status_code == 201, res.text
    admin2_data = res.json()
    assert "ADMIN" in admin2_data["roles"]

    # Admin 2 can log in
    login_res = c.post("/auth/login", json={"group_id": "#00000001", "username": "admin2", "password": PASSWORD2})
    assert login_res.status_code == 200
    admin2_token = {"Authorization": "Bearer " + login_res.json()["token"]}

    # Snapshot shows both accounts having ADMIN
    snap = c.get("/groups/%2300000001", headers=admin2_token).json()
    admin_accounts = [a for a in snap["accounts"] if "ADMIN" in a["roles"]]
    assert len(admin_accounts) == 2
    assert {a["username"] for a in admin_accounts} == {"admin1", "admin2"}


def test_singular_roles_still_prohibit_duplicates(co_admin_system):
    c, t = co_admin_system
    # Creating a second SG without transfer fails with 409
    res = c.post(
        "/groups/%2300000001/accounts",
        headers=t["admin1"],
        json={"username": "sg2", "password": PASSWORD2, "member_id": "m1", "roles": ["SG"]},
    )
    assert res.status_code == 409
    assert "Un rôle unique est déjà attribué" in res.text


def test_add_admin_role_via_put_roles_without_transfer(co_admin_system):
    c, t = co_admin_system
    # Promote existing SG to also have ADMIN without needing transfer=True
    res = c.put(
        f"/groups/%2300000001/accounts/{t['sg_id']}/roles",
        headers=t["admin1"],
        json={"roles": ["ADMIN", "SG"]},
    )
    assert res.status_code == 200, res.text
    assert "ADMIN" in res.json()["roles"]
    assert "SG" in res.json()["roles"]

    # Admin 1 still retains ADMIN
    snap = c.get("/groups/%2300000001", headers=t["admin1"]).json()
    admin1_acc = next(a for a in snap["accounts"] if a["id"] == t["admin1_id"])
    assert "ADMIN" in admin1_acc["roles"]


def test_admin_can_reset_another_admin_password(co_admin_system):
    c, t = co_admin_system
    # 1. Create admin 2
    r2 = c.post(
        "/groups/%2300000001/accounts",
        headers=t["admin1"],
        json={"username": "admin2", "password": PASSWORD2, "member_id": "m3", "roles": ["ADMIN"]},
    )
    assert r2.status_code == 201
    admin2_id = r2.json()["id"]

    # Admin 2 logs in
    login2 = c.post("/auth/login", json={"group_id": "#00000001", "username": "admin2", "password": PASSWORD2})
    admin2_token = {"Authorization": "Bearer " + login2.json()["token"]}
    assert c.get("/groups/%2300000001", headers=admin2_token).status_code == 200

    # 2. Admin 1 resets Admin 2's password
    res_reset = c.post(
        f"/groups/%2300000001/accounts/{admin2_id}/password",
        headers=t["admin1"],
        json={"password": NEW_PASSWORD},
    )
    assert res_reset.status_code == 200

    # 3. Admin 2's previous token is revoked
    assert c.get("/groups/%2300000001", headers=admin2_token).status_code == 401

    # 4. Admin 2 logs in with new password
    assert c.post("/auth/login", json={"group_id": "#00000001", "username": "admin2", "password": PASSWORD2}).status_code == 401
    assert c.post("/auth/login", json={"group_id": "#00000001", "username": "admin2", "password": NEW_PASSWORD}).status_code == 200

    # 5. Audit trail records manager_password_reset with admin1 as actor
    snap = c.get("/groups/%2300000001", headers=t["admin1"]).json()
    reset_audit = next(a for a in reversed(snap["audit"]) if a["action"] == "manager_password_reset")
    assert reset_audit["actor"] == t["admin1_id"]


def test_admin_cannot_reset_own_password_via_manager_endpoint(co_admin_system):
    c, t = co_admin_system
    # Self-reset on /accounts/{own_id}/password is rejected with 409
    res = c.post(
        f"/groups/%2300000001/accounts/{t['admin1_id']}/password",
        headers=t["admin1"],
        json={"password": NEW_PASSWORD},
    )
    assert res.status_code == 409
    assert "Cette action ne peut pas remplacer votre propre mot de passe Admin" in res.text


def test_last_admin_cannot_be_demoted(co_admin_system):
    c, t = co_admin_system
    # When admin1 is the only admin, removing ADMIN role fails with 409
    res = c.put(
        f"/groups/%2300000001/accounts/{t['admin1_id']}/roles",
        headers=t["admin1"],
        json={"roles": ["CENSOR"]},
    )
    assert res.status_code == 409
    assert "Transférez le rôle obligatoire avant de le retirer" in res.text


def test_co_admin_can_be_demoted_if_another_admin_exists(co_admin_system):
    c, t = co_admin_system
    # 1. Create admin 2 with ADMIN and CENSOR
    r2 = c.post(
        "/groups/%2300000001/accounts",
        headers=t["admin1"],
        json={"username": "admin2", "password": PASSWORD2, "member_id": "m3", "roles": ["ADMIN", "CENSOR"]},
    )
    assert r2.status_code == 201
    admin2_id = r2.json()["id"]

    # 2. Demote admin 2 to CENSOR only
    res_demote = c.put(
        f"/groups/%2300000001/accounts/{admin2_id}/roles",
        headers=t["admin1"],
        json={"roles": ["CENSOR"]},
    )
    assert res_demote.status_code == 200
    assert "ADMIN" not in res_demote.json()["roles"]
    assert "CENSOR" in res_demote.json()["roles"]

    # 3. Admin 1 is still ADMIN
    snap = c.get("/groups/%2300000001", headers=t["admin1"]).json()
    admin1_acc = next(a for a in snap["accounts"] if a["id"] == t["admin1_id"])
    assert "ADMIN" in admin1_acc["roles"]


def test_demoted_admin_loses_recovery_code(co_admin_system):
    c, t = co_admin_system
    # 1. Create admin 2 with ADMIN and CENSOR
    r2 = c.post(
        "/groups/%2300000001/accounts",
        headers=t["admin1"],
        json={"username": "admin2", "password": PASSWORD2, "member_id": "m3", "roles": ["ADMIN", "CENSOR"]},
    )
    assert r2.status_code == 201
    admin2_id = r2.json()["id"]

    # Admin 2 sets recovery code
    l2 = c.post("/auth/login", json={"group_id": "#00000001", "username": "admin2", "password": PASSWORD2})
    admin2_token = {"Authorization": "Bearer " + l2.json()["token"]}
    r_code = c.put(
        "/groups/%2300000001/account/recovery-code",
        headers=admin2_token,
        json={"current_password": PASSWORD2, "recovery_code": "WXYZ-2345-6789-ABCD"},
    )
    assert r_code.status_code == 200

    # Check recovery is configured
    snap_before = c.get("/groups/%2300000001", headers=admin2_token).json()
    assert snap_before["recovery"]["configured"] is True

    # 2. Demote admin 2 (remove ADMIN)
    res_demote = c.put(
        f"/groups/%2300000001/accounts/{admin2_id}/roles",
        headers=t["admin1"],
        json={"roles": ["CENSOR"]},
    )
    assert res_demote.status_code == 200

    # 3. Snapshot for demoted admin no longer has recovery
    snap_after = c.get("/groups/%2300000001", headers=admin2_token).json()
    assert "recovery" not in snap_after or snap_after.get("recovery") is None


def test_non_admin_cannot_manage_admins(co_admin_system):
    c, t = co_admin_system
    # SG tries to create an ADMIN -> 403
    r_add = c.post(
        "/groups/%2300000001/accounts",
        headers=t["sg"],
        json={"username": "hacker", "password": PASSWORD2, "member_id": "m3", "roles": ["ADMIN"]},
    )
    assert r_add.status_code == 403

    # SG tries to reset admin1 password -> 403
    r_reset = c.post(
        f"/groups/%2300000001/accounts/{t['admin1_id']}/password",
        headers=t["sg"],
        json={"password": NEW_PASSWORD},
    )
    assert r_reset.status_code == 403

    # SG tries to grant themselves ADMIN -> 403
    r_roles = c.put(
        f"/groups/%2300000001/accounts/{t['sg_id']}/roles",
        headers=t["sg"],
        json={"roles": ["ADMIN", "SG"]},
    )
    assert r_roles.status_code == 403
