#!/usr/bin/env bash
# Copies this library into a plugin: bin/sync-to.sh ../mlab-seo
# The plugin then requires lib/mlab-license-client/load.php from its main file.
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="${1:?Usage: bin/sync-to.sh <plugin directory>}"
DEST="$PLUGIN/lib/mlab-license-client"
[ -f "$PLUGIN/$(basename "$PLUGIN").php" ] || { echo "Not a plugin directory: $PLUGIN" >&2; exit 1; }
rm -rf "$DEST"
mkdir -p "$DEST"
cp -r "$SRC/load.php" "$SRC/src" "$SRC/languages" "$SRC/LICENSE" "$DEST/"
VERSION="$(grep -oE "add\( '[0-9.]+'" "$SRC/load.php" | grep -oE '[0-9.]+')"
echo "Copied mlab-license-client $VERSION to $DEST"
