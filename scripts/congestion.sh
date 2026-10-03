#!/usr/bin/env bash
# Switch real congestion on and off: ct1 (in upstream A) sends UDP towards target1 across the
# 10 Mbit/s transit link in a repeating cycle, 14 Mbit/s for 1 s and then 6 Mbit/s for 2 s. Each burst
# fills the queue and each quiet spell drains it, so the queue keeps changing length: latency and its
# spread rise together while the minimum stays near the baseline, as Module 2.7 shows congestion.
#
# Usage: ./congestion.sh start | stop | status

set -euo pipefail
LAB=measlab
CT=clab-${LAB}-ct1

case "${1:-}" in
  start)
    docker exec -d ${CT} sh -c 'echo $$ > /tmp/measlab-congestion.pid; while true; do iperf3 -u -b 14M -t 1 -c 10.40.10.10 >/dev/null 2>&1; iperf3 -u -b 6M -t 2 -c 10.40.10.10 >/dev/null 2>&1; done'
    echo "Congestion running: bursts of cross traffic on the transit link towards dest-1."
    ;;
  stop)
    docker exec ${CT} sh -c 'kill "$(cat /tmp/measlab-congestion.pid 2>/dev/null)" 2>/dev/null; rm -f /tmp/measlab-congestion.pid; pkill iperf3' || true
    echo "Congestion stopped."
    ;;
  status)
    # An empty PID makes `kill -0` succeed in this shell, so the PID must exist first.
    if docker exec ${CT} sh -c 'p=$(cat /tmp/measlab-congestion.pid 2>/dev/null) && [ -n "$p" ] && kill -0 "$p" 2>/dev/null'; then
      echo "Congestion is running."
    else
      echo "Congestion is not running."
    fi
    ;;
  *)
    echo "Usage: $0 start|stop|status"; exit 1
    ;;
esac
