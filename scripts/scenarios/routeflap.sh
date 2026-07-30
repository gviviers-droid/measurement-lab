#!/usr/bin/env bash
# Route-flap scenario: dest-1 bounces its transit BGP sessions every 40 seconds.
# Learners observe churn in their own BGP tables and intermittent reachability
# of target1, then attribute the instability to the right AS.
#
# Runs in the foreground; press Ctrl-C to stop (sessions are restored on exit).

set -euo pipefail
LAB=measlab
RD1=clab-${LAB}-rd1

restore () {
  docker exec ${RD1} vtysh \
    -c "configure terminal" -c "router bgp 65040" \
    -c "no neighbor 100.64.34.1 shutdown" \
    -c "no neighbor 3fff:30:0:34::1 shutdown" || true
  echo; echo "Flapping stopped, sessions restored."
}
trap restore EXIT

echo "Flapping dest-1's transit sessions every 40 s. Ctrl-C to stop."
while true; do
  docker exec ${RD1} vtysh \
    -c "configure terminal" -c "router bgp 65040" \
    -c "neighbor 100.64.34.1 shutdown" \
    -c "neighbor 3fff:30:0:34::1 shutdown"
  sleep 40
  docker exec ${RD1} vtysh \
    -c "configure terminal" -c "router bgp 65040" \
    -c "no neighbor 100.64.34.1 shutdown" \
    -c "no neighbor 3fff:30:0:34::1 shutdown"
  sleep 40
done
