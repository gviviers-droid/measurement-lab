#!/usr/bin/env bash
# One-command control for the Internet Measurements lab. Run with sudo.
#
#   ./lab.sh up      deploy the network, apply link conditions, run the health check
#   ./lab.sh check   run the health check
#   ./lab.sh reset   return a running lab to the base state every activity assumes
#   ./lab.sh down    remove the lab completely
#   ./lab.sh docs    serve the activity frontend at http://localhost:8080

set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${DIR}"

case "${1:-}" in
  up)
    containerlab deploy -t topology.clab.yml --runtime podman
    ./scripts/impairments.sh
    echo
    ./scripts/lab-check.sh
    ;;
  check)
    ./scripts/lab-check.sh
    ;;
  reset)
    ./scripts/congestion.sh stop || true
    ./scripts/peering.sh down || true
    ./scripts/scenario.sh 1 off || true
    ./scripts/scenario.sh 2 off || true
    echo "Base state restored. Verifying:"
    sleep 20
    ./scripts/lab-check.sh
    ;;
  down)
    containerlab destroy -t topology.clab.yml --runtime podman
    ;;
  docs)
    echo "Serving the activity frontend at http://localhost:8080 (Ctrl-C to stop)."
    cd frontend && python3 -m http.server 8080
    ;;
  *)
    echo "Usage: $0 up|check|reset|down|docs"; exit 1
    ;;
esac
