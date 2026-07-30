#!/usr/bin/env bash
# Switch real congestion on and off: ct1 (in upstream A) streams 9 Mbit/s of UDP
# towards target1 across the 10 Mbit/s transit link. Learners then measure genuine
# queueing delay, jitter and loss. Compressed diurnal pattern on demand.
#
# Usage: ./congestion.sh start | stop | status

set -euo pipefail
LAB=measlab
CT=clab-${LAB}-ct1

case "${1:-}" in
  start)
    docker exec -d ${CT} iperf3 -u -b 9M -t 86400 -c 10.40.10.10
    echo "Congestion running: 9 Mbit/s cross traffic on the transit link towards dest-1."
    ;;
  stop)
    docker exec ${CT} pkill iperf3 || true
    echo "Congestion stopped."
    ;;
  status)
    if docker exec ${CT} pgrep iperf3 > /dev/null 2>&1; then
      echo "Congestion is running."
    else
      echo "Congestion is not running."
    fi
    ;;
  *)
    echo "Usage: $0 start|stop|status"; exit 1
    ;;
esac
