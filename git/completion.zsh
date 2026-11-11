# Git completion is handled via Homebrew's site-functions in $fpath (configured in zsh/fpath.zsh).
# Configure the underlying git-completion.bash path if present in Homebrew.
if [[ -f /opt/homebrew/etc/bash_completion.d/git-completion.bash ]]
then
  zstyle ':completion:*:*:git:*' script /opt/homebrew/etc/bash_completion.d/git-completion.bash
fi
