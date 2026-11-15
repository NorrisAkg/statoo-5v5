"""Accès membre en lecture seule par simple numéro de groupe."""
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from app.models import database

PASSWORD = 'Admin-Password-2026'


@pytest.fixture
def api():
    engine = database('sqlite:///:memory:')
    with patch('app.main.database', return_value=engine), patch('app.main.REGISTRATIONS_PER_HOUR', 10_000):
        app = create_app('sqlite:///:memory:')
        with TestClient(app) as client:
            yield client


def register(client):
    body = {
        'group_id': '#00000001',
        'name': 'Groupe Test',
        'username': 'admin',
        'password': PASSWORD,
        'shared_username': 'membres',
        'shared_password': PASSWORD,
        'recovery_code': 'ABCD-EFGH-JKLM-NPQR',
        'members': [{'id': 'a', 'name': 'Alice'}],
    }
    response = client.post('/groups', json=body)
    assert response.status_code == 201, response.text
    return response.json()['group_id']


@pytest.mark.parametrize('format_fn', [lambda gid: gid, lambda gid: gid.lstrip('#'), lambda gid: f'  {gid}  '])
def test_join_readonly_nominal_with_or_without_hash(api, format_fn):
    group_id = register(api)
    res = api.post('/groups/join-readonly', json={'group_id': format_fn(group_id)})
    assert res.status_code == 200, res.text
    data = res.json()
    assert data['group_id'] == group_id
    assert data['token']
    assert data['expires_at']
    assert data['account']['shared'] is True
    assert data['account']['roles'] == ['MEMBER']


def test_join_readonly_token_is_forbidden_on_mutations(api):
    group_id = register(api)
    res = api.post('/groups/join-readonly', json={'group_id': group_id})
    assert res.status_code == 200, res.text
    token = res.json()['token']
    headers = {'Authorization': f'Bearer {token}'}

    # Lecture autorisée
    from urllib.parse import quote
    gid = quote(group_id)
    get_res = api.get(f'/groups/{gid}', headers=headers)
    assert get_res.status_code == 200, get_res.text

    # Mutation refusée (403)
    mut_res = api.put(
        f'/groups/{gid}/shared-access',
        headers=headers,
        json={'group_id': group_id, 'username': 'membres', 'password': PASSWORD},
    )
    assert mut_res.status_code == 403


def test_join_readonly_unknown_group_returns_404(api):
    register(api)
    res = api.post('/groups/join-readonly', json={'group_id': '#99999999'})
    assert res.status_code == 404


@pytest.mark.parametrize('bad_id', ['', '   ', '#', '#   '])
def test_join_readonly_invalid_format_returns_422(api, bad_id):
    res = api.post('/groups/join-readonly', json={'group_id': bad_id})
    assert res.status_code == 422


def test_join_readonly_rate_limited_per_ip(api):
    group_id = register(api)
    statuses = [
        api.post('/groups/join-readonly', json={'group_id': '#99999999'}).status_code
        for _ in range(15)
    ]
    assert 429 in statuses
    # Même un groupe valide est bloqué une fois le quota IP dépassé
    res = api.post('/groups/join-readonly', json={'group_id': group_id})
    assert res.status_code == 429
