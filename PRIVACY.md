# Privacy Policy — Lab Credential Sync

_Last updated: 24 October 2026_

Lab Credential Sync is an unofficial browser extension and local
helper script for AWS Academy Learner Lab. This policy covers both.

## The short version

Nothing is collected, and nothing leaves your computer. There is no
server, no analytics, no telemetry, and no network request of any kind
in the extension or the helper.

## What the extension reads

On pages under `vocareum.com` only, the extension checks whether the
AWS CLI credentials box is visible. Once **you** reveal it by clicking
**Show**, it reads that block of text: an AWS access key ID, secret
access key and session token. These are the temporary credentials
for your Learner Lab sandbox. The extension never clicks Show for you
and reads nothing else from the page.

## What happens to it

The credentials are passed from the extension to the helper script
running on your own computer, using the browser's native messaging
feature. This is a direct local connection between your browser and
a program you installed; it does not go over the internet.

The helper writes them to `~/.aws/credentials` on your computer, with
permissions that only your user account can read. It keeps a copy of
the previous file as a backup on your computer (see the README for
exactly how).

## What the extension stores

In the browser's local extension storage, it keeps only whether the
last sync succeeded and when it happened, so the popup can show you
that. It does not store the credentials themselves.

## What is shared

Nothing. No data is sold, shared with, or sent to the developer or any
third party, and none is used for advertising, profiling,
creditworthiness, or any purpose other than writing your credentials
file.

## Removing it

Uninstalling the extension deletes its local storage. To remove
everything the helper wrote, follow the uninstall steps in the
[README](README.md#uninstalling). Your `~/.aws/credentials` file and
its backups are ordinary files on your computer that you can delete
at any time.

## Verifying this

The full source of the extension and helper is in this repository.
It is short enough to read in a few minutes, and the code installed
from the stores is built from it unchanged.

## Contact

Questions or concerns: open an issue at
<https://github.com/s3731804/lab-credential-sync/issues>.
