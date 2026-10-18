from urllib.parse import quote

import pytest
from fastapi.testclient import TestClient
from app.main import create_app

PASSWORD = 'Collective-Test-2026'


@pytest.fixture
def access():
    with TestClient(create_app('sqlite:///:memory:')) as client:
        result = client.post('/groups', json={
            'name': 'Atlas', 'username': 'admin', 'password': 'Admin-Test-2026',
            'shared_username': 'members', 'shared_password': PASSWORD,
            'members': [{'id': 'a', 'name': 'Alice'}],
        }).json()
        group = result['group_id']
        path = '/groups/' + quote(group, safe='')
        admin = {'Authorization': 'Bearer ' + result['token']}
        yield client, group, path, admin


def test_verify_is_read_only_and_never_returns_secret(access):
    c, group, path, admin = access
    before = c.get(path, headers=admin).json()
    response = c.post(path + '/shared-access/verify', headers=admin, json={'password': PASSWORD})
    assert response.status_code == 200
    assert response.json() == {'verified': True, 'group_id': group, 'username': 'members'}
    assert c.get(path, headers=admin).json() == before
    assert c.post('/auth/login', json={'group_id': group, 'username': 'members', 'password': PASSWORD}).status_code == 200


def test_wrong_password_and_bounds(access):
    c, _, path, admin = access
    for password, status in [('Wrong-password', 400), ('', 422), ('short', 422), ('x' * 201, 422)]:
        response = c.post(path + '/shared-access/verify', headers=admin, json={'password': password})
        assert response.status_code == status
        assert password not in response.text if len(password) > 7 else True


def test_only_scoped_admin_can_verify(access):
    c, group, path, admin = access
    assert c.post(path + '/shared-access/verify', json={'password': PASSWORD}).status_code == 401
    for username, roles in [('sport', ['SG']), ('members', None)]:
        if roles:
            assert c.post(path + '/accounts', headers=admin, json={'username': username, 'password': PASSWORD, 'member_id': 'a', 'roles': roles}).status_code == 201
        login = c.post('/auth/login', json={'group_id': group, 'username': username, 'password': PASSWORD}).json()
        headers = {'Authorization': 'Bearer ' + login['token']}
        assert c.post(path + '/shared-access/verify', headers=headers, json={'password': PASSWORD}).status_code == 403
    assert c.post('/groups/other/shared-access/verify', headers=admin, json={'password': PASSWORD}).status_code == 403


def test_rotation_verifies_only_new_password_and_current_username(access):
    c, group, path, admin = access
    assert c.put(path + '/shared-access', headers=admin, json={'group_id': group, 'username': 'new-members', 'password': 'New-Password-2026'}).status_code == 200
    assert c.post(path + '/shared-access/verify', headers=admin, json={'password': PASSWORD}).status_code == 400
    result = c.post(path + '/shared-access/verify', headers=admin, json={'password': 'New-Password-2026'})
    assert result.status_code == 200
    assert result.json()['username'] == 'new-members'
