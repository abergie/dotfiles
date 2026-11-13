#!/usr/bin/env bash
#
# OpenShell MicroVM configuration and multi-Environment LiteLLM profile setup.
# Stages ~/.config/openshell/{gateway.toml,gateway.env} and syncs OpenShell
# provider profiles for one or more 1Password Environments (default: openshell-pi-dev).

set -euo pipefail

OPENSHELL_DIR="$(cd "$(dirname "$0")" && pwd -P)"

ENV_LIST=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --env|-e)
      [ "$#" -ge 2 ] || { echo "install.sh: --env requires a value" >&2; exit 2; }
      ENV_LIST+=("$2")
      shift 2
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

GH_PROFILE_SRC="$OPENSHELL_DIR/provider-github.yaml"
if [ -f "$GH_PROFILE_SRC" ] && openshell gateway info >/dev/null 2>&1; then
  GH_STAMP="$OPENSHELL_CONFIG_DIR/.profile-github.sha256"
  GH_WANT_SHA="$(shasum -a 256 "$GH_PROFILE_SRC" | awk '{print $1}')"
  GH_HAVE_SHA="$(cat "$GH_STAMP" 2>/dev/null || true)"
  if ! openshell profile describe github >/dev/null 2>&1; then
    openshell profile import -f "$GH_PROFILE_SRC" >/dev/null
    printf '%s\n' "$GH_WANT_SHA" > "$GH_STAMP"
    echo "imported openshell profile: github"
  elif [ "$GH_WANT_SHA" != "$GH_HAVE_SHA" ]; then
    GH_RVER="$(openshell profile export github | awk '/^resource_version:/ {print $2; exit}')"
    GH_TMP="$(mktemp "${TMPDIR:-/tmp}/provider-github-upd.XXXXXX.yaml")"
    chmod 0600 "$GH_TMP"
    awk -v rver="$GH_RVER" 'NR==1 { print; print "resource_version: " rver; next } { print }' "$GH_PROFILE_SRC" > "$GH_TMP"
    openshell profile update -f "$GH_TMP" github >/dev/null
    rm -f "$GH_TMP"
    printf '%s\n' "$GH_WANT_SHA" > "$GH_STAMP"
    echo "updated openshell profile: github"
  fi
fi

PROFILE_TMPL="$OPENSHELL_DIR/provider-litellm.yaml.tmpl"
if [ ! -f "$PROFILE_TMPL" ]; then
  exit 0
fi

if ! openshell gateway info >/dev/null 2>&1; then
  echo "openshell gateway not reachable, skipping provider profile sync"
  exit 0
fi

sanitize_profile_id() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/^-+//; s/-+$//'
}

sync_one_profile() {
  local profile_id="$1" display_name="$2" base_url="$3"
  local stamp_file="$OPENSHELL_CONFIG_DIR/.profile-${profile_id}.sha256"
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

  if ! openshell profile describe "$profile_id" >/dev/null 2>&1; then
    openshell profile import -f "$tmp_rendered" >/dev/null
    printf '%s\n' "$want_sha" > "$stamp_file"
    echo "imported openshell profile: $profile_id"
  elif [ "$want_sha" != "$have_sha" ]; then
    rver="$(openshell profile export "$profile_id" | awk '/^resource_version:/ {print $2; exit}')"
    tmp_update="$(mktemp "${TMPDIR:-/tmp}/provider-${profile_id}-upd.XXXXXX.yaml")"
    chmod 0600 "$tmp_update"
    awk -v rver="$rver" 'NR==1 { print; print "resource_version: " rver; next } { print }' "$tmp_rendered" > "$tmp_update"
    openshell profile update -f "$tmp_update" "$profile_id" >/dev/null
    rm -f "$tmp_update"
    printf '%s\n' "$want_sha" > "$stamp_file"
    echo "updated openshell profile: $profile_id"
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
