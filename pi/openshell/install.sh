#!/usr/bin/env bash
#
# OpenShell MicroVM configuration and multi-Environment LiteLLM profile setup.
# For the local 'openshell' gateway (default), stages ~/.config/openshell/{gateway.toml,gateway.env},
# ensures the local gateway registration exists without changing any active remote gateway,
# and syncs OpenShell provider profiles for one or more 1Password Environments.
# Pass -g/--gateway <name> or --gateway-endpoint <url> to sync provider profiles to a remote gateway.

set -euo pipefail

OPENSHELL_DIR="$(cd "$(dirname "$0")" && pwd -P)"

LOCAL_GATEWAY_NAME="${PI_OPENSHELL_LOCAL_GATEWAY:-openshell}"
LOCAL_GATEWAY_ENDPOINT="${PI_OPENSHELL_LOCAL_ENDPOINT:-https://localhost:17670}"
GATEWAY="${PI_OPENSHELL_GATEWAY:-$LOCAL_GATEWAY_NAME}"
GATEWAY_ENDPOINT="${PI_OPENSHELL_GATEWAY_ENDPOINT:-}"
GATEWAY_INSECURE="${PI_OPENSHELL_GATEWAY_INSECURE:-0}"

usage() {
  cat <<'EOF'
Usage: install.sh [options] [env-name...]

Options:
  -g, --gateway <name>       Target OpenShell gateway name (default: openshell)
  --gateway-endpoint <url>   Target OpenShell gateway endpoint URL directly
  --gateway-insecure         Skip TLS certificate verification for gateway connections
  --local                    Target local OpenShell gateway (shorthand for -g openshell)
  -e, --env <name>           1Password Environment name to sync profile for (repeatable)
  -h, --help                 Show this help message
EOF
}

ENV_LIST=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    -g|--gateway)
      [ "$#" -ge 2 ] || { echo "install.sh: $1 requires a value" >&2; exit 2; }
      GATEWAY="$2"
      GATEWAY_ENDPOINT=""
      shift 2
      ;;
    --gateway-endpoint)
      [ "$#" -ge 2 ] || { echo "install.sh: --gateway-endpoint requires a value" >&2; exit 2; }
      GATEWAY_ENDPOINT="$2"
      shift 2
      ;;
    --gateway-insecure)
      GATEWAY_INSECURE=1
      shift
      ;;
    --local)
      GATEWAY="$LOCAL_GATEWAY_NAME"
      GATEWAY_ENDPOINT=""
      shift
      ;;
    --env|-e)
      [ "$#" -ge 2 ] || { echo "install.sh: --env requires a value" >&2; exit 2; }
      ENV_LIST+=("$2")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      ENV_LIST+=("$1")
      shift
      ;;
  esac
done

if [ "${#ENV_LIST[@]}" -eq 0 ]; then
  RAW_ENVS="${PI_OP_ENVS:-${PI_OP_ENV:-openshell-pi-dev}}"
  for tok in ${RAW_ENVS//,/ }; do
    [ -n "$tok" ] && ENV_LIST+=("$tok")
  done
fi

sanitize_profile_id() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/^-+//; s/-+$//'
}

IS_LOCAL_SETUP=0
if [ -z "$GATEWAY_ENDPOINT" ] && [ "$GATEWAY" = "$LOCAL_GATEWAY_NAME" ]; then
  IS_LOCAL_SETUP=1
fi

GW_ARGS=()
if [ -n "$GATEWAY_ENDPOINT" ]; then
  unset OPENSHELL_GATEWAY
  GW_ARGS=(--gateway-endpoint "$GATEWAY_ENDPOINT")
  GW_LABEL="$GATEWAY_ENDPOINT"
  GW_STAMP_KEY="endpoint-$(printf '%s' "$GATEWAY_ENDPOINT" | shasum -a 256 | awk '{print substr($1,1,12)}')"
else
  unset OPENSHELL_GATEWAY_ENDPOINT
  GW_ARGS=(-g "$GATEWAY")
  GW_LABEL="$GATEWAY"
  GW_STAMP_KEY="$(sanitize_profile_id "$GATEWAY")"
fi
if [ "$GATEWAY_INSECURE" = "1" ] || [ "$GATEWAY_INSECURE" = "true" ]; then
  GW_ARGS+=(--gateway-insecure)
fi

if [ "$IS_LOCAL_SETUP" -eq 1 ]; then
  "$OPENSHELL_DIR/install-tap.sh"
fi

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
mkdir -p "$OPENSHELL_CONFIG_DIR"

if [ "$IS_LOCAL_SETUP" -eq 1 ]; then
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

  # Ensure the local gateway registration exists alongside any remote gateways
  # without changing the user's currently selected active gateway.
  GW_STATE="$(openshell gateway list -o json 2>/dev/null | python3 -c '
import json, sys
target = sys.argv[1]
try:
    gws = json.load(sys.stdin)
except Exception:
    gws = []
has_local = False
active = ""
for g in (gws if isinstance(gws, list) else []):
    if not isinstance(g, dict):
        continue
    if g.get("name") == target:
        has_local = True
    if g.get("active") and g.get("name"):
        active = g["name"]
print("1" if has_local else "0")
print(active)
' "$LOCAL_GATEWAY_NAME" 2>/dev/null || printf '0\n\n')"
  HAS_LOCAL_GW="$(printf '%s\n' "$GW_STATE" | sed -n '1p')"
  PREV_ACTIVE_GW="$(printf '%s\n' "$GW_STATE" | sed -n '2p')"

  if [ "$HAS_LOCAL_GW" != "1" ]; then
    if openshell gateway add "$LOCAL_GATEWAY_ENDPOINT" --local --name "$LOCAL_GATEWAY_NAME" >/dev/null 2>&1; then
      echo "registered local openshell gateway: $LOCAL_GATEWAY_NAME"
      if [ -n "$PREV_ACTIVE_GW" ] && [ "$PREV_ACTIVE_GW" != "$LOCAL_GATEWAY_NAME" ]; then
        openshell gateway select "$PREV_ACTIVE_GW" >/dev/null 2>&1 || true
        echo "preserved active openshell gateway: $PREV_ACTIVE_GW"
      fi
    fi
  fi
fi

if ! openshell gateway info "${GW_ARGS[@]}" >/dev/null 2>&1; then
  echo "openshell gateway '$GW_LABEL' not reachable, skipping provider profile sync"
  exit 0
fi

GH_PROFILE_SRC="$OPENSHELL_DIR/provider-github.yaml"
if [ -f "$GH_PROFILE_SRC" ]; then
  GH_STAMP="$OPENSHELL_CONFIG_DIR/.profile-${GW_STAMP_KEY}-github.sha256"
  GH_WANT_SHA="$(shasum -a 256 "$GH_PROFILE_SRC" | awk '{print $1}')"
  GH_HAVE_SHA="$(cat "$GH_STAMP" 2>/dev/null || true)"
  if ! openshell profile describe "${GW_ARGS[@]}" github >/dev/null 2>&1; then
    openshell profile import "${GW_ARGS[@]}" -f "$GH_PROFILE_SRC" >/dev/null
    printf '%s\n' "$GH_WANT_SHA" > "$GH_STAMP"
    echo "imported openshell profile: github ($GW_LABEL)"
  elif [ "$GH_WANT_SHA" != "$GH_HAVE_SHA" ]; then
    GH_RVER="$(openshell profile export "${GW_ARGS[@]}" github | awk '/^resource_version:/ {print $2; exit}')"
    GH_TMP="$(mktemp "${TMPDIR:-/tmp}/provider-github-upd.XXXXXX.yaml")"
    chmod 0600 "$GH_TMP"
    awk -v rver="$GH_RVER" 'NR==1 { print; print "resource_version: " rver; next } { print }' "$GH_PROFILE_SRC" > "$GH_TMP"
    openshell profile update "${GW_ARGS[@]}" -f "$GH_TMP" github >/dev/null
    rm -f "$GH_TMP"
    printf '%s\n' "$GH_WANT_SHA" > "$GH_STAMP"
    echo "updated openshell profile: github ($GW_LABEL)"
  fi
fi

PROFILE_TMPL="$OPENSHELL_DIR/provider-litellm.yaml.tmpl"
if [ ! -f "$PROFILE_TMPL" ]; then
  exit 0
fi

sync_one_profile() {
  local profile_id="$1" display_name="$2" base_url="$3"
  local stamp_file="$OPENSHELL_CONFIG_DIR/.profile-${GW_STAMP_KEY}-${profile_id}.sha256"
  local tmp_rendered tmp_update want_sha have_sha rver

  tmp_rendered="$(mktemp "${TMPDIR:-/tmp}/provider-${profile_id}.XXXXXX.yaml")"
  chmod 0600 "$tmp_rendered"

  python3 -c '
import re, sys, urllib.parse
tmpl_path, profile_id, display_name, raw_url, out_path = sys.argv[1:6]
url = raw_url.strip()
if url and not re.match(r"^https?://", url, re.I):
    url = "https://" + url
parsed = urllib.parse.urlparse(url)
if not parsed.hostname:
    raise SystemExit(f"Invalid LITELLM_BASE_URL for {profile_id}: {raw_url}")
port = parsed.port or (80 if parsed.scheme == "http" else 443)
with open(tmpl_path) as f:
    rendered = (
        f.read()
        .replace("__PROFILE_ID__", profile_id)
        .replace("__DISPLAY_NAME__", display_name)
        .replace("__LITELLM_HOST__", parsed.hostname)
        .replace("__LITELLM_PORT__", str(port))
    )
with open(out_path, "w") as f:
    f.write(rendered)
' "$PROFILE_TMPL" "$profile_id" "$display_name" "$base_url" "$tmp_rendered"

  want_sha="$(shasum -a 256 "$tmp_rendered" | awk '{print $1}')"
  have_sha="$(cat "$stamp_file" 2>/dev/null || true)"

  if ! openshell profile describe "${GW_ARGS[@]}" "$profile_id" >/dev/null 2>&1; then
    openshell profile import "${GW_ARGS[@]}" -f "$tmp_rendered" >/dev/null
    printf '%s\n' "$want_sha" > "$stamp_file"
    echo "imported openshell profile: $profile_id ($GW_LABEL)"
  elif [ "$want_sha" != "$have_sha" ]; then
    rver="$(openshell profile export "${GW_ARGS[@]}" "$profile_id" | awk '/^resource_version:/ {print $2; exit}')"
    tmp_update="$(mktemp "${TMPDIR:-/tmp}/provider-${profile_id}-upd.XXXXXX.yaml")"
    chmod 0600 "$tmp_update"
    awk -v rver="$rver" 'NR==1 { print; print "resource_version: " rver; next } { print }' "$tmp_rendered" > "$tmp_update"
    openshell profile update "${GW_ARGS[@]}" -f "$tmp_update" "$profile_id" >/dev/null
    rm -f "$tmp_update"
    printf '%s\n' "$want_sha" > "$stamp_file"
    echo "updated openshell profile: $profile_id ($GW_LABEL)"
  fi

  rm -f "$tmp_rendered"
}

PRIMARY_SYNCED=0
for env_name in "${ENV_LIST[@]}"; do
  profile_id="$(sanitize_profile_id "$env_name")"
  [ -n "$profile_id" ] || continue

  base_url=""
  if [ "${#ENV_LIST[@]}" -eq 1 ] && [ -n "${LITELLM_BASE_URL:-}" ]; then
    base_url="$LITELLM_BASE_URL"
  else
    base_url="$("$OPENSHELL_DIR/op-read.sh" --env "$env_name" LITELLM_BASE_URL 2>/dev/null || true)"
    if [ -z "$base_url" ] && [ -n "${LITELLM_BASE_URL:-}" ]; then
      base_url="$LITELLM_BASE_URL"
    fi
  fi

  if [ -z "$base_url" ]; then
    echo "LITELLM_BASE_URL unavailable for environment '$env_name', skipping profile '$profile_id'"
    continue
  fi

  sync_one_profile "$profile_id" "LiteLLM ($env_name)" "$base_url"

  if [ "$PRIMARY_SYNCED" -eq 0 ] && [ "$profile_id" != "litellm" ]; then
    sync_one_profile "litellm" "LiteLLM" "$base_url"
    PRIMARY_SYNCED=1
  fi
done
