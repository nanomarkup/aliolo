#!/bin/bash
# Get the directory of the current script and navigate to project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

# Wrangler uses isolated local D1 and R2 data unless --remote is explicitly used.
"$SCRIPT_DIR/init_local_db.sh"
cd api && npx wrangler dev
