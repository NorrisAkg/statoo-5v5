// PreToolUse (Edit|Write|MultiEdit): refuse hand edits to build_runner outputs.
let input = '';
process.stdin.on('data', (c) => (input += c));
process.stdin.on('end', () => {
  let filePath = '';
  try {
    filePath = JSON.parse(input).tool_input?.file_path ?? '';
  } catch {
    process.exit(0);
  }
  if (!/\.(g|freezed)\.dart$/.test(filePath)) process.exit(0);

  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PreToolUse',
        permissionDecision: 'deny',
        permissionDecisionReason:
          'Generated file. Edit the source (.dart with @riverpod/@freezed/@JsonSerializable) then run: dart run build_runner build --delete-conflicting-outputs',
      },
    }),
  );
});
