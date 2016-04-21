#
# Setup jenv a Java env management tool
# http://www.jenv.be/
#

#!/bin/sh

set -e

# Configure PATH (for zsh)
echo 'export PATH="$HOME/.jenv/bin:$PATH"' >> ~/.zshrc
echo 'eval "$(jenv init -)"' >> ~/.zshrc

# Add JDKs
jenv add /Library/Java/JavaVirtualMachines/jdk1.7.0_80.jdk/Contents/Home
jenv add /Library/Java/JavaVirtualMachines/jdk1.8.0_74.jdk/Contents/Home
jenv rehash

# Use JDK7 as global default
jenv global oracle64-1.7.0.80

# Make maven aware of jenv
jenv enable-plugin maven

exit 0
