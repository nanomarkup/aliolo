#!/bin/bash
# Wrapper script to run the Python script for deleting unused media in R2.

# Set the project root path
PROJECT_ROOT=$(dirname "$(dirname "$(readlink -f "$0")")")
PYTHON_SCRIPT="$PROJECT_ROOT/scripts/python/delete_unused_media.py"

if ! command -v python3 &> /dev/null; then
    echo "Error: python3 could not be found."
    exit 1
fi

python3 "$PYTHON_SCRIPT" "$@"
