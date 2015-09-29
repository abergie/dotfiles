#
# Install gcloud sdk command line tools
#

#!/bin/sh

set -e

echo ""
echo "Installing Google cloud sdk command line tools..."
curl https://sdk.cloud.google.com | bash

# Install GAE/GWT SDKs
mkdir -p ~/libs
pushd ~/libs

echo ""
echo "Downloading appengine-java-sdk-1.9.14..."
wget https://storage.googleapis.com/appengine-sdks/featured/appengine-java-sdk-1.9.14.zip
unzip appengine-java-sdk-1.9.14.zip

echo ""
echo "Downloading gwt-2.5.1..."
wget http://google-web-toolkit.googlecode.com/files/gwt-2.5.1.zip
unzip gwt-2.5.1.zip

popd

exit 0
