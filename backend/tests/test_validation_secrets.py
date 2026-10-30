"""F09: never reflect model input, context, locations or messages in errors."""
import copy
import json
import uuid
from urllib.parse import quote
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from pydantic import BaseModel, field_validator
from sqlalchemy import select
from sqlalchemy.orm import Session
from app.main import create_app
from app.models import Group, Token, RegistrationOperation, database

ADMIN = 'Synthetic-Admin-Only-2026'
COLLECTIVE = 'Synthetic-Readers-Only-2026'
RESPONSIBLE = 'Synthetic-Responsible-Only-2026'
MARKER = 'QA-private-marker-not-for-response'
SHORT = 'qa!x'
LONG = 'QA-long-' + 'x' * 210
MARKERS = [ADMIN, COLLECTIVE, RESPONSIBLE, MARKER, SHORT, LONG]


class ReflectingModel(BaseModel):
    password: str

    @field_validator('password')
    @classmethod
    def reflect_for_test(cls, value):
        raise ValueError('Validator echoed ' + value)


class SyntheticApi:
    """Default repr deliberately does not dump tokens into assertion reports."""


@pytest.fixture(scope='module')
def api():
    engine = database('sqlite:///:memory:')
    with patch('app.main.database', return_value=engine):
        app = create_app('sqlite:///:memory:')

        @app.post('/_test/reflected-validator')
        def reflected_validator(body: ReflectingModel):
            return {'unexpected': True}

        with TestClient(app, raise_server_exceptions=False) as c:
            created = c.post('/groups', json={
                'name': 'Secret checks', 'username': 'admin', 'password': ADMIN,
                'shared_username': 'readers', 'shared_password': COLLECTIVE,
                'members': [{'id': 'a', 'name': 'Alice'}, {'id': 'b', 'name': 'Bob'}],
            })
            assert created.status_code == 201
            s = SyntheticApi()
            s.c, s.engine = c, engine
            s.group = created.json()['group_id']
            s.path = '/groups/' + quote(s.group, safe='')
            s.admin = {'Authorization': 'Bearer ' + created.json()['token']}
            for username, member, role in [('president', 'a', 'PDT'), ('treasurer', 'b', 'TR')]:
                response = c.post(s.path + '/accounts', headers=s.admin, json={
                    'username': username, 'password': RESPONSIBLE, 'member_id': member, 'roles': [role],
                })
                assert response.status_code == 201
                if role == 'PDT':
                    s.target = response.json()['id']
                connected = c.post('/auth/login', json={
                    'group_id': s.group, 'username': username, 'password': RESPONSIBLE,
                })
                assert connected.status_code == 200
                setattr(s, role, {'Authorization': 'Bearer ' + connected.json()['token']})
            readers = c.post('/auth/login', json={
                'group_id': s.group, 'username': 'readers', 'password': COLLECTIVE,
            })
            assert readers.status_code == 200
            s.reader = {'Authorization': 'Bearer ' + readers.json()['token']}
            assert c.post(s.path + '/opening', headers=s.TR, json={'cash': 0, 'members': {}}).status_code == 200
            proposal = c.get(s.path, headers=s.PDT).json()['opening_proposal']
            assert c.post(s.path + '/opening/approve', headers=s.PDT,
                          json={'proposal': proposal}).status_code == 200
            yield s


def state(api):
    with Session(api.engine) as session:
        return (
            {g.id: copy.deepcopy(g.state) for g in session.scalars(select(Group))},
            [(t.digest, t.account_id, t.group_id) for t in session.scalars(select(Token).order_by(Token.digest))],
            [(op.id, op.group_id, op.fingerprint) for op in session.scalars(select(RegistrationOperation))],
        )


def safe_error(response, status=422):
    assert response.status_code == status
    assert response.headers['content-type'].startswith('application/json')
    data = response.json()
    assert set(data) == {'detail'}
    assert isinstance(data['detail'], str), 'Validation must use a safe human-readable detail'
    assert data['detail'].strip()
    combined = response.text + json.dumps(dict(response.headers))
    assert not any(marker in combined for marker in MARKERS), 'Response reflected a synthetic secret'
    return data['detail']


def request_for(api, kind):
    login = {'group_id': api.group, 'username': 'admin', 'password': ADMIN}
    if kind == 'login':
        return 'POST', '/auth/login', {}, login, 'password'
    if kind in ('register', 'register-shared'):
        body = {'name': 'Rejected registration', 'operation_id': str(uuid.uuid4()),
                'username': 'new-admin', 'password': ADMIN, 'shared_username': 'new-readers',
                'shared_password': COLLECTIVE, 'members': []}
        return 'POST', '/groups', {}, body, 'shared_password' if kind == 'register-shared' else 'password'
    if kind == 'account':
        return 'POST', api.path + '/accounts', api.admin, {
            'username': 'candidate', 'password': RESPONSIBLE, 'member_id': 'a', 'roles': ['SG'],
        }, 'password'
    if kind == 'rotate':
        return 'PUT', api.path + '/shared-access', api.admin, login, 'password'
    if kind == 'shared-verify':
        return 'POST', api.path + '/shared-access/verify', api.admin, {'password': COLLECTIVE}, 'password'
    suffix = '/password/verify' if kind == 'manager-verify' else '/password'
    return 'POST', api.path + '/accounts/' + api.target + suffix, api.admin, {'password': RESPONSIBLE}, 'password'


@pytest.mark.parametrize('kind', ['login', 'register', 'register-shared', 'account', 'rotate',
                                  'shared-verify', 'manager-verify', 'manager-reset'])
@pytest.mark.parametrize('invalid', ['short', 'long', 'nested'])
def test_bad_password_never_reflected_and_changes_nothing(api, kind, invalid, caplog):
    method, path, headers, body, field = request_for(api, kind)
    body[field] = {'short': SHORT, 'long': LONG, 'nested': {'private': MARKER}}[invalid]
    before = state(api)
    response = api.c.request(method, path, headers=headers, json=body)
    safe_error(response)
    assert state(api) == before
    assert not any(marker in caplog.text for marker in MARKERS)


@pytest.mark.parametrize('kind,missing', [
    ('login', 'username'), ('register', 'name'), ('account', 'member_id'),
    ('rotate', 'username'), ('shared-verify', 'password'),
    ('manager-verify', 'password'), ('manager-reset', 'password'),
])
def test_missing_fields_do_not_echo_the_rest_of_the_credentials(api, kind, missing):
    method, path, headers, body, _ = request_for(api, kind)
    body.pop(missing)
    body['extra_private_value'] = MARKER
    before = state(api)
    safe_error(api.c.request(method, path, headers=headers, json=body))
    assert state(api) == before


@pytest.mark.parametrize('path', ['/auth/login', '/groups'])
def test_wrong_root_body_is_not_returned(api, path):
    before = state(api)
    safe_error(api.c.post(path, json=[{'password': MARKER}]))
    assert state(api) == before


def test_invalid_json_has_safe_json_response(api):
    before = state(api)
    safe_error(api.c.post('/auth/login', content='{"password":"' + MARKER + '", broken}',
                          headers={'Content-Type': 'application/json'}))
    assert state(api) == before


def test_private_dictionary_keys_are_not_reflected_in_locations(api):
    before = state(api)
    safe_error(api.c.post(api.path + '/opening', headers=api.TR, json={
        'cash': 0, 'members': {MARKER: {'contribution_balance': MARKER}},
    }))
    assert state(api) == before


def test_validator_messages_and_context_cannot_echo_the_value(api, caplog):
    before = state(api)
    safe_error(api.c.post('/_test/reflected-validator', json={'password': MARKER}))
    assert state(api) == before
    assert MARKER not in caplog.text


def finance_version(api):
    return {'operation_id': str(uuid.uuid4()), 'occurrence_id': str(uuid.uuid4()),
            'domain': 'finance', 'base_revision': 0, 'payload': {
                'played_at': '2026-10-26', 'rate': 100, 'cancelled': False,
                'lines': [{'member_id': p, 'contribution': 0, 'penalty_paid': 0, 'penalty_due': 0}
                          for p in ['a', 'b']],
                'expenses': [], 'donations': [],
            }}


@pytest.mark.parametrize('invalid', ['amount', 'extra'])
def test_financial_model_errors_do_not_get_stringified_with_inputs(api, invalid):
    body = finance_version(api)
    if invalid == 'amount':
        body['payload']['rate'] = MARKER
    else:
        body['payload']['extra_private_value'] = MARKER
    before = state(api)
    safe_error(api.c.post(api.path + '/sync', headers=api.TR, json=body))
    assert state(api) == before


@pytest.mark.parametrize('kind,status,word', [('login', 401, 'Identifiants'),
                                            ('permission', 403, 'Droit'),
                                            ('password', 400, 'incorrect')])
def test_safe_business_authentication_errors_keep_their_contract(api, kind, status, word):
    before = state(api)
    if kind == 'login':
        response = api.c.post('/auth/login', json={'group_id': api.group, 'username': 'admin', 'password': MARKER})
    elif kind == 'permission':
        _, path, _, body, _ = request_for(api, 'account')
        response = api.c.post(path, headers=api.reader, json=body)
    else:
        response = api.c.post(api.path + '/shared-access/verify', headers=api.admin, json={'password': MARKER})
    assert word in safe_error(response, status)
    assert state(api) == before


def test_business_financial_message_is_kept(api):
    body = finance_version(api)
    body['payload']['lines'][0]['penalty_paid'] = 1
    before = state(api)
    response = api.c.post(api.path + '/sync', headers=api.TR, json=body)
    assert 'dépasse' in safe_error(response)
    assert state(api) == before


def test_valid_login_still_issues_an_authorized_token(api):
    response = api.c.post('/auth/login', json={'group_id': api.group, 'username': 'admin', 'password': ADMIN})
    assert response.status_code == 200
    assert response.json()['token']
    assert ADMIN not in response.text
    headers = {'Authorization': 'Bearer ' + response.json()['token']}
    assert api.c.get(api.path, headers=headers).status_code == 200
    assert api.c.get(api.path, headers=api.reader).status_code == 200
