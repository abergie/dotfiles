#!/bin/bash
# Runs OUTSIDE the nono sandbox with host privileges before the child starts.
# Loads every field from a single 1Password item (each field labeled to match
# the environment variable it should populate) and exports them into the
# sandboxed child's environment via NONO_ENV_FILE.
#
# Default item: op://Employee/nono-pi-dev (override via OP_ACCOUNT, OP_VAULT, OP_ITEM).
# The "notesPlain" field and username/password are always skipped.
set -euo pipefail

OP_ITEM="${OP_ITEM:-nono-pi-dev}"
OP_VAULT="${OP_VAULT:-Employee}"

if ! command -v op >/dev/null 2>&1; then
  exit 0
fi

if [ -z "${NONO_ENV_FILE:-}" ]; then
  exit 0
fi

fetch_item_json() {
  local acct="${1:-}"
  if [ -n "$acct" ]; then
    op item get "$OP_ITEM" --vault "$OP_VAULT" --account "$acct" --format json 2>/dev/null || true
  else
    op item get "$OP_ITEM" --vault "$OP_VAULT" --format json 2>/dev/null || true
  fi
}

JSON=""
if [ -n "${OP_ACCOUNT:-}" ]; then
  JSON="$(fetch_item_json "$OP_ACCOUNT")"
else
  JSON="$(fetch_item_json "")"
  if [ -z "$JSON" ]; then
    ACCOUNTS="$(op account list --format json 2>/dev/null | python3 -c '
import json, sys
try:
    for a in json.load(sys.stdin):
        acct = a.get("account_uuid") or a.get("url") or ""
        if acct:
            print(acct)
except Exception:
    pass
' || true)"
    while IFS= read -r acct; do
      [ -n "$acct" ] || continue
      JSON="$(fetch_item_json "$acct")"
      [ -n "$JSON" ] && break
    done <<< "$ACCOUNTS"
  fi
fi

if [ -z "$JSON" ]; then
  exit 0
fi

echo "$JSON" | python3 -c '
import json, sys

data = json.load(sys.stdin)
skip = {"notesPlain", "password", "username"}
lines = []
for field in data.get("fields", []):
    label = field.get("label", "")
    value = field.get("value")
    if not label or label in skip or value is None:
        continue
    if value.startswith("REPLACE_ME"):
        continue
    if "\n" in value or "\x00" in value:
        continue
    lines.append(f"{label}={value}")
print("\n".join(lines))
' >> "$NONO_ENV_FILE"
