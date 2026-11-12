#!/usr/bin/env bash
# Read a single field from 1Password without hardcoding an account domain.
# Honors OP_ACCOUNT, OP_VAULT (default: Employee), and OP_ITEM (default: nono-pi-dev).

set -euo pipefail

FIELD="${1:?field name required}"
OP_VAULT="${OP_VAULT:-Employee}"
OP_ITEM="${OP_ITEM:-nono-pi-dev}"
REF="op://${OP_VAULT}/${OP_ITEM}/${FIELD}"

if ! command -v op >/dev/null 2>&1; then
  exit 1
fi

try_read() {
  local acct="${1:-}" val=""
  if [ -n "$acct" ]; then
    val="$(op read --account "$acct" "$REF" 2>/dev/null || true)"
  else
    val="$(op read "$REF" 2>/dev/null || true)"
  fi
  val="${val#"\n"}"
  if [ -n "$val" ] && [[ "$val" != REPLACE_ME* ]]; then
    printf '%s\n' "$val"
    return 0
  fi
  return 1
}

if [ -n "${OP_ACCOUNT:-}" ]; then
  try_read "$OP_ACCOUNT"
  exit $?
fi

if try_read ""; then
  exit 0
fi

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

if [ -n "$ACCOUNTS" ]; then
  while IFS= read -r acct; do
    [ -n "$acct" ] || continue
    if try_read "$acct"; then
      exit 0
    fi
  done <<< "$ACCOUNTS"
fi

exit 1
