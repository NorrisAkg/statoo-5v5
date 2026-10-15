import re
from unittest.mock import patch
from urllib.parse import quote
from fastapi.testclient import TestClient
from app.main import create_app

BODY = {'name': 'Test', 'username': 'admin', 'password': 'Test-Password',
        'shared_username': 'members', 'shared_password': 'Members-Password',
        'members': [{'id': 'a', 'name': 'Alice'}]}


def test_generated_id_and_collision_preserve_first_group():
    with TestClient(create_app('sqlite:///:memory:')) as c:
        with patch('app.main.secrets.randbelow', side_effect=[1, 1, 12345678]):
            first = c.post('/groups', json=BODY)
            assert first.status_code == 201, first.text
            assert first.json()['group_id'] == '#00000001'
            second = c.post('/groups', json={**BODY, 'group_id': 'caller-chosen', 'name': 'Second'})
            assert second.status_code == 201, second.text
            assert second.json()['group_id'] == '#12345678'
        for response, name in [(first, 'Test'), (second, 'Second')]:
            identity = response.json()
            assert re.fullmatch(r'#[0-9]{8}', identity['group_id'])
            login = c.post('/auth/login', json={'group_id': identity['group_id'], 'username': 'admin', 'password': BODY['password']})
            assert login.status_code == 200
            snapshot = c.get('/groups/' + quote(identity['group_id'], safe=''), headers={'Authorization': 'Bearer ' + identity['token']})
            assert snapshot.status_code == 200
            assert snapshot.json()['name'] == name


def test_repeated_collisions_fail_without_overwriting():
    with TestClient(create_app('sqlite:///:memory:')) as c:
        with patch('app.main.secrets.randbelow', return_value=42) as draw:
            first = c.post('/groups', json=BODY)
            assert first.status_code == 201, first.text
            assert first.json()['group_id'] == '#00000042'
            response = c.post('/groups', json=BODY)
            assert response.status_code == 503
            assert draw.call_count <= 21
