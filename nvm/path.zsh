export NVM_DIR="$HOME/.nvm"
mkdir -p "$NVM_DIR"

# HOMEBREW_PREFIX is only set when `brew shellenv` has been evaluated.
# Resolve it here so Homebrew's nvm loads in a normal shell startup as well.
nvm_homebrew_prefix="${HOMEBREW_PREFIX:-}"
if [[ -z "$nvm_homebrew_prefix" && (( $+commands[brew] )) ]]
then
  nvm_homebrew_prefix="$(brew --prefix)"
fi

if [[ -n "$nvm_homebrew_prefix" ]]
then
  [ -s "$nvm_homebrew_prefix/opt/nvm/nvm.sh" ] && \. "$nvm_homebrew_prefix/opt/nvm/nvm.sh"
  [ -s "$nvm_homebrew_prefix/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$nvm_homebrew_prefix/opt/nvm/etc/bash_completion.d/nvm"
fi

unset nvm_homebrew_prefix
