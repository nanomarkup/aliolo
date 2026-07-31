#!/bin/bash
# Get the directory of the current script and navigate to project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

# Keep the checked-in semantic version and refresh the build number from git.
"$SCRIPT_DIR/sync_version.sh" >/dev/null

# Build Flutter web for production
flutter build web --release --dart-define=API_URL=https://aliolo.com
