#!/bin/bash
# Installs the Lab Credential Sync native messaging host on macOS or
# Linux, for Chromium-based browsers (Chrome, Chromium, Brave, Edge)
# and/or Firefox.
#
# Usage:
#   ./install.sh --chrome <extension-id>
#   ./install.sh --firefox
#   ./install.sh --chrome <extension-id> --firefox
#   ./install.sh --uninstall
#
# Or without cloning the repo:
#   curl -fsSL https://github.com/s3731804/lab-credential-sync/releases/latest/download/install.sh | bash -s -- --firefox
#
# --uninstall puts back the ~/.aws/credentials the helper replaced (if
# it still has the helper's marker), then removes the helper and its
# browser registrations.
#
# --chrome registers with every Chromium-based browser that has a
# profile directory, so open a newly installed browser once before
# running this. The extension ID is only needed for --chrome: find it
# at chrome://extensions (or brave://, edge://) with Developer Mode
# on. Firefox's extension ID is fixed in the manifest
# (browser_specific_settings.gecko.id) so it doesn't need to be passed
# in.
set -euo pipefail

CHROME_EXT_ID=""
DO_CHROME=false
DO_FIREFOX=false
DO_UNINSTALL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --chrome)
      DO_CHROME=true
      CHROME_EXT_ID="${2:-}"
      if [ -z "$CHROME_EXT_ID" ]; then
        echo "Error: --chrome requires an extension ID argument."
        exit 1
      fi
      shift 2
      ;;
    --firefox)
      DO_FIREFOX=true
      shift
      ;;
    --uninstall)
      DO_UNINSTALL=true
      shift
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

if [ "$DO_CHROME" = false ] && [ "$DO_FIREFOX" = false ] && [ "$DO_UNINSTALL" = false ]; then
  echo "Usage: $0 --chrome <extension-id> | --firefox | both | --uninstall"
  exit 1
fi

if ! command -v python3 >/dev/null; then
  echo "Error: python3 not found. Install Python 3 first, then re-run this."
  exit 1
fi

# Where the helper files come from. Run from a clone of the repo, they
# sit next to this script. Run as a one-liner (curl ... | bash), there's
# no script file, so they're downloaded from the GitHub release this
# copy of the script belongs to. package.sh pins RELEASE_URL to that
# release's tag in the copy it publishes.
RELEASE_URL="https://github.com/s3731804/lab-credential-sync/releases/latest/download"
HOST_FILES=(
  lab_credential_sync_host.py
  com.lab_credential_sync.host.chromium.json.template
  com.lab_credential_sync.host.firefox.json.template
)

SCRIPT_PATH="${BASH_SOURCE[0]:-}"
if [ -n "$SCRIPT_PATH" ] && [ -f "$(dirname "$SCRIPT_PATH")/${HOST_FILES[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
else
  SCRIPT_DIR="$(mktemp -d)"
  trap 'rm -rf "$SCRIPT_DIR"' EXIT
  echo "Downloading helper files from $RELEASE_URL"
  for f in "${HOST_FILES[@]}"; do
    curl -fsSL "$RELEASE_URL/$f" -o "$SCRIPT_DIR/$f"
  done
fi

INSTALL_DIR="$HOME/.lab-credential-sync"
HOST_SCRIPT="$INSTALL_DIR/lab_credential_sync_host.py"
MANIFEST_NAME="com.lab_credential_sync.host.json"

# Where each browser looks for native messaging host manifests.
if [[ "$OSTYPE" == "darwin"* ]]; then
  BASE="$HOME/Library/Application Support"
  BROWSERS=(
    "Chrome|$BASE/Google/Chrome"
    "Chromium|$BASE/Chromium"
    "Brave|$BASE/BraveSoftware/Brave-Browser"
    "Edge|$BASE/Microsoft Edge"
  )
  FIREFOX_MANIFEST_DIR="$BASE/Mozilla/NativeMessagingHosts"
else
  BASE="${XDG_CONFIG_HOME:-$HOME/.config}"
  BROWSERS=(
    "Chrome|$BASE/google-chrome"
    "Chromium|$BASE/chromium"
    "Brave|$BASE/BraveSoftware/Brave-Browser"
    "Edge|$BASE/microsoft-edge"
  )
  FIREFOX_MANIFEST_DIR="$HOME/.mozilla/native-messaging-hosts"
fi

if [ "$DO_UNINSTALL" = true ]; then
  # Uses this release's copy of the helper rather than the installed
  # one, which may predate --restore. stdin is closed so an old copy
  # couldn't read this script from the curl pipe.
  python3 "$SCRIPT_DIR/lab_credential_sync_host.py" --restore < /dev/null
  for entry in "${BROWSERS[@]}"; do
    rm -f "${entry#*|}/NativeMessagingHosts/$MANIFEST_NAME"
  done
  rm -f "$FIREFOX_MANIFEST_DIR/$MANIFEST_NAME"
  rm -rf "$INSTALL_DIR"
  echo "Removed the helper and its browser registrations."
  echo "Remove the extension from your browser too, if you haven't already."
  exit 0
fi

mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/lab_credential_sync_host.py" "$HOST_SCRIPT"
chmod +x "$HOST_SCRIPT"

register_chromium() {
  local label="$1" manifest_dir="$2"
  mkdir -p "$manifest_dir"
  sed \
    -e "s#__HOST_SCRIPT_PATH__#$HOST_SCRIPT#" \
    -e "s#__EXTENSION_ID__#$CHROME_EXT_ID#" \
    "$SCRIPT_DIR/com.lab_credential_sync.host.chromium.json.template" \
    > "$manifest_dir/$MANIFEST_NAME"
  echo "$label: registered manifest at $manifest_dir/$MANIFEST_NAME"
}

if [ "$DO_CHROME" = true ]; then
  # Each Chromium-based browser looks for native messaging hosts under
  # its own profile directory. Register with every one that's installed
  # (i.e. has a profile directory), falling back to Google Chrome if
  # none are found yet.
  REGISTERED=0
  for entry in "${BROWSERS[@]}"; do
    profile_dir="${entry#*|}"
    if [ -d "$profile_dir" ]; then
      register_chromium "${entry%%|*}" "$profile_dir/NativeMessagingHosts"
      REGISTERED=$((REGISTERED + 1))
    fi
  done

  if [ "$REGISTERED" -eq 0 ]; then
    echo "No Chromium-based browser profile found; registering for Chrome anyway."
    echo "(Using a different browser? Open it once, then re-run this script.)"
    register_chromium Chrome "${BROWSERS[0]#*|}/NativeMessagingHosts"
  fi
fi

if [ "$DO_FIREFOX" = true ]; then
  MANIFEST_DIR="$FIREFOX_MANIFEST_DIR"
  mkdir -p "$MANIFEST_DIR"

  sed \
    -e "s#__HOST_SCRIPT_PATH__#$HOST_SCRIPT#" \
    "$SCRIPT_DIR/com.lab_credential_sync.host.firefox.json.template" \
    > "$MANIFEST_DIR/$MANIFEST_NAME"

  echo "Firefox: registered manifest at $MANIFEST_DIR/$MANIFEST_NAME"
fi

echo ""
echo "Installed helper script to: $HOST_SCRIPT"
echo "Reload the extension, then reopen its popup — it should say"
echo "'Helper connected'."
