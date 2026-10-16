import uuid
import pytest
from fastapi.testclient import TestClient
from app.main import create_app


@pytest.fixture
def system():
    with TestClient(create_app('sqlite:///:memory:')) as client:
        password = 'Synthetic-password-2026'
        identity = client.post('/groups', json={
            'name': 'Sport settings', 'username': 'admin', 'password': password,
            'shared_username': 'readers', 'shared_password': password,
            'members': [{'id': str(i), 'name': f'Player {i}'} for i in range(30)],
        }).json()
        path = '/groups/' + identity['group_id'].replace('#', '%23')
        admin = {'Authorization': 'Bearer ' + identity['token']}
        tokens = {'ADMIN': admin}
        for i, role in enumerate(['SG', 'TR', 'PDT']):
            assert client.post(path + '/accounts', headers=admin, json={
                'username': role, 'password': password, 'member_id': str(i), 'roles': [role],
            }).status_code == 201
            login = client.post('/auth/login', json={'group_id': identity['group_id'], 'username': role, 'password': password}).json()
            tokens[role] = {'Authorization': 'Bearer ' + login['token']}
        login = client.post('/auth/login', json={'group_id': identity['group_id'], 'username': 'readers', 'password': password}).json()
        tokens['MEMBER'] = {'Authorization': 'Bearer ' + login['token']}
        yield client, path, tokens, identity['group_id']


def version(group, count, kind='CLASSIC_2', status='CLOSED'):
    teams = 'ABC' if kind == 'TOURNAMENT_3' else 'AB'
    return {'domain': 'sport', 'operation_id': str(uuid.uuid4()), 'occurrence_id': str(uuid.uuid4()),
            'base_revision': 0, 'generation': 0, 'payload': {
                'session': {'id': str(uuid.uuid4()), 'team_id': group, 'played_at': '2026-10-15T20:00:00',
                            'session_type': kind, 'status': status, 'result': 'A' if kind == 'TOURNAMENT_3' else 'DRAW',
                            'score_a': None if kind == 'TOURNAMENT_3' else 0,
                            'score_b': None if kind == 'TOURNAMENT_3' else 0, 'wins_a': 1, 'wins_b': 0, 'wins_c': 0},
                'participations': [{'player_id': str(i), 'team': teams[i % len(teams)]} for i in range(count)]}}


def event(group, count, **kwargs):
    v = version(group, count, **kwargs)
    for part in v['payload']['participations']:
        part['session_id'] = v['payload']['session']['id']
    return v


def test_default_is_public_and_only_admin_can_change_it(system):
    c, path, tokens, _ = system
    for role, token in tokens.items():
        assert c.get(path, headers=token).json()['sport_settings'] == {'min_players_per_session': 6}
        if role != 'ADMIN':
            assert c.put(path + '/sport-settings', headers=token, json={'min_players_per_session': 4}).status_code == 403
    assert c.put(path + '/sport-settings', headers=tokens['ADMIN'], json={'min_players_per_session': 4}).status_code == 200
    assert c.get(path, headers=tokens['SG']).json()['sport_settings']['min_players_per_session'] == 4


@pytest.mark.parametrize('value', [1, 31, True, 2.5, '6', None])
def test_invalid_minimum_is_rejected(system, value):
    c, path, t, _ = system
    assert c.put(path + '/sport-settings', headers=t['ADMIN'], json={'min_players_per_session': value}).status_code == 422


@pytest.mark.parametrize('minimum', [2, 6, 30])
@pytest.mark.parametrize('kind', ['CLASSIC_2', 'TOURNAMENT_3'])
def test_minimum_is_enforced_by_server_for_closure_only(system, minimum, kind):
    c, path, t, group = system
    assert c.put(path + '/sport-settings', headers=t['ADMIN'], json={'min_players_per_session': minimum}).status_code == 200
    for status in ['DRAFT', 'CANCELLED']:
        assert c.post(path + '/sync', headers=t['SG'], json=event(group, 1, kind=kind, status=status)).status_code == 200
    below = c.post(path + '/sync', headers=t['SG'], json=event(group, minimum - 1, kind=kind))
    assert below.status_code == 422
    assert 'minimum' in below.json()['detail'].lower() or 'joueurs' in below.json()['detail'].lower()
    assert c.post(path + '/sync', headers=t['SG'], json=event(group, minimum, kind=kind)).status_code == 200


def test_candidate_is_checked_against_current_minimum_but_history_can_be_kept(system):
    c, path, t, group = system
    c.put(path + '/sport-settings', headers=t['ADMIN'], json={'min_players_per_session': 2})
    published = event(group, 2)
    assert c.post(path + '/sync', headers=t['SG'], json=published).status_code == 200
    candidate = event(group, 2)
    candidate['occurrence_id'] = published['occurrence_id']
    assert c.post(path + '/sync', headers=t['SG'], json=candidate).json()['status'] == 'conflict'
    c.put(path + '/sport-settings', headers=t['ADMIN'], json={'min_players_per_session': 6})
    url = path + '/documents/sport/' + published['occurrence_id'] + '/resolve'
    decision = {'revision': 1, 'candidate_id': candidate['operation_id'], 'reason': 'Reviewed'}
    assert c.post(url, headers=t['PDT'], json=decision).status_code == 422
    decision['candidate_id'] = 'current'
    assert c.post(url, headers=t['PDT'], json=decision).status_code == 200
