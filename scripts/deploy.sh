#!/bin/bash
# Get the directory of the current script and navigate to project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

# Build the frontend and deploy the worker with the bundled web assets
"$SCRIPT_DIR/build.sh"
cd api && npx wrangler deploy --env production
