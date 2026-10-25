// Only runs inside Vocareum (AWS Learner Lab) pages — see manifest.json
// "matches". This script never clicks the credential "Show" control;
// revealing credentials stays an explicit action the user takes
// themselves. All this does is notice once they're already visible
// and hand them off to the background script.

const host = window.location.hostname.toLowerCase();
const isVocareum = host === "vocareum.com" || host.endsWith(".vocareum.com");

// Shown in the top-right corner, just under the toolbar icon, when
// background.js reports how a sync went. Lives in a shadow root so the
// page's CSS can't restyle it.
const TOAST_MESSAGES = {
  ok: { text: "\u2713 Credentials saved to ~/.aws/credentials", color: "#2e7d32", ms: 2000 },
  error: { text: "Couldn't save credentials. Click the key icon for details.", color: "#c62828", ms: 5000 },
  helper_missing: { text: "Helper not installed. Click the key icon to set it up.", color: "#c62828", ms: 5000 }
};

function showToast(status) {
  const message = TOAST_MESSAGES[status];
  if (!message) {
    return;
  }

  const container = document.createElement("div");
  const shadow = container.attachShadow({ mode: "closed" });
  const toast = document.createElement("div");
  toast.textContent = message.text;
  toast.style.cssText = `
    position: fixed; top: 12px; right: 12px; z-index: 2147483647;
    padding: 10px 14px; border-radius: 6px; border-left: 4px solid ${message.color};
    background: #232f3e; color: #fff; box-shadow: 0 4px 12px rgba(0,0,0,.3);
    font: 14px/1.4 system-ui, sans-serif;
    opacity: 0; transform: translateY(-8px);
    transition: opacity .2s, transform .2s;
  `;
  shadow.appendChild(toast);
  document.documentElement.appendChild(container);

  requestAnimationFrame(() => {
    toast.style.opacity = "1";
    toast.style.transform = "none";
  });
  setTimeout(() => {
    toast.style.opacity = "0";
    setTimeout(() => container.remove(), 200);
  }, message.ms);
}

if (isVocareum) {
  // Waits for revealed credentials and syncs them once, then stops.
  // Switching sync back on in the popup checks again straight away, so
  // credentials already showing are picked up without hiding and
  // re-showing them — in every open lab tab, since storage changes
  // reach background tabs too.
  let pollTimer = null;

  function stopPolling() {
    clearInterval(pollTimer);
    pollTimer = null;
  }

  function startPolling() {
    if (pollTimer === null && !syncIfRevealed()) {
      pollTimer = setInterval(() => {
        if (syncIfRevealed()) {
          stopPolling();
        }
      }, 1000);
    }
  }

  chrome.storage.local.get({ enabled: false }, ({ enabled }) => {
    if (enabled) {
      startPolling();
    }
  });

  chrome.storage.onChanged.addListener((changes, area) => {
    if (area === "local" && changes.enabled) {
      if (changes.enabled.newValue === false) {
        stopPolling();
      } else {
        startPolling();
      }
    }
  });

  // Credentials may be found in an iframe, but the toast belongs in the
  // top frame so it isn't clipped; background.js only messages frame 0.
  if (window === window.top) {
    chrome.runtime.onMessage.addListener((message) => {
      if (message.type === "SYNC_RESULT") {
        showToast(message.status);
      }
    });
  }
}

// Returns true once it has sent a revealed credential block.
function syncIfRevealed() {
  // #clikeybox is the specific box Vocareum reveals the CLI
  // credentials into after "Show" is clicked — it starts with
  // class "hidden-1" / display:none and Vocareum flips it visible
  // itself, so we only act once it's actually showing. Fall back to
  // a broader search of the details panel in case Vocareum's markup
  // shifts the id around later.
  const keyBox =
    document.querySelector("#clikeybox") ||
    document.querySelector("[id*='clikey']") ||
    document.querySelector("#awsdetailsframe");

  if (!keyBox) {
    return false;
  }

  // Use computed style, not just the inline attribute: the
  // "hidden-1" class may set display:none by default via CSS, with
  // Vocareum only adding an inline override once "Show" is clicked.
  // Checking the inline style alone could read as "visible" even
  // while the box is still hidden by the class — and we only ever
  // want to read credentials the user has actually revealed.
  const computedDisplay = window.getComputedStyle(keyBox).display;
  if (computedDisplay === "none") {
    return false;
  }

  const candidates = [keyBox, ...keyBox.querySelectorAll("*")];

  const textBlock = candidates.find((el) => {
    if (el.children.length > 0) {
      return false;
    }
    const text = el.innerText || el.textContent || "";
    return (
      text.includes("aws_access_key_id") &&
      text.includes("aws_secret_access_key") &&
      text.includes("aws_session_token")
    );
  });

  if (!textBlock) {
    return false;
  }

  const credentials = (textBlock.innerText || textBlock.textContent).trim();

  const isValid =
    credentials.includes("aws_access_key_id") &&
    credentials.includes("aws_secret_access_key") &&
    credentials.includes("aws_session_token");

  if (!isValid) {
    return false;
  }

  chrome.runtime.sendMessage({
    type: "NEW_CREDENTIALS",
    data: credentials
  });
  return true;
}
