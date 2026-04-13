#!/bin/bash

# Get the directory of the current script and navigate to project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

echo "Running Standard Flutter Integration Tests..."

# Check if an emulator or device is connected via adb
if ! adb devices | grep -q -E "emulator-|device$"; then
    echo "Error: No Android device or emulator detected."
    echo "Please run ./scripts/start_emulator.sh first and wait for it to be READY."
    exit 1
fi

# Run the standard integration test
# You can add more test files here or use a glob pattern if you convert other tests
flutter test integration_test/standard_test.dart
