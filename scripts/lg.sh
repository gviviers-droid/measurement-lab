#!/usr/bin/env bash
# Looking glass: run read-only "show" commands on Internet routers, the way real
# operators publish looking glasses. Keeps the observe-only rule intact.
#
# Usage:    ./lg.sh <router> "<show command>"
# Routers:  upstream-a  upstream-b  transit  route-server
# Example:  ./lg.sh transit "show bgp ipv4 unicast 10.1.0.0/16"

set -euo pipefail
LAB=measlab

case "${1:-}" in
  upstream-a)   NODE=ra ;;
  upstream-b)   NODE=rb ;;
  transit)      NODE=rt ;;
  route-server) NODE=rs ;;
  *) echo "Usage: $0 {upstream-a|upstream-b|transit|route-server} \"show ...\""; exit 1 ;;
esac

CMD="${2:-}"
case "${CMD}" in
  show\ *) ;;
  *) echo "This looking glass accepts show commands only."; exit 1 ;;
esac

docker exec clab-${LAB}-${NODE} vtysh -c "${CMD}"
