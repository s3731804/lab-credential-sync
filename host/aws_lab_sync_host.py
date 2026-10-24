#!/usr/bin/env python3
"""
AWS Learner Lab Sync — native messaging host.

Reads a single JSON message from the extension over stdin (Chrome's
native messaging framing: 4-byte little-endian length + UTF-8 JSON),
and if it's a validated AWS Learner Lab credential block, writes it to
~/.aws/credentials with 0600 permissions. Responds with a JSON status
over stdout using the same framing.

This script does nothing else: it does not read arbitrary files, does
not make network requests, and only ever writes to ~/.aws/credentials.
Read it end to end before you install it — that's the point of
distributing it as source rather than a binary.
"""
import sys
import json
import struct
import os
import stat
import time


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


def is_valid_credentials(text):
    return (
        "aws_access_key_id" in text
        and "aws_secret_access_key" in text
        and "aws_session_token" in text
    )


def write_credentials(creds_text):
    if not is_valid_credentials(creds_text):
        raise ValueError("Credential block missing required fields.")

    aws_dir = os.path.expanduser("~/.aws")
    os.makedirs(aws_dir, exist_ok=True, mode=0o700)
    cred_path = os.path.join(aws_dir, "credentials")

    if os.path.exists(cred_path) or os.path.islink(cred_path):
        backup = f"{cred_path}.backup-{int(time.time())}"
        os.rename(cred_path, backup)

    with open(cred_path, "w") as f:
        f.write(creds_text + "\n")

    os.chmod(cred_path, stat.S_IRUSR | stat.S_IWUSR)  # 0600


def main():
    msg = read_message()
    msg_type = msg.get("type")

    if msg_type == "PING":
        send_message({"status": "ok"})
        return

    if msg_type == "NEW_CREDENTIALS":
        try:
            write_credentials(msg.get("data", ""))
            send_message({"status": "ok"})
        except Exception as e:
            send_message({"status": "error", "message": str(e)})
        return

    send_message({"status": "error", "message": f"Unknown message type: {msg_type}"})


if __name__ == "__main__":
    main()
