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

MEASLAB_HOP=direct
MEASLAB_MACHINE=podman-machine-default
[ -f .measlab/runtime.env ] && . .measlab/runtime.env

TERMINALS="host1:7681 r1:7682 r2:7683 r3:7684"
PIDS=""

cleanup() {
  for pid in ${PIDS}; do
    kill "${pid}" 2>/dev/null || true
  done
}
trap cleanup EXIT INT TERM

for entry in ${TERMINALS}; do
  node="${entry%%:*}"
  port="${entry##*:}"
  shell_cmd="sudo docker exec -it clab-measlab-${node} sh"
  if [ "${MEASLAB_HOP}" = "podman-machine" ]; then
    ttyd -p "${port}" -i 127.0.0.1 -W -t titleFixed="${node}" \
      podman machine ssh "${MEASLAB_MACHINE}" -- "${shell_cmd}" \
      > /dev/null 2>&1 &
  else
    ttyd -p "${port}" -i 127.0.0.1 -W -t titleFixed="${node}" \
      bash -c "${shell_cmd}" \
      > /dev/null 2>&1 &
  fi
  PIDS="${PIDS} $!"
  echo "Terminal for ${node} at http://localhost:${port}"
done

echo "Control panel + frontend at http://localhost:8080 (Ctrl-C to stop everything)."
python3 frontend/portal_server.py 8080
