#!/bin/bash

# Get the directory of the current script and navigate to project root
SCRIPT_DIR="$( cd "$( dirname "${BSource[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

# Define environment variables if not already set
export ANDROID_HOME=${ANDROID_HOME:-"$HOME/Android/Sdk"}
export ANDROID_AVD_HOME=${ANDROID_AVD_HOME:-"$HOME/.config/.android/avd"}
export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools"

AVD_NAME="aliolo_emulator"
HEADLESS=false
WIPE_FLAG=""

# Parse arguments
for arg in "$@"; do
    if [ "$arg" == "--headless" ]; then
        HEADLESS=true
    fi
    if [ "$arg" == "--wipe" ]; then
        WIPE_FLAG="-wipe-data"
    fi
done

# Check if emulator is already running
if adb devices | grep -q "emulator-5554"; then
    echo "Emulator is already running."
    exit 0
fi

echo "Starting Android Emulator: $AVD_NAME..."

# Basic flags
# -gpu swiftshader_indirect: Software rendering (stable in containers)
# -no-snapshot: Ensures we don't load a corrupted state
EMULATOR_FLAGS="-avd $AVD_NAME -no-audio -no-boot-anim -accel auto -no-snapshot -gpu swiftshader_indirect $WIPE_FLAG"

if [ "$HEADLESS" = true ]; then
    echo "Running in HEADLESS mode..."
    EMULATOR_FLAGS="$EMULATOR_FLAGS -no-window"
else
    echo "Running in VISIBLE mode..."
fi

# Start emulator in background
# We must set ANDROID_AVD_HOME explicitly for the emulator process
ANDROID_AVD_HOME=$ANDROID_AVD_HOME $ANDROID_HOME/emulator/emulator $EMULATOR_FLAGS > /tmp/emulator.log 2>&1 &

echo "Waiting for emulator to boot (this may take 3 minutes)..."

# Wait for boot completion
timeout 180 adb wait-for-device shell 'while [[ -z $(getprop sys.boot_completed) ]]; do sleep 1; done'

if [ $? -eq 0 ]; then
    echo "Emulator is READY!"
    adb devices
else
    echo "Timeout waiting for emulator to boot. Check /tmp/emulator.log for details."
    exit 1
fi
