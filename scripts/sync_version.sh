#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

if [[ ! -f pubspec.yaml ]]; then
    echo "pubspec.yaml not found" >&2
    exit 1
fi

current_version="$(awk '/^version:/ {print $2; exit}' pubspec.yaml)"
if [[ -z "$current_version" ]]; then
    echo "Could not read version from pubspec.yaml" >&2
    exit 1
fi

base_version="${current_version%%+*}"
build_number="${1:-$(git rev-list --count HEAD)}"
new_version="${base_version}+${build_number}"

if [[ "$current_version" != "$new_version" ]]; then
    tmp_file="$(mktemp)"
    sed "s/^version: .*/version: $new_version/" pubspec.yaml > "$tmp_file"
    mv "$tmp_file" pubspec.yaml
    echo "Updated pubspec version: $current_version -> $new_version" >&2
fi

echo "$new_version"
