from concurrent.futures import ThreadPoolExecutor
from app.main import create_app


def test_session_dependency_can_exit_on_a_different_worker():
    app = create_app('sqlite:///:memory:')
    route = next(r for r in app.routes if getattr(r, 'path', None) == '/groups')
    dependency = next(d.call for d in route.dependant.dependencies if d.call.__name__ == 'db')
    context = dependency()
    with ThreadPoolExecutor(max_workers=1) as entry, ThreadPoolExecutor(max_workers=1) as exit:
        entry.submit(next, context).result(timeout=3)
        exit.submit(context.close).result(timeout=3)
        # Closing released the guard: a later request can open and close again.
        fresh = dependency()
        entry.submit(next, fresh).result(timeout=3)
        exit.submit(fresh.close).result(timeout=3)
