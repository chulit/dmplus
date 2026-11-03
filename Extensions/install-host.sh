#!/bin/bash
# Install DMPlusMsgHost and register it with Chrome (Native Messaging).
# Run after `swift build -c release` in the repo root.
set -euo pipefail
cd "$(dirname "$0")/.."

BIN=".build/release/DMPlusMsgHost"
[ -f "$BIN" ] || { echo "DMPlusMsgHost belum ter-build: jalankan swift build -c release dulu"; exit 1; }

DEST="$HOME/Library/Application Support/DMPlus"
mkdir -p "$DEST"
cp "$BIN" "$DEST/DMPlusMsgHost"

HOSTS_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
mkdir -p "$HOSTS_DIR"
cat > "$HOSTS_DIR/com.chulit.dmplus.json" << JSON
{
  "name": "com.chulit.dmplus",
  "description": "DM+ native messaging host",
  "path": "$DEST/DMPlusMsgHost",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://EXTENSION_ID_HERE/"]
}
JSON
echo "Host terpasang di $DEST/DMPlusMsgHost"
echo "Manifest host: $HOSTS_DIR/com.chulit.dmplus.json"
echo "PENTING: ganti EXTENSION_ID_HERE dengan ID ekstensi DM+ dari chrome://extensions,"
echo "lalu muat folder Extensions/Chrome sebagai ekstensi unpacked."
