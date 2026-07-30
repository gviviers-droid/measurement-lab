#!/usr/bin/env bash
# Automated installer for the Internet Measurements Lab.
#
#   macOS / native Linux:  ./install.sh
#   Windows:                run install.ps1 in PowerShell first; it bootstraps
#                            WSL2 and re-runs this script there.
#
# What this does, by platform:
#   - Linux (native or inside WSL2, which reports as Linux too): installs
#     Podman, Containerlab and ttyd directly via the system package manager,
#     with a plain-binary fallback for distros without a suitable package
#     (e.g. immutable ones like Fedora CoreOS). No VM is needed: a real Linux
#     kernel is already present.
#   - macOS: Darwin has no Linux kernel at all, so Podman itself needs a
#     small Linux VM ("podman machine") to run containers in. This is the
#     one platform where that extra hop is unavoidable.
#
# Writes .measlab/runtime.env recording how later scripts (portal.sh,
# frontend/portal_server.py) should reach the lab: directly, or by hopping
# through `podman machine ssh`.

set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${DIR}"

MACHINE_NAME="podman-machine-default"
MACHINE_MEMORY_MB=4096
MACHINE_CPUS=4

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$1" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

OS="$(uname -s)"
case "${OS}" in
  Darwin) PLATFORM=macos ;;
  Linux)  PLATFORM=linux ;;
  *) die "Unsupported OS '${OS}'. On Windows, run install.ps1 in PowerShell (it uses WSL2, which reports as Linux from here)." ;;
esac
log "Detected platform: ${PLATFORM}"

# ---------------------------------------------------------------- Linux ----

pkg_install() {
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -qq && sudo apt-get install -y "$@"
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y "$@"
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Sy --noconfirm "$@"
  else
    return 1
  fi
}

install_podman_linux() {
  if command -v podman >/dev/null 2>&1; then
    log "Podman already installed"
  else
    log "Installing Podman"
    pkg_install podman || die "Could not install Podman automatically (no apt/dnf/pacman found). Install it manually: https://podman.io/docs/installation"
  fi

  # Our scripts call `docker exec` directly (matching the README/Containerlab
  # convention). On a Podman-only host that command doesn't exist unless a
  # compatibility shim is installed, so make sure one is.
  if ! command -v docker >/dev/null 2>&1; then
    log "Adding a docker -> podman compatibility alias"
    pkg_install podman-docker 2>/dev/null || {
      sudo ln -sf "$(command -v podman)" /usr/local/bin/docker
    }
  fi
}

install_containerlab() {
  if command -v containerlab >/dev/null 2>&1; then
    log "Containerlab already installed"
    return
  fi
  log "Installing Containerlab"
  if curl -sL https://get.containerlab.dev | sudo bash; then
    :
  else
    log "Package-based install didn't work (common on immutable distros); falling back to a plain binary"
    curl -sL https://get.containerlab.dev | sudo USE_PKG=false BIN_INSTALL_DIR=/usr/local/bin bash || true
    sudo mkdir -p /etc/containerlab
    sudo touch /etc/containerlab/suid_setup_done
  fi
  command -v containerlab >/dev/null 2>&1 || die "Containerlab install failed. See https://containerlab.dev/install/"
}

install_ttyd_linux() {
  if command -v ttyd >/dev/null 2>&1; then
    log "ttyd already installed"
    return
  fi
  log "Installing ttyd"
  if ! pkg_install ttyd 2>/dev/null; then
    log "ttyd not in this distro's repos; downloading a static binary from GitHub"
    arch="$(uname -m)"
    case "${arch}" in
      x86_64)  bin_arch=x86_64 ;;
      aarch64|arm64) bin_arch=aarch64 ;;
      *) die "No prebuilt ttyd binary for architecture '${arch}'. Install it manually: https://github.com/tsl0922/ttyd" ;;
    esac
    curl -sL "https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.${bin_arch}" -o /tmp/ttyd \
      && sudo install -m 755 /tmp/ttyd /usr/local/bin/ttyd
  fi
  command -v ttyd >/dev/null 2>&1 || die "ttyd install failed. See https://github.com/tsl0922/ttyd"
}

# ---------------------------------------------------------------- macOS ----

install_podman_macos() {
  command -v brew >/dev/null 2>&1 || die "Homebrew is required on macOS: https://brew.sh"
  if command -v podman >/dev/null 2>&1; then
    log "Podman already installed"
  else
    log "Installing Podman via Homebrew"
    brew install podman
  fi
}

install_ttyd_macos() {
  command -v ttyd >/dev/null 2>&1 && { log "ttyd already installed"; return; }
  log "Installing ttyd via Homebrew"
  brew install ttyd
}

setup_podman_machine_macos() {
  if podman machine list --format '{{.Name}}' 2>/dev/null | grep -qx "${MACHINE_NAME}"; then
    log "Podman machine '${MACHINE_NAME}' already exists"
    mem="$(podman machine inspect "${MACHINE_NAME}" --format '{{.Resources.Memory}}' 2>/dev/null || echo 0)"
    if [ "${mem}" -lt 3000 ] 2>/dev/null; then
      warn "The existing Podman machine has only ${mem}MiB RAM; 14 lab containers want ~${MACHINE_MEMORY_MB}MiB. Bump it yourself with:"
      warn "  podman machine stop && podman machine set --memory ${MACHINE_MEMORY_MB} && podman machine start"
      warn "(not done automatically since it stops any containers already running in it)"
    fi
    podman machine set --rootful "${MACHINE_NAME}" >/dev/null 2>&1 || true
  else
    log "Creating the Podman machine (${MACHINE_CPUS} CPUs, ${MACHINE_MEMORY_MB}MiB RAM, rootful)"
    podman machine init --cpus "${MACHINE_CPUS}" --memory "${MACHINE_MEMORY_MB}" --rootful "${MACHINE_NAME}"
  fi

  state="$(podman machine inspect "${MACHINE_NAME}" --format '{{.State}}' 2>/dev/null || echo stopped)"
  if [ "${state}" != "running" ]; then
    log "Starting the Podman machine"
    podman machine start "${MACHINE_NAME}"
  fi

  log "Installing Containerlab inside the Podman machine"
  podman machine ssh "${MACHINE_NAME}" -- '
    set -e
    if ! command -v containerlab >/dev/null 2>&1; then
      if ! curl -sL https://get.containerlab.dev | sudo bash; then
        curl -sL https://get.containerlab.dev | sudo USE_PKG=false BIN_INSTALL_DIR=/usr/local/bin bash || true
        sudo mkdir -p /etc/containerlab
        sudo touch /etc/containerlab/suid_setup_done
      fi
    fi
  '
}

# ------------------------------------------------------------- runtime -----

write_runtime_config() {
  mkdir -p .measlab
  if [ "${PLATFORM}" = macos ]; then
    cat > .measlab/runtime.env <<EOF
MEASLAB_HOP=podman-machine
MEASLAB_MACHINE=${MACHINE_NAME}
EOF
  else
    cat > .measlab/runtime.env <<EOF
MEASLAB_HOP=direct
EOF
  fi
  log "Wrote .measlab/runtime.env (hop=$( [ "${PLATFORM}" = macos ] && echo podman-machine || echo direct ))"
}

lab_already_deployed() {
  if [ "${PLATFORM}" = macos ]; then
    podman machine ssh "${MACHINE_NAME}" -- "sudo docker ps -a --format '{{.Names}}'" 2>/dev/null | grep -q '^clab-measlab-'
  else
    sudo docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q '^clab-measlab-'
  fi
}

deploy_lab() {
  if lab_already_deployed; then
    log "The lab is already deployed. Run 'sudo ./lab.sh down' first if you want install.sh to redeploy it, or 'sudo ./lab.sh check' to see its current state."
    return
  fi
  log "Deploying the lab (this can take a minute)"
  if [ "${PLATFORM}" = macos ]; then
    podman machine ssh "${MACHINE_NAME}" -- "sudo bash '${DIR}/lab.sh' up"
  else
    sudo bash "${DIR}/lab.sh" up
  fi
}

case "${PLATFORM}" in
  macos)
    install_podman_macos
    install_ttyd_macos
    setup_podman_machine_macos
    ;;
  linux)
    install_podman_linux
    install_containerlab
    install_ttyd_linux
    ;;
esac

write_runtime_config
deploy_lab

log "Done. Run ./portal.sh, then open http://localhost:8080"
