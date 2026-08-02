# Windows bootstrap for the Internet Measurements Lab.
#
# Run this in PowerShell from the cloned repo folder:
#   .\install.ps1
#
# Windows has no Linux kernel and no POSIX shell, so this script only does
# one thing: make sure WSL2 with a Linux distro is available, then hand off
# to install.sh running inside it. install.sh itself treats that distro
# exactly like native Linux (no Podman-machine VM needed -- WSL2 already
# provides a real Linux kernel).

$ErrorActionPreference = "Stop"

function Test-WSLReady {
    try {
        $distros = wsl.exe -l -q 2>$null
        return ($LASTEXITCODE -eq 0 -and ($distros | Where-Object { $_.Trim() -ne "" }))
    } catch {
        return $false
    }
}

if (-not (Test-WSLReady)) {
    Write-Host "WSL2 isn't set up yet. Installing WSL2 with Ubuntu..." -ForegroundColor Cyan
    try {
        wsl.exe --install -d Ubuntu
    } catch {
        Write-Host ""
        Write-Host "Couldn't run 'wsl.exe --install'. This needs Windows 10 (2004+) or" -ForegroundColor Red
        Write-Host "Windows 11 with the Windows Subsystem for Linux feature available." -ForegroundColor Red
        Write-Host "Install WSL2 manually (https://learn.microsoft.com/windows/wsl/install)" -ForegroundColor Red
        Write-Host "then re-run this script, or use the GitHub Codespaces / VS Code Dev" -ForegroundColor Red
        Write-Host "Container route from the README instead." -ForegroundColor Red
        Write-Host ""
        Write-Host "Underlying error: $_" -ForegroundColor DarkGray
        exit 1
    }
    Write-Host ""
    Write-Host "WSL2/Ubuntu is installing. If this is the first time WSL has been used on" -ForegroundColor Yellow
    Write-Host "this machine, Windows may need a restart, and Ubuntu may ask you to create" -ForegroundColor Yellow
    Write-Host "a username/password on first launch. Once that's done, re-run:" -ForegroundColor Yellow
    Write-Host "  .\install.ps1" -ForegroundColor Yellow
    exit 0
}

Write-Host "Running the lab installer inside WSL2 (Linux)..." -ForegroundColor Cyan

$repoPathWindows = (Get-Location).Path
$repoPathWsl = (wsl.exe wslpath -a "$repoPathWindows").Trim()

wsl.exe bash -lc "cd '$repoPathWsl' && chmod +x ./install.sh && ./install.sh"

Write-Host ""
Write-Host "Done. From inside WSL2 (run 'wsl' to get a shell), start the portal with:" -ForegroundColor Green
Write-Host "  cd '$repoPathWsl' && ./portal.sh" -ForegroundColor Green
Write-Host "then open http://localhost:8080 in your Windows browser." -ForegroundColor Green
