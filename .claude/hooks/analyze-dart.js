// PostToolUse (Edit|Write|MultiEdit): run `dart analyze` on the touched Dart file
// and feed any issue (infos included) back to Claude.
const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

let input = '';
process.stdin.on('data', (c) => (input += c));
process.stdin.on('end', () => {
  let filePath = '';
  try {
    filePath = JSON.parse(input).tool_input?.file_path ?? '';
  } catch {
    process.exit(0);
  }
  if (!filePath.endsWith('.dart') || /\.(g|freezed)\.dart$/.test(filePath)) process.exit(0);
  // Git Bash style /c/... paths are not resolvable by Node on Windows.
  filePath = filePath.replace(/^\/([a-zA-Z])\//, '$1:/');
  if (!fs.existsSync(filePath)) process.exit(0);

  const rootDir = process.env.CLAUDE_PROJECT_DIR || process.cwd();
  const projectDir = fs.existsSync(path.join(rootDir, 'mobile', 'pubspec.yaml'))
    ? path.join(rootDir, 'mobile') : rootDir;
  // shell is needed on Windows (dart is a .bat), so quote: the project path contains a space.
  const res = spawnSync('dart', ['analyze', `"${path.relative(projectDir, filePath)}"`], {
    cwd: projectDir,
    encoding: 'utf8',
    shell: process.platform === 'win32',
    timeout: 60000,
  });
  const out = `${res.stdout || ''}${res.stderr || ''}`;

  const messages = [];
  const issues = out
    .split(/\r?\n/)
    .filter((l) => /^\s*(error|warning|info) - /.test(l));
  if (issues.length) {
    messages.push(`dart analyze ${path.basename(filePath)}:\n${issues.join('\n')}`);
  }

  const src = fs.readFileSync(filePath, 'utf8');
  if (/^part '.+\.(g|freezed)\.dart';/m.test(src)) {
    messages.push(
      'This file has generated parts: if annotations, fields or provider signatures changed, run `dart run build_runner build --delete-conflicting-outputs`.',
    );
  }

  if (!messages.length) process.exit(0);
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PostToolUse',
        additionalContext: messages.join('\n\n'),
      },
    }),
  );
});
