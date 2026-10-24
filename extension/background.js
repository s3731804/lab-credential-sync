// Native messaging host ID — must match the "name" field in the host
// manifest JSON installed on the user's machine (see host/install.*).
const HOST_NAME = "com.lab_credential_sync.host";

chrome.runtime.onMessage.addListener((message) => {
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
        return;
      }
      chrome.storage.local.set({
        lastSyncStatus: response && response.status === "ok" ? "ok" : "error",
        lastSyncTime: Date.now()
      });
    }
  );
});
