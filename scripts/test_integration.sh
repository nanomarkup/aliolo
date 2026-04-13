#!/bin/bash
# Get the directory of the current script and navigate to project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

# Ensure patrol is in PATH
export PATH="$PATH":"$HOME/.pub-cache/bin"

# Check if patrol is installed
if ! command -v patrol &> /dev/null; then
    echo "Error: 'patrol' command not found."
    echo "Please install it by running: dart pub global activate patrol_cli 3.6.0"
    exit 1
fi

echo "Running Patrol Integration Tests..."
echo "Note: Ensure you have an Android/iOS emulator running or a device connected."

# Run patrol tests
patrol test -t integration_test/
