#!/bin/bash
# Get the directory of the current script and navigate to project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

# Run frontend locally pointing to the local dev server
# -d chrome automatically selects the Chrome browser to avoid the device prompt
flutter run -d chrome --dart-define=API_URL=http://localhost:8787
