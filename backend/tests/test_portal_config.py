from fastapi.testclient import TestClient
from app.main import create_app


def test_public_portal_configuration(monkeypatch):
    monkeypatch.setenv('STATOO_PUBLIC_API_URL', 'https://api.example.test/prefix')
    monkeypatch.setenv('PRIVATE_TEST_SECRET', 'never-expose-this')
    with TestClient(create_app('sqlite:///:memory:')) as client:
        response = client.get('/portal/config.json')
        assert response.status_code == 200
        assert response.json() == {'api_url': 'https://api.example.test/prefix'}
        assert 'never-expose-this' not in response.text


def test_empty_portal_configuration(monkeypatch):
    monkeypatch.setenv('STATOO_PUBLIC_API_URL', '')
    with TestClient(create_app('sqlite:///:memory:')) as client:
        response = client.get('/portal/config.json')
        assert response.status_code == 200
        assert response.json() == {'api_url': ''}
