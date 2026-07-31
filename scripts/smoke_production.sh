#!/bin/bash
set -euo pipefail

BASE_URL="${ALIOLO_PRODUCTION_URL:-https://aliolo.com}"

curl --fail --silent --show-error --location \
  --retry 5 --retry-delay 2 --retry-all-errors \
  "$BASE_URL/" >/dev/null

curl --fail --silent --show-error --location \
  --retry 5 --retry-delay 2 --retry-all-errors \
  "$BASE_URL/api/pillars" >/dev/null

curl --fail --silent --show-error --location \
  --retry 5 --retry-delay 2 --retry-all-errors \
  "$BASE_URL/api/languages" >/dev/null

echo "Production smoke checks passed for $BASE_URL"
