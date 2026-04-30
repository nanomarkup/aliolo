#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

resolved_version="$("$SCRIPT_DIR/sync_version.sh")"

# Build the frontend and deploy the worker with the bundled web assets.
"$SCRIPT_DIR/build.sh"
cd api && npx wrangler deploy --env production

echo ""
echo "=================================================="
echo "Successfully deployed version: $resolved_version"
echo "=================================================="
