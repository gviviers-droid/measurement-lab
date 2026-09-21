#!/usr/bin/env bash
# Update the Internet Measurements Lab to the latest version.
#
#   macOS / native Linux / WSL2:  ./update.sh
#   Windows (PowerShell):         .\update.ps1
#
# Works seamlessly for BOTH Git clones and ZIP downloads.

set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${DIR}"

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$1" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

log "Checking for updates..."

if [ -d .git ] && command -v git >/dev/null 2>&1; then
  log "Updating via Git..."
  git pull origin main || git pull
else
  log "Updating from latest GitHub repository archive (ZIP)..."
  TMP_ZIP="/tmp/measlab-update-$$.zip"
  TMP_DIR="/tmp/measlab-update-$$"
  mkdir -p "${TMP_DIR}"

  curl -fsSL "https://github.com/gviviers-droid/measurement-lab/archive/refs/heads/main.zip" -o "${TMP_ZIP}"
  unzip -q -o "${TMP_ZIP}" -d "${TMP_DIR}"

  # Copy updated files over current directory (preserving .measlab/ and local state)
  cp -R "${TMP_DIR}"/measurement-lab-main/* "${DIR}/"
  [ -f "${TMP_DIR}"/measurement-lab-main/.gitignore ] && cp "${TMP_DIR}"/measurement-lab-main/.gitignore "${DIR}/" 2>/dev/null || true

  rm -rf "${TMP_DIR}" "${TMP_ZIP}"
fi

# Ensure executable permissions on all shell scripts
chmod +x ./*.sh ./scripts/*.sh 2>/dev/null || true

log "Lab files updated successfully!"

# Check if lab containers are currently running
IS_DEPLOYED=0
if [ -f .measlab/runtime.env ]; then
  . .measlab/runtime.env
  if [ "${MEASLAB_HOP:-direct}" = "podman-machine" ] && [ "$(uname -s)" = "Darwin" ]; then
    podman machine ssh "${MEASLAB_MACHINE:-podman-machine-default}" -- "sudo docker ps -a --format '{{.Names}}'" 2>/dev/null | grep -q '^clab-measlab-' && IS_DEPLOYED=1 || true
  else
    sudo docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q '^clab-measlab-' && IS_DEPLOYED=1 || true
  fi
fi

if [ "${IS_DEPLOYED}" -eq 1 ]; then
  echo
  printf '\033[1;33mNetwork containers are currently running.\033[0m\n'
  printf 'If this update changed network topology or router configurations,\n'
  printf 'the containers should be restarted (takes ~20 seconds; container images are cached).\n'
  
  RELOAD=""
  if [ -t 0 ]; then
    read -rp "Would you like to restart the lab containers now? [y/N] " RELOAD
  fi

  if [[ "${RELOAD:-}" =~ ^[Yy]$ ]]; then
    log "Restarting lab containers..."
    if [ "$(uname -s)" = "Darwin" ]; then
      ./lab.sh down && ./lab.sh up
    else
      sudo ./lab.sh down && sudo ./lab.sh up
    fi
  else
    echo "To restart containers manually later if needed, run: ./lab.sh down && ./lab.sh up"
  fi
fi

echo
log "Update complete! If the Control Portal (./portal.sh) is running, restart it (Ctrl-C, then ./portal.sh) to see the changes."
printf '\033[1;32m✓\033[0m Note: Your browser task checkboxes and notes are preserved in localStorage.\n\n'
