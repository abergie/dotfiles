#
# Application installer (via brew-cask)
#

#!/bin/sh

set -e

# Apps
apps=(
  android-file-transfer
  caffeine
  docker
  dropbox
  firefox
  flux
  font-clear-sans
  font-hack
  font-m-plus
  font-roboto
  google-chrome
  handbrake
  iterm2
  keepassx
  keka
  postman
  qlcolorcode
  qlmarkdown
  qlstephen
  quicklook-csv
  quicklook-json
  skitch
  slack
  spotify
  virtualbox
  visual-studio-code
  vlc
  whatsapp
  zoomus
)

# fonts
fonts=(
  font-clear-sans
  font-hack
  font-m-plus
  font-roboto
)

# Specify the location of the apps
# appdir="/Applications"

# Check if homebrew is installed
if test ! $(which brew); then
  echo "Installing homebrew..."
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

# Install homebrew-cask
echo "Tapping casks..."

# Tap alternative versions
brew tap caskroom/versions

# Tap the fonts
brew tap caskroom/fonts

# install apps
echo "Installing apps..."
# brew cask install --appdir=$appdir ${apps[@]}
brew cask install ${apps[@]}

# install fonts
echo "Installing fonts..."
brew cask install ${fonts[@]}

# Tidy up
brew cask cleanup

exit 0
