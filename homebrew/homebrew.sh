#
# Install Homebrew packages
#

#!/bin/sh

set -e

# Check for Homebrew
if test ! $(which brew); then
  echo "Installing homebrew..."
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

# Update homebrew
brew doctor
brew update

# Install brew-cask
brew install caskroom/cask/brew-cask

# Install GNU core utilities (those that come with OS X are outdated)
brew install coreutils

# Install GNU `find`, `locate`, `updatedb`, and `xargs`, g-prefixed
brew install findutils

# Install Bash 4
brew install bash

# Install more recent versions of some OS X tools
# brew tap homebrew/dupes
brew install homebrew/dupes/grep

# Install other useful binaries
binaries=(
  ack
  faac
  ffmpeg
  gifsicle
  git
  go
  graphicsmagick
  jenv
  mercurial
  maven
  node
  openssl
  python
  ruby
  tree
  vim
  webkit2png
  wget
  x264
  xvid
  zsh
)

# Install the binaries
brew install ${binaries[@]}

# Remove outdated versions from the cellar
brew cleanup

exit 0
