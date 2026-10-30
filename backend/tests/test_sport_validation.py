"""F03: real HTTP rejection and atomicity of malformed sport documents."""
import copy
import json
import uuid
from pathlib import Path
from urllib.parse import quote

import pytest
from fastapi.testclient import TestClient
from app.main import create_app, validate_sport


@pytest.fixture(scope='module')
def api():
    with TestClient(create_app('sqlite:///:memory:'), raise_server_exceptions=False) as client:
        password = 'Validation-password-2026'
        created = client.post('/groups', json={
            'name': 'Validation', 'username': 'admin', 'password': password,
            'shared_username': 'readers', 'shared_password': password,
            'members': [{'id': str(i), 'name': f'Player {i}'} for i in range(6)],
        })
        assert created.status_code == 201, created.text
        identity = created.json()
        path = '/groups/' + quote(identity['group_id'], safe='')
        auth = {'Authorization': 'Bearer ' + identity['token']}
        for username, member, role in [('president', '0', 'PDT'), ('treasurer', '1', 'TR')]:
            response = client.post(path + '/accounts', headers=auth, json={
                'username': username, 'password': password, 'member_id': member, 'roles': [role],
            })
            assert response.status_code == 201, response.text
        yield client, path, auth, identity['group_id']


def version(group, kind='CLASSIC_2', status='CLOSED'):
    sid = str(uuid.uuid4())
    return {
        'domain': 'sport', 'operation_id': str(uuid.uuid4()), 'occurrence_id': sid,
        'base_revision': 0, 'generation': 0, 'reason': 'Validation', 'payload': {
            'session': {'id': sid, 'team_id': group, 'played_at': '2026-10-25T09:00:00',
                        'session_type': kind, 'status': status,
                        'score_a': 0, 'score_b': 0, 'result': 'DRAW'},
            'participations': [{'id': str(uuid.uuid4()), 'session_id': sid,
                                'player_id': str(i), 'team': 'AB'[i % 2]}
                               for i in range(6)],
        },
    }


def invalid_cases():
    cases = []
    def add(section, field, values):
        for i, value in enumerate(values):
            cases.append(pytest.param(section, field, value, id=f'{section}-{field}-{i}'))
    add('session', 'played_at', [None, 7, [], {}, 'not-a-date', '2026-02-30', '2026-W43-7', '__missing__'])
    add('session', 'id', [None, '', ' ', [], {}, 1])
    add('session', 'session_type', ['UNKNOWN', [], {}, None])
    add('session', 'status', ['UNKNOWN', [], {}])
    add('session', 'result', ['UNKNOWN', [], {}])
    add('part', 'id', [None, '', [], '__missing__', '__duplicate__'])
    add('part', 'player_id', [None, [], {}, 1, 'unknown', '__duplicate__'])
    add('part', 'session_id', [None, [], 'other'])
    add('part', 'team', ['C', [], {}, None])
    add('session', 'allow_uneven_teams', ['false', 2, None])
    add('session', 'is_ranked', ['true', -1])
    add('session', 'split_mode', ['UNKNOWN', []])
    for field in ['score_a', 'score_b', 'score_c', 'wins_a', 'wins_b', 'wins_c',
                  'unassigned_goals_a', 'unassigned_goals_b', 'unassigned_goals_c', 'draw_points']:
        add('session', field, [-1, True, '1', 1.5])
        if not field.startswith('score_'):
            add('session', field, [None])
    for field in ['goals', 'assists', 'yellow_cards', 'red_cards']:
        add('part', field, [-1, True, '1', 1.5])
    add('payload', 'session', [[], None])
    add('payload', 'participations', [None, {}, [None], '__missing__'])
    add('payload', 'is_active', [1, 'false'])
    return cases


@pytest.mark.parametrize('section,field,value', invalid_cases())
def test_invalid_document_is_422_and_never_persisted(api, section, field, value):
    c, path, auth, group = api
    body = version(group)
    target = body['payload']['participations'][0] if section == 'part' else body['payload'] if section == 'payload' else body['payload']['session']
    if value == '__missing__':
        target.pop(field)
    elif value == '__duplicate__':
        target[field] = body['payload']['participations'][1][field]
    else:
        target[field] = value
    before = c.get(path, headers=auth).json()
    response = c.post(path + '/sync', headers=auth, json=body)
    assert response.status_code == 422, response.text
    assert c.get(path, headers=auth).json() == before


@pytest.mark.parametrize('played_at', ['2026-10-25', '2024-02-29T09:00:00',
    '2026-10-25T09:00:00.123456', '2026-10-25T09:00:00Z', '2026-10-25T09:00:00+01:00'])
def test_valid_dates_remain_accepted(api, played_at):
    c, path, auth, group = api
    body = version(group)
    body['payload']['session']['played_at'] = played_at
    assert c.post(path + '/sync', headers=auth, json=body).status_code == 200


@pytest.mark.parametrize('wins,result', [((1, 0, 0), 'A'), ((0, 1, 0), 'B'),
    ((0, 0, 1), 'C'), ((2, 2, 1), 'DRAW_AB'), ((1, 2, 2), 'DRAW_BC'),
    ((2, 1, 2), 'DRAW_AC'), ((1, 1, 1), 'DRAW_ALL')])
def test_tournament_winner_is_derived_from_wins(api, wins, result):
    c, path, auth, group = api
    body = version(group, 'TOURNAMENT_3')
    session = body['payload']['session']
    session.update(zip(['wins_a', 'wins_b', 'wins_c'], wins))
    session.update(result=result, score_a=None, score_b=None)
    for i, part in enumerate(body['payload']['participations']):
        part['team'] = 'ABC'[i % 3]
    wrong = copy.deepcopy(body)
    wrong['payload']['session']['result'] = 'C' if result != 'C' else 'A'
    before = c.get(path, headers=auth).json()
    assert c.post(path + '/sync', headers=auth, json=wrong).status_code == 422
    assert c.get(path, headers=auth).json() == before
    assert c.post(path + '/sync', headers=auth, json=body).status_code == 200


def test_zero_win_tournament_cannot_close_but_can_remain_draft(api):
    c, path, auth, group = api
    body = version(group, 'TOURNAMENT_3')
    body['payload']['session'].update(wins_a=0, wins_b=0, wins_c=0, result='DRAW_ALL')
    for i, part in enumerate(body['payload']['participations']):
        part['team'] = 'ABC'[i % 3]
    assert c.post(path + '/sync', headers=auth, json=body).status_code == 422
    body['payload']['session'].update(status='DRAFT', result=None, score_a=None, score_b=None)
    assert c.post(path + '/sync', headers=auth, json=body).status_code == 200


@pytest.mark.parametrize('status', ['DRAFT', 'CANCELLED'])
def test_invalid_numbers_are_rejected_even_without_closing(api, status):
    c, path, auth, group = api
    body = version(group, status=status)
    body['payload']['session']['wins_b'] = -1
    assert c.post(path + '/sync', headers=auth, json=body).status_code == 422


def test_negative_unassigned_cannot_cancel_player_goal(api):
    c, path, auth, group = api
    body = version(group)
    body['payload']['session']['unassigned_goals_a'] = -1
    body['payload']['participations'][0]['goals'] = 1
    assert c.post(path + '/sync', headers=auth, json=body).status_code == 422


def test_classic_team_c_is_invalid_even_with_uneven_override(api):
    c, path, auth, group = api
    body = version(group)
    body['payload']['session']['allow_uneven_teams'] = 1
    body['payload']['participations'][0]['team'] = 'C'
    assert c.post(path + '/sync', headers=auth, json=body).status_code == 422


def test_historical_classic_format_and_empty_draft_remain_valid(api):
    c, path, auth, group = api
    body = version(group, status='DRAFT')
    body['payload']['session'].pop('session_type')
    body['payload']['session'].update(score_a=None, score_b=None, result=None)
    body['payload']['participations'] = []
    assert c.post(path + '/sync', headers=auth, json=body).status_code == 200


def test_invalid_correction_preserves_current_document_and_history(api):
    c, path, auth, group = api
    body = version(group)
    assert c.post(path + '/sync', headers=auth, json=body).status_code == 200
    body.update(operation_id=str(uuid.uuid4()), base_revision=1)
    body['payload']['session']['played_at'] = 'broken'
    before = c.get(path, headers=auth).json()
    assert c.post(path + '/sync', headers=auth, json=body).status_code == 422
    assert c.get(path, headers=auth).json() == before


def president_auth(c, group):
    response = c.post('/auth/login', json={
        'group_id': group, 'username': 'president', 'password': 'Validation-password-2026',
    })
    assert response.status_code == 200
    return {'Authorization': 'Bearer ' + response.json()['token']}


def test_invalid_other_author_does_not_create_candidate(api):
    c, path, auth, group = api
    body = version(group)
    assert c.post(path + '/sync', headers=auth, json=body).status_code == 200
    other = president_auth(c, group)
    body.update(operation_id=str(uuid.uuid4()))
    body['payload']['session']['played_at'] = 'invalid'
    before = c.get(path, headers=other).json()
    assert c.post(path + '/sync', headers=other, json=body).status_code == 422
    assert c.get(path, headers=other).json() == before


def test_old_invalid_candidate_is_revalidated_but_current_can_be_kept(api, monkeypatch):
    c, path, auth, group = api
    body = version(group)
    assert c.post(path + '/sync', headers=auth, json=body).status_code == 200
    other = president_auth(c, group)
    body.update(operation_id=str(uuid.uuid4()))
    body['payload']['session']['played_at'] = 'invalid'
    # Reproduce a historical candidate accepted before strict validation.
    with monkeypatch.context() as patch:
        patch.setattr('app.main.validate_sport', lambda *args: None)
        response = c.post(path + '/sync', headers=other, json=body)
        assert response.status_code == 200, response.text
        assert response.json()['status'] == 'conflict'
    url = path + '/documents/sport/' + body['occurrence_id'] + '/resolve'
    decision = {'revision': 1, 'candidate_id': body['operation_id'], 'reason': 'Review'}
    before = c.get(path, headers=other).json()
    assert c.post(url, headers=other, json=decision).status_code == 422
    assert c.get(path, headers=other).json() == before
    decision['candidate_id'] = 'current'
    assert c.post(url, headers=other, json=decision).status_code == 200


@pytest.mark.parametrize('change', ['minimum', 'uneven', 'goals', 'assists', 'self-assist', 'too-many'])
def test_existing_sport_invariants_still_reject_bad_closure(api, change):
    c, path, auth, group = api
    body = version(group)
    session = body['payload']['session']
    parts = body['payload']['participations']
    if change == 'minimum':
        body['payload']['participations'] = parts[:2]
    elif change == 'uneven':
        parts[1]['team'] = 'A'
    elif change == 'goals':
        session.update(score_a=1, result='A')
    elif change == 'assists':
        parts[0]['assists'] = 1
    elif change == 'self-assist':
        session.update(score_a=1, result='A')
        parts[0].update(goals=1, assists=1)
    else:
        body['payload']['participations'] = parts * 167
    assert c.post(path + '/sync', headers=auth, json=body).status_code == 422


@pytest.mark.parametrize('mode', [None, 'RANDOM', 'RANDOM_ADJUSTED', 'MANUAL'])
def test_valid_native_options_and_uneven_override(api, mode):
    c, path, auth, group = api
    body = version(group)
    body['payload']['session'].update(split_mode=mode, allow_uneven_teams=1, is_ranked=0)
    body['payload']['participations'][1]['team'] = 'A'
    assert c.post(path + '/sync', headers=auth, json=body).status_code == 200


def test_existing_cross_client_wire_fixture_stays_valid():
    fixture = Path(__file__).resolve().parents[2] / 'web/tests/fixtures/mobile-snapshot.json'
    snapshot = json.loads(fixture.read_text())
    document = next(iter(snapshot['documents'].values()))
    payload = document['payload']
    validate_sport(payload, {m['id'] for m in snapshot['members']},
                   payload['session']['team_id'], snapshot['sport_settings']['min_players_per_session'])
