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

## Quick install

Needs Python 3. Worth a skim of [what it actually does](#what-it-actually-does-read-this-before-installing)
first, since step 2 installs a small program on your computer.

### Firefox

1. **[Add to Firefox](https://github.com/s3731804/lab-credential-sync/releases/latest/download/lab-credential-sync.xpi)**:
   Firefox asks to confirm; click **Continue to installation**, then
   **Add**. (Signed by Mozilla.)
2. **Install the helper**, by pasting one line into a terminal:

   macOS / Linux:
   ```bash
   curl -fsSL https://github.com/s3731804/lab-credential-sync/releases/latest/download/install.sh | bash -s -- --firefox
   ```
   Windows (PowerShell):
   ```powershell
   iwr -useb https://github.com/s3731804/lab-credential-sync/releases/latest/download/install.ps1 -OutFile $env:TEMP\lcs-install.ps1; powershell -ExecutionPolicy Bypass -File $env:TEMP\lcs-install.ps1 -Firefox
   ```
3. Click the key icon in the toolbar. It should say **Helper
   connected**. Switch **Sync credentials** on, then just start your
   lab and click **Show** as usual.

### Chrome / Chromium / Brave / Edge

1. **[Add to Chrome](https://chromewebstore.google.com/detail/lab-credential-sync/edgfieafnmggobcecofedjoigfchflom)** from the Chrome Web Store (also works
   in Brave and Edge).
2. **Install the helper**, by pasting one line into a terminal:

   macOS / Linux:
   ```bash
   curl -fsSL https://github.com/s3731804/lab-credential-sync/releases/latest/download/install.sh | bash -s -- --chrome edgfieafnmggobcecofedjoigfchflom
   ```
   Windows (PowerShell):
   ```powershell
   iwr -useb https://github.com/s3731804/lab-credential-sync/releases/latest/download/install.ps1 -OutFile $env:TEMP\lcs-install.ps1; powershell -ExecutionPolicy Bypass -File $env:TEMP\lcs-install.ps1 -ChromeExtensionId edgfieafnmggobcecofedjoigfchflom
   ```
3. Click the key icon in the toolbar (pin it from the puzzle-piece
   menu first). It should say **Helper connected**. Switch **Sync
   credentials** on, then just start your lab and click **Show** as
   usual.

### Prefer to read the installer before running it?

Download [`install.sh`](https://github.com/s3731804/lab-credential-sync/releases/latest/download/install.sh)
(or [`install.ps1`](https://github.com/s3731804/lab-credential-sync/releases/latest/download/install.ps1)),
read it, then run `bash install.sh --firefox` (or `--chrome edgfieafnmggobcecofedjoigfchflom`). It fetches the helper
from the same release it came from. The step-by-step setup below
does the same thing from a clone of the repo.

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
`~/.aws/credentials.backup-<timestamp>` the first time. Files the
helper wrote itself only ever hold expired lab credentials, so those
are just kept as a single `credentials.previous` rather than piling
up.

**Switching sync off puts your file back.** The extension's popup has
a **Sync credentials** switch, off until you turn it on. Turning it off stops syncing, moves your
newest `credentials.backup-*` back into place as `~/.aws/credentials`,
and deletes the lab credentials it wrote (if you had no file before,
the lab one is just removed). It only does this while
`~/.aws/credentials` still has the marker, so a file you've put back or
edited yourself is left alone. Turning it back on syncs straight away
if your credentials are already showing on the lab page, no need to
hide and re-show them.

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

1. Install from the (unlisted) [Chrome Web Store](https://chromewebstore.google.com/detail/lab-credential-sync/edgfieafnmggobcecofedjoigfchflom).
2. Install the helper, with the store version's extension ID:
   ```bash
   cd host
   ./install.sh --chrome edgfieafnmggobcecofedjoigfchflom
   ```
   Windows: `.\install.ps1 -ChromeExtensionId "edgfieafnmggobcecofedjoigfchflom"`

   If you loaded the extension from source instead, use the ID shown
   on its card at `chrome://extensions`.

   This registers the helper with every Chromium-based browser it
   finds (Chrome, Chromium, Brave, Edge). On macOS/Linux a browser is
   only found once it's been opened at least once, so open a newly
   installed one first and re-run the script if needed.

### Firefox

1. Open **[lab-credential-sync.xpi](https://github.com/s3731804/lab-credential-sync/releases/latest/download/lab-credential-sync.xpi)**
   in Firefox (always the latest [release](../../releases)). It's
   signed by Mozilla, so Firefox offers to install it directly and it
   stays installed across restarts.
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

Switch **Sync credentials** on in the extension's popup (once; it
stays on). Start your Learner Lab as normal. Once it's ready, click **AWS
Details → Show** next to the CLI credentials, same as you always do.
The extension picks them up from there automatically — no copy/paste,
no terminal command, every session — and shows a brief "Credentials
saved" message in the corner of the page.

**Updating from 2.0?** Re-run the helper install command above once:
switching sync off needs the 2.1 helper. The popup tells you if your
helper is out of date.

## Uninstalling

Run the uninstall command first, then remove the extension from your
browser. (Removing the extension opens this page, since an extension
can't clean up after itself.)

macOS / Linux:
```bash
curl -fsSL https://github.com/s3731804/lab-credential-sync/releases/latest/download/install.sh | bash -s -- --uninstall
```
Windows (PowerShell):
```powershell
iwr -useb https://github.com/s3731804/lab-credential-sync/releases/latest/download/install.ps1 -OutFile $env:TEMP\lcs-install.ps1; powershell -ExecutionPolicy Bypass -File $env:TEMP\lcs-install.ps1 -Uninstall
```

This puts your previous `~/.aws/credentials` back (or removes the
lab one, if you had none), the same as switching sync off, then
deletes the helper (`~/.lab-credential-sync/`) and its browser
registrations. From a clone, it's `host/install.sh --uninstall` or
`host\install.ps1 -Uninstall`. Any older `credentials.backup-*` files
are left for you to delete.

<details>
<summary>Removing it by hand instead</summary>

- Switch sync off in the popup first, so your previous credentials
  file is put back.
- Remove the extension from your browser (`chrome://extensions` or
  `about:addons`).
- Delete `~/.lab-credential-sync/` (the helper script).
- Delete the native messaging manifest:
  - Chromium-based, macOS: `com.lab_credential_sync.host.json` in the `NativeMessagingHosts` folder under `~/Library/Application Support/` → `Google/Chrome`, `Chromium`, `BraveSoftware/Brave-Browser` or `Microsoft Edge`.
  - Chromium-based, Linux: the same file under `~/.config/` → `google-chrome`, `chromium`, `BraveSoftware/Brave-Browser` or `microsoft-edge`, each in `NativeMessagingHosts/`.
  - Chromium-based, Windows: delete the `NativeMessagingHosts\com.lab_credential_sync.host` registry key under each of `HKCU:\Software\Google\Chrome`, `HKCU:\Software\Chromium`, `HKCU:\Software\BraveSoftware\Brave-Browser` and `HKCU:\Software\Microsoft\Edge`.
  - Firefox, macOS: `~/Library/Application Support/Mozilla/NativeMessagingHosts/com.lab_credential_sync.host.json`
  - Firefox, Linux: `~/.mozilla/native-messaging-hosts/com.lab_credential_sync.host.json`
  - Firefox, Windows: delete the `HKCU:\Software\Mozilla\NativeMessagingHosts\com.lab_credential_sync.host` registry key.

</details>

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
  (`credentials.previous`, `credentials.backup-*`), nothing else, and
  only deletes files it wrote itself.
- Published as **unlisted** on the Chrome Web Store and (optionally)
  AMO — reviewed and signed, but not searchable; install links are
  only shared here and in the linked assignment.
- Source is fully available in `extension/` and `host/` regardless of
  how you install it — read it before running the helper install
  script, which is the part that touches your filesystem.
- Built for AWS Academy Learner Lab's temporary credential flow
  specifically — not a general AWS credential manager.
