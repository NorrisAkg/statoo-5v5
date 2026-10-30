import pytest
from fastapi.testclient import TestClient
from app.main import create_app
from test_api import PASSWORD, system


def test_change_own_password_success(system):
    c, t, accounts = system
    # 1. Login with admin in a second session to have a secondary token
    login2 = c.post('/auth/login', json={'group_id': '#00000001', 'username': 'admin', 'password': PASSWORD})
    assert login2.status_code == 200
    token2_header = {'Authorization': 'Bearer ' + login2.json()['token']}

    # Also check member token is active
    assert c.get('/groups/%2300000001', headers=t['members']).status_code == 200
    # And president token is active
    assert c.get('/groups/%2300000001', headers=t['president']).status_code == 200

    # 2. Admin changes own password
    new_pw = 'New-Admin-Pass-2026'
    resp = c.post(
        '/groups/%2300000001/account/password',
        headers=t['admin'],
        json={'current_password': PASSWORD, 'new_password': new_pw},
    )
    assert resp.status_code == 200, resp.text
    assert resp.json() == {'ok': True}

    # 3. Current token still works
    assert c.get('/groups/%2300000001', headers=t['admin']).status_code == 200

    # 4. Secondary token of the same account is revoked
    assert c.get('/groups/%2300000001', headers=token2_header).status_code == 401

    # 5. Tokens of other accounts remain valid
    assert c.get('/groups/%2300000001', headers=t['members']).status_code == 200
    assert c.get('/groups/%2300000001', headers=t['president']).status_code == 200

    # 6. Old password fails, new password succeeds
    assert c.post('/auth/login', json={'group_id': '#00000001', 'username': 'admin', 'password': PASSWORD}).status_code == 401
    new_login = c.post('/auth/login', json={'group_id': '#00000001', 'username': 'admin', 'password': new_pw})
    assert new_login.status_code == 200

    # 7. Audit log contains password_changed
    snapshot = c.get('/groups/%2300000001', headers=t['admin']).json()
    audit_entries = [e for e in snapshot.get('audit', []) if e.get('action') == 'password_changed']
    assert len(audit_entries) >= 1
    # Check that secrets are not present in audit or response
    assert new_pw not in resp.text
    assert new_pw not in str(snapshot['audit'])


def test_manager_can_change_own_password(system):
    c, t, accounts = system
    new_pw = 'New-Sport-Pass-2026'
    resp = c.post(
        '/groups/%2300000001/account/password',
        headers=t['sport'],
        json={'current_password': PASSWORD, 'new_password': new_pw},
    )
    assert resp.status_code == 200, resp.text
    assert resp.json() == {'ok': True}

    # Check login with new password
    assert c.post('/auth/login', json={'group_id': '#00000001', 'username': 'sport', 'password': new_pw}).status_code == 200
    assert c.post('/auth/login', json={'group_id': '#00000001', 'username': 'sport', 'password': PASSWORD}).status_code == 401


def test_change_password_wrong_current_password(system):
    c, t, _ = system
    resp = c.post(
        '/groups/%2300000001/account/password',
        headers=t['admin'],
        json={'current_password': 'WrongPassword123', 'new_password': 'Valid-Pass-2026'},
    )
    assert resp.status_code == 400
    assert 'Mot de passe actuel incorrect' in resp.text
    # Original password still works
    assert c.post('/auth/login', json={'group_id': '#00000001', 'username': 'admin', 'password': PASSWORD}).status_code == 200


def test_change_password_shared_account_rejected(system):
    c, t, _ = system
    resp = c.post(
        '/groups/%2300000001/account/password',
        headers=t['members'],
        json={'current_password': PASSWORD, 'new_password': 'Valid-Pass-2026'},
    )
    assert resp.status_code == 422
    assert 'Compte individuel requis' in resp.text


def test_change_password_auth_and_scope(system):
    c, t, _ = system
    # No auth
    assert c.post('/groups/%2300000001/account/password', json={'current_password': PASSWORD, 'new_password': 'Valid-Pass-2026'}).status_code == 401
    # Wrong group scope
    assert c.post('/groups/other-group/account/password', headers=t['admin'], json={'current_password': PASSWORD, 'new_password': 'Valid-Pass-2026'}).status_code == 403


def test_change_password_same_password_rejected(system):
    c, t, _ = system
    resp = c.post(
        '/groups/%2300000001/account/password',
        headers=t['admin'],
        json={'current_password': PASSWORD, 'new_password': PASSWORD},
    )
    assert resp.status_code == 422


@pytest.mark.parametrize('invalid_pw', [
    '',
    'short',          # < 8 chars
    'nouppercase1',   # no uppercase
    'NOLOWERCASE1',   # no lowercase
    'NoDigitsHere',   # no digit
    'admin',          # equals username (and too short)
    'Admin',          # equals username case-insensitively
])
def test_change_password_validation_rules(system, invalid_pw):
    c, t, _ = system
    resp = c.post(
        '/groups/%2300000001/account/password',
        headers=t['admin'],
        json={'current_password': PASSWORD, 'new_password': invalid_pw},
    )
    assert resp.status_code == 422
    # Verify original password unchanged
    assert c.post('/auth/login', json={'group_id': '#00000001', 'username': 'admin', 'password': PASSWORD}).status_code == 200


def test_change_password_replay_fails(system):
    c, t, _ = system
    new_pw = 'Replay-Pass-2026'
    r1 = c.post(
        '/groups/%2300000001/account/password',
        headers=t['admin'],
        json={'current_password': PASSWORD, 'new_password': new_pw},
    )
    assert r1.status_code == 200

    # Replay of the exact same request fails with 400 because current_password has changed
    r2 = c.post(
        '/groups/%2300000001/account/password',
        headers=t['admin'],
        json={'current_password': PASSWORD, 'new_password': new_pw},
    )
    assert r2.status_code == 400


def test_change_password_rate_limiting(system):
    c, t, _ = system
    # Perform 5 failed attempts
    for _ in range(5):
        r = c.post(
            '/groups/%2300000001/account/password',
            headers=t['admin'],
            json={'current_password': 'WrongPassword123', 'new_password': 'Valid-Pass-2026'},
        )
        assert r.status_code == 400

    # 6th attempt should be rate limited with 429
    r_limited = c.post(
        '/groups/%2300000001/account/password',
        headers=t['admin'],
        json={'current_password': 'WrongPassword123', 'new_password': 'Valid-Pass-2026'},
    )
    assert r_limited.status_code == 429
    assert 'Trop de tentatives' in r_limited.text

    # Another account (e.g. president) is NOT blocked
    r_other = c.post(
        '/groups/%2300000001/account/password',
        headers=t['president'],
        json={'current_password': PASSWORD, 'new_password': 'New-President-2026'},
    )
    assert r_other.status_code == 200


def test_unified_password_policy_across_endpoints(system):
    c, t, accounts = system
    valid_pw = 'Unified-Pass-2026'
    weak_pw = 'weakpassword'

    # 1. change_own_password accepts valid_pw, rejects weak_pw
    assert c.post(
        '/groups/%2300000001/account/password',
        headers=t['admin'],
        json={'current_password': PASSWORD, 'new_password': weak_pw},
    ).status_code == 422
    assert c.post(
        '/groups/%2300000001/account/password',
        headers=t['admin'],
        json={'current_password': PASSWORD, 'new_password': valid_pw},
    ).status_code == 200

    # 2. reset_manager_password accepts valid_pw, rejects weak_pw
    sport_id = accounts['sport']
    assert c.post(
        f'/groups/%2300000001/accounts/{sport_id}/password',
        headers={'Authorization': t['admin']['Authorization']},
        json={'password': weak_pw},
    ).status_code == 422
    assert c.post(
        f'/groups/%2300000001/accounts/{sport_id}/password',
        headers={'Authorization': t['admin']['Authorization']},
        json={'password': valid_pw},
    ).status_code == 200

    # 3. add_account accepts valid_pw, rejects weak_pw
    assert c.post(
        '/groups/%2300000001/accounts',
        headers=t['admin'],
        json={'username': 'new-user', 'password': weak_pw, 'member_id': 'd', 'roles': ['CENSOR']},
    ).status_code == 422
    assert c.post(
        '/groups/%2300000001/accounts',
        headers=t['admin'],
        json={'username': 'new-user', 'password': valid_pw, 'member_id': 'd', 'roles': ['CENSOR']},
    ).status_code == 201

    # 4. rotate_shared accepts valid_pw, rejects weak_pw
    assert c.put(
        '/groups/%2300000001/shared-access',
        headers=t['admin'],
        json={'group_id': '#00000001', 'username': 'new-members', 'password': weak_pw},
    ).status_code == 422
    assert c.put(
        '/groups/%2300000001/shared-access',
        headers=t['admin'],
        json={'group_id': '#00000001', 'username': 'new-members', 'password': valid_pw},
    ).status_code == 200

    # 5. register accepts valid_pw, rejects weak_pw
    with TestClient(create_app('sqlite:///:memory:')) as fresh_c:
        reg_weak = {
            'group_id': '#00000099',
            'name': 'Group99',
            'username': 'admin99',
            'password': weak_pw,
            'shared_username': 'members99',
            'shared_password': valid_pw,
            'members': [{'id': 'm1', 'name': 'M1'}],
        }
        assert fresh_c.post('/groups', json=reg_weak).status_code == 422
        reg_valid = {
            'group_id': '#00000099',
            'name': 'Group99',
            'username': 'admin99',
            'password': valid_pw,
            'shared_username': 'members99',
            'shared_password': valid_pw,
            'members': [{'id': 'm1', 'name': 'M1'}],
        }
        assert fresh_c.post('/groups', json=reg_valid).status_code == 201

