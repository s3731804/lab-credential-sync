# Lab Credential Sync

> **Unofficial.** Not affiliated with, endorsed by, or supported by
> Amazon Web Services, AWS Academy, or Vocareum. It works with AWS
> Academy Learner Lab sandboxes.

A small browser extension + local helper that saves you re-copying AWS
Learner Lab's temporary CLI credentials into `~/.aws/credentials` every
time they expire (every 4 hours). Built as a companion to a
reproducible DevOps assignment using Terraform/Ansible via GitHub
Actions — this mirrors that automation locally for anyone running the
project against their own Learner Lab sandbox.

**Supported:** Chrome/Chromium/Brave/Edge and Firefox, on macOS,
Linux and Windows.

## What it actually does (read this before installing)

1. On any `*.vocareum.com` page, a content script watches for the AWS
   CLI credential block to appear **after you reveal it yourself** by
   clicking "Show" in AWS Details. It never clicks Show for you.
2. Once the credential text is visible on the page, the extension
   reads it, checks it looks like a real AWS Learner Lab credential
   block, and passes it to a small Python script (the "native
   messaging host") running on your own machine.
3. That script checks the block strictly (a `[profile]` header and
   exactly the three expected keys, nothing else) and writes it to
   `~/.aws/credentials` with `0600` permissions, under a
   `# managed by lab-credential-sync` marker line.

**Your existing credentials are never deleted.** If
`~/.aws/credentials` doesn't have that marker — i.e. it's your own
file, with real keys or other profiles — it's moved to
`~/.aws/credentials.backup-<timestamp>` the first time, and the helper
never touches that backup again. Files the helper wrote itself only
ever hold expired lab credentials, so those are just kept as a single
`credentials.previous` rather than piling up. If you had other
profiles, copy them back from the backup into a separate file (or
point `AWS_SHARED_CREDENTIALS_FILE` elsewhere) — the helper rewrites
`~/.aws/credentials` on every sync.

Nothing is sent anywhere except from your browser to a process running
locally on your own computer. There is no server, no telemetry, no
network request of any kind in either the extension or the host
script — you can verify this by reading `extension/content.js`,
`extension/background.js`, and `host/lab_credential_sync_host.py` in full;
none of them total more than ~150 lines. See [PRIVACY.md](PRIVACY.md)
for the formal privacy policy.

## Why a native helper instead of just downloading a file?

An earlier version of this wrote credentials via `chrome.downloads`
into your Downloads folder and had you symlink them in manually. That
works, but Downloads is commonly synced by iCloud Drive / OneDrive /
Dropbox, which isn't somewhere temporary cloud credentials should
casually end up. The native messaging host writes directly to
`~/.aws/credentials` with `0600` permissions and nothing passes
through Downloads at all. The tradeoff is a one-time setup step
outside the browser — see below.

## Setup

This is published as an **unlisted** extension on both stores —
reviewed and signed, but not searchable or browsable, so it only
installs for someone who has the link below. You're still welcome to
load it from source instead; see "Loading from source" further down.

### Chrome / Chromium / Brave / Edge

1. Install from the direct (unlisted) Chrome Web Store link:
   **[chrome web store link — fill in after publishing]**
2. Once installed, copy the extension ID shown on its card at
   `chrome://extensions`.
3. Install the helper:
   ```bash
   cd host
   ./install.sh --chrome <your-extension-id>
   ```
   Windows: `.\install.ps1 -ChromeExtensionId "<your-extension-id>"`

   This registers the helper with every Chromium-based browser it
   finds (Chrome, Chromium, Brave, Edge). On macOS/Linux a browser is
   only found once it's been opened at least once, so open a newly
   installed one first and re-run the script if needed.

### Firefox

1. Install the signed `.xpi` from the latest
   [GitHub Release](../../releases) (or the AMO unlisted link, if
   you're using one: **[amo link — fill in after publishing]**).
   Firefox installs it directly when you open the file — no
   temporary-add-on reload-on-restart involved.
2. Install the helper:
   ```bash
   cd host
   ./install.sh --firefox
   ```
   Windows: `.\install.ps1 -Firefox`

   The Firefox extension ID is fixed in the manifest
   (`browser_specific_settings.gecko.id`), so no ID argument is
   needed.

Both install scripts require Python 3 on your `PATH`, and can be run
together (`./install.sh --chrome <id> --firefox`) if you use both
browsers.

### Loading from source instead

If you'd rather not install the packaged version, everything above
also works by loading it from source. `extension/` holds one manifest
per browser (`manifest.json` for Firefox, `manifest.chromium.json`
for Chrome), so first build a separate copy for each:

```bash
./build.sh   # creates dist/chromium/ and dist/firefox/
```

- **Chrome**: `chrome://extensions` → enable Developer Mode → **Load
  unpacked** → select `dist/chromium/`.
- **Firefox**: `about:debugging#/runtime/this-firefox` → **Load
  Temporary Add-on** → select `dist/firefox/manifest.json`. Note this
  unloads on every Firefox restart, since it isn't signed.

Re-run `./build.sh` after changing anything in `extension/`, then
reload the extension.

The install steps for the native helper are the same either way.

### Verify

Open the extension's popup in whichever browser you set up. It should
say **"Helper connected."** If it says setup is required, double
check the IDs line up between the extension and the install command.

## Using it

Start your Learner Lab as normal. Once it's ready, click **AWS
Details → Show** next to the CLI credentials, same as you always do.
The extension picks them up from there automatically — no copy/paste,
no terminal command, every session.

## Uninstalling

- Remove the extension from your browser (`chrome://extensions` or
  `about:debugging` → Remove, for Firefox temporary add-ons it's
  enough to just restart the browser).
- Delete `~/.lab-credential-sync/` (the helper script).
- Delete the native messaging manifest:
  - Chromium-based, macOS: `com.lab_credential_sync.host.json` in the `NativeMessagingHosts` folder under `~/Library/Application Support/` → `Google/Chrome`, `Chromium`, `BraveSoftware/Brave-Browser` or `Microsoft Edge`.
  - Chromium-based, Linux: the same file under `~/.config/` → `google-chrome`, `chromium`, `BraveSoftware/Brave-Browser` or `microsoft-edge`, each in `NativeMessagingHosts/`.
  - Chromium-based, Windows: delete the `NativeMessagingHosts\com.lab_credential_sync.host` registry key under each of `HKCU:\Software\Google\Chrome`, `HKCU:\Software\Chromium`, `HKCU:\Software\BraveSoftware\Brave-Browser` and `HKCU:\Software\Microsoft\Edge`.
  - Firefox, macOS: `~/Library/Application Support/Mozilla/NativeMessagingHosts/com.lab_credential_sync.host.json`
  - Firefox, Linux: `~/.mozilla/native-messaging-hosts/com.lab_credential_sync.host.json`
  - Firefox, Windows: delete the `HKCU:\Software\Mozilla\NativeMessagingHosts\com.lab_credential_sync.host` registry key.

## Packaging for the stores (maintainers)

```bash
./package.sh
```

Builds `dist/lab-credential-sync-chromium-<version>.zip` (Chrome Web
Store upload, with the manifest's development `key` removed) and
`dist/lab-credential-sync-firefox-<version>.zip` (AMO, linted with
`web-ext`). With `WEB_EXT_API_KEY` and `WEB_EXT_API_SECRET` set to
your [AMO API credentials](https://addons.mozilla.org/developers/addon/api/key/),
it also signs the Firefox build as unlisted and saves the signed
`.xpi` to `dist/` for a GitHub Release. Bump `"version"` in both
manifests before each release; the script refuses to run if they
differ.

## Scope and limitations

- Only runs on `vocareum.com` pages.
- Only reads credentials already visible on the page — never
  interacts with AWS Details or Show on your behalf.
- Only ever writes to `~/.aws/credentials` and its backups
  (`credentials.previous`, `credentials.backup-*`), nothing else.
- Published as **unlisted** on the Chrome Web Store and (optionally)
  AMO — reviewed and signed, but not searchable; install links are
  only shared here and in the linked assignment.
- Source is fully available in `extension/` and `host/` regardless of
  how you install it — read it before running the helper install
  script, which is the part that touches your filesystem.
- Built for AWS Academy Learner Lab's temporary credential flow
  specifically — not a general AWS credential manager.
