#!/usr/bin/env bash
# Refreshes web/sqlite3.wasm and web/drift_worker.js so they match the drift
# and sqlite3 versions locked in pubspec.lock. Run after upgrading either
# package: tool/web/update_sqlite_assets.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

locked() {
  awk -v pkg="$1" '
    $0 ~ "^  " pkg ":$" { found = 1; next }
    found && /^    version:/ { gsub(/"/, "", $2); print $2; exit }
  ' pubspec.lock
}

drift_version=$(locked drift)
sqlite3_version=$(locked sqlite3)
echo "drift $drift_version, sqlite3 $sqlite3_version"

flutter pub get >/dev/null
pub_cache=${PUB_CACHE:-$HOME/.pub-cache}
cp "$pub_cache/hosted/pub.dev/drift-$drift_version/drift_worker.js" web/drift_worker.js

curl -fsSL -o web/sqlite3.wasm \
  "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-$sqlite3_version/sqlite3.wasm"

ls -la web/drift_worker.js web/sqlite3.wasm
