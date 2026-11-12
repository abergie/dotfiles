#!/usr/bin/env bash
#
# OpenShell MicroVM configuration and LiteLLM provider profile setup.
# Stages ~/.config/openshell/{gateway.toml,gateway.env} and renders/imports the
# litellm provider profile using LITELLM_BASE_URL from env or 1Password.

set -euo pipefail

OPENSHELL_DIR="$(cd "$(dirname "$0")" && pwd -P)"

"$OPENSHELL_DIR/install-tap.sh"

if ! command -v openshell >/dev/null 2>&1; then
  echo "openshell not installed, skipping openshell setup"
  exit 0
fi

FILE_CHANGED=0
install_file_if_changed() {
  local src="$1" dst="$2" mode="$3" label="$4"
  FILE_CHANGED=0
  if [ ! -f "$src" ]; then
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  if ! cmp -s "$src" "$dst" 2>/dev/null; then
    install -m "$mode" "$src" "$dst"
    echo "installed $label"
    FILE_CHANGED=1
  fi
}

OPENSHELL_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/openshell"
OPENSHELL_CHANGED=0
for cfg in gateway.toml gateway.env; do
  install_file_if_changed \
    "$OPENSHELL_DIR/$cfg" \
    "$OPENSHELL_CONFIG_DIR/$cfg" \
    0600 \
    "openshell config: $cfg"
  if [ "$FILE_CHANGED" -eq 1 ]; then
    OPENSHELL_CHANGED=1
  fi
done

if [ "$OPENSHELL_CHANGED" -eq 1 ] && command -v brew >/dev/null 2>&1; then
  if brew services list 2>/dev/null | awk '$1 == "openshell" && $2 == "started" { found=1 } END { exit !found }'; then
    brew services restart nvidia/openshell/openshell >/dev/null 2>&1 || true
    sleep 1
  fi
fi

PROFILE_TMPL="$OPENSHELL_DIR/provider-litellm.yaml.tmpl"
PROFILE_STAMP="$OPENSHELL_CONFIG_DIR/.litellm-profile.sha256"

if [ -f "$PROFILE_TMPL" ]; then
  if openshell gateway info >/dev/null 2>&1; then
    BASE_URL="${LITELLM_BASE_URL:-}"
    if [ -z "$BASE_URL" ]; then
      BASE_URL="$("$OPENSHELL_DIR/op-read.sh" LITELLM_BASE_URL 2>/dev/null || true)"
    fi

    if [ -z "$BASE_URL" ]; then
      echo "LITELLM_BASE_URL not set and unavailable from 1Password, skipping litellm profile sync"
      exit 0
    fi

    TMP_RENDERED="$(mktemp "${TMPDIR:-/tmp}/provider-litellm.XXXXXX.yaml")"
    chmod 0600 "$TMP_RENDERED"
    trap 'rm -f "$TMP_RENDERED"' EXIT

    python3 -c '
import sys, urllib.parse
tmpl_path, base_url, out_path = sys.argv[1], sys.argv[2].strip(), sys.argv[3]
parsed = urllib.parse.urlparse(base_url)
if not parsed.hostname:
    raise SystemExit(f"Invalid LITELLM_BASE_URL (missing hostname): {base_url}")
port = parsed.port or (80 if parsed.scheme == "http" else 443)
with open(tmpl_path) as f:
    rendered = f.read().replace("__LITELLM_HOST__", parsed.hostname).replace("__LITELLM_PORT__", str(port))
with open(out_path, "w") as f:
    f.write(rendered)
' "$PROFILE_TMPL" "$BASE_URL" "$TMP_RENDERED"

    WANT_SHA="$(shasum -a 256 "$TMP_RENDERED" | awk '{print $1}')"
    HAVE_SHA="$(cat "$PROFILE_STAMP" 2>/dev/null || true)"

    if ! openshell profile describe litellm >/dev/null 2>&1; then
      openshell profile import -f "$TMP_RENDERED" >/dev/null
      printf '%s\n' "$WANT_SHA" > "$PROFILE_STAMP"
      echo "imported openshell profile: litellm"
    elif [ "$WANT_SHA" != "$HAVE_SHA" ]; then
      RVER="$(openshell profile export litellm | awk '/^resource_version:/ {print $2; exit}')"
      TMP_UPDATE="$(mktemp "${TMPDIR:-/tmp}/provider-litellm-upd.XXXXXX.yaml")"
      chmod 0600 "$TMP_UPDATE"
      awk -v rver="$RVER" 'NR==1 { print; print "resource_version: " rver; next } { print }' "$TMP_RENDERED" > "$TMP_UPDATE"
      openshell profile update -f "$TMP_UPDATE" litellm >/dev/null
      rm -f "$TMP_UPDATE"
      printf '%s\n' "$WANT_SHA" > "$PROFILE_STAMP"
      echo "updated openshell profile: litellm"
    fi
  else
    echo "openshell gateway not reachable, skipping litellm profile sync"
  fi
fi
