#!/usr/bin/env bash

# Install Homebrew packages.

set -e

# Check for Homebrew.
if test ! $(which brew); then
  echo "Installing homebrew..."
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

# Ensure install was correct.
brew doctor

# Make sure we’re using the latest Homebrew.
brew update

# Upgrade any already-installed formulae.
brew upgrade

# Save Homebrew’s installed location.
BREW_PREFIX=$(brew --prefix)

# Install GNU core utilities (those that come with macOS are outdated).
# Don’t forget to add `$(brew --prefix coreutils)/libexec/gnubin` to `$PATH`.
brew install coreutils
ln -s "${BREW_PREFIX}/bin/gsha256sum" "${BREW_PREFIX}/bin/sha256sum"

# Install some other useful utilities like `sponge`.
brew install moreutils
# Install GNU `find`, `locate`, `updatedb`, and `xargs`, `g`-prefixed.
brew install findutils
# Install GNU `sed`, overwriting the built-in `sed`.
brew install gnu-sed --with-default-names
# Install Bash 4.
brew install bash
brew install bash-completion2

# Switch to using brew-installed bash as default shell
if ! fgrep -q "${BREW_PREFIX}/bin/bash" /etc/shells; then
  echo "${BREW_PREFIX}/bin/bash" | sudo tee -a /etc/shells;
  chsh -s "${BREW_PREFIX}/bin/bash";
fi;

# Install font tools.
brew tap bramstein/webfonttools
brew install sfnt2woff
brew install sfnt2woff-zopfli
brew install woff2

# Install other useful binaries.
binaries=(
  ack
  aircrack-ng
  bfg
  binutils
  binwalk
  cifer
  dex2jar
  dns2tcp
  faac
  fcrackzip
  ffmpeg
  foremost
  gifsicle
  git
  git-lfs
  gmp
  gnupg
  go
  graphicsmagick
  grep
  hashpump
  hydra
  imagemagick --with-webp
  john
  knock
  lua
  lynx
  mercurial
  netpbm
  nmap
  openssh
  openssl
  p7zip
  php
  pigz
  pngcheck
  pv
  python
  rename
  rlwrap
  ruby
  screen
  socat
  sqlmap
  ssh-copy-id
  tcpflow
  tcpreplay
  tcptrace
  tree
  ucspi-tcp
  vbindiff
  vim --with-override-system-vi
  webkit2png
  wget --with-iri
  x264
  xpdf
  xvid
  xz
  zopfli
  zsh
)

# Install the binaries
brew install ${binaries[@]}

# Remove outdated versions from the cellar.
brew cleanup

exit 0