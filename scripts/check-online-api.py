"""Read-only deployment receipt: no login, credentials or remote mutations."""
import argparse
import json
import sys
import urllib.error
import urllib.request


def check(base):
    passed = True
    for path in ['/health', '/openapi.json']:
        with urllib.request.urlopen(base.rstrip('/') + path, timeout=60) as response:
            data = json.load(response)
        if path == '/health':
            ok = data.get('status') == 'ok'
            print('Health:', 'OK' if ok else 'FAIL')
        else:
            schema = data['components']['schemas']['Registration']
            ok = 'group_id' not in schema.get('required', []) and 'operation_id' in schema.get('properties', {})
            print('PWA registration contract:', 'OK' if ok else 'FAIL (backend update required)')
        passed = passed and ok
    for origin in ['http://127.0.0.1:18085', 'http://localhost:18085']:
        request = urllib.request.Request(base.rstrip('/') + '/groups', method='OPTIONS', headers={
            'Origin': origin, 'Access-Control-Request-Method': 'POST',
            'Access-Control-Request-Headers': 'content-type,authorization'})
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                ok = response.status == 200 and response.headers.get('Access-Control-Allow-Origin') == origin
        except urllib.error.HTTPError:
            ok = False
        print('CORS', origin + ':', 'OK' if ok else 'FAIL (allowed origins update required)')
        passed = passed and ok
    return 0 if passed else 1


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url', default='https://statoo-api.onrender.com')
    args = parser.parse_args()
    try:
        sys.exit(check(args.url))
    except (OSError, ValueError, KeyError) as error:
        print('Receipt unavailable:', type(error).__name__)
        sys.exit(1)
