# Store listing text

Copy-paste text for the Chrome Web Store developer dashboard. Keep it
in sync with what the code actually does.

## Package

Upload `dist/lab-credential-sync-chromium-<version>.zip` from
`./package.sh`.

## Store listing tab

**Name** (from the manifest): Lab Credential Sync

**Summary** (from the manifest, max 132 chars):
Unofficial companion for AWS Academy Learner Lab: syncs the CLI credentials you reveal to ~/.aws/credentials via a local helper.

**Description:**

```
Unofficial. Not affiliated with, endorsed by, or supported by Amazon Web Services, AWS Academy, or Vocareum.

AWS Academy Learner Lab gives you temporary AWS CLI credentials that expire every few hours, so you end up copying them into ~/.aws/credentials over and over. Lab Credential Sync does that step for you.

How it works:
• Start your Learner Lab and click AWS Details → Show, as usual.
• Once the credentials are visible, the extension reads them and passes them to a small helper script running on your own computer.
• The helper writes them to ~/.aws/credentials (readable only by your user account), keeping a backup of any file it didn't write itself.

What it doesn't do:
• It never clicks Show for you — it only reads credentials you've revealed yourself.
• It only runs on vocareum.com pages.
• It sends nothing over the network. No server, no analytics, no telemetry.

Setup needs a one-time install of the helper script (Python 3, macOS / Linux / Windows). Instructions and the full source code:
https://github.com/s3731804/lab-credential-sync
```

**Category:** Developer Tools

**Language:** English

**Store icon:** `extension/icons/icon-128.png`

**Screenshots:** at least one is required, 1280×800 or 640×400. A
screenshot of the popup showing "Helper connected", placed on a plain
background at 1280×800, is enough.

## Privacy practices tab

**Single purpose:**

```
Copies the AWS Academy Learner Lab CLI credentials that the user has revealed on the Vocareum lab page into the user's local ~/.aws/credentials file, via a native helper the user installs.
```

**Permission justifications:**

`nativeMessaging`:
```
Sends the revealed lab credentials to a helper script the user installs on their own computer, which writes them to ~/.aws/credentials. Browsers can't write that file directly, and this avoids routing credentials through the Downloads folder. The helper is open source in the same repository.
```

`storage`:
```
Stores only whether the last sync succeeded and when it happened, so the popup can show it. Credentials are never stored by the extension.
```

Host permission (content script on `https://*.vocareum.com/*`):
```
AWS Academy Learner Lab runs on vocareum.com, and the credentials are shown in the lab page there. The content script only checks whether the credentials box is visible and reads it after the user clicks Show. It runs on no other sites.
```

**Are you using remote code?** No, I am not using remote code.

**Data usage — what user data do you collect?**
Tick **Authentication information**. It's handled entirely on the
user's device and never transmitted. Disclosing it anyway is the
conservative choice, and it matches the privacy policy.

Then certify all three:
- I do not sell or transfer user data to third parties, outside of the approved use cases
- I do not use or transfer user data for purposes that are unrelated to my item's single purpose
- I do not use or transfer user data to determine creditworthiness or for lending purposes

**Privacy policy URL:**
https://github.com/s3731804/lab-credential-sync/blob/main/PRIVACY.md

## Distribution tab

**Visibility:** Unlisted

## Firefox (AMO)

Unlisted add-ons signed with `web-ext sign --channel unlisted` (via
`./package.sh`) don't get a public listing page, so none of the above
is needed there. If AMO asks for a summary, reuse the one above.
