#!/bin/bash
# Get the directory of the current script and navigate to project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

echo "Running E2E tests against production API..."
echo "Note: To run full authenticated tests, ensure you export MAIN_USER_PASSWORD and TEST_USER_PASSWORD"
echo "      e.g., MAIN_USER_PASSWORD='xxx' TEST_USER_PASSWORD='yyy' ./scripts/test_e2e.sh"
echo "      Ensure your local 'wrangler' is authenticated (npx wrangler login) for direct DB queries."

# Run E2E tests against production
cd api && npm run test:e2e
