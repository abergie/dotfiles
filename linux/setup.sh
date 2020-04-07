#!/bin/sh

sudo apt-get update && sudo apt-get upgrade -y

sudo apt install git zsh curl xclip
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"


# Dislable capslock
setxkbmap -option "caps:none"
setxkbmap -option "shift:both_capslock"