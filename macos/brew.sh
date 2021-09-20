#!/usr/bin/env bash

# Install Homebrew + packages.

# Check for Homebrew.
if test ! $(which brew); then
  echo "Installing homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

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
# Install a modern version of Bash.
brew install bash
brew install bash-completion2

# Switch to using brew-installed bash as default shell
if ! fgrep -q "${BREW_PREFIX}/bin/bash" /etc/shells; then
  echo "${BREW_PREFIX}/bin/bash" | sudo tee -a /etc/shells;
  chsh -s "${BREW_PREFIX}/bin/bash";
fi;

# Install `wget` with IRI support.
brew install wget --with-iri

# Install GnuPG to enable PGP-signing commits.
brew install gnupg

# Install more recent versions of some macOS tools.
brew install vim --with-override-system-vi
brew install grep
brew install openssh
brew install screen
brew install php
brew install gmp

# Install font tools.
brew tap bramstein/webfonttools
brew install sfnt2woff
brew install sfnt2woff-zopfli
brew install woff2

# Install other useful binaries.
brew install ack
brew install aircrack-ng
brew install azure-cli
brew install bfg
brew install binutils
brew install binwalk
brew install cifer
brew install dex2jar
brew install dns2tcp
brew install faac
brew install fcrackzip
brew install ffmpeg
brew install foremost
brew install gifsicle
brew install git
brew install git-lfs
brew install gnupg
brew install go
brew install graphicsmagick
brew install hashpump
brew install hydra
brew install imagemagick --with-webp
brew install john
brew install knock
brew install kubernetes-cli
brew install lua
brew install lynx
brew install mercurial
brew install netpbm
brew install nmap
brew install openssl
brew install p7zip
brew install pigz
brew install pngcheck
brew install pv
brew install python
brew install rename
brew install rlwrap
brew install ruby
brew install socat
brew install sqlmap
brew install ssh-copy-id
brew install tcpflow
brew install tcpreplay
brew install tcptrace
brew install tree
brew install ucspi-tcp
brew install vbindiff
brew install webkit2png
brew install wget --with-iri
brew install x264
brew install xpdf
brew install xvid
brew install xz
brew install zopfli
brew install zsh

# Install Fonts
brew install font-clear-sans
brew install font-hack
brew install font-m-plus
brew install font-roboto

# Install Casks Apps
brew install --cask 1password
brew install --cask android-file-transfer
brew install --cask azure-data-studio
brew install --cask caffeine
brew install --cask dbeaver-community
brew install --cask docker
brew install --cask dropbox
brew install --cask firefox
brew install --cask flux
brew install --cask google-chrome
brew install --cask iterm2
brew install --cask keka
brew install --cask keybase
brew install --cask microsoft-azure-storage-explorer
brew install --cask postman
brew install --cask qlcolorcode
brew install --cask qlmarkdown
brew install --cask qlstephen
brew install --cask quicklook-csv
brew install --cask quicklook-json
brew install --cask skitch
brew install --cask slack
brew install --cask spotify
brew install --cask visual-studio-code
brew install --cask whatsapp
brew install --cask zoomus

# Remove outdated versions from the cellar.
brew cleanup