#
# Install gcloud sdk command line tools
#

#!/bin/sh

set -e

echo ""
echo "Installing Google Cloud SDK..."
curl https://sdk.cloud.google.com | bash

# Restart shell
exec -l $SHELL

# initialize
gcloud init

# Install GAE/GWT SDKs
# mkdir -p ~/libs
# pushd ~/libs

# echo ""
# echo "Downloading appengine-java-sdk-1.9.14..."
# wget https://storage.googleapis.com/appengine-sdks/featured/appengine-java-sdk-1.9.14.zip
# unzip appengine-java-sdk-1.9.14.zip

# echo ""
# echo "Downloading gwt-2.5.1..."
# wget http://google-web-toolkit.googlecode.com/files/gwt-2.5.1.zip
# unzip gwt-2.5.1.zip

popd

exit 0
