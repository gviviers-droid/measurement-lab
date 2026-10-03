# Unit 2 Activities: Overview

Six activities run on the same base topology. They move from guided measurement to independent fault diagnosis. Learners install the lab once. Every activity starts from the same base state. A script switches each scenario on and off.

| # | Activity | Modules | Type | Scripts used | Time |
|---|---|---|---|---|---|
| 1 | Measure the Path | 2.2, 2.3 | Guided | none | 30 to 40 min |
| 2 | When the Path Gets Busy | 2.6, 2.7, 2.8 | Guided | congestion.sh | 30 min |
| 3 | Turn On Peering | 2.2, 2.3, 1.3 | Guided | peering.sh | 25 min |
| 4 | The Slow Neighbour | 2.9 | Scenario | scenario.sh 1, lg.sh | 30 to 40 min |
| 5 | A Route That Comes and Goes | 2.9 | Scenario | scenario.sh 2, lg.sh | 30 min |
| 6 | Two Faults at Once (Stretch) | 2.6, 2.8, 2.9 | Scenario | scenario.sh 3, lg.sh | 35 to 45 min |

## The arc

Each activity builds on the one before it:

1. **Activity 1** teaches the instruments in both address families. Learners use traceroute, ping and mtr, then read their own BGP table. The two targets have different paths.
2. **Activity 2** adds load over time. Cross traffic arrives in bursts that fill a queue and then let it drain. Learners compute the Module 2.8 statistics from their own packets.
3. **Activity 3** is a before-and-after measurement. Learners switch on a peering session at the exchange. They measure both targets before and after the change and compare the results.
4. **Activities 4 and 5** remove the step-by-step guidance. Learners get a ticket and the tools. They write an incident summary. Activity 4 has a slow path. Activity 5 has a route that comes and goes.
5. **Activity 6** is a stretch scenario for learners who finish early. Two separate faults run at once, each on a different destination.

The closing questions of each activity point forward to three Unit 3 topics:

- views from many vantage points (RIPE Atlas)
- the BGP routes that the Routing Information Service (RIS) collectors record from their peers, as BGPlay shows them
- measurement campaigns that run over time

## Base state, and why it matters

Every sheet assumes the base state:

- `sudo ./lab.sh check` passes on every line
- congestion is stopped
- peering is down
- all scenarios are off

Activities 2 to 6 each end by restoring this state. A learner may report strange results. First ask whether an earlier activity left something switched on. One command restores the base state and then runs the health check:

```
sudo ./lab.sh reset
```

## For maintainers

The learner-facing scenario switch is `scripts/scenario.sh`. Its output stays neutral. The scripts under `scripts/scenarios/` describe each fault, so they give the answers away. The task sheets tell learners not to read them.

To add a scenario:

1. Write it as a toggle in `scripts/scenarios/`.
2. Add a neutral case to `scenario.sh`.
3. Write the task sheet with its model incident summary.
4. Change `lab-check.sh` only if the base state changes. It should not change.
