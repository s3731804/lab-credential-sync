#!/bin/bash
# Installs the AWS Learner Lab Sync native messaging host on macOS or
# Linux, for Chromium-based browsers (Chrome, Chromium, Brave, Edge)
# and/or Firefox.
#
# Usage:
#   ./install.sh --chrome <extension-id>
#   ./install.sh --firefox
#   ./install.sh --chrome <extension-id> --firefox
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
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

if [ "$DO_CHROME" = false ] && [ "$DO_FIREFOX" = false ]; then
  echo "Usage: $0 --chrome <extension-id> | --firefox | both"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.aws-lab-sync"
HOST_SCRIPT="$INSTALL_DIR/aws_lab_sync_host.py"

mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/aws_lab_sync_host.py" "$HOST_SCRIPT"
chmod +x "$HOST_SCRIPT"

IS_MAC=false
[[ "$OSTYPE" == "darwin"* ]] && IS_MAC=true

register_chromium() {
  local label="$1" manifest_dir="$2"
  mkdir -p "$manifest_dir"
  sed \
    -e "s#__HOST_SCRIPT_PATH__#$HOST_SCRIPT#" \
    -e "s#__EXTENSION_ID__#$CHROME_EXT_ID#" \
    "$SCRIPT_DIR/com.aws_lab_sync.host.chromium.json.template" \
    > "$manifest_dir/com.aws_lab_sync.host.json"
  echo "$label: registered manifest at $manifest_dir/com.aws_lab_sync.host.json"
}

if [ "$DO_CHROME" = true ]; then
  # Each Chromium-based browser looks for native messaging hosts under
  # its own profile directory. Register with every one that's installed
  # (i.e. has a profile directory), falling back to Google Chrome if
  # none are found yet.
  if [ "$IS_MAC" = true ]; then
    BASE="$HOME/Library/Application Support"
    BROWSERS=(
      "Chrome|$BASE/Google/Chrome"
      "Chromium|$BASE/Chromium"
      "Brave|$BASE/BraveSoftware/Brave-Browser"
      "Edge|$BASE/Microsoft Edge"
    )
  else
    BASE="${XDG_CONFIG_HOME:-$HOME/.config}"
    BROWSERS=(
      "Chrome|$BASE/google-chrome"
      "Chromium|$BASE/chromium"
      "Brave|$BASE/BraveSoftware/Brave-Browser"
      "Edge|$BASE/microsoft-edge"
    )
  fi

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
  if [ "$IS_MAC" = true ]; then
    MANIFEST_DIR="$HOME/Library/Application Support/Mozilla/NativeMessagingHosts"
  else
    MANIFEST_DIR="$HOME/.mozilla/native-messaging-hosts"
  fi
  mkdir -p "$MANIFEST_DIR"

  sed \
    -e "s#__HOST_SCRIPT_PATH__#$HOST_SCRIPT#" \
    "$SCRIPT_DIR/com.aws_lab_sync.host.firefox.json.template" \
    > "$MANIFEST_DIR/com.aws_lab_sync.host.json"

  echo "Firefox: registered manifest at $MANIFEST_DIR/com.aws_lab_sync.host.json"
fi

echo ""
echo "Installed helper script to: $HOST_SCRIPT"
echo "Reload the extension, then reopen its popup — it should say"
echo "'Helper connected'."
