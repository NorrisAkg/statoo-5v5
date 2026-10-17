import pytest
from urllib.parse import quote
from fastapi.testclient import TestClient
from app.main import create_app
from test_group_registration import BODY


@pytest.mark.parametrize('short,expected', [(None, ''), ('', ''), ('   ', ''), (' ÉFC ', 'ÉFC'), ('A' * 30, 'A' * 30)])
def test_short_name_round_trip(short, expected):
    with TestClient(create_app('sqlite:///:memory:')) as c:
        body = {**BODY, 'operation_id': 'short-name-test'}
        if short is not None:
            body['short_name'] = short
        result = c.post('/groups', json=body)
        assert result.status_code == 201
        identity = result.json()
        headers = {'Authorization': 'Bearer ' + identity['token']}
        data = c.get('/groups/' + quote(identity['group_id'], safe=''), headers=headers).json()
        assert data['name'] == BODY['name']
        assert data.get('short_name') == expected
        assert c.post('/groups', json=body).json()['group_id'] == identity['group_id']


def test_short_name_rejected_when_too_long_and_retry_cannot_change_it():
    with TestClient(create_app('sqlite:///:memory:')) as c:
        assert c.post('/groups', json={**BODY, 'short_name': 'A' * 31}).status_code == 422
        body = {**BODY, 'operation_id': 'same-attempt', 'short_name': 'FC'}
        assert c.post('/groups', json=body).status_code == 201
        assert c.post('/groups', json={**body, 'short_name': 'ABC'}).status_code == 409
