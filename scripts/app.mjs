import { existsSync, cpSync, mkdirSync } from 'node:fs';
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

if (process.argv[2] === 'build') {
  run(python, ['-m', 'compileall', '-q', 'backend/app']);
  run(python, ['-m', 'pytest', '-q'], join(process.cwd(), 'backend'));
  run(process.execPath, ['--test', 'web/tests/summary.test.mjs']);
  mkdirSync('web/dist', { recursive: true });
  for (const file of ['index.html', 'app.mjs', 'summary.mjs', 'styles.css']) {
    if (existsSync(`web/${file}`)) cpSync(`web/${file}`, `web/dist/${file}`);
  }
  console.log('Build passed: FastAPI compiled, backend and portal tests passed, static portal packaged.');
} else if (process.argv[2] === 'start') {
  run(python, ['-m', 'uvicorn', 'app.main:app', '--app-dir', 'backend', '--host', '127.0.0.1', '--port', process.env.PORT || '8000']);
} else {
  throw new Error('Expected build or start');
}
