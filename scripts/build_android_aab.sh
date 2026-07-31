#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

API_URL="https://aliolo.com"
AAB_PATH="build/app/outputs/bundle/release/app-release.aab"
KEY_PROPERTIES_PATH="android/key.properties"

usage() {
    cat <<EOF
Usage: ./scripts/build_android_aab.sh [options]

Build a signed production Android App Bundle (AAB).

Options:
  --api-url URL        Build against a custom API URL
  --help               Show this help message

Examples:
  ./scripts/build_android_aab.sh
  ./scripts/build_android_aab.sh --api-url https://staging.aliolo.com
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
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

if [[ ! -f "$KEY_PROPERTIES_PATH" ]]; then
    echo "Error: $KEY_PROPERTIES_PATH is missing."
    echo "Production AAB builds require Android release signing to be configured."
    exit 1
fi

resolved_version="$("$SCRIPT_DIR/sync_version.sh")"
echo "Resolved app version: $resolved_version"

echo "Running flutter pub get..."
flutter pub get

echo "Building signed Android release AAB against API_URL=$API_URL"
flutter build appbundle --release --dart-define=API_URL="$API_URL"

if [[ ! -f "$AAB_PATH" ]]; then
    echo "Error: Expected AAB was not created at $AAB_PATH"
    exit 1
fi

echo
echo "AAB ready:"
echo "  $AAB_PATH"
