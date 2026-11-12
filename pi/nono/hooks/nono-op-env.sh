#!/bin/bash
# Runs OUTSIDE the nono sandbox with host privileges before the child starts.
# Loads every field from a single 1Password item (each field labeled to match
# the environment variable it should populate) and exports them into the
# sandboxed child's environment via NONO_ENV_FILE.
#
# Item: op://Employee/nono-pi-dev
# Add/rename fields in that item to add/rename env vars picked up here
# (currently GH_TOKEN, LITELLM_API_KEY, LITELLM_BASE_URL). The "notesPlain"
# field (1Password's default notes field) and username/password are always
# skipped.
set -euo pipefail

OP_ACCOUNT="${OP_ACCOUNT:-graderainc.1password.com}"
OP_ITEM="${OP_ITEM:-nono-pi-dev}"
OP_VAULT="${OP_VAULT:-Employee}"

if ! command -v op >/dev/null 2>&1; then
  exit 0
fi

if [ -z "${NONO_ENV_FILE:-}" ]; then
  exit 0
fi

JSON="$(op item get "$OP_ITEM" --vault "$OP_VAULT" --account "$OP_ACCOUNT" --format json 2>/dev/null || true)"
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
