#!/bin/bash
# Copies the Android upload key out of 1Password into the repository's GitHub
# configuration, which is what .github/workflows/android.yml reads.
#
# Nothing is written to disk and no value is printed: each one is piped from
# `op` straight into `gh`, so it never reaches the terminal or the shell
# history. Run once, and again only if the key is rotated.
#
# PLAY_SERVICE_ACCOUNT_JSON, the fourth one the workflow wants, comes from the
# Google Cloud console rather than from here.

set -euo pipefail

ACCOUNT="XUBOVEPXVBFVNDMVLNWZO3Y3RU"
ITEM="op://Personal/Cat vs Bugs - Android upload key"
REPO="lukew-cogapp/cookie-cat"

for tool in op gh base64; do
    command -v "$tool" > /dev/null || { echo "$tool is not installed." >&2; exit 1; }
done

op account get --account "$ACCOUNT" > /dev/null || {
    echo "1Password is locked. Run: eval \$(op signin --account $ACCOUNT)" >&2
    exit 1
}

# The keystore is an attachment, so it arrives as bytes and has to be base64'd:
# GitHub stores text.
echo "ANDROID_KEYSTORE_BASE64"
op read "$ITEM/keystore" --account "$ACCOUNT" \
    | base64 \
    | gh secret set ANDROID_KEYSTORE_BASE64 --repo "$REPO"

# `op read` ends its output with a newline. Left in, it becomes part of the
# password, and the export then fails in CI reporting a wrong password for a
# password that is right.
for pair in "ANDROID_KEYSTORE_ALIAS:alias" "ANDROID_KEYSTORE_PASSWORD:password"; do
    name="${pair%%:*}"
    field="${pair##*:}"
    echo "$name"
    op read "$ITEM/$field" --account "$ACCOUNT" \
        | tr -d '\n' \
        | gh secret set "$name" --repo "$REPO"
done

echo
echo "Now set in the repository:"
gh secret list --repo "$REPO"
