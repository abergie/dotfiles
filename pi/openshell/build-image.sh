#!/usr/bin/env bash
#
# Build the self-contained Linux arm64 Pi image used by OpenShell's MicroVM
# compute driver. Docker (Colima) is used strictly at image-build time to
# compile Dockerfile.pi; runtime sandboxes boot inside Apple Hypervisor VMs.

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
IMAGE_TAG="${PI_OPENSHELL_IMAGE:-pi-openshell:local}"
PI_VERSION_ARG="${PI_VERSION:-1.5.2}"

if ! command -v docker >/dev/null 2>&1; then
  echo "build-image.sh: docker CLI not found on PATH" >&2
  exit 1
fi

if [ -z "${DOCKER_HOST:-}" ] && [ ! -S /var/run/docker.sock ] && [ -S "$HOME/.colima/default/docker.sock" ]; then
  export DOCKER_HOST="unix://$HOME/.colima/default/docker.sock"
fi

# Avoid macOS Keychain prompts from docker-credential-osxkeychain when pulling
# the public node:24-bookworm-slim base image unless explicitly opted in.
TMP_DOCKER_CONFIG=""
cleanup() {
  if [ -n "$TMP_DOCKER_CONFIG" ] && [ -d "$TMP_DOCKER_CONFIG" ]; then
    rm -rf "$TMP_DOCKER_CONFIG"
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

BUILD_ARGS=(
  --platform linux/arm64
  --build-arg "PI_VERSION=${PI_VERSION_ARG}"
  -t "$IMAGE_TAG"
  -f "$DOTFILES_ROOT/pi/openshell/Dockerfile.pi"
  "$DOTFILES_ROOT"
)

# Note: do not use 'exec' here so the EXIT trap cleans up TMP_DOCKER_CONFIG.
if docker buildx version >/dev/null 2>&1; then
  docker buildx build --load "${BUILD_ARGS[@]}"
else
  docker build "${BUILD_ARGS[@]}"
fi
