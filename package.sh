#!/bin/bash
# Packages the extension for store upload, into dist/:
#
#   lab-credential-sync-chromium-<version>.zip
#       For the Chrome Web Store. Same as dist/chromium/ but with the
#       manifest's "key" removed, since the store assigns its own.
#
#   lab-credential-sync-firefox-<version>.zip
#       For AMO, built and checked with web-ext.
#
#   release/
#       Files to attach to the GitHub release for v<version>: the helper,
#       its manifest templates, and install.sh / install.ps1 pinned to
#       that release so the one-line installers fetch matching files.
#
# If WEB_EXT_API_KEY and WEB_EXT_API_SECRET are set (AMO API
# credentials, from https://addons.mozilla.org/developers/addon/api/key/),
# it also signs the Firefox build as unlisted and saves the signed .xpi
# in dist/, ready to attach to a GitHub Release.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="$ROOT/dist"

"$ROOT/build.sh"

version_of() {
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$1"
}
VERSION="$(version_of "$DIST/chromium/manifest.json")"
if [ "$VERSION" != "$(version_of "$DIST/firefox/manifest.json")" ]; then
  echo "Error: manifest.json and manifest.chromium.json have different versions."
  exit 1
fi

# Chrome Web Store
CHROMIUM_ZIP="$DIST/lab-credential-sync-chromium-$VERSION.zip"
python3 - "$DIST/chromium" "$CHROMIUM_ZIP" <<'EOF'
import json, os, sys, zipfile
src, out = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for dirpath, _, files in os.walk(src):
        for f in sorted(files):
            path = os.path.join(dirpath, f)
            name = os.path.relpath(path, src)
            if name == "manifest.json":
                manifest = json.load(open(path))
                manifest.pop("key", None)
                z.writestr(name, json.dumps(manifest, indent=2) + "\n")
            else:
                z.write(path, name)
EOF
echo "Built $CHROMIUM_ZIP"

# Firefox / AMO
npx --yes web-ext lint --source-dir "$DIST/firefox"
npx --yes web-ext build \
  --source-dir "$DIST/firefox" \
  --artifacts-dir "$DIST" \
  --filename "lab-credential-sync-firefox-$VERSION.zip" \
  --overwrite-dest

# GitHub release assets for the one-line helper installers: the host
# files plus install scripts pinned to download from this version's
# tag, so a given install.sh always installs its own release's helper.
RELEASE="$DIST/release"
mkdir -p "$RELEASE"
cp "$ROOT"/host/lab_credential_sync_host.py "$ROOT"/host/*.template "$RELEASE/"
for f in install.sh install.ps1; do
  sed "s#releases/latest/download\"#releases/download/v$VERSION\"#" \
    "$ROOT/host/$f" > "$RELEASE/$f"
  grep -q "releases/download/v$VERSION\"" "$RELEASE/$f" || {
    echo "Error: couldn't pin the release URL in $f."
    exit 1
  }
done
echo "Built release assets in $RELEASE"

if [ -n "${WEB_EXT_API_KEY:-}" ] && [ -n "${WEB_EXT_API_SECRET:-}" ]; then
  npx --yes web-ext sign \
    --source-dir "$DIST/firefox" \
    --artifacts-dir "$DIST" \
    --channel unlisted
else
  echo "Skipping Firefox signing (WEB_EXT_API_KEY / WEB_EXT_API_SECRET not set)."
fi
