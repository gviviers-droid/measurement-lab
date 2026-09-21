#!/usr/bin/env bash
# Clean uninstaller for the Internet Measurements Lab.
# Tears down virtual networks, reclaims disk space & RAM,
# removes container images, and cleans up virtualization resources.
#
#   macOS / native Linux / WSL2:  ./uninstall.sh
#   Windows (PowerShell):         .\uninstall.ps1
#   Or via lab controller:        ./lab.sh uninstall

set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${DIR}"

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$1" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

FORCE=0
for arg in "$@"; do
  case "${arg}" in
    -y|--yes|--force) FORCE=1 ;;
    -h|--help)
      echo "Usage: $0 [-y|--yes|--force]"
      echo "Safely removes the lab, containers, generated files, and frees RAM/disk space."
      exit 0
      ;;
  esac
done

printf '\033[1;31m=================================================================\033[0m\n'
printf '\033[1;31m         Internet Measurements Lab - Clean Uninstaller           \033[0m\n'
printf '\033[1;31m=================================================================\033[0m\n\n'
printf 'This will safely remove:\n'
printf '  - All 14 running lab containers and virtual network bridges\n'
printf '  - Web portal processes (portal_server and ttyd terminals)\n'
printf '  - Generated runtime directories (clab-measlab/, .measlab/)\n'
printf '  - Measurement log outputs and temporary files\n'
printf '  - Platform resources (e.g. Podman machine VM on macOS to reclaim RAM/disk)\n\n'

if [ "${FORCE}" -ne 1 ]; then
  read -rp "Are you sure you want to uninstall the lab? [y/N] " confirm
  if [[ ! "${confirm:-}" =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    exit 0
  fi
fi

# 1. Stop background portal processes
log "Stopping portal and terminal background processes..."
pkill -f "python3 frontend/portal_server.py" 2>/dev/null || true
pkill -f "ttyd -p 768" 2>/dev/null || true

# 2. Check platform and runtime configuration
PLATFORM="$(uname -s)"
MEASLAB_HOP="direct"
MEASLAB_MACHINE="podman-machine-default"
if [ -f .measlab/runtime.env ]; then
  . .measlab/runtime.env
fi

# 3. Tear down virtual network containers
log "Tearing down lab network containers..."
if [ "${PLATFORM}" = "Darwin" ] && [ "${MEASLAB_HOP}" = "podman-machine" ]; then
  if podman machine list --format '{{.Name}}' 2>/dev/null | grep -qx "${MEASLAB_MACHINE}"; then
    state="$(podman machine inspect "${MEASLAB_MACHINE}" --format '{{.State}}' 2>/dev/null || echo stopped)"
    if [ "${state}" = "running" ]; then
      podman machine ssh "${MEASLAB_MACHINE}" -- "sudo containerlab destroy -t '${DIR}/topology.clab.yml' --runtime podman" 2>/dev/null || true
    fi
  fi
else
  if command -v containerlab >/dev/null 2>&1; then
    sudo containerlab destroy -t "${DIR}/topology.clab.yml" --runtime podman 2>/dev/null || true
  fi
fi

# 4. Clean up generated local runtime files
log "Cleaning up generated directories and files..."
rm -rf clab-measlab/ .measlab/ 2>/dev/null || sudo rm -rf clab-measlab/ .measlab/ 2>/dev/null || true
rm -f measurements.csv baseline.txt baseline6.txt busy.txt rtt.txt target1.txt target2.txt 2>/dev/null || true

# 5. Platform-specific cleanups
if [ "${PLATFORM}" = "Darwin" ]; then
  # Check for Podman machine VM
  if podman machine list --format '{{.Name}}' 2>/dev/null | grep -qx "${MEASLAB_MACHINE}"; then
    echo
    printf '\033[1;33mThe Podman machine VM ("%s") is currently installed.\033[0m\n' "${MEASLAB_MACHINE}"
    printf 'It reserves 4 vCPUs, 4 GiB of RAM, and ~5-10 GiB of disk space.\n'
    
    RM_VM=""
    if [ "${FORCE}" -eq 1 ]; then
      RM_VM="y"
    else
      read -rp "Remove the Podman machine VM to reclaim its RAM and disk space? [Y/n] " RM_VM
    fi

    if [[ ! "${RM_VM:-y}" =~ ^[Nn]$ ]]; then
      log "Stopping and removing Podman machine VM '${MEASLAB_MACHINE}'..."
      podman machine stop "${MEASLAB_MACHINE}" 2>/dev/null || true
      podman machine rm -f "${MEASLAB_MACHINE}" 2>/dev/null || true
      log "Podman machine VM removed! Reclaimed 4 GiB RAM and disk space."
    fi
  fi

  # Offer Homebrew packages cleanup
  echo
  RM_BREW=""
  if [ "${FORCE}" -ne 1 ]; then
    printf 'Homebrew packages (podman, ttyd) are installed on macOS.\n'
    read -rp "Would you also like to uninstall podman and ttyd via Homebrew? [y/N] " RM_BREW
  fi
  if [[ "${RM_BREW:-}" =~ ^[Yy]$ ]]; then
    log "Uninstalling Homebrew packages..."
    brew uninstall podman ttyd 2>/dev/null || true
  fi

elif [ "${PLATFORM}" = "Linux" ]; then
  # Reclaim container image disk space
  echo
  RM_IMAGES=""
  if [ "${FORCE}" -eq 1 ]; then
    RM_IMAGES="y"
  else
    read -rp "Remove downloaded container images (FRR, multitool) to free ~3-5 GB disk space? [Y/n] " RM_IMAGES
  fi
  if [[ ! "${RM_IMAGES:-y}" =~ ^[Nn]$ ]]; then
    log "Removing cached lab container images..."
    sudo podman rmi quay.io/frrouting/frr:10.2.1 ghcr.io/srl-labs/network-multitool 2>/dev/null || true
    sudo docker rmi quay.io/frrouting/frr:10.2.1 ghcr.io/srl-labs/network-multitool 2>/dev/null || true
  fi

  # Clean docker-shim if we created it
  if [ -f /usr/local/bin/docker ] && grep -q "podman" /usr/local/bin/docker 2>/dev/null; then
    sudo rm -f /usr/local/bin/docker
  fi

  # Offer tool removal
  echo
  RM_TOOLS=""
  if [ "${FORCE}" -ne 1 ]; then
    read -rp "Would you also like to remove the Containerlab and ttyd binaries? [y/N] " RM_TOOLS
  fi
  if [[ "${RM_TOOLS:-}" =~ ^[Yy]$ ]]; then
    log "Removing Containerlab and ttyd..."
    sudo rm -f /usr/local/bin/containerlab /usr/local/bin/ttyd 2>/dev/null || true
    sudo rm -rf /etc/containerlab 2>/dev/null || true
  fi
fi

echo
printf '\033[1;32m=================================================================\033[0m\n'
printf '\033[1;32m        Internet Measurements Lab uninstalled successfully!      \033[0m\n'
printf '\033[1;32m=================================================================\033[0m\n\n'
printf 'All containers, virtual networks, and temporary runtime files have been removed.\n'
printf 'If you no longer need the lab materials, you can safely delete this folder:\n'
printf '  rm -rf "%s"\n\n' "${DIR}"
