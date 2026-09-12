#!/usr/bin/env python3
import os
import time
import urllib.error
import urllib.request
from email import policy
from email.header import Header
from email.parser import BytesHeaderParser
from email.utils import getaddresses, parseaddr
from pathlib import Path

MAIL_ROOT = Path("/mail")
NTFY_URL = "http://100.64.0.1:2586/email"
POLL_SECONDS = 5.0
HTTP_TIMEOUT_SECONDS = 15.0
QUEENS_ADDRESS = "{{ homelab.priv_queens_email }}"

def log(message):
    print(time.strftime("%Y-%m-%dT%H:%M:%S%z"), message, flush=True)

def clean_header(value, fallback):
    if value is None:
        return fallback
    cleaned = " ".join(str(value).split())
    return cleaned[:500] or fallback

def sender_name(value):
    name, address = parseaddr(str(value or ""))
    if name:
        return clean_header(name, "Unknown sender")[:200]
    if address:
        return clean_header(address.partition("@")[0], "Unknown sender")[:200]
    return "Unknown sender"

def account_label(path, headers):
    recipients = getaddresses(str(value) for value in headers.get_all("To", []))
    if any(address.casefold() == QUEENS_ADDRESS for _, address in recipients):
        return "queens"
    if path.parents[2].name == "icloud":
        return "icloud"
    return "gmail"

def message_details(path):
    with path.open("rb") as mail:
        headers = BytesHeaderParser(policy=policy.default).parse(mail, headersonly=True)
    return (
        account_label(path, headers),
        sender_name(headers.get("From")),
        clean_header(headers.get("Subject"), "(no subject)"),
    )

def publish(account, sender, subject):
    title = f"{sender} ({account})"
    try:
        title.encode("ascii")
    except UnicodeEncodeError:
        title = Header(title, "utf-8", maxlinelen=998).encode(linesep="")

    request = urllib.request.Request(
        NTFY_URL,
        data=subject.encode("utf-8"),
        headers={
            "Content-Type": "text/plain; charset=utf-8",
            "Title": title,
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=HTTP_TIMEOUT_SECONDS) as response:
        if not 200 <= response.status < 300:
            raise RuntimeError(f"ntfy returned HTTP {response.status}")

def seen_name(name):
    if ":2," not in name:
        return f"{name}:2,S"
    base, flags = name.rsplit(":2,", 1)
    return f"{base}:2,{''.join(sorted(set(flags + 'S')))}"

def mark_seen(path):
    destination = path.parent.parent / "cur" / seen_name(path.name)
    path.replace(destination)

def new_messages():
    messages = []
    for new_dir in MAIL_ROOT.glob("*/INBOX/new"):
        try:
            messages.extend(path for path in new_dir.iterdir() if path.is_file())
        except FileNotFoundError:
            continue
    return sorted(messages, key=lambda path: (path.stat().st_mtime_ns, str(path)))

notified = set()
while True:
    try:
        messages = new_messages()
    except OSError as error:
        log(f"cannot scan Maildir: {error}")
        time.sleep(POLL_SECONDS)
        continue

    current_paths = {str(path) for path in messages}
    notified.intersection_update(current_paths)

    for path in messages:
        path_key = str(path)
        try:
            if path_key not in notified:
                account, sender, subject = message_details(path)
                publish(account, sender, subject)
                notified.add(path_key)
                log(f"notified for {account}: {subject}")

            mark_seen(path)
            notified.discard(path_key)
            log(f"marked read: {path}")
        except FileNotFoundError:
            notified.discard(path_key)
        except (OSError, ValueError, RuntimeError, urllib.error.URLError) as error:
            log(f"will retry {path}: {error}")

    time.sleep(POLL_SECONDS)
