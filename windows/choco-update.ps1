## Run this script in Administrator powershell session ##
$username="aber9496"

Write-Host "Override Admin Environment Variables:"
Write-Host "-------------------------------------"
$env:APPDATA="C:\Users\$username\AppData\Roaming"
$env:LOCALAPPDATA="C:\Users\$username\AppData\Local"
$env:TEMP="C:\Users\$username\AppData\Local\Temp"
$env:TMP="C:\Users\$username\AppData\Local\Temp"
$env:USERNAME="$username"
$env:USERPROFILE="C:\Users\$username"

Write-Host "APPDATA=$env:APPDATA"
Write-Host "LOCALAPPDATA=$env:LOCALAPPDATA"
Write-Host "TEMP=$env:TEMP"
Write-Host "TMP=$env:TMP"
Write-Host "USERNAME=$env:USERNAME"
Write-Host "USERPROFILE=$env:USERPROFILE"
Write-Host ""
choco upgrade all -y