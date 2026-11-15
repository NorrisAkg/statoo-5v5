"""PERF-001 / SEC-001 (audit 14/11/2026) : l'API ne doit jamais geler sous charge concurrente.

Ces tests démarrent un vrai serveur uvicorn dans un thread : un TestClient n'utilise pas
le pool de threads AnyIO de la même manière et ne reproduit pas l'interblocage.
Le verrou global tenu à travers plusieurs sauts de thread bloquait définitivement l'API
dès que ~40 requêtes concurrentes occupaient tout le pool (40 threads).
"""
import threading
import time
from urllib.parse import quote
from concurrent.futures import ThreadPoolExecutor

import httpx
import pytest
import uvicorn

from app.main import create_app

PASSWORD = "Test-Password-2026"
BURST = 50  # strictement plus que les 40 threads du pool AnyIO


class _Server:
    def __init__(self, app):
        self.server = uvicorn.Server(uvicorn.Config(app, host="127.0.0.1", port=0, log_level="warning",
                                                    lifespan="on"))
        self.thread = threading.Thread(target=self.server.run, daemon=True)

    def __enter__(self):
        self.thread.start()
        deadline = time.monotonic() + 15
        while not self.server.started:
            if time.monotonic() > deadline:
                raise RuntimeError("uvicorn n'a pas démarré")
            time.sleep(0.05)
        port = self.server.servers[0].sockets[0].getsockname()[1]
        self.url = f"http://127.0.0.1:{port}"
        return self

    def __exit__(self, *exc):
        # Un serveur interbloqué ne s'arrête jamais : le thread est daemon, on n'attend pas indéfiniment.
        self.server.should_exit = True
        self.thread.join(timeout=5)


def _register(url):
    """Crée un groupe ; le serveur attribue l'identifiant (renvoyé encodé pour l'URL)."""
    body = {"group_id": "#00000001", "name": "Group", "username": "admin", "password": PASSWORD,
            "shared_username": "members", "shared_password": PASSWORD,
            "members": [{"id": "a", "name": "Alice"}, {"id": "b", "name": "Bob"}]}
    r = httpx.post(url + "/groups", json=body, timeout=30)
    assert r.status_code == 201, r.text
    return {"Authorization": "Bearer " + r.json()["token"]}, r.json()["group_id"]


def _burst(calls):
    """Exécute toutes les requêtes en même temps ; renvoie les codes HTTP ou le nom de l'exception."""
    barrier = threading.Barrier(len(calls))

    def run(call):
        barrier.wait(timeout=10)
        try:
            return call().status_code
        except httpx.HTTPError as error:
            return type(error).__name__

    with ThreadPoolExecutor(max_workers=len(calls)) as pool:
        return list(pool.map(run, calls))


def _health_ok(url):
    try:
        return httpx.get(url + "/health", timeout=5).status_code == 200
    except httpx.HTTPError:
        return False


@pytest.fixture
def server():
    with _Server(create_app("sqlite:///:memory:")) as running:
        yield running


def test_unauthenticated_login_burst_does_not_freeze_the_api(server):
    # Nominal du défaut : 80 connexions non authentifiées simultanées (groupe inexistant).
    login = lambda: httpx.post(server.url + "/auth/login", timeout=20,
                               json={"group_id": "#99999999", "username": "x", "password": "nope-nope-1"})
    codes = _burst([login] * BURST)
    assert all(code in (401, 429) for code in codes), codes
    assert _health_ok(server.url), "l'API ne répond plus après la rafale"


def test_authenticated_reads_on_two_groups_all_complete(server):
    # Variante authentifiée, multi-groupes : chaque lecture aboutit et reste isolée à son groupe.
    (first, first_id), (second, second_id) = _register(server.url), _register(server.url)
    assert first_id != second_id
    read_first = lambda: httpx.get(server.url + "/groups/" + quote(first_id, safe=""), headers=first, timeout=20)
    read_second = lambda: httpx.get(server.url + "/groups/" + quote(second_id, safe=""), headers=second, timeout=20)
    cross = lambda: httpx.get(server.url + "/groups/" + quote(second_id, safe=""), headers=first, timeout=20)
    codes = _burst([read_first, read_second] * (BURST // 2) + [cross] * 4)
    assert codes[:BURST] == [200] * BURST, codes
    assert codes[BURST:] == [403] * 4, codes
    assert _health_ok(server.url)


def test_mixed_burst_of_writes_and_reads_keeps_state_consistent(server):
    # Concurrence en écriture : des PUT /members concurrents ne corrompent pas l'agrégat.
    admin, group_id = _register(server.url)
    path = server.url + "/groups/" + quote(group_id, safe="")
    roster = [{"id": "a", "name": "Alice"}, {"id": "b", "name": "Bob"}]
    write = lambda: httpx.put(path + "/members", headers=admin, json=roster, timeout=20)
    read = lambda: httpx.get(path, headers=admin, timeout=20)
    codes = _burst([write, read] * (BURST // 2))
    assert all(code == 200 for code in codes), codes
    snapshot = httpx.get(path, headers=admin, timeout=5).json()
    assert [m["id"] for m in snapshot["members"]] == ["a", "b"]


def test_login_throttle_counts_every_concurrent_failure(server):
    # Régression : le compteur de tentatives reste exact sous concurrence. Sur SQLite les requêtes
    # sont sérialisées ; le cas sans sérialisation (PostgreSQL) est couvert par le test suivant.
    # Identifiants tous différents : seule la limite par IP (20/min) s'applique, pas celle par compte.
    _, group_id = _register(server.url)
    bad = lambda i: (lambda: httpx.post(server.url + "/auth/login", timeout=20,
                                        json={"group_id": group_id, "username": f"user{i}", "password": "wrong-password-1"}))
    codes = _burst([bad(i) for i in range(30)])
    assert codes.count(401) == 20, codes
    assert codes.count(429) == 10, codes


def test_recover_burst_without_session_serialization_allows_only_five_attempts(monkeypatch, tmp_path):
    # PostgreSQL n'a plus de verrou applicatif : N récupérations simultanées sur le même compte
    # ne doivent pas toutes passer le contrôle avant que le premier échec soit compté.
    # Base SQLite fichier (plusieurs connexions) et sérialisation désactivée pour simuler ce cas.
    monkeypatch.setattr("app.main._serialize_sessions", lambda engine: False)
    with _Server(create_app(f"sqlite:///{tmp_path / 'recover.db'}")) as running:
        body = {"group_id": "#00000001", "name": "Group", "username": "admin", "password": PASSWORD,
                "shared_username": "members", "shared_password": PASSWORD,
                "recovery_code": "ABCD-EFGH-JKLM-NPQR",
                "members": [{"id": "a", "name": "Alice"}, {"id": "b", "name": "Bob"}]}
        created = httpx.post(running.url + "/groups", json=body, timeout=30)
        assert created.status_code == 201, created.text
        group_id = created.json()["group_id"]
        attempt = lambda: httpx.post(running.url + "/auth/recover", timeout=60, json={
            "group_id": group_id, "username": "admin", "recovery_code": "WXYZ-2345-6789-ABCD",
            "new_password": "New-Password-2026", "new_recovery_code": "KLMN-PQRS-TUVW-XYZ2"})
        codes = _burst([attempt] * 12)
    assert codes.count(401) == 5, codes
    assert codes.count(429) == 7, codes


def test_account_and_registration_limits_hold_without_session_serialization(monkeypatch, tmp_path):
    # SEC-002 / SEC-003 sous concurrence réelle, comportement PostgreSQL (aucun verrou applicatif).
    monkeypatch.setattr("app.main._serialize_sessions", lambda engine: False)
    monkeypatch.delenv("STATOO_CLIENT_IP_HEADER", raising=False)
    monkeypatch.delenv("STATOO_TRUSTED_PROXY_HOPS", raising=False)
    with _Server(create_app(f"sqlite:///{tmp_path / 'limits.db'}")) as running:
        _, group_id = _register(running.url)
        bad = lambda: httpx.post(running.url + "/auth/login", timeout=60,
                                 json={"group_id": group_id, "username": "admin", "password": "wrong-password-1"})
        login_codes = _burst([bad] * 15)

        def create(i):
            body = {"group_id": "#00000001", "name": f"G{i}", "username": "admin", "password": PASSWORD,
                    "shared_username": "members", "shared_password": PASSWORD, "members": []}
            return lambda: httpx.post(running.url + "/groups", json=body, timeout=60)
        creation_codes = _burst([create(i) for i in range(8)])
    assert login_codes.count(401) == 10, login_codes
    assert login_codes.count(429) == 5, login_codes
    # Une création a déjà eu lieu (_register) : il en reste 4 sur 5 dans l'heure.
    assert creation_codes.count(201) == 4, creation_codes
    assert creation_codes.count(429) == 4, creation_codes
