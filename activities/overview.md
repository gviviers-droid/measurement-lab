# Unit 2 Activities: Overview

Five activities run on the one base topology, escalating from guided measurement to independent fault diagnosis. Learners install the lab once; every activity starts from the same base state and any scenario switches on and off by script.

| # | Activity | Modules | Type | Scripts used | Time |
|---|---|---|---|---|---|
| 1 | Measure the Path | 2.1, 2.3 | Guided | none | 30 to 40 min |
| 2 | When the Path Gets Busy | 2.3, 2.5 | Guided | congestion.sh | 30 min |
| 3 | Turn On Peering | 2.1, 2.3, Unit 1 | Guided | peering.sh | 25 min |
| 4 | The Slow Neighbour | 2.6 | Scenario | scenario.sh 1, lg.sh | 30 to 40 min |
| 5 | Now You See It, Now You Don't | 2.6 | Scenario | scenario.sh 2, lg.sh | 30 min |

## The arc

Activity 1 teaches the instruments: traceroute, ping, mtr, and the learner's own BGP table, in both address families, against two targets with contrasting paths. Activity 2 adds time and load, turning the statistics of Module 2.5 into things the learner computes from their own packets. Activity 3 has the learner change their own network for the first time, with the before-and-after discipline that real peering decisions rest on. Activities 4 and 5 withdraw the guidance: a ticket, the tools, and an incident summary as the deliverable, first for a degraded path and then for an intermittent one.

Each activity's closing questions point forward to Unit 3: distributed vantage points (RIPE Atlas), the Internet-wide BGP view (RIS, BGPlay), and measurement campaigns over time.

## Base state, and why it matters

Every sheet assumes: `lab-check.sh` green, congestion stopped, peering down, all scenarios off. Activities 3 to 5 end by restoring this state. If a learner reports strange results, the first question is always whether a previous activity left something switched on; `lab-check.sh` plus `congestion.sh status`, `peering.sh status` and re-running `scenario.sh <n> off` resets the world.

## For maintainers

The learner-facing scenario switch is `scripts/scenario.sh`, which keeps its output neutral. The scripts under `scripts/scenarios/` document each fault and are therefore spoilers; task sheets tell learners not to read them. When adding a scenario: implement it as a toggle in `scripts/scenarios/`, add a neutral case to `scenario.sh`, write the task sheet with the model incident summary, and extend `lab-check.sh` only if the base state changes (it should not).

A planned sixth activity, not yet written: a stretch scenario combining two simultaneous faults (for example congestion plus the trombone), for learners who finish early. The scripts already compose; only the sheet is missing.
