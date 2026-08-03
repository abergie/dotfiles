# sup yarn
# https://yarnpkg.com

# Yarn 2+ removed `yarn global bin`; retain the Yarn Classic global binary path
# without invoking Yarn during shell startup.
if [[ -d "$HOME/.yarn/bin" ]]
then
  export PATH="$PATH:$HOME/.yarn/bin"
fi
