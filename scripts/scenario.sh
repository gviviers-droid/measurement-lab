#!/usr/bin/env bash
# Learner-facing scenario switch. Output stays neutral on purpose: the underlying
# scripts in scenarios/ document what each fault is, and reading them spoils the
# diagnosis. Learners run this wrapper; maintainers read the scenario scripts.
#
# Usage: ./scenario.sh <1|2|3> <on|off>

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
  3-on)
    "${DIR}/scenarios/trombone.sh" on > /dev/null
    "${DIR}/congestion.sh" start > /dev/null
    echo "Scenario 3 is active. Allow up to a minute for symptoms to appear."
    ;;
  3-off)
    "${DIR}/scenarios/trombone.sh" off > /dev/null
    "${DIR}/congestion.sh" stop > /dev/null
    echo "Scenario 3 cleared. Allow up to a minute for the network to settle."
    ;;
  status|status-)
    s1="off"; s2="off"; s3="off"
    if docker exec clab-${LAB}-ra vtysh -c "show bgp summary" 2>/dev/null | grep '100.64.99.1' | grep -qi 'Admin'; then
      s1="on"
    fi
    if [ -f "${PIDFILE}" ] && kill -0 "$(cat "${PIDFILE}" 2>/dev/null)" 2>/dev/null; then
      s2="on"
    fi
    if [ "${s1}" = "on" ] && docker exec clab-${LAB}-ct1 pgrep iperf3 > /dev/null 2>&1; then
      s3="on"
    fi
    echo "scenario1=${s1} scenario2=${s2} scenario3=${s3}"
    ;;
  *)
    echo "Usage: $0 <1|2|3> <on|off> | status"; exit 1
    ;;
esac
