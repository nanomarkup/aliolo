#!/bin/bash
# Get the directory of the current script and navigate to project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

echo "Running Golden Snapshot Tests..."

# Check if --update flag is provided
if [ "$1" == "--update" ]; then
    echo "Updating goldens..."
    flutter test --update-goldens --tags golden
else
    flutter test --tags golden
fi
