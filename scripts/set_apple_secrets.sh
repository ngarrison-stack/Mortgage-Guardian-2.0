#!/usr/bin/env bash
set -euo pipefail

echo "This script sets APPLE_KEY_ID, APPLE_ISSUER_ID, and APPLE_KEY_CONTENT in your GitHub repo using the GitHub CLI (gh)."

# Defaults
DEFAULT_REPO="ngarrison-stack/Mortgage-Guadian-2.0"
DEFAULT_P8="~/Downloads/AuthKey_M78936QK5N.p8"

# Check for gh
if ! command -v gh >/dev/null 2>&1; then
  echo "gh (GitHub CLI) is required. Install it first: https://cli.github.com/"
  exit 1
fi

read -r -p "Path to .p8 file [${DEFAULT_P8}]: " P8_PATH
P8_PATH=${P8_PATH:-$DEFAULT_P8}
P8_PATH=$(eval echo "$P8_PATH")

if [ ! -f "$P8_PATH" ]; then
  echo "File not found: $P8_PATH"
  exit 1
fi

read -r -p "Target repo (owner/repo) [${DEFAULT_REPO}]: " REPO
REPO=${REPO:-$DEFAULT_REPO}

read -r -p "APPLE_ISSUER_ID (from App Store Connect) : " APPLE_ISSUER_ID
if [ -z "$APPLE_ISSUER_ID" ]; then
  echo "APPLE_ISSUER_ID is required."
  exit 1
fi

# Try to infer Key ID from filename: AuthKey_<KEYID>.p8
KEY_FILENAME=$(basename "$P8_PATH")
if [[ "$KEY_FILENAME" =~ AuthKey_([A-Za-z0-9]+)\.p8 ]]; then
  APPLE_KEY_ID=${BASH_REMATCH[1]}
else
  read -r -p "Could not infer Key ID from filename. Enter APPLE_KEY_ID: " APPLE_KEY_ID
fi

echo "Setting secrets for repo: $REPO"

echo "- Setting APPLE_KEY_ID = $APPLE_KEY_ID"
gh secret set APPLE_KEY_ID --body "$APPLE_KEY_ID" --repo "$REPO"

echo "- Setting APPLE_ISSUER_ID"
gh secret set APPLE_ISSUER_ID --body "$APPLE_ISSUER_ID" --repo "$REPO"

echo "- Setting APPLE_KEY_CONTENT from $P8_PATH"
# Use cat to preserve newlines
gh secret set APPLE_KEY_CONTENT --body "$(cat "$P8_PATH")" --repo "$REPO"

echo "All done. Verify with: gh secret list --repo $REPO"

echo "Security note: keep the .p8 file private. Rotate the key if you ever commit it to source control by mistake."
