## Powershell admin console needed ##

# Disable PS Beep on Backspace
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
if (!(Test-Path -Path "$Profile")) {New-Item -ItemType File -Path "$Profile" -Force}
Add-Content -Value "Set-PSReadlineOption -BellStyle None" -Path "$Profile"

# Install WSL
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
#TODO - Windows store Ubuntu install

# Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Chocolatey packages
@(
    git
    visualstudiocode
    keepassx
    dropbox
    spotify
    firefox
    screentogif
    wsltty
    7zip
    jdk8
    python
    docker
)
choco install {@0} -y
# Refresh powershell env
refreshenv

# Install VSTS CLI
# TODO

# Install AzureRM powershell tools
Install-Module PowerShellGet -Force
Install-Module -Name AzureRM -AllowClobber

# TODO Import AzureRM in local user powershell


