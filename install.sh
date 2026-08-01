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

pkg_remove() {
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get remove -y "$@"
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf remove -y "$@"
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -R --noconfirm "$@"
  else
    return 1
  fi
}

MIN_PODMAN_MAJOR=4  # Containerlab needs the >=4.0 Podman API

podman_major_version() {
  # No `grep | head`: piping into head can SIGPIPE the grep stage once head
  # exits, which under `pipefail` makes the whole pipeline report failure
  # even though the right value was already captured. awk | cut both read
  # their entire input, so neither triggers that.
  local v
  v="$(podman --version 2>/dev/null)" || return 1
  printf '%s\n' "${v}" | awk '{print $3}' | cut -d. -f1
}

# Some distros (Ubuntu 22.04's default repo included: Podman 3.4.4) ship a
# Podman too old for Containerlab's API requirements, and there's no reliable
# third-party apt repo for a newer one anymore (the old Kubic OBS repo that
# used to be recommended for this is discontinued). Homebrew on Linux carries
# a current Podman with prebuilt bottles, so fall back to it when needed --
# the same tool this installer already uses on macOS.
#
# This *replaces* the distro's Podman rather than letting both coexist:
# mixing them is a real mess in practice (confirmed by testing this on a
# fresh Ubuntu 22.04 VM) -- the old crun/podman binaries linger at standard
# paths like /usr/bin/podman and /usr/bin/crun that podman's own runtime
# search and the docker-CLI shim both hardcode, so a newer podman ends up
# silently invoking the ancient crun anyway ("crun: unknown version
# specified"), and old + new podman argue over the on-disk storage format
# (BoltDB vs SQLite). Called immediately after `pkg_install podman` and
# before anything is deployed, so there's nothing running yet to disrupt.
install_podman_via_linuxbrew() {
  log "Removing the distro's Podman first (avoids old/new binaries conflicting)"
  sudo systemctl disable --now podman.socket podman.service 2>/dev/null || true
  pkg_remove podman podman-docker crun 2>/dev/null || true
  sudo rm -rf /var/lib/containers
  # Some distros' package removal masks the unit names (symlinks them to
  # /dev/null) as a matter of course; unmask before we write our own units
  # with the same names below, or they'd silently write into /dev/null.
  sudo systemctl unmask podman.socket podman.service 2>/dev/null || true

  log "Installing Homebrew (Linuxbrew) to get a current Podman"
  pkg_install build-essential procps curl file git >/dev/null 2>&1 || true
  if [ ! -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  # Persist brew on PATH for future login shells too
  grep -q linuxbrew/.linuxbrew/bin/brew ~/.profile 2>/dev/null || \
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.profile

  log "Installing Podman via Homebrew"
  brew install podman
  BREW_PODMAN="$(command -v podman)"

  # `sudo`, systemd services, and the docker shim below don't see Linuxbrew's
  # PATH, so point everything at the brew binary by its full path instead of
  # relying on PATH resolution.
  sudo ln -sf "${BREW_PODMAN}" /usr/local/bin/podman
  hash -r

  # Point Podman's own OCI runtime search at Linuxbrew's crun explicitly --
  # otherwise it falls back to a system search path list that doesn't include
  # Linuxbrew's directory and can silently pick up a stale runtime.
  BREW_CRUN="$(dirname "${BREW_PODMAN}")/crun"
  sudo mkdir -p /etc/containers
  if ! grep -q "engine.runtimes" /etc/containers/containers.conf 2>/dev/null; then
    printf '\n[engine.runtimes]\ncrun = ["%s"]\n' "${BREW_CRUN}" | sudo tee -a /etc/containers/containers.conf >/dev/null
  fi

  # Recreate systemd's rootful Podman API socket/service, now pointing at the
  # brew binary (with its own bin dir first on PATH, for the same reason).
  sudo tee /etc/systemd/system/podman.socket >/dev/null <<'EOF'
[Unit]
Description=Podman API Socket
Documentation=man:podman-system-service(1)

[Socket]
ListenStream=%t/podman/podman.sock
SocketMode=0660

[Install]
WantedBy=sockets.target
EOF
  sudo tee /etc/systemd/system/podman.service >/dev/null <<EOF
[Unit]
Description=Podman API Service
Requires=podman.socket
After=podman.socket
Documentation=man:podman-system-service(1)
StartLimitIntervalSec=0

[Service]
Type=exec
KillMode=process
Environment=LOGGING="--log-level=info"
Environment=PATH=$(dirname "${BREW_PODMAN}"):/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=${BREW_PODMAN} \$LOGGING system service

[Install]
WantedBy=default.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable --now podman.socket
}

podman_is_linuxbrew() {
  # command -v gives the path as found on PATH, which may just be the
  # /usr/local/bin/podman symlink install_podman_via_linuxbrew creates --
  # resolve it to its real target before pattern-matching, or this always
  # looks like a plain, non-Linuxbrew path.
  case "$(readlink -f "$(command -v podman 2>/dev/null)" 2>/dev/null)" in
    */linuxbrew/*) return 0 ;;
    *) return 1 ;;
  esac
}

install_podman_linux() {
  if command -v podman >/dev/null 2>&1; then
    log "Podman already installed ($(podman --version))"
  else
    log "Installing Podman"
    pkg_install podman || die "Could not install Podman automatically (no apt/dnf/pacman found). Install it manually: https://podman.io/docs/installation"
  fi

  major="$(podman_major_version || echo 0)"
  if ! podman_is_linuxbrew && [ "${major:-0}" -lt "${MIN_PODMAN_MAJOR}" ] 2>/dev/null; then
    warn "This distro's Podman ($(podman --version 2>/dev/null)) is older than Containerlab needs."
    install_podman_via_linuxbrew
  fi

  # Our scripts call `docker exec` directly (matching the README/Containerlab
  # convention). Make sure that command exists and points at whichever podman
  # we're actually using. Skip the podman-docker *package* if we're on the
  # Linuxbrew podman (this run or a previous one) -- that package depends on
  # (and would silently reinstall) the distro's own podman, undoing that
  # removal and reintroducing the exact conflict the fallback avoids.
  log "Adding a docker -> podman compatibility alias"
  podman_path="$(command -v podman)"
  if podman_is_linuxbrew || ! pkg_install podman-docker 2>/dev/null || [ ! -x /usr/bin/podman ]; then
    sudo tee /usr/local/bin/docker >/dev/null <<EOF
#!/bin/sh
exec ${podman_path} "\$@"
EOF
    sudo chmod +x /usr/local/bin/docker
  fi

  # If podman.socket exists (systemd-managed rootful podman) but isn't
  # actually answering, Containerlab can't reach it at all -- this can be
  # true independently of anything above, e.g. after a VM reboot, or if a
  # previous run's failure left it in systemd's "failed" state, which
  # doesn't clear on its own. Reset and restart it defensively every time;
  # this is a no-op if it's already healthy.
  if systemctl list-unit-files podman.socket >/dev/null 2>&1; then
    sudo systemctl reset-failed podman.socket podman.service 2>/dev/null || true
    sudo systemctl restart podman.socket 2>/dev/null || true
  fi
  sudo podman ps >/dev/null 2>&1 || warn "Podman doesn't seem to be responding yet; the deploy step below may fail. Try: sudo systemctl status podman.socket"
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
