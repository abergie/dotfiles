#!/usr/bin/env bash
#
# Ensure Homebrew's zsh is registered in /etc/shells and set as the login shell.

set -e

BREW_ZSH="/opt/homebrew/bin/zsh"

if [ ! -x "$BREW_ZSH" ]; then
  exit 0
fi

if ! grep -qx "$BREW_ZSH" /etc/shells; then
  echo "  Adding $BREW_ZSH to /etc/shells (requires sudo)..."
  echo "$BREW_ZSH" | sudo tee -a /etc/shells >/dev/null
fi

CURRENT_SHELL="$(dscl . -read "/Users/$USER" UserShell | awk '{print $2}')"
if [ "$CURRENT_SHELL" != "$BREW_ZSH" ]; then
  echo "  Changing login shell for $USER to $BREW_ZSH..."
  chsh -s "$BREW_ZSH"
fi
