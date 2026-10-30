"""F10: serve only the legacy portal's intentional public surface."""
import re
from pathlib import Path
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from app.main import create_app

ROOT = Path(__file__).resolve().parents[2] / 'web'
PUBLIC = [
    'index.html', 'app.mjs', 'interaction.mjs', 'button-state.mjs',
    'validation.mjs', 'vendor/zod.mjs', 'vendor/ZOD-LICENSE.txt',
    'config.mjs', 'registration-draft.mjs', 'client.mjs', 'domain.mjs',
    'summary.mjs', 'pwa.mjs', 'sw.js', 'styles.css', 'manifest.webmanifest',
    'team-names.json', 'icons/icon-192.png', 'icons/icon-1024.png',
    'icons/logo.jpg', 'icons/logo-transparent.png', 'icons/favicon.png',
    'icons/apple-touch-icon.png', 'fonts/Poppins-Regular.ttf',
    'fonts/Poppins-SemiBold.ttf', 'fonts/OFL.txt',
]
PRIVATE = [
    'tests/client.test.mjs', 'tests/fixtures/mobile-snapshot.json',
    'tests/serve.py', 'tests/audit/client.audit.mjs',
    'prototypes/live-stats/index.html', 'prototypes/live-stats/model.mjs',
    'README.md', 'tests/', 'prototypes/live-stats/',
    '%74ests/client.test.mjs', 'tests%2fclient.test.mjs',
    'icons/%2e%2e/tests/client.test.mjs',
    'tests/client.test.mjs?download=1', '%2e%2e/backend/app/main.py',
]


@pytest.fixture(scope='module')
def client():
    with TestClient(create_app('sqlite:///:memory:')) as client:
        yield client


@pytest.mark.parametrize('path', PRIVATE)
@pytest.mark.parametrize('method', ['GET', 'HEAD'])
def test_private_portal_paths_are_not_served(client, path, method):
    response = client.request(method, '/portal/' + path)
    assert response.status_code == 404
    if method == 'HEAD':
        assert response.content == b''


@pytest.mark.parametrize('path', PUBLIC)
@pytest.mark.parametrize('method', ['GET', 'HEAD'])
def test_public_assets_stay_available(client, path, method):
    response = client.request(method, '/portal/' + path)
    assert response.status_code == 200
    assert response.headers['content-type'] != 'application/json' or path.endswith('.json')
    assert response.content == ((ROOT / path).read_bytes() if method == 'GET' else b'')
    expected = ('text/html' if path.endswith('.html') else
                'text/css' if path.endswith('.css') else
                'image/png' if path.endswith('.png') else None)
    if expected:
        assert response.headers['content-type'].startswith(expected)


def test_index_redirect_and_unknown_routes(client):
    redirect = client.get('/portal', follow_redirects=False)
    assert redirect.status_code == 307
    assert redirect.headers['location'].endswith('/portal/')
    assert client.get('/portal/').content == client.get('/portal/index.html').content
    assert client.get('/portal/').status_code == 200
    assert client.get('/portal/unknown-screen').status_code == 404


def test_public_worker_shell_and_local_imports_are_complete(client):
    worker = client.get('/portal/sw.js').text
    shell = worker.split('const SHELL = [', 1)[1].split('];', 1)[0]
    resources = re.findall(r'"([^"]+)"', shell)
    assert resources
    for resource in resources:
        assert client.get('/portal/' + resource).status_code == 200, resource
    for name in PUBLIC:
        if not name.endswith(('.mjs', '.js')):
            continue
        for relative in re.findall(r'(?:from\s*|import\s*)[\'"](\./[^\'"]+)[\'"]', (ROOT / name).read_text()):
            parent = Path(name).parent
            response = client.get('/portal/' + (parent / relative).as_posix())
            assert response.status_code == 200, (name, relative)


@pytest.mark.parametrize('path', ['private-new.mjs', 'icons/private.json',
                                 'fonts/private.txt', 'vendor/private.mjs',
                                 'dist/index.html', 'universal-dist/index.html'])
def test_new_files_are_private_by_default(tmp_path, path):
    (tmp_path / 'index.html').write_text('Synthetic public index')
    private = tmp_path / path
    private.parent.mkdir(parents=True, exist_ok=True)
    private.write_text('Synthetic private content')
    # Substitute only the portal root; do not write into the real web tree.
    with patch('app.main.Path') as mocked:
        mocked.return_value.resolve.return_value.parents.__getitem__.return_value.__truediv__.return_value = tmp_path
        app = create_app('sqlite:///:memory:')
    with TestClient(app) as c:
        assert c.get('/portal/' + path).status_code == 404
        assert c.get('/portal/').status_code == 200


@pytest.mark.parametrize('inside', [False, True])
def test_private_symlink_stays_private(tmp_path, inside):
    portal = tmp_path / 'portal'
    portal.mkdir()
    secret = (portal if inside else tmp_path) / 'private.txt'
    secret.write_text('Synthetic outside content')
    (portal / 'index.html').symlink_to(secret)
    with patch('app.main.Path') as mocked:
        mocked.return_value.resolve.return_value.parents.__getitem__.return_value.__truediv__.return_value = portal
        app = create_app('sqlite:///:memory:')
    with TestClient(app) as c:
        assert c.get('/portal/index.html').status_code == 404
        assert c.get('/portal/').status_code == 404


def test_dynamic_config_and_api_contract(client, monkeypatch):
    monkeypatch.setenv('STATOO_PUBLIC_API_URL', 'https://api.example.test/prefix')
    monkeypatch.setenv('PRIVATE_TEST_SECRET', 'Synthetic not public')
    assert client.get('/portal/config.json').json() == {'api_url': 'https://api.example.test/prefix'}
    assert client.get('/health').status_code == 200
    assert client.get('/groups/unknown').status_code == 401


def test_cache_methods_and_missing_files(client):
    response = client.get('/portal/styles.css')
    assert response.status_code == 200
    assert client.get('/portal/styles.css', headers={'If-None-Match': response.headers['etag']}).status_code == 304
    assert client.post('/portal/styles.css').status_code == 405
    assert client.get('/portal/missing.mjs').status_code == 404
