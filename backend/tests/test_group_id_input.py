"""UX-003 (audit 14/11/2026) : l'identifiant de groupe se saisit avec ou sans « # ».

L'identifiant affiché est « #13120987 ». Un membre qui recopie « 13120987 » recevait
« Identifiants incorrects », message qui accuse ses identifiants et non le format.
"""
import copy
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import create_app
from app.models import Group, database

PASSWORD = 'Admin-Password-2026'
LOGIN_REFUSED = "Identifiant du groupe, identifiant ou mot de passe incorrect."


@pytest.fixture
def api():
    engine = database('sqlite:///:memory:')
    with patch('app.main.database', return_value=engine), patch('app.main.REGISTRATIONS_PER_HOUR', 10_000):
        app = create_app('sqlite:///:memory:')
        with TestClient(app) as client:
            yield client, engine


def register(client, **changes):
    body = {'group_id': '#00000001', 'name': 'Groupe', 'username': 'admin', 'password': PASSWORD,
            'shared_username': 'membres', 'shared_password': PASSWORD,
            'recovery_code': 'ABCD-EFGH-JKLM-NPQR',
            'members': [{'id': 'a', 'name': 'Alice'}], **changes}
    response = client.post('/groups', json=body)
    assert response.status_code == 201, response.text
    return response.json()['group_id']


def login(client, group_id, password=PASSWORD, username='admin'):
    return client.post('/auth/login', json={'group_id': group_id, 'username': username, 'password': password})


@pytest.mark.parametrize('typed', ['{id}', '{digits}', ' {digits} ', '\t{id}\n', '{digits}\u00a0',
                                   '#\u00a0{digits}', '\u200b{digits}', '\ufeff{id}', '{digits}\u200b'])
def test_login_accepts_the_group_id_with_or_without_hash_and_spaces(api, typed):
    client, _ = api
    group_id = register(client)
    assert group_id.startswith('#') and len(group_id) == 9
    response = login(client, typed.format(id=group_id, digits=group_id[1:]))
    assert response.status_code == 200, response.text
    assert response.json()['group_id'] == group_id


def test_wrong_password_and_unknown_group_get_an_explicit_message(api):
    client, _ = api
    group_id = register(client)
    for attempt in (login(client, group_id[1:], password='wrong-password-1'),
                    login(client, '99999999'),
                    login(client, group_id, username='inconnu')):
        assert attempt.status_code == 401
        assert attempt.json()['detail'] == LOGIN_REFUSED


def test_blank_group_id_is_refused_like_any_unknown_group(api):
    client, _ = api
    register(client)
    response = login(client, '  \u200b ')
    assert response.status_code == 401
    assert response.json()['detail'] == LOGIN_REFUSED


def test_only_eight_digits_get_the_hash_prefix(api):
    client, _ = api
    group_id = register(client)
    for typed in (group_id[2:], group_id[1:] + '0', 'x' + group_id[1:], '##' + group_id[1:]):
        assert login(client, typed).status_code == 401, typed


def test_an_existing_group_id_without_hash_keeps_priority(api):
    # Les premiers groupes (avant le 15/10) gardaient l'identifiant choisi par le client.
    client, engine = api
    group_id = register(client)
    with Session(engine) as session, session.begin():
        source = session.get(Group, group_id)
        legacy_state = copy.deepcopy(source.state)
        legacy_state['name'] = 'Ancien groupe'
        session.add(Group(id=group_id[1:], state=legacy_state))
    response = login(client, group_id[1:])
    assert response.status_code == 200, response.text
    assert response.json()['group_id'] == group_id[1:]


def test_failures_with_and_without_hash_count_for_the_same_account(api):
    client, _ = api
    group_id = register(client)
    for i in range(10):
        typed = group_id if i % 2 else group_id[1:]
        assert login(client, typed, password='wrong-password-1').status_code == 401
    assert login(client, group_id, password='wrong-password-1').status_code == 429
    assert login(client, group_id[1:], password='wrong-password-1').status_code == 429


def test_recover_accepts_the_group_id_without_hash(api):
    client, _ = api
    group_id = register(client)
    response = client.post('/auth/recover', json={
        'group_id': f' {group_id[1:]} ', 'username': 'admin', 'recovery_code': 'ABCD-EFGH-JKLM-NPQR',
        'new_password': 'New-Password-2026', 'new_recovery_code': 'KLMN-PQRS-TUVW-XYZ2'})
    assert response.status_code == 200, response.text
    assert response.json()['group_id'] == group_id


def test_recover_failures_with_and_without_hash_share_the_account_limit(api):
    client, _ = api
    group_id = register(client)
    body = {'username': 'admin', 'recovery_code': 'WXYZ-2345-6789-ABCD',
            'new_password': 'New-Password-2026', 'new_recovery_code': 'KLMN-PQRS-TUVW-XYZ2'}
    codes = [client.post('/auth/recover', json={**body, 'group_id': group_id if i % 2 else group_id[1:]}).status_code
             for i in range(6)]
    assert codes == [401] * 5 + [429]
