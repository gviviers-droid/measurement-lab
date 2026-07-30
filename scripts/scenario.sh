#!/usr/bin/env bash
# Learner-facing scenario switch. Output stays neutral on purpose: the underlying
# scripts in scenarios/ document what each fault is, and reading them spoils the
# diagnosis. Learners run this wrapper; maintainers read the scenario scripts.
#
# Usage: ./scenario.sh <1|2> <on|off>

set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
PIDFILE=/tmp/measlab-scenario2.pid
LAB=measlab

case "${1:-}-${2:-}" in
  1-on)
    "${DIR}/scenarios/trombone.sh" on > /dev/null
    echo "Scenario 1 is active. Allow up to a minute for symptoms to appear."
    ;;
  1-off)
    "${DIR}/scenarios/trombone.sh" off > /dev/null
    echo "Scenario 1 cleared. Allow up to a minute for the network to settle."
    ;;
  2-on)
    nohup "${DIR}/scenarios/routeflap.sh" > /dev/null 2>&1 &
    echo $! > "${PIDFILE}"
    echo "Scenario 2 is active. Allow up to a minute for symptoms to appear."
    ;;
  2-off)
    if [ -f "${PIDFILE}" ]; then
      kill "$(cat "${PIDFILE}")" 2>/dev/null || true
      rm -f "${PIDFILE}"
    fi
    sleep 1
    docker exec clab-${LAB}-rd1 vtysh \
      -c "configure terminal" -c "router bgp 65040" \
      -c "no neighbor 100.64.34.1 shutdown" \
      -c "no neighbor 3fff:30:0:34::1 shutdown" > /dev/null 2>&1 || true
    echo "Scenario 2 cleared. Allow up to a minute for the network to settle."
    ;;
  *)
    echo "Usage: $0 <1|2> <on|off>"; exit 1
    ;;
esac
