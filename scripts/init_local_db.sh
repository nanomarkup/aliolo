#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."
SCHEMA_SOURCE="$PROJECT_ROOT/api/test/setup.ts"
TEMP_SCHEMA="$(mktemp)"

cleanup() {
  rm -f "$TEMP_SCHEMA"
}
trap cleanup EXIT

# Keep local development and isolated backend tests on the same baseline schema.
awk '
  /^const SCHEMA = `$/ { copying = 1; next }
  copying && /^`;$/ { exit }
  copying { print }
' "$SCHEMA_SOURCE" > "$TEMP_SCHEMA"

cd "$PROJECT_ROOT/api"
npx wrangler d1 execute aliolo-db --local --file "$TEMP_SCHEMA"
npx wrangler d1 execute aliolo-db --local --command \
  "INSERT OR IGNORE INTO pillars (id, sort_order, name, names, description, descriptions) VALUES (6, 6, 'General', '{\"en\":\"General\"}', 'Local development content', '{\"en\":\"Local development content\"}')"

echo "Local D1 schema is ready. Production data was not accessed."
