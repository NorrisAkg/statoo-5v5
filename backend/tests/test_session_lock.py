import asyncio

from app.main import create_app


def _db_dependency(app):
    route = next(r for r in app.routes if getattr(r, 'path', None) == '/groups')
    return next(d.call for d in route.dependant.dependencies if d.call.__name__ == 'db')


def test_session_dependency_releases_the_sqlite_guard_when_closed():
    # SQLite partage une connexion : la dépendance sérialise les sessions. Depuis PERF-001,
    # ce verrou est asynchrone (aucun thread du pool n'est bloqué pendant l'attente).
    dependency = _db_dependency(create_app('sqlite:///:memory:'))

    async def scenario():
        first = dependency()
        await asyncio.wait_for(anext(first), 3)
        second = dependency()
        waiting = asyncio.ensure_future(anext(second))
        await asyncio.sleep(0.05)
        assert not waiting.done(), "deux sessions SQLite ne doivent pas être ouvertes en même temps"
        await asyncio.wait_for(first.aclose(), 3)
        # Fermer la première session libère le verrou : la suivante s'ouvre puis se referme.
        await asyncio.wait_for(waiting, 3)
        await asyncio.wait_for(second.aclose(), 3)

    asyncio.run(scenario())
