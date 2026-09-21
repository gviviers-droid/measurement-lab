# Windows bootstrap to uninstall the Internet Measurements Lab inside WSL2.
#
# Run this in PowerShell from the lab folder:
#   .\uninstall.ps1

$ErrorActionPreference = "Stop"

$repoPathWindows = (Get-Location).Path
$repoPathWsl = (wsl.exe wslpath -a "$repoPathWindows").Trim()

Write-Host "Uninstalling Internet Measurements Lab inside WSL2..." -ForegroundColor Yellow
wsl.exe bash -lc "cd '$repoPathWsl' && chmod +x ./uninstall.sh && ./uninstall.sh $args"
