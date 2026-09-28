#!/usr/bin/env bash
# Run this on your own machine (not inside the Containerlab VM/devcontainer):
# it serves the activity frontend, the lab control API, and one browser
# terminal per learner-accessible node (r1, r2, r3, host1).
#
#   ./portal.sh        start everything, Ctrl-C to stop
#
# Requires: python3, ttyd (brew install ttyd / apt install ttyd)
# Run ./install.sh first if you haven't -- it writes .measlab/runtime.env,
# which tells this script whether the lab is reachable directly (native
# Linux, WSL2) or needs a `podman machine ssh` hop (macOS).

set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${DIR}"

# Ensure Podman, Homebrew, or MacPorts paths are active on macOS
if [ "$(uname -s)" = "Darwin" ]; then
  if [ -d /opt/podman/bin ] && [[ ":$PATH:" != *":/opt/podman/bin:"* ]]; then
    export PATH="/opt/podman/bin:$PATH"
  fi
  if [ -d /opt/local/bin ] && [[ ":$PATH:" != *":/opt/local/bin:"* ]]; then
    export PATH="/opt/local/bin:$PATH"
  fi
  if ! command -v ttyd >/dev/null 2>&1; then
    if [ -x /opt/homebrew/bin/brew ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi
fi

MEASLAB_HOP=direct
MEASLAB_MACHINE=podman-machine-default
MEASLAB_HOST=127.0.0.1
[ -f .measlab/runtime.env ] && . .measlab/runtime.env

TERMINALS="host1:7681 r1:7682 r2:7683 r3:7684"
PIDS=""

cleanup() {
  for pid in ${PIDS}; do
    kill "${pid}" 2>/dev/null || true
  done
}
trap cleanup EXIT INT TERM

if command -v ttyd >/dev/null 2>&1; then
  for entry in ${TERMINALS}; do
    node="${entry%%:*}"
    port="${entry##*:}"
    shell_cmd="sudo docker exec -it clab-measlab-${node} sh"
    if [ "${MEASLAB_HOP}" = "podman-machine" ]; then
      ttyd -p "${port}" -i "${MEASLAB_HOST}" -W -t titleFixed="${node}" \
        podman machine ssh "${MEASLAB_MACHINE}" -- "${shell_cmd}" \
        > /dev/null 2>&1 &
    else
      ttyd -p "${port}" -i "${MEASLAB_HOST}" -W -t titleFixed="${node}" \
        bash -c "${shell_cmd}" \
        > /dev/null 2>&1 &
    fi
    PIDS="${PIDS} $!"
    echo "Terminal for ${node} at http://${MEASLAB_HOST}:${port}"
  done
else
  echo "Note: ttyd is not installed. Browser web terminals will not be active."
  if [ "${MEASLAB_HOP}" = "podman-machine" ]; then
    echo "To access router shells via terminal, use: podman machine ssh ${MEASLAB_MACHINE} -- sudo docker exec -it clab-measlab-<node> sh"
  else
    echo "To access router shells via terminal, use: sudo docker exec -it clab-measlab-<node> sh"
  fi
fi

echo "Control panel + frontend at http://localhost:8080 (Ctrl-C to stop everything)."
python3 frontend/portal_server.py 8080
