#!/bin/bash
# Install DMPlusMsgHost and register it with Chrome (Native Messaging).
# Run after `swift build -c release` in the repo root.
#
# No manual steps: the extension ID is derived automatically from the
# public "key" pinned in Extensions/Chrome/manifest.json, so it is
# permanent and allowed_origins is always written correctly.
# An explicit ID may still be passed as $1 to override.
set -euo pipefail
cd "$(dirname "$0")/.."

BIN=".build/release/DMPlusMsgHost"
[ -f "$BIN" ] || { echo "DMPlusMsgHost belum ter-build: jalankan swift build -c release dulu"; exit 1; }

if [ -n "${1:-}" ]; then
  EXT_ID="$1"
else
  EXT_ID="$(python3 - Extensions/Chrome/manifest.json << 'INPY'
import base64, hashlib, json, sys
key = json.load(open(sys.argv[1]))["key"]
digest = hashlib.sha256(base64.b64decode(key)).digest()[:16]
print("".join(chr(97 + (b >> 4)) + chr(97 + (b & 15)) for b in digest))
INPY
)"
fi
[ -n "$EXT_ID" ] || { echo "Gagal menurunkan ID ekstensi dari manifest"; exit 1; }

DEST="$HOME/Library/Application Support/DMPlus"
mkdir -p "$DEST"
cp "$BIN" "$DEST/DMPlusMsgHost"
chmod +x "$DEST/DMPlusMsgHost"

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
echo "allowed_origins diisi ID ekstensi tetap: $EXT_ID"
echo "Selesai — muat/reload folder Extensions/Chrome di chrome://extensions, lalu mulai ulang Chrome."
