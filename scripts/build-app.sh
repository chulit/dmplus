#!/bin/bash
# Build DMPlus.app (standalone, survives without Xcode) into dist/
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN=".build/release/DMPlus"
APP="dist/DMPlus.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/DMPlus"
cp packaging/Info.plist "$APP/Contents/Info.plist"

echo "Built $APP"
echo "Run: open $APP"
