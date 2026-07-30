#!/usr/bin/env bash
# Lab health check: confirms the environment behaves as the task sheets assume.
# Run with sudo after deploy + impairments. Safe to re-run at any time.
# Maintainers: re-run after any change to configs, impairments or scenarios.

set -uo pipefail
LAB=measlab
PASS=0; FAIL=0

check () {
  local desc="$1"; shift
  if "$@" > /dev/null 2>&1; then
    echo "PASS  $desc"; PASS=$((PASS+1))
  else
    echo "FAIL  $desc"; FAIL=$((FAIL+1))
  fi
}

bgp_established () {
  # Established sessions show a numeric prefix count in the State/PfxRcd column (field 10);
  # non-established sessions show a state name there instead (Active, Idle, Connect, ...).
  local node="$1" expected="$2" count
  count=$(docker exec clab-${LAB}-${node} vtysh -c "show bgp summary" 2>/dev/null | awk '$10 ~ /^[0-9]+$/ {c++} END{print c+0}') || return 1
  [ "$count" -ge "$expected" ]
}

ping_ok () {
  # Passes when at most ~8% loss (tolerates the injected 1%)
  local node="$1" target="$2"
  docker exec clab-${LAB}-${node} sh -c \
    "ping -c 10 -i 0.2 ${target} | grep -qE ' [0-8]?%? ?packet loss| [0-8]% packet loss| 0% packet loss'"
}

rtt_above () {
  # set -o pipefail so a totally failed ping (no rtt summary line) fails the check
  # instead of silently falling through with awk's default exit status of 0.
  local node="$1" target="$2" floor="$3"
  docker exec clab-${LAB}-${node} sh -c \
    "set -o pipefail; ping -c 5 -i 0.2 ${target} | awk -F'/' '/rtt|round-trip/ {rtt=\$5; found=1} END{if (!found) exit 1; exit (rtt > ${floor}) ? 0 : 1}'"
}

rtt_below () {
  local node="$1" target="$2" ceiling="$3"
  docker exec clab-${LAB}-${node} sh -c \
    "set -o pipefail; ping -c 5 -i 0.2 ${target} | awk -F'/' '/rtt|round-trip/ {rtt=\$5; found=1} END{if (!found) exit 1; exit (rtt < ${ceiling}) ? 0 : 1}'"
}

# 1. BGP control plane (counts cover IPv4 + IPv6 sessions)
check "r1: 6 BGP sessions established (4 iBGP + 2 eBGP)"        bgp_established r1 6
check "r2: 6 BGP sessions established (IXP sessions stay down)" bgp_established r2 6
check "transit: 8 BGP sessions established"                     bgp_established rt 8
check "route server: 6 sessions (A, B, dest-2, both families)"  bgp_established rs 6

# 2. Dormant sessions really are dormant
check "r2 IXP v4 session is admin-shutdown" \
  docker exec clab-${LAB}-r2 sh -c "vtysh -c 'show bgp summary' | grep '100.64.99.1' | grep -qi 'Idle (Admin)'"
check "dest-1 IXP v4 session is admin-shutdown" \
  docker exec clab-${LAB}-rd1 sh -c "vtysh -c 'show bgp summary' | grep '100.64.99.1' | grep -qi 'Idle (Admin)'"

# 3. Routes present in the learner AS, both families
check "r1 has IPv4 route to dest-1 (10.40.0.0/16)" \
  docker exec clab-${LAB}-r1 vtysh -c "show bgp ipv4 unicast 10.40.0.0/16"
check "r1 has IPv6 route to dest-1 (3fff:40::/32)" \
  docker exec clab-${LAB}-r1 vtysh -c "show bgp ipv6 unicast 3fff:40::/32"
check "r1 has IPv4 route to dest-2 (10.50.0.0/16)" \
  docker exec clab-${LAB}-r1 vtysh -c "show bgp ipv4 unicast 10.50.0.0/16"
check "r1 has IPv6 route to dest-2 (3fff:50::/32)" \
  docker exec clab-${LAB}-r1 vtysh -c "show bgp ipv6 unicast 3fff:50::/32"

# 4. End-to-end reachability, both families, both targets
check "host1 -> target1 IPv4"  ping_ok host1 10.40.10.10
check "host1 -> target1 IPv6"  ping_ok host1 3fff:40:10::10
check "host1 -> target2 IPv4"  ping_ok host1 10.50.10.10
check "host1 -> target2 IPv6"  ping_ok host1 3fff:50:10::10

# 5. Impairments in place: transit path slow, peering path fast
check "RTT to target1 exceeds 40 ms (transit path impaired)"  rtt_above host1 10.40.10.10 40
check "RTT to target2 below 15 ms (IXP path clean)"           rtt_below host1 10.50.10.10 15
check "IPv6 RTT to target1 exceeds 40 ms"                     rtt_above host1 3fff:40:10::10 40

echo
echo "Result: ${PASS} passed, ${FAIL} failed."
[ "$FAIL" -eq 0 ]
