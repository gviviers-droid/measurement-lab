# Windows bootstrap to update the Internet Measurements Lab inside WSL2.
#
# Run this in PowerShell from the lab folder:
#   .\update.ps1

$ErrorActionPreference = "Stop"

$repoPathWindows = (Get-Location).Path
$repoPathWsl = (wsl.exe wslpath -a "$repoPathWindows").Trim()

Write-Host "Updating Internet Measurements Lab inside WSL2..." -ForegroundColor Cyan
wsl.exe bash -lc "cd '$repoPathWsl' && chmod +x ./update.sh && ./update.sh"
