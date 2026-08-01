#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

resolved_version="$("$SCRIPT_DIR/sync_version.sh")"

if [[ "${1:-}" != "--confirm-production" ]]; then
  echo "Production is deployed automatically by GitHub Actions after CI passes."
  echo "For an emergency local deployment, run:"
  echo "  ./scripts/deploy.sh --confirm-production"
  exit 2
fi

# Emergency fallback: test, build, deploy, and verify from this checkout.
"$SCRIPT_DIR/test_ci.sh"
"$SCRIPT_DIR/build.sh"
cd api && npx wrangler deploy --env production
cd "$SCRIPT_DIR/.."
"$SCRIPT_DIR/smoke_production.sh"

echo ""
echo "=================================================="
echo "Successfully deployed version: $resolved_version"
echo "=================================================="
