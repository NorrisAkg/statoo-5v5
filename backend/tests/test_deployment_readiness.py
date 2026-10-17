from fastapi.testclient import TestClient
from app.main import create_app
import pytest


def test_deployment_contract_and_local_portal_cors(monkeypatch):
    monkeypatch.setenv('CORS_ORIGINS', 'http://127.0.0.1:18085,http://localhost:18085')
    with TestClient(create_app('sqlite:///:memory:')) as client:
        assert client.get('/health').json() == {'status': 'ok'}
        schema = client.get('/openapi.json').json()['components']['schemas']['Registration']
        assert 'group_id' not in schema.get('required', [])
        assert 'operation_id' in schema['properties']
        for origin in ['http://127.0.0.1:18085', 'http://localhost:18085', 'https://unrelated.example']:
            response = client.options('/groups', headers={
                'Origin': origin, 'Access-Control-Request-Method': 'POST',
                'Access-Control-Request-Headers': 'content-type,authorization'})
            if origin.startswith('http://'):
                assert response.status_code == 200
                assert response.headers['access-control-allow-origin'] == origin
            else:
                assert response.status_code == 400
                assert 'access-control-allow-origin' not in response.headers


@pytest.mark.parametrize('render,branch,allowed', [('true','staging',True),('true','main',False),('','staging',False)])
def test_render_staging_allows_local_portal_without_dashboard_change(monkeypatch, render, branch, allowed):
    monkeypatch.setenv('RENDER', render)
    monkeypatch.setenv('RENDER_GIT_BRANCH', branch)
    monkeypatch.setenv('CORS_ORIGINS', 'https://existing.example')
    with TestClient(create_app('sqlite:///:memory:')) as client:
        for origin in ['http://127.0.0.1:18085','http://localhost:18085','http://127.0.0.1:19095','http://localhost:19095','https://existing.example','https://unrelated.example','http://127.0.0.1:19096','http://127.0.0.1.evil.example:19095']:
            response=client.options('/groups',headers={'Origin':origin,'Access-Control-Request-Method':'POST','Access-Control-Request-Headers':'content-type,authorization'})
            expected=origin=='https://existing.example' or (allowed and origin in ['http://127.0.0.1:18085','http://localhost:18085','http://127.0.0.1:19095','http://localhost:19095'])
            assert response.status_code==(200 if expected else 400),origin
