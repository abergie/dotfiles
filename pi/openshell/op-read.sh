#!/usr/bin/env bash
# Read configuration or secrets from a 1Password Environment (default: openshell-pi-dev)
# without hardcoding an account domain. Falls back to legacy vault item lookup
# (op://Employee/nono-pi-dev) only when using the default environment and the
# Environment lookup produces no result.
#
# Usage:
#   op-read.sh [--env <env-name-or-id>] [--no-reveal] <FIELD>
#   op-read.sh --list-unconcealed [--env <env-name-or-id>]

set -euo pipefail

DEFAULT_ENV="${PI_OP_ENV:-${OP_ENV:-openshell-pi-dev}}"
TARGET_ENV="$DEFAULT_ENV"
ENV_EXPLICIT=0
ALLOW_REVEAL=1
LIST_UNCONCEALED=0
FIELD=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --env|-e)
      [ "$#" -ge 2 ] || { echo "op-read.sh: --env requires a value" >&2; exit 2; }
      TARGET_ENV="$2"
      ENV_EXPLICIT=1
      shift 2
      ;;
    --no-reveal)
      ALLOW_REVEAL=0
      shift
      ;;
    --list-unconcealed)
      LIST_UNCONCEALED=1
      shift
      ;;
    *)
      FIELD="$1"
      shift
      ;;
  esac
done

if [ "$LIST_UNCONCEALED" -eq 0 ] && [ -z "$FIELD" ]; then
  echo "op-read.sh: field name or --list-unconcealed required" >&2
  exit 2
fi

if ! command -v op >/dev/null 2>&1; then
  exit 1
fi

list_accounts() {
  if [ -n "${OP_ACCOUNT:-}" ]; then
    printf '%s\n' "$OP_ACCOUNT"
    return 0
  fi
  printf '\n'
  op account list --format json 2>/dev/null | python3 -c '
import json, sys
try:
    for a in json.load(sys.stdin):
        acct = a.get("account_uuid") or a.get("url") or ""
        if acct:
            print(acct)
except Exception:
    pass
' || true
}

run_env_list() {
  local acct="$1" reveal_flag="$2"
  local args=(environment secret list "$TARGET_ENV" --format=json)
  if [ "$reveal_flag" = "1" ]; then
    args+=(--reveal)
  fi
  if [ -n "$acct" ]; then
    args+=(--account "$acct")
  fi
  op "${args[@]}" 2>/dev/null || true
}

if [ "$LIST_UNCONCEALED" -eq 1 ]; then
  while IFS= read -r acct; do
    RAW="$(run_env_list "$acct" "0")"
    [ -n "$RAW" ] || continue
    PARSED="$(printf '%s' "$RAW" | python3 -c '
import json, re, sys
try:
    payload = json.load(sys.stdin)
except Exception:
    raise SystemExit(1)
items = payload if isinstance(payload, list) else (payload.get("secrets") or payload.get("variables") or [])
for entry in items:
    name = (entry.get("name") or "").strip()
    if not re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", name):
        continue
    concealed = bool(entry.get("is_concealed") or entry.get("concealed") or entry.get("masked"))
    val = entry.get("value")
    if concealed or val is None:
        continue
    val = str(val)
    if not val or val.startswith("REPLACE_ME") or val == "<concealed by 1Password>":
        continue
    if "\n" in val or "\x00" in val:
        continue
    print(f"{name}={val}")
' 2>/dev/null)" || continue
    printf '%s\n' "$PARSED"
    exit 0
  done < <(list_accounts)
  exit 1
fi

# Single-field lookup from 1Password Environment
while IFS= read -r acct; do
  RAW="$(run_env_list "$acct" "0")"
  [ -n "$RAW" ] || continue
  STATUS_AND_VAL="$(printf '%s' "$RAW" | python3 -c '
import json, sys
target = sys.argv[1]
try:
    payload = json.load(sys.stdin)
except Exception:
    raise SystemExit(1)
items = payload if isinstance(payload, list) else (payload.get("secrets") or payload.get("variables") or [])
for entry in items:
    if entry.get("name") != target:
        continue
    concealed = bool(entry.get("is_concealed") or entry.get("concealed") or entry.get("masked"))
    val = entry.get("value")
    if val and not concealed and val != "<concealed by 1Password>":
        print("VALUE:" + str(val))
    else:
        print("CONCEALED:")
    raise SystemExit(0)
print("MISSING:")
' "$FIELD" 2>/dev/null)" || continue

  case "$STATUS_AND_VAL" in
    VALUE:*)
      VAL="${STATUS_AND_VAL#VALUE:}"
      if [ -n "$VAL" ] && [[ "$VAL" != REPLACE_ME* ]]; then
        printf '%s\n' "$VAL"
        exit 0
      fi
      ;;
    CONCEALED:*)
      if [ "$ALLOW_REVEAL" -eq 1 ]; then
        RAW_REV="$(run_env_list "$acct" "1")"
        if [ -n "$RAW_REV" ]; then
          REV_VAL="$(printf '%s' "$RAW_REV" | python3 -c '
import json, sys
target = sys.argv[1]
payload = json.load(sys.stdin)
items = payload if isinstance(payload, list) else (payload.get("secrets") or payload.get("variables") or [])
for entry in items:
    if entry.get("name") == target and entry.get("value"):
        print(str(entry["value"]))
        break
' "$FIELD" 2>/dev/null || true)"
          if [ -n "$REV_VAL" ] && [[ "$REV_VAL" != REPLACE_ME* ]]; then
            printf '%s\n' "$REV_VAL"
            exit 0
          fi
        fi
      fi
      exit 1
      ;;
    MISSING:*)
      # Environment existed on this account, field was not in it
      if [ "$ENV_EXPLICIT" -eq 1 ]; then
        exit 1
      fi
      break
      ;;
  esac
done < <(list_accounts)

# Fallback to legacy vault item only when --env was not explicitly specified
if [ "$ENV_EXPLICIT" -eq 0 ]; then
  OP_VAULT="${OP_VAULT:-Employee}"
  OP_ITEM="${OP_ITEM:-nono-pi-dev}"
  REF="op://${OP_VAULT}/${OP_ITEM}/${FIELD}"
  while IFS= read -r acct; do
    if [ -n "$acct" ]; then
      VAL="$(op read --account "$acct" "$REF" 2>/dev/null || true)"
    else
      VAL="$(op read "$REF" 2>/dev/null || true)"
    fi
    if [ -n "$VAL" ] && [[ "$VAL" != REPLACE_ME* ]]; then
      printf '%s\n' "$VAL"
      exit 0
    fi
  done < <(list_accounts)
fi

exit 1
