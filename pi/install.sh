#!/usr/bin/env bash
#
# pi coding agent host setup
#
# Symlinks pi agent config and extensions into ~/.pi/agent for running pi
# directly on the host or under nono, and stages the nono session hook.
# OpenShell setup lives separately in pi/openshell/install.sh.

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

for ext in litellm local-models worktree-status; do
  ext_src="$DOTFILES_ROOT/pi/agent/extensions/$ext"
  ext_dst="$PI_AGENT_DIR/extensions/$ext"
  if [ -e "$ext_src" ]; then
    setup_link "$ext_src" "$ext_dst" "pi extension: $ext"
  fi
done

NONO_HOOK_SRC="$DOTFILES_ROOT/pi/nono/hooks/nono-op-env.sh"
NONO_HOOK_DST="$HOME/.config/nono/hooks/nono-op-env.sh"
if [ -f "$NONO_HOOK_SRC" ]; then
  mkdir -p "$(dirname "$NONO_HOOK_DST")"
  if ! cmp -s "$NONO_HOOK_SRC" "$NONO_HOOK_DST" 2>/dev/null; then
    install -m 0755 "$NONO_HOOK_SRC" "$NONO_HOOK_DST"
    echo "installed nono hook: nono-op-env.sh"
  fi
fi

echo "pi agent setup complete"
