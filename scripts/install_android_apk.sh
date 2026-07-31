#!/bin/bash
set -euo pipefail

# Get the directory of the current script and navigate to project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

DEVICE_SERIAL=""
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"

usage() {
    cat <<EOF
Usage: ./scripts/install_android_apk.sh [options]

Install a built Android APK on a connected Android device.

Options:
  --device SERIAL      Install to the specified adb device serial
  --apk PATH           Install a custom APK path
  --help               Show this help message

Examples:
  ./scripts/install_android_apk.sh
  ./scripts/install_android_apk.sh --device R5CY123456A
  ./scripts/install_android_apk.sh --apk build/app/outputs/flutter-apk/app-release.apk
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --device)
            if [[ $# -lt 2 ]]; then
                echo "Error: --device requires an adb serial."
                exit 1
            fi
            DEVICE_SERIAL="$2"
            shift 2
            ;;
        --apk)
            if [[ $# -lt 2 ]]; then
                echo "Error: --apk requires a file path."
                exit 1
            fi
            APK_PATH="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1"
            echo
            usage
            exit 1
            ;;
    esac
done

print_android_debug_help() {
    cat <<EOF
No authorized Android device is available for installation.

Phone setup:
  1. Enable Developer options on the phone
  2. Enable USB debugging
  3. Connect the phone by USB
  4. Accept the laptop authorization prompt on the phone
  5. Run: adb devices
EOF
}

list_connected_devices() {
    adb devices | awk 'NR > 1 && $1 != "" { print $1 "\t" $2 }'
}

pick_install_device() {
    local devices
    devices="$(list_connected_devices)"

    if [[ -n "$DEVICE_SERIAL" ]]; then
        if echo "$devices" | awk '{print $1}' | grep -Fxq "$DEVICE_SERIAL"; then
            echo "$DEVICE_SERIAL"
            return 0
        fi
        echo "Error: Requested device '$DEVICE_SERIAL' is not connected."
        echo
        echo "Connected devices:"
        echo "$devices"
        exit 1
    fi

    local authorized_count
    authorized_count="$(echo "$devices" | awk '$2 == "device" { count++ } END { print count + 0 }')"

    if [[ "$authorized_count" -eq 1 ]]; then
        echo "$devices" | awk '$2 == "device" { print $1; exit }'
        return 0
    fi

    if [[ "$authorized_count" -eq 0 ]]; then
        echo "Error: No authorized Android devices found."
        if [[ -n "$devices" ]]; then
            echo
            echo "Detected adb entries:"
            echo "$devices"
        fi
        echo
        print_android_debug_help
        exit 1
    fi

    echo "Error: Multiple Android devices are connected."
    echo "Use --device SERIAL to choose one:"
    echo
    echo "$devices"
    exit 1
}

if ! command -v adb >/dev/null 2>&1; then
    echo "Error: 'adb' is not available in PATH."
    echo "Install Android platform-tools and make sure 'adb' is available in PATH."
    exit 1
fi

if [[ ! -f "$APK_PATH" ]]; then
    echo "Error: APK not found at $APK_PATH"
    echo "Build it first with ./scripts/build_android_apk.sh"
    exit 1
fi

TARGET_DEVICE="$(pick_install_device)"

echo "Installing APK on device: $TARGET_DEVICE"
adb -s "$TARGET_DEVICE" install -r "$APK_PATH"

echo
echo "Install completed successfully."
