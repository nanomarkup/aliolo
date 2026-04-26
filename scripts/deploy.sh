#!/bin/bash
# Get the directory of the current script and navigate to project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

# Bump the version in pubspec.yaml
if [ -f pubspec.yaml ]; then
    current_version=$(grep -E '^version: ' pubspec.yaml | awk '{print $2}')
    major=$(echo "$current_version" | cut -d. -f1)
    minor=$(echo "$current_version" | cut -d. -f2)
    patch=$(echo "$current_version" | cut -d. -f3)
    new_patch=$((patch + 1))
    new_version="${major}.${minor}.${new_patch}"
    
    echo "Bumping version from $current_version to $new_version"
    
    # Update pubspec.yaml
    sed -i "s/^version: .*/version: $new_version/" pubspec.yaml
fi

# Build the frontend and deploy the worker with the bundled web assets
"$SCRIPT_DIR/build.sh"
cd api && npx wrangler deploy --env production
