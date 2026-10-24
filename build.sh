#!/bin/bash
# Builds per-browser copies of the extension into dist/, each with the
# right manifest named manifest.json, so either can be loaded unpacked
# (or zipped for store upload) without renaming files in extension/.
#
#   dist/chromium/  — Chrome/Chromium/Brave/Edge (manifest.chromium.json)
#   dist/firefox/   — Firefox (manifest.json)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$ROOT/extension"
DIST="$ROOT/dist"

rm -rf "$DIST"

for browser in chromium firefox; do
  out="$DIST/$browser"
  mkdir -p "$out"
  cp "$SRC"/*.js "$SRC"/*.html "$out/"
  if [ "$browser" = chromium ]; then
    cp "$SRC/manifest.chromium.json" "$out/manifest.json"
  else
    cp "$SRC/manifest.json" "$out/manifest.json"
  fi
  echo "Built $out"
done
