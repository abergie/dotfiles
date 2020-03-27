#!/bin/sh

sudo snap install spotify
sudo snap install slack --classic
sudo snap install code --classic

curl --remote-name https://prerelease.keybase.io/keybase_amd64.deb
sudo apt install ./keybase_amd64.deb
run_keybase

ssh-keygen -t rsa -b 4096 -C "email@example.com"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa
