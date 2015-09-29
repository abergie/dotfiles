#
# Application installer (via brew-cask)
#

#!/bin/sh

set -e

# Apps
apps=(
  dropbox
  google-chrome
  google-chrome-canary
  google-drive
  firefox
  firefoxdeveloperedition
  spotify
  flash
  atom
  sublime-text3
  virtualbox
  iterm2
  flux
  skitch
  vlc
  qlcolorcode
  qlstephen
  qlmarkdown
  quicklook-json
  quicklook-csv
  betterzipql
  skype
  transmission
  keka
  android-file-transfer
  caffeine
)
  # bittorrent-sync

# fonts
fonts=(
  font-m-plus
  font-clear-sans
  font-roboto
  font-hack
)

# Specify the location of the apps
appdir="/Applications"

main() {

  # Check if homebrew is installed
  homebrew

  # Install homebrew-cask
  echo "Installing cask..."
  brew tap phinze/homebrew-cask
  brew install phinze/cask/brew-cask

  # Tap alternative versions
  brew tap caskroom/versions

  # Tap the fonts
  brew tap caskroom/fonts

  # install apps
  echo "Installing apps..."
  brew cask install --appdir=$appdir ${apps[@]}

  # install fonts
  echo "Installing fonts..."
  brew cask install ${fonts[@]}

  cleanup
}

homebrew() {
  if test ! $(which brew); then
    echo "Installing homebrew..."
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  fi
}

cleanup() {
  brew cleanup
}

main "$@"
exit 0
