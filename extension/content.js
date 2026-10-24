// Only runs inside Vocareum (AWS Learner Lab) pages — see manifest.json
// "matches". This script never clicks the credential "Show" control;
// revealing credentials stays an explicit action the user takes
// themselves. All this does is notice once they're already visible
// and hand them off to the background script.

const host = window.location.hostname.toLowerCase();
const isVocareum = host === "vocareum.com" || host.endsWith(".vocareum.com");

if (isVocareum) {
  let credentialsSynced = false;

  const pollForCredentials = setInterval(() => {
    if (credentialsSynced) {
      clearInterval(pollForCredentials);
      return;
    }

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
      return;
    }

    // Use computed style, not just the inline attribute: the
    // "hidden-1" class may set display:none by default via CSS, with
    // Vocareum only adding an inline override once "Show" is clicked.
    // Checking the inline style alone could read as "visible" even
    // while the box is still hidden by the class — and we only ever
    // want to read credentials the user has actually revealed.
    const computedDisplay = window.getComputedStyle(keyBox).display;
    if (computedDisplay === "none") {
      return;
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
      return;
    }

    const credentials = (textBlock.innerText || textBlock.textContent).trim();

    const isValid =
      credentials.includes("aws_access_key_id") &&
      credentials.includes("aws_secret_access_key") &&
      credentials.includes("aws_session_token");

    if (!isValid) {
      return;
    }

    credentialsSynced = true;
    clearInterval(pollForCredentials);

    chrome.runtime.sendMessage({
      type: "NEW_CREDENTIALS",
      data: credentials
    });
  }, 1000);
}