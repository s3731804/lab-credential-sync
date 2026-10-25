const REPO_URL = "https://github.com/s3731804/lab-credential-sync";
const SETUP_URL = `${REPO_URL}#quick-install`;

document.getElementById("repo-link").href = SETUP_URL;
document.getElementById("source-link").href = REPO_URL;

const HOST_NAME = "com.lab_credential_sync.host";

// The oldest helper that understands everything this extension sends
// (2.1 added RESTORE). Older ones don't report a version at all.
const MIN_HELPER_VERSION = [2, 1];

function helperIsCurrent(version) {
  if (typeof version !== "string") {
    return false;
  }
  const [major, minor] = version.split(".").map(Number);
  return major > MIN_HELPER_VERSION[0] ||
    (major === MIN_HELPER_VERSION[0] && minor >= MIN_HELPER_VERSION[1]);
}
const statusEl = document.getElementById("status");
const setupEl = document.getElementById("setup");

function showStatus(kind, text) {
  statusEl.className = `status-banner status-${kind}`;
  statusEl.textContent = text;
  setupEl.style.display = kind === "missing" || kind === "outdated" ? "block" : "none";
}

// Ping the native host. If it's not installed/registered, Chrome
// surfaces that as a runtime.lastError rather than a thrown exception.
chrome.runtime.sendNativeMessage(
  HOST_NAME,
  { type: "PING" },
  (response) => {
    if (chrome.runtime.lastError) {
      showStatus(
        "missing",
        "Setup required — local helper not found."
      );
      return;
    }
    if (response && response.status === "ok" && !helperIsCurrent(response.version)) {
      showStatus(
        "outdated",
        "Helper is out of date. Re-run the install command to update it."
      );
    } else if (response && response.status === "ok") {
      showStatus("ok", "✅ Helper connected.");
    } else {
      showStatus("error", "Helper responded unexpectedly — see console.");
    }
  }
);

// The sync switch. Turning it off makes background.js ask the helper
// to put back whatever credentials file it replaced; restoreResult is
// how that went.
const enabledEl = document.getElementById("enabled");
const toggleNoteEl = document.getElementById("toggle-note");

const RESTORE_NOTES = {
  restored: "Off. Your previous credentials file has been put back.",
  removed: "Off. Lab credentials removed (you had no file before).",
  not_ours: "Off. Your credentials file wasn't made by this extension, so it was left alone.",
  nothing: "Off. No credentials file to restore.",
  helper_missing: "Off, but the helper wasn't found, so nothing was restored.",
  error: "Off, but restoring failed. Your helper may be out of date: re-run the installer.",
  pending: "Off. Restoring your previous credentials file\u2026"
};

function showToggleNote(enabled, restoreResult) {
  toggleNoteEl.textContent = enabled
    ? "On. Credentials you reveal with Show are saved to ~/.aws/credentials."
    : RESTORE_NOTES[restoreResult] ||
      "Off. Turn on to save the credentials you reveal with Show to " +
      "~/.aws/credentials. Your own file is backed up, and put back " +
      "when you turn this off.";
}

chrome.storage.local.get({ enabled: false, restoreResult: null }, (result) => {
  enabledEl.checked = result.enabled;
  showToggleNote(result.enabled, result.restoreResult);
});

enabledEl.addEventListener("change", () => {
  const enabled = enabledEl.checked;
  chrome.storage.local.set({ enabled, restoreResult: null });
  showToggleNote(enabled, "pending");
});

chrome.storage.onChanged.addListener((changes, area) => {
  if (area === "local" && changes.restoreResult && changes.restoreResult.newValue) {
    showToggleNote(enabledEl.checked, changes.restoreResult.newValue);
  }
});

// Also show when the last credential sync happened, if we have one.
chrome.storage.local.get(["lastSyncStatus", "lastSyncTime"], (result) => {
  if (!result.lastSyncTime) return;
  const when = new Date(result.lastSyncTime).toLocaleTimeString();
  const note = document.createElement("p");
  note.textContent =
    result.lastSyncStatus === "ok"
      ? `Last synced at ${when}.`
      : `Last sync attempt at ${when} failed — check the helper.`;
  document.body.appendChild(note);
});
