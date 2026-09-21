# Activity 5, Scenario 2: Now You See It, Now You Don't

**Maps to:** Module 2.6 (Troubleshooting with Measurements), with a direct bridge to Unit 3 (RIS and BGPlay)
**Time:** 30 minutes
**Start state:** lab deployed, `lab-check.sh` all green, congestion stopped, peering down, Scenario 1 off.
**Do not read** the files under `scripts/scenarios/`; they contain the answer.

Activity 4 gave you a degraded path. This scenario gives you something meaner: a fault that keeps disappearing while you look at it. Intermittent problems are the hardest class of network incident, because a single measurement can land in a good moment and declare everything healthy. Your tools against them are measurement over time and the routing control plane itself.

## The ticket

> target1 (10.40.10.10 / 3fff:40:10::10) keeps dropping out. It works, then it does not, then it works again. Monitoring shows the pattern started 20 minutes ago. target2 is fine. Please investigate and tell us whose problem this is.

Start the incident by clicking **Scenario 2 on** in the Control Portal (or run on your own machine in the lab folder):

```
sudo ./scripts/scenario.sh 2 on
```

Wait a minute, then investigate. Try your own approach first.

## Task 1: Measure over time with MTR

Intermittent faults fool single pings. From host1 (via the **host1** terminal in the Control Portal or `podman exec -it clab-measlab-host1 bash`), run a 100-cycle mtr to target1:

```bash
mtr -n --report --report-cycles 100 10.40.10.10
```

> [!TIP]
> **Where to look in the MTR report:** Look at the `Loss%` column for intermediate hops (1 to 4) versus the final destination (target1). Notice how hops 1–4 show 0.0% loss, but the destination reports roughly 50% loss.

**Question 1.** What loss percentage does MTR report for target1 over 100 cycles, and why did a single ping fail to reveal this pattern?

<details class="answers" markdown="1">
<summary>Check your findings for Task 1 (reveal after measuring)</summary>

```text
Sample output (mtr -n --report --report-cycles 100 10.40.10.10):
HOST: host1                       Loss%   Snt   Last   Avg  Best  Wrst StDev
  1.|-- 10.1.10.1                  0.0%   100    0.1   0.1   0.1   0.2   0.0
  2.|-- 10.1.1.1                   0.0%   100    0.2   0.2   0.2   0.3   0.0
  3.|-- 100.64.11.1                0.0%   100    0.5   0.5   0.4   0.7   0.1
  4.|-- 100.64.13.2                0.0%   100   20.8  20.8  20.4  22.1   0.3
  5.|-- ???                       100.0   100    0.0   0.0   0.0   0.0   0.0
  6.|-- 10.40.10.10               48.0%   100   46.1  46.2  45.8  47.9   0.5
```

**Finding:** Loss to target1 is roughly 48%–50% over time. A single ping probe that lands during an "up" window reports 100% success with normal ~46 ms latency, completely hiding the periodic outage. Only continuous sampling over time exposes intermittent faults.

</details>

## Task 2: Distinguish link loss from routing table withdrawal

Read the failure mode closely. Run a continuous ping to target1:

```bash
ping 10.40.10.10
```

Watch the terminal as it alternates between successful replies and failure messages (press `Ctrl + C` to stop after observing the pattern).

> [!TIP]
> **Interpreting ICMP errors:**  
> - **Request timeout:** Packets left your network, but no reply returned (typical of physical packet loss, link congestion, or dead hosts).  
> - **From 10.1.1.1: Destination Net Unreachable:** Your *own local router* (`r1`) actively rejected the packet because it has no route to the destination network in its routing table!

**Question 2.** What specific error message does ping display during outage windows, and which machine issues it?

<details class="answers" markdown="1">
<summary>Check your findings for Task 2 (reveal after ping check)</summary>

```text
Sample output during outage:
From 10.1.1.1 icmp_seq=1 Destination Net Unreachable
From 10.1.1.1 icmp_seq=2 Destination Net Unreachable
```

**Finding:** The error is `Destination Net Unreachable` coming directly from our border router `10.1.1.1` (`r1`). This proves the failure is NOT packets dropping on a noisy cable; our own router has lost its BGP route to `10.40.0.0/16` entirely!

</details>

## Task 3: Observe route flaps on the control plane and looking glass

On r1 (in the Control Portal switch to the **r1** terminal and type `vtysh`, or run `podman exec -it clab-measlab-r1 vtysh`), check the route repeatedly over two minutes:

```
show bgp ipv4 unicast 10.40.0.0/16
```

Then query the looking glass (use the **Looking glass** section in the Control Portal, or run from your host machine):

```bash
sudo ./scripts/lg.sh transit "show bgp ipv4 unicast 10.40.0.0/16"
sudo ./scripts/lg.sh route-server "show bgp summary"
```

> [!TIP]
> **Where to look in BGP lookups:**
> * On `r1`: During good windows, check the route age (`Last update: 00:00:15 ago`). Notice how the age repeatedly resets back to seconds! During bad windows, it reports `% Network not in table`.
> * In the looking glass: Check if the transit carrier (`AS 65030`) also sees dest-1 (`AS 65040`) appearing and disappearing.

<details class="answers" markdown="1">
<summary>Check your findings for Task 3 (reveal after checking BGP)</summary>

```text
Sample output on r1 (UP window):
  BGP routing table entry for 10.40.0.0/16
  Paths: (1 available, best #1)
    65010 65030 65040
    Last update: 00:00:12 ago (age resets repeatedly!)

Sample output on r1 (DOWN window):
  % Network not in table
```

**Finding:** The prefix `10.40.0.0/16` is rhythmically withdrawn and re-announced in roughly 40-second cycles. Transit's looking glass confirms the same flap on its session to AS 65040, while IXP route-server sessions remain stable. This isolates the fault to dest-1's transit connection with AS 65030.

</details>

## Task 4: Formulate your incident summary

Close the scenario by clicking **Scenario 2 off** in the Control Portal (or run):

```bash
sudo ./scripts/scenario.sh 2 off
```

### Your incident summary

Write it before reading the model answer: symptom with numbers, the evidence that this is a routing problem rather than a lossy link, the responsible network, and whom you would contact.

<details class="answers" markdown="1">
<summary>Model incident summary (reveal after writing your own)</summary>

```text
Key diagnostic evidence:

1. MTR over 100 cycles to target1 (mtr -n --report --report-cycles 100 10.40.10.10):
HOST: host1                       Loss%   Snt   Last   Avg  Best  Wrst StDev
  1.|-- 10.1.10.1                  0.0%   100    0.1   0.1   0.1   0.2   0.0
  2.|-- 10.1.1.1                   0.0%   100    0.2   0.2   0.2   0.3   0.0
  3.|-- 100.64.11.1                0.0%   100    0.5   0.5   0.4   0.7   0.1
  4.|-- 100.64.13.2                0.0%   100   20.8  20.8  20.4  22.1   0.3
  5.|-- ???                       100.0   100    0.0   0.0   0.0   0.0   0.0
  6.|-- 10.40.10.10               48.0%   100   46.1  46.2  45.8  47.9   0.5
  (Intermediate hops stay clean while destination shows ~50% loss)

2. Ping error during outage window:
From 10.1.1.1 icmp_seq=1 Destination Net Unreachable
(Indicates routing table withdrawal on our first hop, not link packet loss)

3. Control plane BGP lookup (show bgp ipv4 unicast 10.40.0.0/16 on r1):
- UP window:   route present, age resets: Last update: 00:00:15 ago
- DOWN window: % Network not in table
```

> **Symptom.** target1 alternates between full reachability and total outage in a regular cycle of roughly 40 seconds each way, in both address families. Over a two-minute mtr, loss to target1 reads near 50%, while every intermediate hop up to the transit carrier stays clean. target2 is unaffected.
>
> **This is routing, not a lossy link.** During outage windows our own routers hold no route to 10.40.0.0/16 or 3fff:40::/32 at all: pings fail with "Network unreachable" from our first hop rather than timing out, and the BGP table entry for the prefix vanishes and reappears with an age of seconds. Packet loss degrades a path; a withdrawn route removes it. We observed removal.
>
> **Root cause attribution.** The transit carrier's own view (via its looking glass) shows its route to dest-1 appearing and disappearing on the same cycle, learned on its direct session to AS 65040. The IXP route server shows all member sessions stable. The instability therefore originates at dest-1's connection to its transit provider: either the dest-1 router, the link between them, or a misbehaving policy repeatedly resetting the session. From outside, we cannot distinguish which, and honest attribution stops at the boundary the evidence supports: AS 65040's transit connection.
>
> **Action.** This is not our network and not our upstream's. We would report the evidence to dest-1's operations contact, and note that every network on the Internet observing this prefix sees the same churn.

</details>

The name for this pattern is a route flap, and its signature, a prefix rhythmically announced and withdrawn, propagates through the routing system to every observer. That last point is the doorway to Unit 3: RIPE RIS records exactly these announcements and withdrawals from hundreds of vantage points, and BGPlay animates them, so the flap you just diagnosed from one AS with a looking glass is the flap you will next watch ripple across the whole Internet.
