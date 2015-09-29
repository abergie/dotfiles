#
# Install Homebrew packages / npm correctly for OSX
#

#!/bin/sh

set -e

# npm default global packages
packages=(
  grunt-cli
  http-server
  uglify-js
  jshint
  yo
  bower
  node-inspector
  forever
  nodemon
)

npm install -g ${packages[@]}
