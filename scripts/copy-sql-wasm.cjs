/**
 * Copies sql.js's WASM binary into public/, where the browser SQLite driver
 * fetches it from. Runs on postinstall.
 *
 * Resolved with require.resolve rather than a hardcoded node_modules path: the
 * previous version assumed sql.js was hoisted to the top level, which only
 * holds by accident of npm's layout. Any tree where it sits under
 * jeep-sqlite/node_modules broke the copy — and a throwing postinstall fails
 * the whole `npm install`.
 */
const fs = require('fs')
const path = require('path')

const TARGETS = ['public/sql-wasm.wasm', 'public/assets/sql-wasm.wasm']

let src
try {
  src = require.resolve('sql.js/dist/sql-wasm.wasm')
} catch {
  // Never fail the install over this: the binaries are committed, so a
  // checkout already has a working copy. Warn and move on.
  console.warn('[copy-sql-wasm] sql.js not resolvable, keeping the committed sql-wasm.wasm')
  process.exit(0)
}

for (const target of TARGETS) {
  const dest = path.resolve(__dirname, '..', target)
  fs.mkdirSync(path.dirname(dest), { recursive: true })
  fs.copyFileSync(src, dest)
}

console.log(`[copy-sql-wasm] copied ${path.basename(src)} to ${TARGETS.join(' and ')}`)
