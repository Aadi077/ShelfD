#!/usr/bin/env bash
# Builds the app and zips it for a GitHub release: build/ShelfD-<version>.zip.
set -euo pipefail

cd "$(dirname "$0")/.."

./scripts/build-app.sh
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"
ZIP="build/ShelfD-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent build/ShelfD.app "$ZIP"
echo "Packaged $ZIP"
