#!/usr/bin/env bash
# Enable or disable the learner AS's peering sessions at the IXP route server
# (used by the "benefits of peering" activity: measure, enable, measure again).
#
# Usage: ./peering.sh up | down | status

set -euo pipefail
LAB=measlab
R2=clab-${LAB}-r2

case "${1:-}" in
  up)
    docker exec ${R2} vtysh \
      -c "configure terminal" -c "router bgp 65001" \
      -c "no neighbor 100.64.99.1 shutdown" \
      -c "no neighbor 3fff:ff::1 shutdown"
    echo "Peering sessions to the route server enabled (IPv4 and IPv6). Allow ~30 s to establish."
    ;;
  down)
    docker exec ${R2} vtysh \
      -c "configure terminal" -c "router bgp 65001" \
      -c "neighbor 100.64.99.1 shutdown" \
      -c "neighbor 3fff:ff::1 shutdown"
    echo "Peering sessions shut. Back to transit-only."
    ;;
  status)
    docker exec ${R2} vtysh -c "show bgp summary" | grep -E "100.64.99.1|3fff:ff::1" || true
    ;;
  *)
    echo "Usage: $0 up|down|status"; exit 1
    ;;
esac
