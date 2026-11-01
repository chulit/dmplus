#!/bin/bash
# Build UnduhQu.app (standalone, survives without Xcode) into dist/
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN=".build/release/UnduhQu"
APP="dist/UnduhQu.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/UnduhQu"
cp packaging/Info.plist "$APP/Contents/Info.plist"

echo "Built $APP"
echo "Run: open $APP"
