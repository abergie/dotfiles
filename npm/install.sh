#
# Install Homebrew packages / npm correctly for OSX
#

#!/bin/sh

set -e

# npm default global packages
packages=(
  bower
  forever
  grunt-cli
  gulp
  http-server
  jasmine
  jshint
  node-inspector
  nodemon
  uglify-js
  yo
)

npm install -g ${packages[@]}

exit 0
