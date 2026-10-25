#!/usr/bin/env python3
"""
Lab Credential Sync — native messaging host.

Reads a single JSON message from the extension over stdin (Chrome's
native messaging framing: 4-byte little-endian length + UTF-8 JSON),
and if it's a validated AWS Learner Lab credential block, writes it to
~/.aws/credentials with 0600 permissions. Responds with a JSON status
over stdout using the same framing.

The file it writes starts with a marker comment. On each sync:
  - if the existing file has the marker, this script wrote it, so it
    only holds (expired) lab credentials: it's kept as
    credentials.previous, replacing any older one;
  - if it doesn't, it's yours — real keys, other profiles, anything —
    so it's moved to a timestamped credentials.backup-<time> that this
    script never deletes.

When sync is switched off in the extension, it undoes this: if
~/.aws/credentials still has the marker, the newest
credentials.backup-<time> is moved back into place (or, with no
backup, the file is deleted, since there was none before), and
credentials.previous is deleted. A file without the marker is never
touched. The uninstall command (install.sh --uninstall) does the same
by running this script with --restore.

This script does nothing else: it does not make network requests, only
reads ~/.aws/credentials (to check for the marker), and only writes
~/.aws/credentials and those backups. Read it end to end before you
install it — that's the point of distributing it as source rather
than a binary.
"""
import sys
import json
import struct
import os
import re
import time
import glob

# Reported to the extension's popup, so it can tell you when the
# helper is older than the extension and needs reinstalling.
VERSION = "2.1"

MARKER = "# managed by lab-credential-sync - overwritten on each sync"

# Exactly what a Learner Lab "AWS CLI" block contains. Anything else is
# rejected rather than passed through, so a page can't slip extra
# settings (e.g. credential_process, which the AWS CLI executes) into
# your credentials file.
PROFILE_RE = re.compile(r"^\[([A-Za-z0-9_.-]+)\]$")
KEY_PATTERNS = {
    "aws_access_key_id": re.compile(r"^(ASIA|AKIA)[A-Z0-9]{16}$"),
    "aws_secret_access_key": re.compile(r"^[A-Za-z0-9/+=]{40}$"),
    "aws_session_token": re.compile(r"^[A-Za-z0-9/+=]{100,}$"),
}


def read_message():
    raw_length = sys.stdin.buffer.read(4)
    if len(raw_length) == 0:
        sys.exit(0)
    length = struct.unpack("=I", raw_length)[0]
    message = sys.stdin.buffer.read(length).decode("utf-8")
    return json.loads(message)


def send_message(message_dict):
    encoded = json.dumps(message_dict).encode("utf-8")
    sys.stdout.buffer.write(struct.pack("=I", len(encoded)))
    sys.stdout.buffer.write(encoded)
    sys.stdout.buffer.flush()


def parse_credentials(text):
    """Return (profile, {key: value}) or raise ValueError."""
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    if not lines:
        raise ValueError("Empty credential block.")

    header = PROFILE_RE.match(lines[0])
    if not header:
        raise ValueError("Credential block must start with a [profile] header.")

    values = {}
    for line in lines[1:]:
        key, sep, value = line.partition("=")
        key, value = key.strip(), value.strip()
        if not sep or key not in KEY_PATTERNS or key in values:
            raise ValueError(f"Unexpected line in credential block: {key!r}")
        if not KEY_PATTERNS[key].match(value):
            raise ValueError(f"Malformed value for {key}.")
        values[key] = value

    missing = set(KEY_PATTERNS) - set(values)
    if missing:
        raise ValueError(f"Credential block missing: {', '.join(sorted(missing))}")

    return header.group(1), values


def is_ours(path):
    try:
        with open(path, encoding="utf-8") as f:
            return f.readline().strip() == MARKER
    except (OSError, UnicodeDecodeError):
        return False


def credentials_path():
    return os.path.join(os.path.expanduser("~/.aws"), "credentials")


def restore_backup():
    """Put back the file this script displaced, if it's still in charge.

    Returns "restored", "removed" (nothing to restore, so the lab file
    was deleted), "not_ours" (the file isn't one this script wrote, so
    it's left alone) or "nothing" (no file at all).
    """
    cred_path = credentials_path()
    previous = cred_path + ".previous"

    if os.path.exists(cred_path) or os.path.islink(cred_path):
        if not is_ours(cred_path):
            return "not_ours"
    elif not os.path.exists(previous):
        return "nothing"

    backups = []
    for path in glob.glob(glob.escape(cred_path) + ".backup-*"):
        stamp = path.rsplit("-", 1)[1]
        if stamp.isdigit():
            backups.append((int(stamp), path))

    if backups:
        os.replace(max(backups)[1], cred_path)
        result = "restored"
    else:
        if os.path.exists(cred_path) or os.path.islink(cred_path):
            os.remove(cred_path)
        result = "removed"

    if os.path.exists(previous):
        os.remove(previous)
    return result


RESTORE_MESSAGES = {
    "restored": "Put back your previous ~/.aws/credentials.",
    "removed": "Removed the lab credentials (you had no ~/.aws/credentials before).",
    "not_ours": "Left ~/.aws/credentials alone: it wasn't written by Lab Credential Sync.",
    "nothing": "No ~/.aws/credentials to restore.",
}


def write_credentials(creds_text):
    profile, values = parse_credentials(creds_text)

    cred_path = credentials_path()
    aws_dir = os.path.dirname(cred_path)
    os.makedirs(aws_dir, exist_ok=True, mode=0o700)
    tmp_path = os.path.join(aws_dir, f".credentials.lab-credential-sync-{os.getpid()}")

    content = "\n".join(
        [MARKER, f"[{profile}]"] + [f"{k}={values[k]}" for k in KEY_PATTERNS]
    ) + "\n"

    # Created 0600 from the start, so the file is never briefly readable
    # by other users the way write-then-chmod would leave it.
    fd = os.open(tmp_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(content)
            f.flush()
            os.fsync(f.fileno())

        if os.path.exists(cred_path) or os.path.islink(cred_path):
            if is_ours(cred_path):
                os.replace(cred_path, cred_path + ".previous")
            else:
                os.rename(cred_path, f"{cred_path}.backup-{int(time.time())}")

        os.replace(tmp_path, cred_path)
    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)


def main():
    msg = read_message()
    msg_type = msg.get("type")

    if msg_type == "PING":
        send_message({"status": "ok", "version": VERSION})
        return

    if msg_type == "NEW_CREDENTIALS":
        try:
            write_credentials(msg.get("data", ""))
            send_message({"status": "ok"})
        except Exception as e:
            send_message({"status": "error", "message": str(e)})
        return

    if msg_type == "RESTORE":
        try:
            send_message({"status": "ok", "result": restore_backup()})
        except Exception as e:
            send_message({"status": "error", "message": str(e)})
        return

    send_message({"status": "error", "message": f"Unknown message type: {msg_type}"})


if __name__ == "__main__":
    # Browsers pass their own arguments (the extension's origin), so
    # only this exact one means it was run by hand or by the uninstaller.
    if sys.argv[1:] == ["--restore"]:
        print(RESTORE_MESSAGES[restore_backup()])
    else:
        main()
