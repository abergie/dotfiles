#
# Install xcode command line tools (Without the full Xcode.app)
# http://osxdaily.com/2014/02/12/install-command-line-tools-mac-os-x/
#

#!/bin/sh

set -e

sudo -v

echo ""
echo "Installing XCode command line tools..."
echo "(Will need to accept Terms now)"
xcode-select --install

exit 0
