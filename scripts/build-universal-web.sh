#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if ! command -v flutter >/dev/null 2>&1; then
  SDK="$ROOT/.flutter-sdk"
  if [ ! -x "$SDK/bin/flutter" ]; then
    git clone --depth 1 --branch 3.47.5 https://github.com/flutter/flutter.git "$SDK"
  fi
  export PATH="$SDK/bin:$PATH"
fi
npm run build:web
cd "$ROOT/mobile"
flutter config --no-analytics
flutter pub get --enforce-lockfile
dart run sqflite_common_ffi_web:setup
flutter build web --release --target lib/main_web.dart --no-web-resources-cdn --dart-define="STATOO_API=${STATOO_PUBLIC_API_URL:-https://statoo-api.onrender.com}"
cd "$ROOT"
node scripts/package-universal-web.mjs
