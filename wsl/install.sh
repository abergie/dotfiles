#!/bin/sh

## Setup shell for WSL
## Based on script from jldeen - https://github.com/jldeen/dotfiles/blob/wsl/configure.sh

echo "Updating package lists..."
sudo apt-get update
sudo apt-get upgrade -y

# zsh install
echo ''
echo "Installing zsh..."
echo ''
sudo apt install zsh -y

# Installing git completion
echo ''
echo "Installing git and bash-completion..."
sudo apt-get install git bash-completion -y

echo ''
echo "Configuring git-completion..."
GIT_VERSION=`git --version | awk '{print $3}'`
URL="https://raw.github.com/git/git/v$GIT_VERSION/contrib/completion/git-completion.bash"
echo ''
echo "Downloading git-completion for git version: $GIT_VERSION..."
if ! curl "$URL" --silent --output "$HOME/.git-completion.bash"; then
	echo "ERROR: Couldn't download completion script. Make sure you have a working internet connection." && exit 1
fi

# oh-my-zsh install
echo ''
echo "Installing oh-my-zsh..."
echo ''
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

# oh-my-zsh plugin install
echo ''
echo "Installing oh-my-zsh plugins..."
echo ''
git clone https://github.com/zsh-users/zsh-completions ~/.oh-my-zsh/custom/plugins/zsh-completions
git clone git://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh/zsh-syntax-highlighting

# # powerlevel9k oh-my-zsh theme install
# echo ''
# echo "Installing powerlevel9k..."
# echo ''
# git clone https://github.com/bhilburn/powerlevel9k.git ~/.oh-my-zsh/custom/themes/powerlevel9k

# # vimrc vundle install
# echo ''
# echo "Installing vundle..."
# echo ''
# git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim

# # Pathogen install
# echo ''
# echo "Installing Pathogen..."
# echo ''
# mkdir -p ~/.vim/autoload ~/.vim/bundle && \
# 	curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim

# # Nerdtree for vim install
# echo ''
# echo "Installing Nerdtree for Vim..."
# echo ''
# git clone https://github.com/scrooloose/nerdtree.git ~/.vim/bundle/nerdtree

# # Vim color scheme install
# echo ''
# echo "Installing vim wombat color scheme..."
# echo ''
# git clone https://github.com/sheerun/vim-wombat-scheme.git ~/.vim/colors/wombat 
# mv ~/.vim/colors/wombat/colors/* ~/.vim/colors/

# # Midnight commander install
echo ''
echo "Installing Midnight commander..."
echo ''
sudo apt-get install mc -y

# Install pyenv - https://github.com/pyenv/pyenv | https://github.com/pyenv/pyenv-installer
echo ''
echo "Installing pyenv..."
echo ''
curl -L https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash
echo 'export PATH="/home/bergie/.pyenv/bin:$PATH"' >> ~/.zshrc
echo 'eval "$(pyenv init -)"' >> ~/.zshrc
echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.zshrc
source ~/.zshrc
pyenv update

# Speedtest-cli, pip and jq install
echo ''
echo "Installing Speedtest-cli, pip, tmux and jq..."
echo ''
sudo apt-get install jq tmux python-pip -y
sudo pip install --upgrade pip
sudo pip install speedtest-cli

# Bash color scheme
echo ''
echo "Installing solarized dark WSL color scheme..."
echo ''
wget https://raw.githubusercontent.com/seebi/dircolors-solarized/master/dircolors.256dark
mv dircolors.256dark .dircolors

# Pull down personal dotfiles
# echo ''
# read -p "Do you want to use jldeen's dotfiles? y/n" -n 1 -r
# echo    # (optional) move to a new line
# if [[ $REPLY =~ ^[Yy]$ ]]
# then
#     echo ''
# 	echo "Now pulling down jldeen dotfiles..."
# 	git clone https://github.com/jldeen/dotfiles.git ~/.dotfiles
# 	echo ''
# 	cd $HOME/.dotfiles && echo "switched to .dotfiles dir..."
# 	echo ''
# 	echo "Checking out wsl branch..." && git checkout wsl
# 	echo ''
# 	echo "Now configuring symlinks..." && $HOME/.dotfiles/script/bootstrap
#     if [[ $? -eq 0 ]]
#     then
#         echo "Successfully configured your environment with jldeen's dotfiles..."
#     else
#         echo "jldeen's dotfiles were not applied successfully..." >&2
# fi
# else 
echo ''
echo "Setting defaults for .zshrc and .bashrc..."
echo ''
echo "source $HOME/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> ${ZDOTDIR:-$HOME}/.zshrc && echo "added zsh-syntax-highlighting to .zshrc..."
echo ''
echo "source $HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" >> ${ZDOTDIR:-$HOME}/.zshrc && echo "added zsh-autosuggestions to .zshrc..."
echo ''
echo "source $HOME/.git-completion.bash" >> ${ZDOTDIR:-$HOME}/.bashrc && echo "added git-completion to .bashrc..."	
# fi

# Install vsts-cli
echo ''
echo "Installing VSTS CLI..."
# prerequisites
sudo apt-get install libssl-dev libffi-dev python3-dev build-essential -y
curl -L https://aka.ms/install-vsts-cli | bash

# Install azure-cli
echo ''
echo "Installing Azure CLI..."
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | \
    sudo tee /etc/apt/sources.list.d/azure-cli.list

sudo apt-key adv --keyserver packages.microsoft.com --recv-keys 52E16F86FEE04B979B07E28DB02C46DF417A0893
sudo apt-get install apt-transport-https
sudo apt-get update
sudo apt-get install azure-cli -y

if [[ $? -eq 0 ]]
then
    echo "Successfully installed Azure CLI 2.0."
else
    echo "[Warning] Azure CLI not installed successfully." >&2
fi


# Set default shell to zsh
echo ''
echo "Now setting default shell to zsh..."
chsh -s $(which zsh)

if [[ $? -eq 0 ]]
then
    echo "Successfully set your default shell to zsh..."
else
    echo "[Warning] Default shell not set successfully..." >&2
fi