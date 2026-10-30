"""F06: username comparison must agree with storage and authentication."""
import json
import uuid
from urllib.parse import quote
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.orm import Session
from app.main import create_app
from app.models import Group, Token, RegistrationOperation, database
from app.security import password_matches

ADMIN_PASSWORD = 'Admin-Password-2026'
MEMBER_PASSWORD = 'Members-Password-2026'


def registration(**changes):
    return {
        'name': 'Identifier checks', 'username': 'admin', 'password': ADMIN_PASSWORD,
        'shared_username': 'readers', 'shared_password': MEMBER_PASSWORD,
        'members': [{'id': 'a', 'name': 'Alice'}], **changes,
    }


@pytest.fixture(scope='module')
def api():
    engine = database('sqlite:///:memory:')
    with patch('app.main.database', return_value=engine):
        app = create_app('sqlite:///:memory:')
        with TestClient(app) as client:
            yield client, engine


@pytest.fixture
def group(api):
    c, _ = api
    response = c.post('/groups', json=registration())
    assert response.status_code == 201, response.text
    identity = response.json()
    path = '/groups/' + quote(identity['group_id'], safe='')
    headers = {'Authorization': 'Bearer ' + identity['token']}
    return c, identity['group_id'], path, headers


def counts(engine):
    with Session(engine) as session:
        return tuple(session.scalar(select(func.count()).select_from(model))
                     for model in (Group, Token, RegistrationOperation))


def login(c, group_id, username, password):
    return c.post('/auth/login', json={
        'group_id': group_id, 'username': username, 'password': password,
    })


@pytest.mark.parametrize('individual,collective', [
    ('admin', ' admin '), (' admin ', 'admin'), (' AdMiN ', ' ADMIN '),
    ('admin', '\tADMIN\n'), ('admin', '\u00a0ADMIN\u00a0'), ('Straße', ' STRASSE '),
])
def test_equivalent_initial_identifiers_are_rejected_atomically(api, individual, collective):
    c, engine = api
    before = counts(engine)
    response = c.post('/groups', json=registration(
        username=individual, shared_username=collective, operation_id=str(uuid.uuid4())))
    assert response.status_code == 422, response.text
    assert 'token' not in response.json()
    assert counts(engine) == before


@pytest.mark.parametrize('field', ['username', 'shared_username'])
@pytest.mark.parametrize('value', ['   ', '\t\n', '\u00a0'])
def test_blank_registration_identifier_is_rejected_without_consuming_operation(api, field, value):
    c, engine = api
    op = str(uuid.uuid4())
    before = counts(engine)
    response = c.post('/groups', json=registration(**{field: value}, operation_id=op))
    assert response.status_code == 422, response.text
    assert counts(engine) == before
    corrected = c.post('/groups', json=registration(operation_id=op))
    assert corrected.status_code == 201, corrected.text


@pytest.mark.parametrize('individual,collective', [
    (' Admin ', ' Readers '), ('team one', 'teamone'), ('Équipe', 'equipe'),
])
def test_distinct_logins_keep_correct_account_and_roles(api, individual, collective):
    c, _ = api
    response = c.post('/groups', json=registration(username=individual, shared_username=collective))
    assert response.status_code == 201, response.text
    group_id = response.json()['group_id']
    for username, password, shared in [(individual, ADMIN_PASSWORD, False), (collective, MEMBER_PASSWORD, True)]:
        connected = login(c, group_id, ' ' + username.swapcase() + ' ', password)
        assert connected.status_code == 200, connected.text
        account = connected.json()['account']
        assert account['shared'] is shared
        assert account['username'] == username.strip()
        assert ('ADMIN' in account['roles']) is not shared


@pytest.mark.parametrize('value', ['   ', '\t\n', '\u00a0'])
def test_blank_manager_is_rejected_without_state_change(group, value):
    c, _, path, admin = group
    before = c.get(path, headers=admin).json()
    response = c.post(path + '/accounts', headers=admin, json={
        'username': value, 'password': ADMIN_PASSWORD, 'member_id': 'a', 'roles': ['SG'],
    })
    assert response.status_code == 422, response.text
    assert c.get(path, headers=admin).json() == before


@pytest.mark.parametrize('value', [' AdMiN ', '\tREADERS\n'])
def test_manager_collision_keeps_existing_accounts(group, value):
    c, _, path, admin = group
    before = c.get(path, headers=admin).json()
    response = c.post(path + '/accounts', headers=admin, json={
        'username': value, 'password': ADMIN_PASSWORD, 'member_id': 'a', 'roles': ['SG'],
    })
    assert response.status_code == 409, response.text
    assert c.get(path, headers=admin).json() == before


def test_valid_manager_is_trimmed_and_connectable(group):
    c, group_id, path, admin = group
    response = c.post(path + '/accounts', headers=admin, json={
        'username': ' Sport Lead ', 'password': ADMIN_PASSWORD, 'member_id': 'a', 'roles': ['SG'],
    })
    assert response.status_code == 201, response.text
    assert response.json()['username'] == 'Sport Lead'
    connected = login(c, group_id, ' SPORT lead ', ADMIN_PASSWORD)
    assert connected.status_code == 200
    assert 'SG' in connected.json()['account']['roles']
    assert 'ADMIN' not in connected.json()['account']['roles']


@pytest.mark.parametrize('value,status', [(' ', 422), ('\t\n', 422), ('\u00a0', 422), (' ADMIN ', 409)])
def test_invalid_collective_rotation_does_not_revoke_current_login(group, value, status):
    c, group_id, path, admin = group
    reader = login(c, group_id, 'readers', MEMBER_PASSWORD)
    assert reader.status_code == 200
    headers = {'Authorization': 'Bearer ' + reader.json()['token']}
    before = c.get(path, headers=admin).json()
    response = c.put(path + '/shared-access', headers=admin, json={
        'group_id': group_id, 'username': value, 'password': 'Changed-Password-2026',
    })
    assert response.status_code == status, response.text
    assert c.get(path, headers=admin).json() == before
    assert c.get(path, headers=headers).status_code == 200


def test_valid_rotation_keeps_admin_and_revokes_old_collective_token(group):
    c, group_id, path, admin = group
    reader = login(c, group_id, 'readers', MEMBER_PASSWORD).json()
    headers = {'Authorization': 'Bearer ' + reader['token']}
    body = {'group_id': group_id, 'username': ' New Readers ', 'password': 'Changed-Password-2026'}
    assert c.put(path + '/shared-access', headers=headers, json=body).status_code == 403
    assert c.put(path + '/shared-access', headers=admin, json=body).status_code == 200
    assert c.get(path, headers=headers).status_code == 401
    connected = login(c, group_id, ' new READERS ', body['password'])
    assert connected.status_code == 200
    assert connected.json()['account']['username'] == 'New Readers'
    assert connected.json()['account']['shared'] is True
    assert c.get(path, headers=admin).status_code == 200


@pytest.mark.parametrize('value', [' ', '\t\n', '\u00a0'])
def test_blank_login_is_a_validation_error(group, value):
    c, group_id, _, _ = group
    assert login(c, group_id, value, ADMIN_PASSWORD).status_code == 422


def test_padded_registration_retry_preserves_historical_fingerprint(api):
    c, engine = api
    body = registration(username=' Admin ', shared_username=' Readers ', operation_id=str(uuid.uuid4()))
    first = c.post('/groups', json=body)
    assert first.status_code == 201, first.text
    historical_json = json.dumps({k: v for k, v in body.items() if k != 'operation_id'},
                                 sort_keys=True, ensure_ascii=False)
    with Session(engine) as session:
        operation = session.get(RegistrationOperation, body['operation_id'])
        assert password_matches(historical_json, operation.fingerprint)
    again = c.post('/groups', json=body)
    assert again.status_code == 201
    assert again.json()['group_id'] == first.json()['group_id']
    changed = c.post('/groups', json={**body, 'name': 'Changed'})
    assert changed.status_code == 409
