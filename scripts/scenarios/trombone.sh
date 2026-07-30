#!/usr/bin/env bash
# Tromboning scenario: upstream A loses its IXP sessions, so traffic to the
# "nearby" dest-2 detours via distant transit (+30 ms path). Learners diagnose why
# a local destination suddenly measures like a remote one.
#
# Usage: ./trombone.sh on | off

set -euo pipefail
LAB=measlab
RA=clab-${LAB}-ra

case "${1:-}" in
  on)
    docker exec ${RA} vtysh \
      -c "configure terminal" -c "router bgp 65010" \
      -c "neighbor 100.64.99.1 shutdown" \
      -c "neighbor 3fff:ff::1 shutdown"
    echo "Trombone active: upstream A is off the IXP. Traffic to dest-2 now detours via transit."
    ;;
  off)
    docker exec ${RA} vtysh \
      -c "configure terminal" -c "router bgp 65010" \
      -c "no neighbor 100.64.99.1 shutdown" \
      -c "no neighbor 3fff:ff::1 shutdown"
    echo "Trombone cleared: upstream A is back at the IXP."
    ;;
  *)
    echo "Usage: $0 on|off"; exit 1
    ;;
esac
