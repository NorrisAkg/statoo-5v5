import { existsSync, cpSync, mkdirSync, readdirSync, writeFileSync } from 'node:fs';
import { apiAddress } from '../web/config.mjs';
import { spawnSync } from 'node:child_process';
import { join } from 'node:path';

const python = process.env.PYTHON ||
  (existsSync('backend/.venv/Scripts/python.exe') ? join(process.cwd(), 'backend/.venv/Scripts/python.exe') :
    existsSync('backend/.venv/bin/python') ? join(process.cwd(), 'backend/.venv/bin/python') : 'python');

function run(command, args, cwd = process.cwd()) {
  const result = spawnSync(command, args, { cwd, stdio: 'inherit', env: process.env });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status || 1);
}

function buildPortal() {
  for (const path of ['.env.local', '.env']) if (existsSync(path)) process.loadEnvFile(path);
  const configured = process.env.STATOO_PUBLIC_API_URL?.trim() || '';
  const api_url = configured ? apiAddress({api_url: configured}) : '';
  run(process.execPath, ['--test', ...readdirSync('web/tests').filter(name => name.endsWith('.test.mjs')).map(name => `web/tests/${name}`)]);
  mkdirSync('web/dist', { recursive: true });
  for (const file of ['index.html', 'app.mjs', 'config.mjs', 'registration-draft.mjs', 'client.mjs', 'domain.mjs', 'summary.mjs', 'pwa.mjs', 'sw.js', 'styles.css', 'manifest.webmanifest', 'team-names.json', 'icons', 'fonts']) {
    if (!existsSync(`web/${file}`)) throw new Error(`Missing PWA asset: ${file}`);
    cpSync(`web/${file}`, `web/dist/${file}`, { recursive: true });
  }
  writeFileSync('web/dist/config.json', JSON.stringify({api_url}) + '\n');
}

if (process.argv[2] === 'build') {
  run(python, ['-m', 'compileall', '-q', 'backend/app']);
  run(python, ['-m', 'pytest', '-q'], join(process.cwd(), 'backend'));
  buildPortal();
  console.log('Build passed: FastAPI compiled, backend and portal tests passed, static portal packaged.');
} else if (process.argv[2] === 'build-web') {
  buildPortal();
  console.log('PWA tests passed and static portal packaged.');
} else if (process.argv[2] === 'start') {
  run(python, ['-m', 'uvicorn', 'app.main:app', '--app-dir', 'backend', '--host', '127.0.0.1', '--port', process.env.PORT || '8000']);
} else {
  throw new Error('Expected build, build-web or start');
}
