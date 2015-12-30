#
# Install atom packages
#

#!/bin/sh

set -e

packages=(
  sort-lines
  linter
  linter-jshint
  atom-beautify
)

# Check if apm (Atom Package Manager) is installed
if test $(apm help install); then
  # install packages
  echo "Installing Atom Packages..."
  brew cask install ${packages[@]}
fi

exit 0
