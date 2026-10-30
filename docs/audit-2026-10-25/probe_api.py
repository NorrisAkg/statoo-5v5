"""Sondes AUD-04/06/07/08, uniquement sur SQLite en mémoire.

Exécution depuis backend : .venv/bin/python ../docs/audit-2026-10-25/probe_api.py
Aucun appel réseau ni accès à une base utilisateur.
"""
import copy
import json
import sys
import uuid
from pathlib import Path
from urllib.parse import quote

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'backend'))
from fastapi.testclient import TestClient
from app.main import create_app

results = []
def record(name, response, expected, **extra):
    results.append(dict(scenario=name, observed=response.status_code,
                        expected=expected, **extra))

with TestClient(create_app('sqlite:///:memory:'), raise_server_exceptions=False) as c:
    registration = dict(name='Audit fictif', username='admin', password='Audit-Admin-2026',
                        shared_username='members', shared_password='Audit-Members-2026',
                        members=[dict(id=x, name=x.upper()) for x in 'abcdef'])
    created = c.post('/groups', json=registration)
    assert created.status_code == 201
    identity = created.json()
    group = identity['group_id']
    base = '/groups/' + quote(group, safe='')
    auth = {'Authorization': 'Bearer ' + identity['token']}
    for user, member, role in [('president', 'a', 'PDT'), ('treasurer', 'b', 'TR')]:
        r = c.post(base + '/accounts', headers=auth,
                   json=dict(username=user, password='Audit-Role-2026', member_id=member, roles=[role]))
        assert r.status_code == 201
    nominal = dict(session=dict(id='s', team_id=group, played_at='2026-10-25T09:00:00',
                               status='CLOSED', session_type='CLASSIC_2', score_a=0, score_b=0, result='DRAW'),
                   participations=[dict(id='part-'+x, player_id=x, session_id='s', team='A' if i < 3 else 'B')
                                   for i, x in enumerate('abcdef')])
    variants = []
    variants.append(('nominal', copy.deepcopy(nominal), '200'))
    for name, key, value in [('invalid_date','played_at','not-a-date'),
                             ('missing_date','played_at',None),
                             ('unknown_type','session_type','UNKNOWN'),
                             ('invalid_score_type','score_a','broken')]:
        p = copy.deepcopy(nominal)
        if value is None: p['session'].pop(key)
        else: p['session'][key] = value
        variants.append((name, p, '4xx'))
    p = copy.deepcopy(nominal)
    p['session'].update(session_type='TOURNAMENT_3', result='C', wins_a=9, wins_b=0, wins_c=-1)
    p['participations'] = [dict(x, team='ABC'[i//2]) for i,x in enumerate(p['participations'])]
    variants.append(('tournament_negative_wins_and_wrong_winner',p,'4xx'))
    p = copy.deepcopy(nominal)
    p['participations'][-1]['team'] = 'C'
    p['session']['allow_uneven_teams'] = True
    variants.append(('classic_with_team_c',p,'4xx'))
    p = copy.deepcopy(nominal)
    p['session']['unassigned_goals_a'] = -1
    p['participations'][0]['goals'] = 1
    variants.append(('negative_unassigned_goals',p,'4xx'))
    p = copy.deepcopy(nominal)
    for x in p['participations']: x.pop('id')
    variants.append(('missing_participation_ids',p,'4xx'))
    p = copy.deepcopy(nominal)
    for x in p['participations']: x['id'] = 'duplicate'
    variants.append(('duplicate_participation_ids',p,'4xx'))
    p = copy.deepcopy(nominal)
    p['participations'][0]['player_id'] = []
    variants.append(('unhashable_player_id',p,'4xx'))
    for name, payload, expected in variants:
        r = c.post(base+'/sync', headers=auth,
                   json=dict(operation_id=str(uuid.uuid4()), occurrence_id=name, domain='sport',
                             base_revision=0, payload=payload, reason='audit'))
        record(name,r,expected)
    r = c.post('/auth/login',json=dict(group_id=group,username='admin',password='s3cret!'))
    record('validation_password_echo',r,'422 without submitted password',
           submitted_password_echoed='s3cret!' in r.text)
    r = c.get('/portal/tests/client.test.mjs')
    record('public_test_source',r,'not public',source_served='import ' in r.text)
    r = c.get('/portal/../backend/app/main.py')
    record('static_traversal',r,'404')
    snapshot = c.get(base,headers=auth)
    record('snapshot_has_no_credentials',snapshot,'200 without hashes',
           hash_marker_found='password' in snapshot.text,
           accepted_documents=len(snapshot.json().get('documents',{})))

with TestClient(create_app('sqlite:///:memory:'),raise_server_exceptions=False) as c:
    registration.update(username='admin',shared_username=' admin ')
    r = c.post('/groups',json=registration)
    record('normalized_username_collision_registration',r,'422')
    if r.status_code == 201:
        gid = r.json()['group_id']
        r = c.post('/auth/login',json=dict(group_id=gid,username='admin',password='Audit-Members-2026'))
        record('colliding_collective_login',r,'200 if creation accepted')

print(json.dumps(results,ensure_ascii=False,indent=2))
