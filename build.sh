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

# web-ext sign records a pending AMO upload here; keep it across
# rebuilds so re-running package.sh picks up that upload's signed .xpi
# instead of re-submitting the same version.
AMO_UUID="$DIST/firefox/.amo-upload-uuid"
SAVED_UUID=""
[ -f "$AMO_UUID" ] && SAVED_UUID="$(cat "$AMO_UUID")"

rm -rf "$DIST"

for browser in chromium firefox; do
  out="$DIST/$browser"
  mkdir -p "$out"
  cp -r "$SRC"/*.js "$SRC"/*.html "$SRC"/icons "$out/"
  if [ "$browser" = chromium ]; then
    cp "$SRC/manifest.chromium.json" "$out/manifest.json"
  else
    cp "$SRC/manifest.json" "$out/manifest.json"
  fi
  echo "Built $out"
done

if [ -n "$SAVED_UUID" ]; then
  printf '%s' "$SAVED_UUID" > "$AMO_UUID"
fi
