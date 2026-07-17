#!/usr/bin/env bash
#
# pi coding agent setup
#
# Symlinks pi agent config and extensions into ~/.pi/agent.
# Skips entirely if pi is not installed.

set -e

DOTFILES_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
PI_AGENT_DIR="$HOME/.pi/agent"

if ! command -v pi >/dev/null 2>&1; then
  echo "pi not installed, skipping agent setup"
  exit 0
fi

mkdir -p "$PI_AGENT_DIR/extensions"

# AGENTS.md
if [ -L "$PI_AGENT_DIR/AGENTS.md" ] || [ -f "$PI_AGENT_DIR/AGENTS.md" ]; then
  rm -f "$PI_AGENT_DIR/AGENTS.md"
fi
ln -sf "$DOTFILES_ROOT/pi/AGENTS.md" "$PI_AGENT_DIR/AGENTS.md"

# sandbox.json global config
ln -sf "$DOTFILES_ROOT/pi/agent/sandbox.json" "$PI_AGENT_DIR/extensions/sandbox.json"

# extensions
for ext in sandbox litellm; do
  ext_src="$DOTFILES_ROOT/pi/agent/extensions/$ext"
  ext_dst="$PI_AGENT_DIR/extensions/$ext"
  if [ -e "$ext_src" ]; then
    if [ -L "$ext_dst" ] || [ -e "$ext_dst" ]; then
      rm -rf "$ext_dst"
    fi
    ln -s "$ext_src" "$ext_dst"
    echo "linked pi extension: $ext"
  fi
done

# install sandbox extension dependencies
if [ -f "$PI_AGENT_DIR/extensions/sandbox/package.json" ]; then
  echo "installing sandbox extension dependencies"
  cd "$PI_AGENT_DIR/extensions/sandbox"
  npm install
fi

echo "pi agent setup complete"
