from fastapi.testclient import TestClient
from app.main import create_app
from test_group_registration import BODY

def test_registration_retry_returns_same_group_and_rejects_changed_request():
    with TestClient(create_app('sqlite:///:memory:')) as c:
        body = {**BODY, 'operation_id': 'offline-creation-test'}
        first = c.post('/groups', json=body)
        assert first.status_code == 201
        second = c.post('/groups', json=body)
        assert second.status_code == 201
        assert second.json()['group_id'] == first.json()['group_id']
        for change in [{'password': 'Changed-Password-2026'}, {'name': 'Changed'}, {'members': []}]:
            rejected = c.post('/groups', json={**body, **change})
            assert rejected.status_code == 409
            assert 'token' not in rejected.json()
