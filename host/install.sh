#!/bin/bash
# Installs the AWS Learner Lab Sync native messaging host on macOS or
# Linux, for Chrome/Chromium and/or Firefox.
#
# Usage:
#   ./install.sh --chrome <extension-id>
#   ./install.sh --firefox
#   ./install.sh --chrome <extension-id> --firefox
#
# The Chrome extension ID is only needed for --chrome: find it at
# chrome://extensions with Developer Mode on. Firefox's extension ID
# is fixed in the manifest (browser_specific_settings.gecko.id) so it
# doesn't need to be passed in.
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

if [ "$DO_CHROME" = true ]; then
  if [ "$IS_MAC" = true ]; then
    MANIFEST_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
  else
    MANIFEST_DIR="$HOME/.config/google-chrome/NativeMessagingHosts"
  fi
  mkdir -p "$MANIFEST_DIR"

  sed \
    -e "s#__HOST_SCRIPT_PATH__#$HOST_SCRIPT#" \
    -e "s#__EXTENSION_ID__#$CHROME_EXT_ID#" \
    "$SCRIPT_DIR/com.aws_lab_sync.host.chromium.json.template" \
    > "$MANIFEST_DIR/com.aws_lab_sync.host.json"

  echo "Chrome: registered manifest at $MANIFEST_DIR/com.aws_lab_sync.host.json"
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
