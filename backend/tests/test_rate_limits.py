"""SEC-002, SEC-003, SEC-005 (audit 14/11/2026) : limitation des tentatives.

- SEC-002 : l'IP client est configurable derrière un proxy (STATOO_CLIENT_IP_HEADER ou
  STATOO_TRUSTED_PROXY_HOPS) ; par défaut, X-Forwarded-For est ignoré (non falsifiable).
  La connexion est aussi limitée par compte, indépendamment de l'IP.
- SEC-003 : 5 créations de groupe par heure et par IP ; les rejeux idempotents et les
  requêtes invalides ne consomment pas le quota.
- SEC-005 : les routes qui vérifient un mot de passe limitent les échecs par acteur.
"""
import time
import uuid
from types import SimpleNamespace
from urllib.parse import quote

import pytest
from fastapi.testclient import TestClient

import app.main as main
from app.main import create_app

PASSWORD = "Test-Password-2026"
WRONG = "Wrong-Password-2026"


def registration(**extra):
    body = {"operation_id": str(uuid.uuid4()), "group_id": "#00000001", "name": "Group",
            "username": "admin", "password": PASSWORD, "shared_username": "members",
            "shared_password": PASSWORD, "recovery_code": "ABCD-EFGH-JKLM-NPQR",
            "members": [{"id": "a", "name": "Alice"}, {"id": "b", "name": "Bob"}]}
    body.update(extra)
    return body


def bad_login(client, headers=None, group_id="#99999999", username="x"):
    # Varier `username` pour tester la limite par IP sans déclencher la limite par compte (10).
    return client.post("/auth/login", headers=headers or {},
                       json={"group_id": group_id, "username": username, "password": WRONG})


@pytest.fixture
def client(monkeypatch):
    monkeypatch.delenv("STATOO_CLIENT_IP_HEADER", raising=False)
    monkeypatch.delenv("STATOO_TRUSTED_PROXY_HOPS", raising=False)
    with TestClient(create_app("sqlite:///:memory:")) as c:
        yield c


def app_with(monkeypatch, **env):
    monkeypatch.delenv("STATOO_CLIENT_IP_HEADER", raising=False)
    monkeypatch.delenv("STATOO_TRUSTED_PROXY_HOPS", raising=False)
    for key, value in env.items():
        monkeypatch.setenv(key, value)
    return TestClient(create_app("sqlite:///:memory:"))


@pytest.fixture
def group(client):
    r = client.post("/groups", json=registration())
    assert r.status_code == 201, r.text
    admin = {"Authorization": "Bearer " + r.json()["token"]}
    gid = r.json()["group_id"]
    path = "/groups/" + quote(gid, safe="")
    manager = client.post(path + "/accounts", headers=admin, json={
        "username": "sport", "password": PASSWORD, "member_id": "b", "roles": ["SG"]})
    assert manager.status_code == 201, manager.text
    return {"id": gid, "path": path, "admin": admin, "manager_id": manager.json()["id"]}


# --- SEC-002 : IP client ---------------------------------------------------------------

def test_forwarded_for_is_ignored_by_default_so_it_cannot_bypass_the_limit(client):
    codes = [bad_login(client, {"X-Forwarded-For": f"10.0.0.{i}"}, username=f"x{i}").status_code for i in range(21)]
    assert codes[:20] == [401] * 20
    assert codes[20] == 429


def test_trusted_proxy_hops_uses_the_entry_appended_by_the_proxy(monkeypatch):
    with app_with(monkeypatch, STATOO_TRUSTED_PROXY_HOPS="1") as c:
        # Le client peut forger les entrées de gauche ; seule la dernière (ajoutée par le proxy) compte.
        codes = [bad_login(c, {"X-Forwarded-For": f"6.6.6.{i}, 203.0.113.7"}, username=f"x{i}").status_code for i in range(21)]
        assert codes[20] == 429
        assert bad_login(c, {"X-Forwarded-For": "203.0.113.8"}).status_code == 401


def test_trusted_proxy_hops_beyond_the_header_falls_back_to_the_socket_address(monkeypatch):
    with app_with(monkeypatch, STATOO_TRUSTED_PROXY_HOPS="3") as c:
        codes = [bad_login(c, {"X-Forwarded-For": f"203.0.113.{i}"}, username=f"x{i}").status_code for i in range(21)]
        assert codes[20] == 429  # en-tête trop court : adresse du socket, commune à tous


def test_client_ip_header_isolates_clients(monkeypatch):
    with app_with(monkeypatch, STATOO_CLIENT_IP_HEADER="CF-Connecting-IP") as c:
        codes = [bad_login(c, {"CF-Connecting-IP": "198.51.100.1"}, username=f"x{i}").status_code for i in range(21)]
        assert codes[20] == 429
        assert bad_login(c, {"CF-Connecting-IP": "198.51.100.2"}).status_code == 401
        # Sans l'en-tête, retour à l'adresse du socket (compteur distinct).
        assert bad_login(c).status_code == 401


def test_invalid_hops_value_falls_back_to_default(monkeypatch):
    with app_with(monkeypatch, STATOO_TRUSTED_PROXY_HOPS="abc") as c:
        codes = [bad_login(c, {"X-Forwarded-For": f"10.0.0.{i}"}, username=f"x{i}").status_code for i in range(21)]
        assert codes[20] == 429


def test_login_is_limited_per_account_and_ip(monkeypatch):
    with app_with(monkeypatch, STATOO_TRUSTED_PROXY_HOPS="1") as c:
        created = c.post("/groups", json=registration(), headers={"X-Forwarded-For": "192.0.2.1"})
        gid = created.json()["group_id"]
        attacker = {"X-Forwarded-For": "203.0.113.1"}
        codes = [bad_login(c, attacker, gid, "members").status_code for _ in range(11)]
        assert codes[:10] == [401] * 10
        assert codes[10] == 429
        # Le bon mot de passe est refusé depuis cette IP pendant la fenêtre.
        blocked = c.post("/auth/login", headers=attacker,
                         json={"group_id": gid, "username": "members", "password": PASSWORD})
        assert blocked.status_code == 429
        # Un membre légitime (autre IP) se connecte toujours au compte commun : pas de verrouillage ciblé.
        member = c.post("/auth/login", headers={"X-Forwarded-For": "198.51.100.5"},
                        json={"group_id": gid, "username": "members", "password": PASSWORD})
        assert member.status_code == 200, member.text


def test_login_has_a_global_ceiling_per_account_across_ips(monkeypatch):
    with app_with(monkeypatch, STATOO_TRUSTED_PROXY_HOPS="1") as c:
        gid = c.post("/groups", json=registration(), headers={"X-Forwarded-For": "192.0.2.1"}).json()["group_id"]
        # 50 échecs répartis sur 10 IP (5 chacune, sous la limite par IP et par compte).
        for i in range(50):
            assert bad_login(c, {"X-Forwarded-For": f"203.0.113.{i % 10}"}, gid, "admin").status_code == 401
        assert bad_login(c, {"X-Forwarded-For": "198.51.100.77"}, gid, "admin").status_code == 429
        # Un autre compte du même groupe n'est pas touché.
        assert bad_login(c, {"X-Forwarded-For": "198.51.100.78"}, gid, "members").status_code == 401


def test_successful_login_resets_the_account_counter(client, group):
    for _ in range(9):
        assert bad_login(client, None, group["id"], "admin").status_code == 401
    ok = client.post("/auth/login", json={"group_id": group["id"], "username": "admin", "password": PASSWORD})
    assert ok.status_code == 200
    for _ in range(9):
        assert bad_login(client, None, group["id"], "admin").status_code == 401


# --- SEC-003 : création de groupes ------------------------------------------------------

def test_group_creation_is_limited_to_five_per_hour_per_ip(monkeypatch):
    with app_with(monkeypatch, STATOO_TRUSTED_PROXY_HOPS="1") as c:
        same = {"X-Forwarded-For": "203.0.113.1"}
        codes = [c.post("/groups", json=registration(), headers=same).status_code for _ in range(6)]
        assert codes == [201] * 5 + [429]
        assert c.post("/groups", json=registration(), headers={"X-Forwarded-For": "203.0.113.2"}).status_code == 201


def test_idempotent_replay_and_invalid_requests_do_not_consume_the_quota(client):
    first = registration()
    assert client.post("/groups", json=first).status_code == 201
    for _ in range(5):
        replay = client.post("/groups", json=first)
        assert replay.status_code == 201, replay.text
    for _ in range(5):
        invalid = client.post("/groups", json=registration(shared_username="admin"))
        assert invalid.status_code == 422
    codes = [client.post("/groups", json=registration()).status_code for _ in range(5)]
    assert codes == [201] * 4 + [429]


def test_group_creation_quota_expires_after_an_hour(client, monkeypatch):
    for _ in range(5):
        assert client.post("/groups", json=registration()).status_code == 201
    assert client.post("/groups", json=registration()).status_code == 429
    # Horloge remplacée seulement pour le module de l'app (pas pour AnyIO ni httpx).
    later = time.monotonic() + 3601
    monkeypatch.setattr(main, "time", SimpleNamespace(monotonic=lambda: later))
    assert client.post("/groups", json=registration()).status_code == 201


# --- SEC-005 : oracles de mot de passe ---------------------------------------------------

def test_manager_password_verify_is_limited_per_actor(client, group):
    url = group["path"] + "/accounts/" + group["manager_id"] + "/password/verify"
    for _ in range(6):  # les vérifications réussies ne comptent pas
        assert client.post(url, headers=group["admin"], json={"password": PASSWORD}).status_code == 200
    codes = [client.post(url, headers=group["admin"], json={"password": WRONG}).status_code for _ in range(6)]
    assert codes == [400] * 5 + [429]
    assert client.post(url, headers=group["admin"], json={"password": PASSWORD}).status_code == 429


def test_shared_access_verify_is_limited_per_actor(client, group):
    url = group["path"] + "/shared-access/verify"
    assert client.post(url, headers=group["admin"], json={"password": PASSWORD}).status_code == 200
    codes = [client.post(url, headers=group["admin"], json={"password": WRONG}).status_code for _ in range(6)]
    assert codes == [400] * 5 + [429]


def test_recovery_code_regeneration_is_limited_per_actor(client, group):
    url = group["path"] + "/account/recovery-code"
    body = {"current_password": WRONG, "recovery_code": "WXYZ-2345-6789-ABCD"}
    codes = [client.put(url, headers=group["admin"], json=body).status_code for _ in range(6)]
    assert codes == [400] * 5 + [429]


def test_password_verify_limits_are_isolated_between_groups(client, group):
    other = client.post("/groups", json=registration())
    other_admin = {"Authorization": "Bearer " + other.json()["token"]}
    other_url = "/groups/" + quote(other.json()["group_id"], safe="") + "/shared-access/verify"
    url = group["path"] + "/shared-access/verify"
    for _ in range(5):
        assert client.post(url, headers=group["admin"], json={"password": WRONG}).status_code == 400
    assert client.post(url, headers=group["admin"], json={"password": WRONG}).status_code == 429
    assert client.post(other_url, headers=other_admin, json={"password": WRONG}).status_code == 400



def test_verify_validation_errors_do_not_count(client, group):
    url = group["path"] + "/shared-access/verify"
    for _ in range(6):
        assert client.post(url, headers=group["admin"], json={"password": "short"}).status_code == 422
    codes = [client.post(url, headers=group["admin"], json={"password": WRONG}).status_code for _ in range(6)]
    assert codes == [400] * 5 + [429]


def test_client_ip_header_value_is_truncated(monkeypatch):
    with app_with(monkeypatch, STATOO_CLIENT_IP_HEADER="True-Client-IP") as c:
        prefix = "1" * 100
        codes = [bad_login(c, {"True-Client-IP": prefix + str(i)}, username=f"x{i}").status_code for i in range(21)]
        assert codes[20] == 429  # mêmes 100 premiers caractères : même client


# --- Configuration au démarrage ----------------------------------------------------------

def test_render_requires_an_explicit_client_ip_source(monkeypatch):
    monkeypatch.setenv("RENDER", "true")
    monkeypatch.delenv("STATOO_CLIENT_IP_HEADER", raising=False)
    monkeypatch.delenv("STATOO_TRUSTED_PROXY_HOPS", raising=False)
    with pytest.raises(RuntimeError, match="STATOO_TRUSTED_PROXY_HOPS"):
        create_app("sqlite:///:memory:")
    monkeypatch.setenv("STATOO_TRUSTED_PROXY_HOPS", "1")
    create_app("sqlite:///:memory:")


def test_forwarded_for_cannot_be_used_as_client_ip_header(monkeypatch):
    monkeypatch.setenv("STATOO_CLIENT_IP_HEADER", "X-Forwarded-For")
    with pytest.raises(RuntimeError, match="STATOO_TRUSTED_PROXY_HOPS"):
        create_app("sqlite:///:memory:")


# --- Purge des compteurs -------------------------------------------------------------------

def test_prune_drops_expired_keys_then_the_oldest_beyond_the_cap():
    bucket = {"expired": [0.0], "old": [100.0], "mid": [200.0], "new": [300.0]}
    main._prune(bucket, window=250.0, now=301.0, cap=2)  # seul "expired" a plus de 250 s
    assert set(bucket) == {"mid", "new"}


def test_prune_keeps_everything_under_the_cap():
    bucket = {"a": [0.0], "b": [10.0]}
    main._prune(bucket, window=60.0, now=1000.0, cap=10)
    assert set(bucket) == {"a", "b"}


def test_prune_leaves_headroom_so_it_does_not_sort_on_every_new_key():
    bucket = {f"k{i}": [1000.0 + i] for i in range(11)}
    main._prune(bucket, window=60.0, now=1011.0, cap=10)
    assert set(bucket) == {f"k{i}" for i in range(2, 11)}  # 9 clés restantes : marge de 10 %
