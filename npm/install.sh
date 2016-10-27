#
# Install nvm to manage node and npm
#

#!/bin/sh

set -e

# Install nvm to manage node versions
brew update
brew install nvm

echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.zshrc
echo '. "/usr/local/opt/nvm/nvm.sh"' >> ~/.zshrc

# install node and npm (LTS version)
nvm install --lts node

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
