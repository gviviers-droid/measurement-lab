#!/usr/bin/env python3
"""Serves the activity frontend and a small control API for the lab.

Runs on the host (macOS/Linux), not inside the Containerlab VM. Every action
shells out to the same podman VM Containerlab deploys into, via
`podman machine ssh`, and runs the existing lab.sh / scripts/*.sh unchanged --
this is a thin control surface over the same commands from the README, not a
reimplementation of them.

Usage: python3 frontend/portal_server.py [port]   (default port 8080)
"""

import json
import re
import shlex
import subprocess
import sys
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FRONTEND = ROOT / "frontend"
PODMAN_MACHINE = "podman-machine-default"
ANSI_RE = re.compile(r"\x1b\[[0-9;]*[a-zA-Z]")

# Fixed, argument-free actions only -- each maps to an existing script call.
ACTIONS = {
    "lab_up": ("lab.sh", ["up"]),
    "lab_down": ("lab.sh", ["down"]),
    "lab_check": ("lab.sh", ["check"]),
    "lab_reset": ("lab.sh", ["reset"]),
    "scenario1_on": ("scripts/scenario.sh", ["1", "on"]),
    "scenario1_off": ("scripts/scenario.sh", ["1", "off"]),
    "scenario2_on": ("scripts/scenario.sh", ["2", "on"]),
    "scenario2_off": ("scripts/scenario.sh", ["2", "off"]),
    "peering_up": ("scripts/peering.sh", ["up"]),
    "peering_down": ("scripts/peering.sh", ["down"]),
    "peering_status": ("scripts/peering.sh", ["status"]),
    "congestion_start": ("scripts/congestion.sh", ["start"]),
    "congestion_stop": ("scripts/congestion.sh", ["stop"]),
    "congestion_status": ("scripts/congestion.sh", ["status"]),
}

LG_ROUTERS = {"upstream-a", "upstream-b", "transit", "route-server"}

TIMEOUTS = {"lab_up": 180, "lab_down": 120, "lab_reset": 120}
DEFAULT_TIMEOUT = 60


def run_in_vm(script: str, args: list) -> tuple:
    """Run <repo>/<script> <args> inside the Containerlab VM over podman machine ssh."""
    remote_path = str(ROOT / script)
    remote_cmd = "sudo bash " + " ".join(shlex.quote(p) for p in [remote_path, *args])
    try:
        proc = subprocess.run(
            ["podman", "machine", "ssh", PODMAN_MACHINE, "--", remote_cmd],
            capture_output=True,
            text=True,
            timeout=TIMEOUTS.get(script, DEFAULT_TIMEOUT),
        )
        output = ANSI_RE.sub("", proc.stdout + proc.stderr)
        return proc.returncode == 0, output
    except subprocess.TimeoutExpired:
        return False, "Timed out waiting for the command to finish."
    except FileNotFoundError:
        return False, "podman command not found on this machine."


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(FRONTEND), **kwargs)

    def log_message(self, fmt, *args):
        pass  # keep the console quiet; errors still raise

    def _json(self, status: int, payload: dict):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        if self.path == "/api/run":
            length = int(self.headers.get("Content-Length", 0))
            try:
                body = json.loads(self.rfile.read(length) or b"{}")
            except json.JSONDecodeError:
                return self._json(400, {"ok": False, "output": "Bad JSON body."})
            action = body.get("action", "")
            if action not in ACTIONS:
                return self._json(404, {"ok": False, "output": f"Unknown action: {action}"})
            script, args = ACTIONS[action]
            ok, output = run_in_vm(script, args)
            return self._json(200, {"ok": ok, "output": output})

        if self.path == "/api/lg":
            length = int(self.headers.get("Content-Length", 0))
            try:
                body = json.loads(self.rfile.read(length) or b"{}")
            except json.JSONDecodeError:
                return self._json(400, {"ok": False, "output": "Bad JSON body."})
            router = body.get("router", "")
            cmd = body.get("cmd", "")
            if router not in LG_ROUTERS:
                return self._json(400, {"ok": False, "output": "Unknown router."})
            if not cmd.startswith("show "):
                return self._json(400, {"ok": False, "output": "Only show commands are allowed."})
            ok, output = run_in_vm("scripts/lg.sh", [router, cmd])
            return self._json(200, {"ok": ok, "output": output})

        self._json(404, {"ok": False, "output": "Not found."})


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print(f"Serving the activity frontend + control API at http://localhost:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
