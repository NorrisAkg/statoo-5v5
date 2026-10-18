import pytest
from test_collective_access import access, PASSWORD


@pytest.fixture
def manager(access):
    c, group, path, admin = access
    created = c.post(path + '/accounts', headers=admin, json={
        'username': 'sport', 'password': PASSWORD, 'member_id': 'a', 'roles': ['SG']})
    assert created.status_code == 201
    target = created.json()['id']
    login = c.post('/auth/login', json={'group_id': group, 'username': 'sport', 'password': PASSWORD}).json()
    return c, group, path, admin, target, {'Authorization': 'Bearer ' + login['token']}


def test_verify_existing_manager_is_read_only(manager):
    c, group, path, admin, target, _ = manager
    before = c.get(path, headers=admin).json()
    result = c.post(f'{path}/accounts/{target}/password/verify', headers=admin, json={'password': PASSWORD})
    assert result.status_code == 200
    assert result.json() == {'verified': True, 'group_id': group, 'username': 'sport'}
    assert c.get(path, headers=admin).json() == before
    assert c.post(f'{path}/accounts/{target}/password/verify', headers=admin, json={'password': 'Wrong-Password'}).status_code == 400


def test_reset_only_target_revokes_its_sessions(manager):
    c, group, path, admin, target, sport = manager
    result = c.post(f'{path}/accounts/{target}/password', headers=admin, json={'password': 'aB3dE6fG'})
    assert result.status_code == 200
    assert 'aB3dE6fG' not in result.text
    assert c.get(path, headers=sport).status_code == 401
    assert c.get(path, headers=admin).status_code == 200
    assert c.post('/auth/login', json={'group_id': group, 'username': 'sport', 'password': PASSWORD}).status_code == 401
    assert c.post('/auth/login', json={'group_id': group, 'username': 'sport', 'password': 'aB3dE6fG'}).status_code == 200
    assert c.post('/auth/login', json={'group_id': group, 'username': 'members', 'password': PASSWORD}).status_code == 200
    snapshot = c.get(path, headers=admin).json()
    assert next(a for a in snapshot['accounts'] if a['id'] == target)['roles'] == ['MEMBER', 'SG']
    assert 'aB3dE6fG' not in str(snapshot)


def test_manager_access_is_admin_scoped_and_individual(manager):
    c, group, path, admin, target, sport = manager
    snapshot = c.get(path, headers=admin).json()
    shared = next(a['id'] for a in snapshot['accounts'] if a['shared'])
    own = next(a['id'] for a in snapshot['accounts'] if 'ADMIN' in a['roles'])
    for suffix in ['/password', '/password/verify']:
        url = f'{path}/accounts/{target}{suffix}'
        assert c.post(url, json={'password': 'aB3dE6fG'}).status_code == 401
        assert c.post(url, headers=sport, json={'password': 'aB3dE6fG'}).status_code == 403
        assert c.post(f'/groups/other/accounts/{target}{suffix}', headers=admin, json={'password': 'aB3dE6fG'}).status_code == 403
        assert c.post(f'{path}/accounts/missing{suffix}', headers=admin, json={'password': 'aB3dE6fG'}).status_code == 404
        assert c.post(f'{path}/accounts/{shared}{suffix}', headers=admin, json={'password': 'aB3dE6fG'}).status_code == 422
    assert c.post(f'{path}/accounts/{own}/password', headers=admin, json={'password': 'aB3dE6fG'}).status_code == 409


@pytest.mark.parametrize('password', ['', 'short', 'Longer123', 'abcdefgh', 'ABCDEFGH', '12345678'])
def test_reset_requires_generated_password_contract(manager, password):
    c, _, path, admin, target, _ = manager
    result = c.post(f'{path}/accounts/{target}/password', headers=admin, json={'password': password})
    assert result.status_code == 422
    assert c.post(f'{path}/accounts/{target}/password/verify', headers=admin, json={'password': PASSWORD}).status_code == 200
