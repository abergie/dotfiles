#
# Setup Git repos for development
#

#!/bin/sh

set -e

# try connecting to github
echo ""
echo "Testing connection to GitHub..."
ssh -T git@github.com
# manual prompt for yes/no autoprompt if not known_hosts.

# create our code directory
mkdir -p ~/code
pushd ~/code

# Clone our repos
echo ""
echo "Cloning repo/name..."
git clone git@github.com:abergie/repo.git

popd

exit 0
