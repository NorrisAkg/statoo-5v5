from test_api import system, sport, event


def payload(identifier, active=True, status='DRAFT'):
    value = sport('CLOSED')
    value['session']['id'] = identifier
    value['session']['status'] = status
    for part in value['participations']:
        part['session_id'] = identifier
    value['is_active'] = active
    return value


def test_active_session_is_unique_shared_and_released(system):
    c, t, _ = system
    def send(value, occurrence, revision=0):
        body = event('sport', value, revision=revision)
        body['occurrence_id'] = occurrence
        return c.post('/groups/%2300000001/sync', headers=t['sport'], json=body)
    first = send(payload('one'), 'one')
    assert first.status_code == 200, first.text
    state = c.get('/groups/%2300000001', headers=t['members']).json()
    assert state.get('active_session_id') == 'one'
    rejected = send(payload('two'), 'two')
    assert rejected.status_code == 409
    assert rejected.json()['detail']['code'] == 'active_session_conflict'
    assert send(payload('waiting', active=False), 'waiting').status_code == 200
    assert send(payload('one', active=False, status='CLOSED'), 'one', 1).status_code == 200
    assert c.get('/groups/%2300000001', headers=t['sport']).json()['active_session_id'] is None
    assert send(payload('waiting'), 'waiting', 1).status_code == 200
    assert c.get('/groups/%2300000001', headers=t['sport']).json()['active_session_id'] == 'waiting'


def test_invalid_start_and_conflicting_candidate_do_not_change_active_session(system):
    c, t, _ = system
    bad = payload('s')
    bad['participations'] = []
    r = c.post('/groups/%2300000001/sync', headers=t['sport'], json=event('sport', bad))
    assert r.status_code == 422
    body = event('sport', payload('s', active=False))
    assert c.post('/groups/%2300000001/sync', headers=t['sport'], json=body).status_code == 200
    candidate = event('sport', payload('s'), revision=0)
    response = c.post('/groups/%2300000001/sync', headers=t['vice'], json=candidate)
    assert response.json()['status'] == 'conflict'
    assert c.get('/groups/%2300000001', headers=t['sport']).json().get('active_session_id') is None


def test_legacy_group_does_not_explicitly_clear_existing_device_active_session(system):
    c, t, _ = system
    data = c.get('/groups/%2300000001', headers=t['sport']).json()
    assert 'active_session_id' not in data
