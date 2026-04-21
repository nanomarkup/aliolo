#!/bin/bash
# Wrapper script to rebuild ui_translation_bundles from ui_translations.

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: python3 could not be found."
    exit 1
fi

python3 "$SCRIPT_DIR/python/refresh_ui_translation_bundles.py" "$@"
