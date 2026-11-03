#!/bin/bash
# Install DMPlusMsgHost and register it with Chrome (Native Messaging).
# Run after `swift build -c release` in the repo root.
# Usage: ./Extensions/install-host.sh [EXTENSION_ID]
# Pass the extension ID from chrome://extensions so allowed_origins is
# written correctly in one go (without it, a placeholder is written and
# Chrome will refuse the native connection until you edit the manifest).
set -euo pipefail
EXT_ID="${1:-EXTENSION_ID_HERE}"
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
  "allowed_origins": ["chrome-extension://$EXT_ID/"]
}
JSON
echo "Host terpasang di $DEST/DMPlusMsgHost"
echo "Manifest host: $HOSTS_DIR/com.chulit.dmplus.json"
if [ "$EXT_ID" = "EXTENSION_ID_HERE" ]; then
  echo "PENTING: kamu belum memberi ID ekstensi. Muat folder Extensions/Chrome di"
  echo "chrome://extensions, salin ID-nya, lalu jalankan lagi:"
  echo "  ./Extensions/install-host.sh <ID_EKSTENSI>"
else
  echo "allowed_origins sudah diisi ID ekstensi: $EXT_ID"
  echo "Muat/reload folder Extensions/Chrome di chrome://extensions, lalu mulai ulang Chrome."
fi
