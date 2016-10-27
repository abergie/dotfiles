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

echo "Installing Atom Packages..."
apm install ${packages[@]}


exit 0
