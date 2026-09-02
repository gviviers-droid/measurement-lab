# Activity 6, Scenario 3: Double Trouble

**Maps to:** Modules 2.3, 2.5 (Analysing Measurement Data) and 2.6 (Troubleshooting with Measurements)
**Time:** 35 to 45 minutes
**Start state:** lab deployed, `lab-check.sh` all green, congestion stopped, peering down, Scenarios 1 and 2 off.
**Do not read** the files under `scripts/scenarios/`; they contain the answer.

Activities 4 and 5 presented single, isolated incidents. On the real Internet, incidents rarely wait in line: multiple independent faults often occur simultaneously, or one failure triggers secondary degradation elsewhere. This stretch scenario challenges you to analyze a multi-variable incident where two distinct destinations suffer degradation at the same time.

Your deliverable is a comprehensive incident summary proving whether these symptoms share a common cause or represent independent problems, identifying the responsible networks, and proposing concrete actions.

## The ticket

> **Urgent:** Users are reporting widespread degradation across multiple external services. Connectivity to target1 (10.40.10.10 / 3fff:40:10::10) is experiencing severe packet loss and jitter. Simultaneously, target2 (10.50.10.10 / 3fff:50:10::10) has become noticeably sluggish. Management suspects our border connection to Upstream A is failing. Please investigate, isolate the root cause(s), and submit an incident report.

Start the incident on your own machine in the lab folder:

```
sudo ./scripts/scenario.sh 3 on
```

Wait a minute for conditions to stabilize, then investigate.

## Suggested investigation, if you want structure

### Step 1: Disentangle the symptoms
Do not assume both targets suffer from the same underlying fault just because the complaints arrived together. Collect measurements for both targets from host1:

```
ping -c 100 -i 0.2 10.40.10.10 | grep -oE 'time=[0-9.]+' | cut -d= -f2 > target1.txt
ping -c 100 -i 0.2 10.50.10.10 | grep -oE 'time=[0-9.]+' | cut -d= -f2 > target2.txt
```

Compute statistics for each:

```
sort -n target1.txt | awk '{a[NR]=$1; s+=$1} END {print "t1 count:", NR, "mean:", s/NR, "median:", a[int((NR+1)/2)], "p95:", a[int(NR*0.95)], "min:", a[1], "max:", a[NR]}'
sort -n target2.txt | awk '{a[NR]=$1; s+=$1} END {print "t2 count:", NR, "mean:", s/NR, "median:", a[int((NR+1)/2)], "p95:", a[int(NR*0.95)], "min:", a[1], "max:", a[NR]}'
```

Compare the distributions:
* Which target exhibits high variance, large difference between mean and median, and packet loss?
* Which target exhibits a stable distribution whose baseline has simply shifted upwards?

### Step 2: Trace and locate each path
Run `mtr` and `traceroute` for each target:

```
mtr -n --report --report-cycles 50 10.40.10.10
mtr -n --report --report-cycles 50 10.50.10.10
```

* On target1, at which specific link do the jitter and packet loss begin?
* On target2, compare the sequence of hops against your baseline from Activity 1. Has the path changed?

### Step 3: Consult the control plane and looking glass
Check your BGP table on r1 (`docker exec -it clab-measlab-r1 vtysh`):

```
show bgp ipv4 unicast 10.40.0.0/16
show bgp ipv4 unicast 10.50.0.0/16
```

Then query the looking glass from your lab folder:

```
sudo ./scripts/lg.sh route-server "show bgp summary"
sudo ./scripts/lg.sh upstream-a "show bgp ipv4 unicast 10.50.0.0/16"
```

* Are both routes learned through the same upstream?
* Does the route server show any peering sessions down?

### Step 4: Optional local mitigation
Can you mitigate either symptom locally without waiting for external providers?
* Does changing local preference on r1 towards Upstream B improve reachability for target2?
* Does local routing policy have any effect on target1's congested transit link?

Restore baseline when finished:

```
sudo ./scripts/scenario.sh 3 off
```

## Model incident summary

Reveal after writing your own.

> **Executive Summary.** The reported issues are two distinct, concurrent faults occurring in separate Autonomous Systems. Our own AS network, local border links, and Upstream A connection are fully operational.
>
> **Fault 1 (target1 · AS 65040): Congestion & Queueing Loss**
> * **Symptom:** Mean RTT increased with high jitter (p95 > 100 ms) and ~10% packet loss. Median RTT remains close to the baseline (~45 ms), and minimum RTT is unchanged.
> * **Root Cause:** Buffer saturation and queueing delay on the rate-limited transit link between AS 65030 (transit) and AS 65040 (`100.64.34.2`). The routing path itself is unchanged.
> * **Action:** Report link saturation to AS 65040 (dest-1) and transit provider AS 65030. No local routing change can bypass this link, as dest-1 has only this single transit path active.
>
> **Fault 2 (target2 · AS 65050): Routing Detour (Tromboning)**
> * **Symptom:** Clean latency increase from <2 ms to ~50 ms across both IPv4 and IPv6, with 0% packet loss and negligible jitter (mean ≈ median ≈ 50 ms).
> * **Root Cause:** Upstream A (AS 65010) lost its BGP peering sessions with the IXP route server (AS 65100). Traffic to dest-2 therefore detoured through the transit carrier AS 65030 and dest-2's prepended backup path (`65010 65030 65050 65050 65050 65050`).
> * **Action & Local Mitigation:** Open a ticket with Upstream A requesting restoration of their IXP peering. In the interim, lower local preference on r1 for Upstream A (`set local-preference 90`) to steer outbound traffic through Upstream B (AS 65020), which maintains active IXP peering, immediately restoring <2 ms latency.

This scenario reinforces the core lesson of Unit 2: **latency is not a single number, and performance degradation is not a single phenomenon**. A shift in minimum RTT points to propagation distance and path changes; a shift in mean/p95 with steady minimum points to queueing and link saturation.
