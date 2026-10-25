// Native messaging host ID — must match the "name" field in the host
// manifest JSON installed on the user's machine (see host/install.*).
const HOST_NAME = "com.lab_credential_sync.host";

// Sync starts switched off, so nothing replaces ~/.aws/credentials until
// you turn it on in the popup. Upgrades from 2.0, which had no switch
// and always synced, are kept on rather than silently stopping.
chrome.runtime.onInstalled.addListener(({ reason }) => {
  if (reason === "update") {
    chrome.storage.local.get("enabled", (result) => {
      if (result.enabled === undefined) {
        chrome.storage.local.set({ enabled: true });
      }
    });
  }
});

// An extension can't run anything as it's removed, so uninstalling
// opens the README's uninstall steps instead: one command puts your
// previous credentials file back and removes the helper.
chrome.runtime.setUninstallURL(
  "https://github.com/s3731804/lab-credential-sync#uninstalling"
);

// How the result of a sync is shown: a toast in the page (drawn by
// content.js in the tab's top frame) and a brief badge on the toolbar
// icon. Neither needs an extra permission.
const RESULT_BADGE = {
  ok: { text: "\u2713", color: "#2e7d32", ms: 2000 },
  error: { text: "!", color: "#c62828", ms: 5000 },
  helper_missing: { text: "!", color: "#c62828", ms: 5000 }
};

function reportResult(tabId, status) {
  if (tabId === undefined) {
    return;
  }
  chrome.tabs
    .sendMessage(tabId, { type: "SYNC_RESULT", status }, { frameId: 0 })
    .catch(() => {});

  const badge = RESULT_BADGE[status];
  chrome.action.setBadgeBackgroundColor({ tabId, color: badge.color });
  chrome.action.setBadgeText({ tabId, text: badge.text });
  setTimeout(() => chrome.action.setBadgeText({ tabId, text: "" }), badge.ms);
}

chrome.runtime.onMessage.addListener((message, sender) => {
  if (message.type !== "NEW_CREDENTIALS" || typeof message.data !== "string") {
    return;
  }

  const credentials = message.data.trim();

  // Re-validate at this boundary rather than trusting content.js blindly.
  const isValid =
    credentials.includes("aws_access_key_id") &&
    credentials.includes("aws_secret_access_key") &&
    credentials.includes("aws_session_token");

  if (!isValid) {
    console.warn("Lab Credential Sync: invalid credential block received.");
    return;
  }

  const tabId = sender.tab && sender.tab.id;

  // content.js checks this too, but it could have been switched off
  // between that check and now.
  chrome.storage.local.get({ enabled: false }, ({ enabled }) => {
    if (enabled) {
      syncCredentials(credentials, tabId);
    }
  });
});

function syncCredentials(credentials, tabId) {
  chrome.runtime.sendNativeMessage(
    HOST_NAME,
    { type: "NEW_CREDENTIALS", data: credentials },
    (response) => {
      if (chrome.runtime.lastError) {
        console.warn(
          "Lab Credential Sync: native helper unreachable —",
          chrome.runtime.lastError.message
        );
        chrome.storage.local.set({ lastSyncStatus: "helper_missing" });
        reportResult(tabId, "helper_missing");
        return;
      }
      const status = response && response.status === "ok" ? "ok" : "error";
      chrome.storage.local.set({
        lastSyncStatus: status,
        lastSyncTime: Date.now()
      });
      reportResult(tabId, status);
    }
  );
}

// Switching sync off in the popup puts back whatever credentials file
// the helper displaced. Done here rather than in the popup, which may
// close before the helper answers.
chrome.storage.onChanged.addListener((changes, area) => {
  if (area !== "local" || !changes.enabled || changes.enabled.newValue !== false) {
    return;
  }
  chrome.runtime.sendNativeMessage(HOST_NAME, { type: "RESTORE" }, (response) => {
    let restoreResult;
    if (chrome.runtime.lastError) {
      restoreResult = "helper_missing";
    } else if (response && response.status === "ok") {
      restoreResult = response.result;
    } else {
      // A helper from before 2.1 doesn't know RESTORE.
      restoreResult = "error";
    }
    chrome.storage.local.set({ restoreResult });
  });
});
