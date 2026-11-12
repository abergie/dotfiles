#!/bin/sh
#
# Pre-stage NVIDIA's local --no-git Homebrew tap (nvidia/openshell) on Apple
# Silicon macOS before 'brew bundle' runs, since NVIDIA publishes openshell.rb
# as a GitHub release asset rather than a remote git tap repository.

set -e

if ! command -v brew >/dev/null 2>&1; then
  exit 0
fi

if [ "$(uname -s)" = "Darwin" ] && [ "$(uname -m)" = "arm64" ]; then
  OPENSHELL_TAP="nvidia/openshell"
  if ! brew tap-info "$OPENSHELL_TAP" >/dev/null 2>&1; then
    DEV_WAS_ON=0
    if brew developer state 2>/dev/null | grep -qi "enabled"; then
      DEV_WAS_ON=1
    fi
    brew tap-new --no-git "$OPENSHELL_TAP" >/dev/null
    if [ "$DEV_WAS_ON" -eq 0 ]; then
      brew developer off >/dev/null 2>&1 || true
    fi
  fi
  TAP_DIR="$(brew --repository "$OPENSHELL_TAP")"
  FORMULA_PATH="$TAP_DIR/Formula/openshell.rb"
  if [ ! -f "$FORMULA_PATH" ]; then
    OPENSHELL_RELEASE_TAG="${OPENSHELL_VERSION:-}"
    if [ -z "$OPENSHELL_RELEASE_TAG" ]; then
      RESOLVED_URL="$(curl -fLsS -o /dev/null -w '%{url_effective}' https://github.com/NVIDIA/OpenShell/releases/latest)"
      OPENSHELL_RELEASE_TAG="${RESOLVED_URL##*/}"
    fi
    mkdir -p "$TAP_DIR/Formula"
    TMP_FORMULA="$(mktemp "${TMPDIR:-/tmp}/openshell.rb.XXXXXX")"
    curl -fLsS "https://github.com/NVIDIA/OpenShell/releases/download/${OPENSHELL_RELEASE_TAG}/openshell.rb" -o "$TMP_FORMULA"
    sed 's/entitlements\.write <<~XML/entitlements.atomic_write <<~XML/' "$TMP_FORMULA" > "$FORMULA_PATH"
    chmod 0644 "$FORMULA_PATH"
    rm -f "$TMP_FORMULA"
    brew trust --formula nvidia/openshell/openshell >/dev/null 2>&1 || true
  fi
fi
