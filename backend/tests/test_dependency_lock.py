"""DEP-001 / OPS-005 / DEP-002 (audit 14/11/2026) : build backend reproductible.

Render installait à chaque build les dernières versions compatibles des bornes de
`requirements.txt`, sur une version de Python choisie par Render. La production pouvait
donc tourner avec des versions jamais testées.
"""
import re
import sys
from pathlib import Path

import pytest
import yaml
from packaging.requirements import Requirement
from packaging.utils import canonicalize_name
from packaging.version import Version

BACKEND = Path(__file__).resolve().parents[1]
ROOT = BACKEND.parent
HASH = re.compile(r'--hash=sha256:[0-9a-f]{64}')
# Render (Linux) et les postes de développement : les README donnent les commandes Windows.
PLATFORMS = {
    'linux': {'sys_platform': 'linux', 'platform_system': 'Linux', 'os_name': 'posix'},
    'win32': {'sys_platform': 'win32', 'platform_system': 'Windows', 'os_name': 'nt'},
    'darwin': {'sys_platform': 'darwin', 'platform_system': 'Darwin', 'os_name': 'posix'},
}


def service():
    services = yaml.safe_load((ROOT / 'render.yaml').read_text(encoding='utf-8'))['services']
    return next(s for s in services if s['name'] == 'statoo-api')


def env(name):
    return next((v for v in service().get('envVars', []) if v.get('key') == name), None)


def lock_entries(name, platform=None):
    """Lit un fichier au format pip-compile : `paquet==version \\` puis des lignes `--hash`.

    Avec `platform`, ne garde que les paquets dont le marqueur s'applique à cette plateforme
    (Python 3.12, celle de Render)."""
    path = BACKEND / name
    assert path.is_file(), f'{name} absent'
    logical, current = [], ''
    for raw in path.read_text(encoding='utf-8').splitlines():
        line = raw.split(' #', 1)[0].rstrip() if not raw.lstrip().startswith('#') else ''
        if not line.strip():
            continue
        current += ' ' + line.rstrip('\\').strip()
        if not line.endswith('\\'):
            logical.append(current.strip())
            current = ''
    assert not current, f'{name} : continuation de ligne non terminée'
    entries = {}
    for line in logical:
        assert not line.startswith('-'), f'{name} : option globale inattendue : {line}'
        spec, hashes = line.split(' --hash', 1)[0], HASH.findall(line)
        requirement = Requirement(spec)
        pins = list(requirement.specifier)
        assert len(pins) == 1 and pins[0].operator == '==', f'{name} : version non épinglée : {spec}'
        assert hashes, f'{name} : empreinte absente pour {requirement.name}'
        if platform is not None and requirement.marker is not None and not requirement.marker.evaluate(
                {**PLATFORMS[platform], 'python_version': '3.12', 'python_full_version': '3.12.3',
                 'implementation_name': 'cpython', 'platform_python_implementation': 'CPython'}):
            continue
        key = canonicalize_name(requirement.name)
        assert key not in entries, f'{name} : {requirement.name} en double'
        entries[key] = Version(pins[0].version)
    return entries


def manifest(name):
    out = []
    for raw in (BACKEND / name).read_text(encoding='utf-8').splitlines():
        line = raw.split('#', 1)[0].strip()
        if line and not line.startswith('-'):
            out.append(Requirement(line))
    return out


def test_render_installs_the_hashed_lockfile_only():
    command = service()['buildCommand']
    assert re.search(r'pip install .*--require-hashes', command), command
    assert re.search(r'-r requirements\.lock\b', command), command
    assert 'requirements.txt' not in command


def test_render_pins_a_fully_qualified_python_version():
    variable = env('PYTHON_VERSION')
    assert variable is not None, 'PYTHON_VERSION absent de render.yaml'
    assert 'sync' not in variable, 'la version doit être dans le dépôt, pas saisie sur Render'
    assert re.fullmatch(r'3\.\d+\.\d+', str(variable.get('value', ''))), variable


def test_tests_run_on_the_production_python_minor_version():
    variable = env('PYTHON_VERSION')
    assert variable is not None, 'PYTHON_VERSION absent de render.yaml'
    major, minor, _ = (int(part) for part in str(variable['value']).split('.'))
    assert sys.version_info[:2] == (major, minor), (
        f'pytest tourne en {sys.version.split()[0]}, Render en {env("PYTHON_VERSION")["value"]}')


@pytest.mark.parametrize('lock,source', [('requirements.lock', 'requirements.txt'),
                                         ('requirements-dev.lock', 'requirements-dev.txt')])
def test_each_lock_satisfies_its_manifest(lock, source):
    entries = lock_entries(lock)
    for requirement in manifest(source):
        key = canonicalize_name(requirement.name)
        assert key in entries, f'{lock} : {requirement.name} absent'
        assert requirement.specifier.contains(entries[key]), f'{lock} : {requirement.name} {entries[key]} hors de {requirement.specifier}'


def test_dev_lock_keeps_the_production_versions():
    production, development = lock_entries('requirements.lock'), lock_entries('requirements-dev.lock')
    drift = {name: (version, development.get(name)) for name, version in production.items()
             if development.get(name) != version}
    assert not drift, f'les tests ne porteraient pas sur les versions de production : {drift}'


def test_dev_only_tools_stay_out_of_the_production_lock():
    production = lock_entries('requirements.lock')
    for tool in ('pytest', 'httpx', 'pip-audit', 'pip-tools'):
        assert canonicalize_name(tool) not in production, tool


def test_dev_requirements_point_to_the_production_requirements():
    assert '-r requirements.txt' in (BACKEND / 'requirements-dev.txt').read_text(encoding='utf-8')


def test_opentelemetry_api_is_locked_past_the_known_vulnerability():
    # DEP-002 : CVE-2026-126360, corrigée en 1.45.2 ; dépendance de FastAPI.
    for lock in ('requirements.lock', 'requirements-dev.lock'):
        version = lock_entries(lock).get('opentelemetry-api')
        assert version is not None, f'{lock} : opentelemetry-api absent (FastAPI en dépend)'
        assert version >= Version('1.45.2'), f'{lock} : opentelemetry-api {version}'


# Revue DEP-001 : un lock résolu sous Linux sans marqueurs imposait uvloop (absent de
# Windows) et omettait colorama (requis par pytest sous Windows), donc
# `pip install --require-hashes` échouait sur les postes Windows.
@pytest.mark.parametrize('lock', ['requirements.lock', 'requirements-dev.lock'])
def test_locks_keep_platform_markers(lock):
    assert 'uvloop' in lock_entries(lock, 'linux'), 'uvloop doit rester installé sur Render'
    assert 'uvloop' not in lock_entries(lock, 'win32'), 'uvloop ne s’installe pas sous Windows'


def test_dev_lock_installs_pytest_windows_dependencies():
    assert 'colorama' not in lock_entries('requirements-dev.lock', 'linux')
    assert 'colorama' in lock_entries('requirements-dev.lock', 'win32'), 'pytest exige colorama sous Windows'


@pytest.mark.parametrize('platform', sorted(PLATFORMS))
def test_dev_lock_keeps_the_production_versions_on_every_platform(platform):
    production = lock_entries('requirements.lock', platform)
    development = lock_entries('requirements-dev.lock', platform)
    assert {n: v for n, v in production.items() if development.get(n) != v} == {}


# OPS-006 (décision du 15/11/2026) : production maintenue sur le plan gratuit, risque
# accepté (mise en veille, démarrage à froid, pas d'engagement de disponibilité). Les
# compteurs de tentatives (SEC-002/003/005) sont en mémoire : une seule instance.
def test_render_runs_a_single_instance_without_autoscaling():
    api = service()
    # Explicite : pour un service existant, une clé absente garde la valeur du tableau de bord.
    assert api.get('numInstances') == 1, 'compteurs de tentatives en mémoire : numInstances: 1'
    assert 'scaling' not in api, 'mise à l’échelle automatique incompatible avec les compteurs en mémoire'
    # `--workers 1` l'emporte sur WEB_CONCURRENCY, que uvicorn lit sinon.
    assert re.search(r'--workers 1\b', api['startCommand']), api['startCommand']
    assert env('WEB_CONCURRENCY') is None


def test_render_plan_choice_is_documented():
    # Un changement de plan doit être une décision explicite, consignée avec le plan.
    raw = (ROOT / 'render.yaml').read_text(encoding='utf-8')
    plan = re.escape(service()['plan'])
    assert re.search(rf'^\s*#.*OPS-006.*\n(?:\s*#.*\n)*\s*plan: {plan}\b', raw, re.M), (
        'commentaire OPS-006 attendu juste au-dessus de `plan:`')
