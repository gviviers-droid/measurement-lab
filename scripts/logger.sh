#!/usr/bin/env bash
# Continuous ping measurement logger for the Internet Measurements lab.
# Periodically probes targets from host1 and records timestamped RTT statistics,
# jitter, and loss into a CSV file for time-series analysis (Module 2.5).
#
# Usage: ./logger.sh start [interval_sec] [csv_file]
#        ./logger.sh stop
#        ./logger.sh status
#        ./logger.sh dump [lines]

set -euo pipefail
DIR="$(cd "$(dirname "$0")"/.. && pwd)"
LAB=measlab
NODE=clab-${LAB}-host1
PIDFILE=/tmp/measlab-logger.pid
FILE_PATH=/tmp/measlab-logger.file
CSV_DEFAULT="${DIR}/measurements.csv"

case "${1:-}" in
  start)
    if [ -f "${PIDFILE}" ] && kill -0 "$(cat "${PIDFILE}" 2>/dev/null)" 2>/dev/null; then
      echo "Logger is already running (PID: $(cat "${PIDFILE}"))."
      exit 0
    fi
    INTERVAL="${2:-5}"
    OUTFILE="${3:-${CSV_DEFAULT}}"

    # Create CSV header if file doesn't exist
    if [ ! -s "${OUTFILE}" ]; then
      echo "timestamp,target,af,sent,received,loss_pct,min_rtt_ms,avg_rtt_ms,max_rtt_ms,mdev_rtt_ms" > "${OUTFILE}"
    fi

    # Background measurement loop
    (
      while true; do
        TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        for target in "10.40.10.10" "10.50.10.10" "3fff:40:10::10" "3fff:50:10::10"; do
          af="ipv4"
          ping_cmd="ping -c 5 -i 0.2 -W 1 ${target}"
          if [[ "${target}" == *:* ]]; then
            af="ipv6"
            ping_cmd="ping -6 -c 5 -i 0.2 -W 1 ${target}"
          fi

          out=$(docker exec ${NODE} sh -c "${ping_cmd}" 2>/dev/null || true)

          sent=$(echo "${out}" | grep -oE '[0-9]+ packets transmitted' | awk '{print $1}')
          recv=$(echo "${out}" | grep -oE '[0-9]+ (packets )?received' | awk '{print $1}')
          loss=$(echo "${out}" | grep -oE '[0-9]+(\.[0-9]+)?% packet loss' | awk -F'%' '{print $1}')

          sent=${sent:-5}
          recv=${recv:-0}
          loss=${loss:-100.0}

          rtt_line=$(echo "${out}" | grep -E 'rtt|round-trip' || true)
          if [ -n "${rtt_line}" ]; then
            rtt_vals=$(echo "${rtt_line}" | awk -F'=' '{print $2}' | awk '{print $1}')
            min_rtt=$(echo "${rtt_vals}" | awk -F'/' '{print $1}')
            avg_rtt=$(echo "${rtt_vals}" | awk -F'/' '{print $2}')
            max_rtt=$(echo "${rtt_vals}" | awk -F'/' '{print $3}')
            mdev_rtt=$(echo "${rtt_vals}" | awk -F'/' '{print $4}')
          else
            min_rtt=""
            avg_rtt=""
            max_rtt=""
            mdev_rtt=""
          fi

          echo "${TS},${target},${af},${sent},${recv},${loss},${min_rtt},${avg_rtt},${max_rtt},${mdev_rtt}" >> "${OUTFILE}"
        done
        sleep "${INTERVAL}"
      done
    ) >/dev/null 2>&1 &

    echo $! > "${PIDFILE}"
    echo "${OUTFILE}" > "${FILE_PATH}"
    echo "Measurement logger started (PID: $!, interval: ${INTERVAL}s). Logging to ${OUTFILE}"
    ;;

  stop)
    if [ -f "${PIDFILE}" ]; then
      PID=$(cat "${PIDFILE}" 2>/dev/null || true)
      if [ -n "${PID}" ]; then
        kill "${PID}" 2>/dev/null || true
      fi
      rm -f "${PIDFILE}" "${FILE_PATH}"
      echo "Measurement logger stopped."
    else
      echo "Measurement logger is not running."
    fi
    ;;

  status)
    if [ -f "${PIDFILE}" ] && kill -0 "$(cat "${PIDFILE}" 2>/dev/null)" 2>/dev/null; then
      CSV="${CSV_DEFAULT}"
      [ -f "${FILE_PATH}" ] && CSV="$(cat "${FILE_PATH}")"
      echo "Measurement logger is running (PID: $(cat "${PIDFILE}"), logging to ${CSV})."
    else
      echo "Measurement logger is not running."
    fi
    ;;

  dump)
    LINES="${2:-15}"
    CSV="${CSV_DEFAULT}"
    [ -f "${FILE_PATH}" ] && CSV="$(cat "${FILE_PATH}")"
    if [ -f "${CSV}" ]; then
      echo "=== Recent records from ${CSV} ==="
      tail -n "${LINES}" "${CSV}"
    else
      echo "No log file found (${CSV}). Run '$0 start' first."
    fi
    ;;

  *)
    echo "Usage: $0 start [interval_sec] [csv_file] | stop | status | dump [lines]"; exit 1
    ;;
esac
