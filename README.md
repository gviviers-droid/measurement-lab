# Internet Measurements Lab (draft v2)

A dual-stack multi-AS network for the hands-on activities in Unit 2 of the Internet Measurements course. Learners operate one AS and measure the rest of the "Internet" from the outside. One base topology carries every activity in the unit; scenarios switch on and off through small scripts, so learners install once and the network never changes shape under them.

## Topology

Fourteen containers form seven autonomous systems plus an IXP:

- **AS 65001 (the learner's network):** border routers r1 and r2, internal router r3, workstation host1. Learners may log in to these and only these. r2 holds a dormant port at the IXP for the peering activity.
- **AS 65010 (upstream A)** and **AS 65020 (upstream B):** the learner's two providers, both present at the IXP. Upstream A also hosts ct1, the cross-traffic generator.
- **AS 65030 (transit):** long-haul carrier connecting the upstreams to the destinations. All impaired links attach here.
- **AS 65040 (dest-1):** hosting network with target1, reached via transit. Holds a dormant IXP port for later scenarios.
- **AS 65050 (dest-2):** content network with target2, reached via the IXP, with a prepended backup path via transit (used by the trombone scenario).
- **AS 65100 (route server)** on the IXP peering LAN, implemented as a bridge container.

All routers run [FRRouting](https://frrouting.org) with per-family eBGP sessions, correct peering policy (upstreams announce only their own and customer routes to peers), and OSPF, OSPFv3 and iBGP inside the learner AS.

## Addressing

IPv6 uses the documentation prefix 3fff::/20 ([RFC 9637](https://www.rfc-editor.org/rfc/rfc9637)), which yields 4,096 /32s, so every AS receives a realistic /32 allocation:

| AS | Network | IPv4 | IPv6 |
|---|---|---|---|
| 65001 | learner | 10.1.0.0/16 | 3fff:1::/32 |
| 65010 | upstream A | 10.10.0.0/16 | 3fff:10::/32 |
| 65020 | upstream B | 10.20.0.0/16 | 3fff:20::/32 |
| 65030 | transit | 10.30.0.0/16 | 3fff:30::/32 |
| 65040 | dest-1 | 10.40.0.0/16 | 3fff:40::/32 |
| 65050 | dest-2 | 10.50.0.0/16 | 3fff:50::/32 |
| IXP LAN | shared | 100.64.99.0/24 | 3fff:ff::/64 |

Inter-AS point-to-point links use 100.64.0.0/10 for IPv4 and /64s from the relevant AS's /32 for IPv6.

## Getting the lab (three routes)

**GitHub Codespaces, nothing installed.** The repository ships a `.devcontainer/` configuration built on Containerlab's official Dev Container image, so a learner can open the repo on GitHub, create a Codespace, and get a browser-based VS Code with Docker and Containerlab pre-installed. GitHub's free allowance (120 core-hours per month at the time of writing) comfortably covers the unit. See [containerlab.dev/manual/codespaces](https://containerlab.dev/manual/codespaces/).

**VS Code Dev Container on the learner's own machine.** The same `.devcontainer/` works locally on Windows, macOS and Linux with [Docker Desktop](https://www.docker.com/products/docker-desktop/) and the Dev Containers extension. This is Containerlab's recommended route on macOS and Windows.

**Native Linux.** Docker Engine plus [Containerlab](https://containerlab.dev/install/), then work in the folder directly.

All three routes converge on `sudo ./lab.sh up` / `check` / `reset` / `down`, and `sudo ./lab.sh docs` serves the activity frontend on port 8080 (auto-forwarded in Codespaces).

## The activity frontend

`frontend/index.html` is a self-contained page (no network access needed, except the Control Portal page below) with the lab guide, all five activity sheets, a command cheatsheet, the topology diagram, and the Control Portal. Model answers sit behind closed disclosure panels, every command block has a copy button, and task progress persists in the learner's browser. Learners open the file directly, via `sudo ./lab.sh docs`, or via `./portal.sh` for the interactive controls and terminals.

The markdown sheets remain the single source of truth: after editing anything in `activities/` or `frontend/pages/`, regenerate with `python3 frontend/build.py` (requires `pip install markdown`).

## Control Portal

The frontend's "Control Portal" page adds buttons for the lab lifecycle and every activity toggle (congestion, peering, scenarios 1/2, looking glass), plus a live browser terminal into each learner-accessible node (r1, r2, r3, host1) — so activities can be run without typing `docker exec` commands by hand.

Run `./portal.sh` on the machine that has a browser (Ctrl-C to stop), then open `http://localhost:8080`. Requires `ttyd` (`brew install ttyd` / `apt install ttyd`) and `python3`. `portal.sh` reaches the lab via `podman machine ssh`, which matches this repo's macOS+Podman setup; on native Linux or a devcontainer, adjust `run_in_vm()` in `frontend/portal_server.py` and the `podman machine ssh` prefix in `portal.sh` to call the lab directly instead.

Known rough edge: the terminal panel nests several nested PTYs (browser → ttyd → ssh → container exec), and an occasional stray cursor-position escape sequence can garble the first characters typed into a fresh tab. Press Ctrl-C and retype if a command looks wrong; it does not recur once a tab has settled.

## Requirements

- Docker ([Docker Desktop](https://www.docker.com/products/docker-desktop/) on macOS and Windows, Docker Engine on Linux)
- [Containerlab](https://containerlab.dev/install/) 0.60 or newer

Around 2 GB of RAM covers the whole lab.

## Start the lab

```
sudo ./lab.sh up
```

This deploys the topology, applies the impairments and runs the health check in one step (the underlying scripts remain individually runnable).

`lab-check.sh` must report every check as PASS before a learner starts. Stop and remove everything with:

```
sudo ./lab.sh down
```

## Scripts

- `scripts/impairments.sh` applies the base link conditions. Its header documents the ground truth for the measurement questions.
- `scripts/lab-check.sh` verifies BGP sessions, dormant ports, dual-stack reachability and the expected latency profile.
- `scripts/congestion.sh start|stop` switches real cross traffic onto the rate-limited transit link, producing genuine queueing delay, jitter and loss on demand.
- `scripts/peering.sh up|down` enables the learner AS's sessions at the route server, for the measure-then-peer-then-measure activity.
- `scripts/lg.sh <router> "show ..."` is the looking glass: read-only visibility into the Internet routers without breaking the observe-only rule.
- `scripts/scenario.sh <1|2> on|off` is the learner-facing scenario switch with neutral output.
- `scripts/scenarios/trombone.sh on|off` detours local traffic through distant transit (maintainer script, spoiler).
- `scripts/scenarios/routeflap.sh` bounces dest-1's transit sessions until stopped with Ctrl-C.

## Activities

The five task sheets and their overview live in `activities/`. Learners work from the sheets; `activities/overview.md` maps each activity to modules, scripts and required lab state.

## For maintainers

The impairment values in `scripts/impairments.sh` are the ground truth for the measurement questions. If you change a delay, jitter, loss or rate value, update the model answers in the task sheets in the same commit, then run `lab-check.sh` to confirm the environment still matches the sheets' assumptions. Configuration lives in one place per router (`configs/<name>/frr.conf`); all routers share `configs/daemons`. New scenarios belong in `scripts/scenarios/` as toggles against the base state, never as edits to the base topology.

## Open items in this draft

- The frontend logic is smoke-tested but the page has not yet been opened in a real browser: do that once and adjust spacing to taste.
- Untested against a live Containerlab install. Deploy once and run `lab-check.sh` before circulating; expect small fixes around FRR image behaviour and exec ordering on the ixp-sw bridge container.
- The topology figure (`topology-diagram.svg`) is the learner version and hides impairments, the cross-traffic host and dest-1's dormant IXP port.
- Planned extensions, decided but not built: DNS names for targets via a small resolver, and a measurement logger writing ping statistics to CSV for the Module 2.5 and 2.7 activities.
