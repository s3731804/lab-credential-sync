// Fill these in once you've published the repo.
const REPO_URL = "https://github.com/yourname/aws-lab-sync";
const SETUP_URL = `${REPO_URL}#setup`;

document.getElementById("repo-link").href = SETUP_URL;
document.getElementById("source-link").href = REPO_URL;

const HOST_NAME = "com.aws_lab_sync.host";
const statusEl = document.getElementById("status");
const setupEl = document.getElementById("setup");

function showStatus(kind, text) {
  statusEl.className = `status-banner status-${kind}`;
  statusEl.textContent = text;
  setupEl.style.display = kind === "missing" ? "block" : "none";
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
    if (response && response.status === "ok") {
      showStatus("ok", "✅ Helper connected. Syncing is automatic.");
    } else {
      showStatus("error", "Helper responded unexpectedly — see console.");
    }
  }
);

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
