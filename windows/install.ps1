## Powershell admin console needed ##
Start-Process PowerShell -Verb RunAs

# Disable PS Beep on Backspace
Write-Output "Disabling PS Beep on Backspace..."
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
if (!(Test-Path -Path "$Profile")) {New-Item -ItemType File -Path "$Profile" -Force}
Add-Content -Value "Set-PSReadlineOption -BellStyle None" -Path "$Profile"

# Install WSL
Write-Output "Installing WSL..."
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

# Download and install Ubuntu
Write-Output "Downloading Ubuntu..."
Invoke-WebRequest -Uri https://aka.ms/wsl-ubuntu-1604 -OutFile "$HOME\Ubuntu.zip" -UseBasicParsing
Expand-Archive "$HOME\Ubuntu.zip" "$HOME\Ubuntu"

# Install Chocolatey
Write-Output "Installing Chocolatey..."
Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Chocolatey packages
$packages = @(
    "7zip"
    "docker"
    "dropbox"
    "etcher"
    "firefox"
    "git"
    "googlechrome"
    "hackfont"
    "jdk8"
    "keepassx"
    "packer"
    "postman"
    "python"
    "python3"
    "screentogif"
    "spotify"
    "terraform"
    "vscode"
    "whatsapp"
    "wsltty"
)
Write-Output "Installing Chocolatey packages..."
ForEach-Object -InputObject $packages { choco install $_ -y }

# Refresh powershell env
refreshenv

# Download and Install VSTS CLI
Write-Output "Installing vsts-cli..."
$vsts_installer_path = "$TEMP\vsts-cli-installer.msi"
Invoke-WebRequest -Uri "https://aka.ms/vsts-cli-windows-installer" -OutFile $vsts_installer_path
Start-Process msiexec.exe -Wait -ArgumentList '/I $vsts_installer_path /quiet'
Remove-Item $vsts_installer_path

# Install AzureRM powershell tools
Write-Output "Installing AzureRM powershell tools..."
Install-Module PowerShellGet -Force
Install-Module -Name AzureRM -AllowClobber

# Import AzureRM in local user powershell
# TODO


