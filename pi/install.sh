#!/usr/bin/env bash
#
# pi coding agent setup
#
# Symlinks pi agent config and extensions into ~/.pi/agent.
# Skips entirely if pi is not installed or if everything is already linked.

set -e

DOTFILES_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
PI_AGENT_DIR="$HOME/.pi/agent"

if ! command -v pi >/dev/null 2>&1; then
  echo "pi not installed, skipping agent setup"
  exit 0
fi

setup_link() {
  local src="$1" dst="$2" label="$3"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    return 0
  fi
  if [ -L "$dst" ] || [ -f "$dst" ]; then
    rm -f "$dst"
  fi
  ln -sf "$src" "$dst"
  echo "linked $label"
}

mkdir -p "$PI_AGENT_DIR/extensions"

setup_link "$DOTFILES_ROOT/pi/AGENTS.md" "$PI_AGENT_DIR/AGENTS.md" "AGENTS.md"

for ext in litellm; do
  ext_src="$DOTFILES_ROOT/pi/agent/extensions/$ext"
  ext_dst="$PI_AGENT_DIR/extensions/$ext"
  if [ -e "$ext_src" ]; then
    setup_link "$ext_src" "$ext_dst" "pi extension: $ext"
  fi
done

echo "pi agent setup complete"
