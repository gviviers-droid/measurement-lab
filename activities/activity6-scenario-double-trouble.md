# Activity 6, Scenario 3: Double Trouble

**Maps to:** Modules 2.3, 2.5 (Analysing Measurement Data) and 2.6 (Troubleshooting with Measurements)
**Time:** 35 to 45 minutes
**Start state:** lab deployed, `lab-check.sh` all green, congestion stopped, peering down, Scenarios 1 and 2 off.
**Do not read** the files under `scripts/scenarios/`; they contain the answer.

Activities 4 and 5 presented single, isolated incidents. On the real Internet, incidents rarely wait in line: multiple independent faults often occur simultaneously, or one failure triggers secondary degradation elsewhere. This stretch scenario challenges you to analyze a multi-variable incident where two distinct destinations suffer degradation at the same time.

Your deliverable is a comprehensive incident summary proving whether these symptoms share a common cause or represent independent problems, identifying the responsible networks, and proposing concrete actions.

## The ticket

> **Urgent:** Users are reporting widespread degradation across multiple external services. Connectivity to target1 (10.40.10.10 / 3fff:40:10::10) is experiencing severe packet loss and jitter. Simultaneously, target2 (10.50.10.10 / 3fff:50:10::10) has become noticeably sluggish. Management suspects our border connection to Upstream A is failing. Please investigate, isolate the root cause(s), and submit an incident report.

Start the incident by clicking **Scenario 3 on** in the Control Portal (or run on your own machine in the lab folder):

```
sudo ./scripts/scenario.sh 3 on
```

Wait a minute for conditions to stabilize, then investigate.

## Task 1: Disentangle the symptoms (statistical analysis)

Do not assume both targets suffer from the same underlying fault just because the complaints arrived together. Collect measurements for both targets from host1 (via the **host1** terminal in the Control Portal, or `podman exec -it clab-measlab-host1 bash`):

```bash
ping -c 100 -i 0.2 10.40.10.10 | grep -oE 'time=[0-9.]+' | cut -d= -f2 > target1.txt
ping -c 100 -i 0.2 10.50.10.10 | grep -oE 'time=[0-9.]+' | cut -d= -f2 > target2.txt
```

Compute statistics for each:

```bash
sort -n target1.txt | awk '{a[NR]=$1; s+=$1} END {print "t1 count:", NR, "mean:", s/NR, "median:", a[int((NR+1)/2)], "p95:", a[int(NR*0.95)], "min:", a[1], "max:", a[NR]}'
sort -n target2.txt | awk '{a[NR]=$1; s+=$1} END {print "t2 count:", NR, "mean:", s/NR, "median:", a[int((NR+1)/2)], "p95:", a[int(NR*0.95)], "min:", a[1], "max:", a[NR]}'
```

> [!TIP]
> **Comparing latency distributions:**  
> - If `min` stays identical to baseline while `mean`, `p95`, and `max` explode with packet loss: this is **queueing delay** (buffer congestion).  
> - If `min`, `median`, and `mean` all shift upwards together by a steady amount with 0% loss: this is a **propagation delay shift** (physical path detour).

**Question 1.** Compare the distributions of target1 and target2. Which represents queueing delay, and which represents a routing detour?

<details class="answers" markdown="1">
<summary>Check your findings for Task 1 (reveal after measuring)</summary>

```text
Sample statistical comparison:
target1: count:  89 | mean: 118.4 | median: 46.2 | p95: 298.5 | min: 45.8 | max: 418.2 (Loss: ~11%)
target2: count: 100 | mean:  51.2 | median: 51.1 | p95:  51.9 | min: 50.8 | max:  52.4 (Loss:   0%)
```

**Finding:** target1 exhibits severe jitter, elevated mean/p95, and ~11% packet loss, but its `min` is unchanged at ~45.8 ms. This is classic queueing delay (link congestion). In contrast, target2 shows zero loss and negligible jitter, but its entire distribution shifted from <2 ms to ~51 ms. This indicates a longer physical routing path. The two destinations have completely different problems!

</details>

## Task 2: Trace and locate each path (MTR)

Run `mtr` and `traceroute` for each target to isolate where each failure manifests:

```bash
mtr -n --report --report-cycles 50 10.40.10.10
mtr -n --report --report-cycles 50 10.50.10.10
```

> [!TIP]
> **Where to look:**
> - On `target1`: Check the hop where `Loss%` and `Avg` latency jump.
> - On `target2`: Compare the hop sequence against your Activity 1 baseline. Does it detour into the transit carrier (`100.64.13.2`)?

**Question 2.** At which hop does packet loss begin on target1? And which hop does target2 detour through?

<details class="answers" markdown="1">
<summary>Check your findings for Task 2 (reveal after running MTR)</summary>

```text
Sample findings:
- target1 path: host1 -> r3 -> r1 -> ra -> rt -> rd1 (100.64.34.2)
  Loss (~11%) and high jitter start specifically at hop 5 (100.64.34.2, dest-1 entry).
- target2 path: host1 -> r3 -> r1 -> ra -> rt (100.64.13.2) -> rd2 backup port (100.64.35.2) -> target2
  Hops to target2 detour through the transit backbone instead of crossing the IXP!
```

**Finding:** The data plane confirms two distinct locations: target1 experiences link congestion between transit (`rt`) and dest-1 (`rd1`), whereas target2 is detouring over transit to reach dest-2's backup link.

</details>

## Task 3: Consult the control plane and looking glass

Check your BGP table on r1 (switch to the **r1** terminal in the Control Portal and type `vtysh`, or run `podman exec -it clab-measlab-r1 vtysh`):

```
show bgp ipv4 unicast 10.40.0.0/16
show bgp ipv4 unicast 10.50.0.0/16
```

Then query the looking glass (use the **Looking glass** section in the Control Portal, or run from your lab folder):

```bash
sudo ./scripts/lg.sh route-server "show bgp summary"
sudo ./scripts/lg.sh upstream-a "show bgp ipv4 unicast 10.50.0.0/16"
```

> [!TIP]
> **Connecting the evidence:**
> - Check if `10.40.0.0/16`'s BGP path has changed (`65010 65030 65040`).
> - Check `10.50.0.0/16`'s BGP path for AS prepending (`65010 65030 65050 65050...`).
> - Look at the route server's summary: why is dest-2 taking the backup path?

**Question 3.** What do the BGP tables and looking glass reveal about management's theory that our border link is failing?

<details class="answers" markdown="1">
<summary>Check your findings for Task 3 (reveal after BGP inspection)</summary>

```text
Sample BGP lookups:
- 10.40.0.0/16 Path: 65010 65030 65040 (Normal path; congestion is purely in data buffer queues).
- 10.50.0.0/16 Path: 65010 65030 65050 65050 65050 65050 (Prepended backup path active).
- Route server summary: Upstream A (100.64.99.10) session is Active/down!
```

**Finding:** Upstream A dropped off the IXP, which caused target2's route to fail over to transit. Meanwhile, target1's routing is completely normal, but the transit link to AS 65040 is overloaded with traffic. Management's suspicion that "our border link to Upstream A is failing" is completely disproven!

</details>

## Task 4: Formulate the incident summary and test local mitigation

Can you mitigate either symptom locally without waiting for external providers?
* Does changing local preference on r1 towards Upstream B improve reachability for target2?
* Does local routing policy have any effect on target1's congested transit link?

In the Control Portal, switch to the **r1** terminal (`vtysh`):

```
configure terminal
route-map FROM-UPSTREAM-A permit 10
 set local-preference 90
exit
exit
clear bgp * soft in
```

Measure both targets again. Notice target2 recovers to <2 ms via Upstream B, but target1 remains congested. Restore local preference to 200 when done (`set local-preference 200` and `clear bgp * soft in`).

Restore baseline when finished by clicking **Scenario 3 off** in the Control Portal (or run):

```bash
sudo ./scripts/scenario.sh 3 off
```

### Your incident summary

Write it before reading the model answer below. Prove whether these symptoms share a common cause, identify the responsible networks, and propose concrete actions.

<details class="answers" markdown="1">
<summary>Model incident summary (reveal after writing your own)</summary>

```text
Key diagnostic comparison:

target1 (Fault 1 · Congestion & Queueing Loss):
- Statistics:   min: 45.8 ms | median: 46.2 ms | mean: 118.4 ms | p95: 298.5 ms | Loss: ~11%
- Path hops:    host1 -> r3 -> r1 -> ra -> rt -> rd1 (loss & jitter begin at 100.64.34.2)
- BGP path:     65010 65030 65040 (path unchanged, queue saturated)

target2 (Fault 2 · Routing Detour / Trombone):
- Statistics:   min: 50.8 ms | median: 51.1 ms | mean: 51.2 ms | p95: 51.9 ms | Loss: 0%
- Path hops:    host1 -> r3 -> r1 -> ra -> rt -> rd2 backup port (100.64.35.2) -> target2
- BGP path:     65010 65030 65050 65050 65050 65050 (prepended backup path selected)
```

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

</details>

This scenario reinforces the core lesson of Unit 2: **latency is not a single number, and performance degradation is not a single phenomenon**. A shift in minimum RTT points to propagation distance and path changes; a shift in mean/p95 with steady minimum points to queueing and link saturation.
