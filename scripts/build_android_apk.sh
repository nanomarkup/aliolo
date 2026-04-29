#!/bin/bash
set -euo pipefail

# Get the directory of the current script and navigate to project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

API_URL="https://aliolo.com"
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"

usage() {
    cat <<EOF
Usage: ./scripts/build_android_apk.sh [options]

Build a release Android APK for local testing.

Options:
  --local-api          Build against the local emulator backend at http://10.0.2.2:8787
  --api-url URL        Build against a custom API URL
  --help               Show this help message

Examples:
  ./scripts/build_android_apk.sh
  ./scripts/build_android_apk.sh --local-api
  ./scripts/build_android_apk.sh --api-url http://192.168.1.20:8787
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --local-api)
            API_URL="http://10.0.2.2:8787"
            shift
            ;;
        --api-url)
            if [[ $# -lt 2 ]]; then
                echo "Error: --api-url requires a URL."
                exit 1
            fi
            API_URL="$2"
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

if ! command -v flutter >/dev/null 2>&1; then
    echo "Error: 'flutter' is not available in PATH."
    echo "Install Flutter and make sure 'flutter' is available in PATH."
    exit 1
fi

echo "Running flutter pub get..."
flutter pub get

echo "Building Android release APK against API_URL=$API_URL"
flutter build apk --release --dart-define=API_URL="$API_URL"

if [[ ! -f "$APK_PATH" ]]; then
    echo "Error: Expected APK was not created at $APK_PATH"
    exit 1
fi

echo
echo "APK ready:"
echo "  $APK_PATH"
