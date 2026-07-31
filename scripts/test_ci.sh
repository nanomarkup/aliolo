#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

echo "Running the same checks that gate production deployment..."

flutter analyze --no-fatal-warnings --no-fatal-infos
"$SCRIPT_DIR/test_frontend.sh"
"$SCRIPT_DIR/test_backend.sh"

echo "All production-gating checks passed."
