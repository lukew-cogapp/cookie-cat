#!/usr/bin/env python3
"""Push the Play store listing from `store/` through the Publishing API.

The copy is parsed out of `play-listing.md` rather than repeated here, so the
file a human edits is the file Play receives.

Needs the service account to hold Store presence as well as Release to testing
tracks; with only the latter the edit commits and the listing is unchanged.
"""

import json
import re
import subprocess
import sys
import urllib.parse
import urllib.request
from pathlib import Path

PACKAGE = "io.github.lukehmu.catvsbugs"
LANGUAGE = "en-GB"
OP_ACCOUNT = "XUBOVEPXVBFVNDMVLNWZO3Y3RU"
OP_ITEM = "Cat vs Bugs - Play publisher service account"

ROOT = Path(__file__).resolve().parents[2]
STORE = ROOT / "store"

API = "https://androidpublisher.googleapis.com/androidpublisher/v3"
UPLOAD = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"

# Play's own limits. Exceeding one is a 400 naming the field but not the size.
LIMITS = {"title": 30, "shortDescription": 80, "fullDescription": 4000}


def _say(msg: str) -> None:
    print(msg, flush=True)


def read_key() -> dict:
    """The key lives in 1Password and is never written to disk."""
    out = subprocess.run(
        ["op", "read", f"op://Personal/{OP_ITEM}/key", "--account", OP_ACCOUNT],
        capture_output=True,
        text=True,
    )
    if out.returncode != 0:
        sys.exit(f"1Password read failed: {out.stderr.strip()}")
    return json.loads(out.stdout)


def access_token(key: dict) -> str:
    """Service account JWT flow, hand-rolled to keep this dependency-free."""
    import time

    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import padding

    def b64(raw: bytes) -> bytes:
        import base64

        return base64.urlsafe_b64encode(raw).rstrip(b"=")

    now = int(time.time())
    header = b64(json.dumps({"alg": "RS256", "typ": "JWT"}).encode())
    claims = b64(
        json.dumps(
            {
                "iss": key["client_email"],
                "scope": SCOPE,
                "aud": "https://oauth2.googleapis.com/token",
                "iat": now,
                "exp": now + 3600,
            }
        ).encode()
    )
    signing_input = header + b"." + claims
    private = serialization.load_pem_private_key(key["private_key"].encode(), password=None)
    signature = b64(private.sign(signing_input, padding.PKCS1v15(), hashes.SHA256()))

    body = urllib.parse.urlencode(
        {
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": (signing_input + b"." + signature).decode(),
        }
    ).encode()
    req = urllib.request.Request("https://oauth2.googleapis.com/token", data=body)
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)["access_token"]


def call(token: str, method: str, url: str, body=None, content_type=None):
    headers = {"Authorization": f"Bearer {token}"}
    data = None
    if body is not None:
        if content_type:
            headers["Content-Type"] = content_type
            data = body
        else:
            headers["Content-Type"] = "application/json"
            data = json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as err:
        sys.exit(f"{method} {url} failed {err.code}: {err.read().decode()[:600]}")


def parse_listing(path: Path) -> dict:
    """Take the first fenced block under each heading the listing needs."""
    text = path.read_text()
    wanted = {
        "title": r"## Title",
        "shortDescription": r"## Short description",
        "fullDescription": r"## Full description",
    }
    out = {}
    for field, heading in wanted.items():
        match = re.search(heading + r".*?```\n(.*?)```", text, re.S)
        if not match:
            sys.exit(f"no fenced block under {heading} in {path.name}")
        value = match.group(1).strip()
        if len(value) > LIMITS[field]:
            sys.exit(f"{field} is {len(value)} chars, limit {LIMITS[field]}")
        out[field] = value
    return out


def main() -> None:
    dry_run = "--dry-run" in sys.argv

    listing = parse_listing(STORE / "play-listing.md")
    shots = sorted((STORE / "screenshots").glob("*.png"))
    _say(f"Listing parsed: title {len(listing['title'])} chars, {len(shots)} screenshots")
    if dry_run:
        for field, value in listing.items():
            _say(f"\n--- {field} ({len(value)} chars) ---\n{value}")
        _say("\nDry run, nothing sent.")
        return

    _say("Reading the service account key from 1Password")
    token = access_token(read_key())

    _say("Opening an edit")
    edit = call(token, "POST", f"{API}/applications/{PACKAGE}/edits")["id"]
    base = f"{API}/applications/{PACKAGE}/edits/{edit}"

    _say(f"Writing the {LANGUAGE} listing")
    call(token, "PUT", f"{base}/listings/{LANGUAGE}", {"language": LANGUAGE, **listing})

    # Images are replaced rather than added: uploading without deleting first
    # appends, and a second run would leave two of everything.
    uploads = [("phoneScreenshots", shots), ("icon", [STORE / "icon_512.png"])]
    uploads.append(("featureGraphic", [STORE / "feature.png"]))
    for kind, files in uploads:
        upload_base = f"{UPLOAD}/applications/{PACKAGE}/edits/{edit}/listings/{LANGUAGE}/{kind}"
        call(token, "DELETE", f"{base}/listings/{LANGUAGE}/{kind}")
        for path in files:
            _say(f"Uploading {kind}: {path.name}")
            call(token, "POST", f"{upload_base}?uploadType=media", path.read_bytes(), "image/png")

    _say("Committing the edit")
    call(token, "POST", f"{base}:commit")
    _say("Listing updated.")


if __name__ == "__main__":
    main()
