#
# Install Homebrew packages
#

#!/bin/sh

set -e

# Check for Homebrew
if test ! $(which brew); then
  echo "Installing homebrew..."
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

# Update homebrew
brew doctor
brew update

# Install brew-cask
brew tap caskroom/cask

# Install more recent versions of some OS X tools
brew tap homebrew/dupes

# Install other useful binaries
binaries=(
  coreutils
  findutils
  bash
  grep
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
