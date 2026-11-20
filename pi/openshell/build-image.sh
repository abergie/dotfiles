#!/usr/bin/env bash
#
# Build the self-contained Linux arm64 Pi image used by OpenShell's MicroVM
# compute driver. Docker (Colima) is used strictly at image-build time to
# compile Dockerfile.pi; runtime sandboxes boot inside Apple Hypervisor VMs.

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
IMAGE_TAG="${PI_OPENSHELL_IMAGE:-pi-openshell:local}"
PI_VERSION_ARG="${PI_VERSION:-1.5.2}"
HOST_PI_AGENT_DIR="${PI_HOST_AGENT_DIR:-${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}}"
HOST_CE_DIR="${PI_COMPOUND_ENGINEERING_DIR:-$HOST_PI_AGENT_DIR/git/github.com/EveryInc/compound-engineering-plugin}"

if ! command -v docker >/dev/null 2>&1; then
  echo "build-image.sh: docker CLI not found on PATH" >&2
  exit 1
fi

if [ -z "${DOCKER_HOST:-}" ] && [ ! -S /var/run/docker.sock ] && [ -S "$HOME/.colima/default/docker.sock" ]; then
  export DOCKER_HOST="unix://$HOME/.colima/default/docker.sock"
fi

# Avoid macOS Keychain prompts from docker-credential-osxkeychain when pulling
# the public node:24-bookworm-slim base image unless explicitly opted in.
if [ ! -d "$HOST_CE_DIR" ]; then
  echo "build-image.sh: compound-engineering-plugin not found at '$HOST_CE_DIR'" >&2
  echo "Install it on the host first with: pi install git:github.com/EveryInc/compound-engineering-plugin" >&2
  exit 1
fi

TMP_DOCKER_CONFIG=""
TMP_BUILD_CTX=""
cleanup() {
  if [ -n "$TMP_DOCKER_CONFIG" ] && [ -d "$TMP_DOCKER_CONFIG" ]; then
    rm -rf "$TMP_DOCKER_CONFIG"
  fi
  if [ -n "$TMP_BUILD_CTX" ] && [ -d "$TMP_BUILD_CTX" ]; then
    rm -rf "$TMP_BUILD_CTX"
  fi
}
trap cleanup EXIT

if [ "${PI_DOCKER_USE_KEYCHAIN:-0}" != "1" ]; then
  TMP_DOCKER_CONFIG="$(mktemp -d "${TMPDIR:-/tmp}/pi-docker-cfg.XXXXXX")"
  chmod 0700 "$TMP_DOCKER_CONFIG"
  printf '{}\n' > "$TMP_DOCKER_CONFIG/config.json"
  export DOCKER_CONFIG="$TMP_DOCKER_CONFIG"
fi

if ! docker info >/dev/null 2>&1; then
  echo "build-image.sh: Docker daemon is not reachable (start Colima with 'colima start' to build $IMAGE_TAG)" >&2
  exit 1
fi

TMP_BUILD_CTX="$(mktemp -d "${TMPDIR:-/tmp}/pi-openshell-ctx.XXXXXX")"
mkdir -p \
  "$TMP_BUILD_CTX/pi/openshell" \
  "$TMP_BUILD_CTX/pi/agent/extensions" \
  "$TMP_BUILD_CTX/pi-seed/git/github.com/EveryInc"

cp "$DOTFILES_ROOT/pi/AGENTS.md" "$TMP_BUILD_CTX/pi/AGENTS.md"
cp "$DOTFILES_ROOT/pi/openshell/settings.json" "$TMP_BUILD_CTX/pi/openshell/settings.json"
cp "$DOTFILES_ROOT/pi/openshell/pi-sandbox-init.sh" "$TMP_BUILD_CTX/pi/openshell/pi-sandbox-init.sh"
cp -R "$DOTFILES_ROOT/pi/agent/extensions/litellm" "$TMP_BUILD_CTX/pi/agent/extensions/litellm"
cp -R "$DOTFILES_ROOT/pi/agent/extensions/worktree-status" "$TMP_BUILD_CTX/pi/agent/extensions/worktree-status"
cp -R "$HOST_CE_DIR" "$TMP_BUILD_CTX/pi-seed/git/github.com/EveryInc/compound-engineering-plugin"
rm -rf "$TMP_BUILD_CTX/pi-seed/git/github.com/EveryInc/compound-engineering-plugin/node_modules"

BUILD_ARGS=(
  --platform linux/arm64
  --build-arg "PI_VERSION=${PI_VERSION_ARG}"
  -t "$IMAGE_TAG"
  -f "$DOTFILES_ROOT/pi/openshell/Dockerfile.pi"
  "$TMP_BUILD_CTX"
)

# Note: do not use 'exec' here so the EXIT trap cleans up TMP_DOCKER_CONFIG.
if docker buildx version >/dev/null 2>&1; then
  docker buildx build --load "${BUILD_ARGS[@]}"
else
  docker build "${BUILD_ARGS[@]}"
fi
