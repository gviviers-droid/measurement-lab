# Activity 6: Two Faults at Once (Stretch)

**Maps to:** Modules 2.6 (Core Performance Metrics: Jitter, Loss and the Whole Picture), 2.8 (Interpreting Data, Detecting Anomalies) and 2.9 (Systematic Troubleshooting)
**Time:** 35 to 45 minutes
**Start state:** lab deployed, `lab-check.sh` all green, congestion stopped, peering down, Scenarios 1 and 2 off.
**Do not read** the files under `scripts/scenarios/`. They contain the answer.

Activities 4 and 5 each gave you one fault. Here two faults happen at the same time, to two different destinations. This activity is harder than the others. Your job is to tell the two faults apart.

Your deliverable is an incident summary. It says whether the two symptoms share a cause. It says where the evidence places each fault, how sure you are and whom you would tell.

## The ticket

> **Urgent:** target1 (10.40.10.10 / 3fff:40:10::10) is slow and loses some packets. At the same time, target2 (10.50.10.10 / 3fff:50:10::10) has become slower. Management suspects that the border link to upstream A is failing. Please investigate and send an incident report.

Start the incident by clicking **Scenario 3 on** in the Control Portal (or run on your own machine in the lab folder):

```
sudo ./scripts/scenario.sh 3 on
```

Wait a minute for the symptoms to appear, then investigate.

## Task 1: Separate the symptoms with statistics

The two complaints arrived together. That does not mean they share a cause. Collect measurements for both targets from host1 (via the **host1** terminal in the Control Portal, or `podman exec -it clab-measlab-host1 bash`):

```bash
ping -c 100 -i 0.2 10.40.10.10 | grep -oE 'time=[0-9.]+' | cut -d= -f2 > target1.txt
ping -c 100 -i 0.2 10.50.10.10 | grep -oE 'time=[0-9.]+' | cut -d= -f2 > target2.txt
```

Compute statistics for each:

```bash
sort -n target1.txt | awk '{a[NR]=$1; s+=$1} END {print "t1 count:", NR, "mean:", s/NR, "median:", a[int((NR+1)/2)], "p95:", a[int(NR*0.95)], "min:", a[1], "max:", a[NR]}'
sort -n target2.txt | awk '{a[NR]=$1; s+=$1} END {print "t2 count:", NR, "mean:", s/NR, "median:", a[int((NR+1)/2)], "p95:", a[int(NR*0.95)], "min:", a[1], "max:", a[NR]}'
```

Compare each figure with your baseline from Activity 1. The count is the number of replies out of 100, so it also gives you the loss.

The pipeline keeps only the round-trip times. For jitter, run each ping once more without the pipe. Read `mdev` at the end of ping's summary line (Module 2.6).

> [!TIP]
> **Comparing latency distributions:**  
> - If `min` and `median` stay near your baseline while `mean`, `p95` and `max` rise, some packets wait in a queue. This is **queuing delay** (Module 2.7).  
> - If `min`, `median` and `mean` all rise by about the same amount, every packet travels further. The **path has changed**.

**Question 1.** Compare the distributions of target1 and target2. Which one shows queuing delay, and which one shows a path change?

<details class="answers" markdown="1">
<summary>Check your findings for Task 1 (reveal after measuring)</summary>

```text
Sample output (the statistics above, run during Scenario 3):
t1 count: 99 mean: 131.73 median: 53.6 p95: 387 min: 42.5 max: 418
t2 count: 100 mean: 41.282 median: 40.4 p95: 47.8 min: 36.1 max: 53.4
```

```text
Sample summary lines from the same pings, run without the pipe:
--- 10.40.10.10 ping statistics ---
100 packets transmitted, 99 received, 1% packet loss, time 20090ms
rtt min/avg/max/mdev = 42.489/131.748/418.140/120.858 ms, pipe 3
--- 10.50.10.10 ping statistics ---
100 packets transmitted, 100 received, 0% packet loss, time 20074ms
rtt min/avg/max/mdev = 36.093/41.282/53.390/3.364 ms
```

**Finding for target1:** the minimum (42.5 ms) and median (53.6 ms) stay near the baseline of about 43 ms and 53 ms. The mean rose to 131.7 ms and the p95 to 387 ms. Jitter (`mdev`) rose from about 5 ms to 120.9 ms.

In all, 99 of 100 pings got a reply, so loss was 1%. This is the shape of queuing delay. Some packets wait in a queue, and most do not.

**Finding for target2:** no packet was lost. The minimum rose from about 7.6 ms to 36.1 ms, and the median from about 10.6 ms to 40.4 ms. Jitter (`mdev`) stayed small, at 3.4 ms against about 1.5 ms at baseline.

This is the shape of a path change. Every packet now travels further.

The two targets have different problems.

</details>

## Task 2: Trace and locate each path with mtr

Run mtr for each target to find where each problem starts:

```bash
mtr -n --report --report-cycles 50 10.40.10.10
mtr -n --report --report-cycles 50 10.50.10.10
```

> [!TIP]
> **Where to look:**
> - For target1: find the hop where `Avg` and `Wrst` jump.
> - For target2: compare the hops with your Activity 1 baseline. Does the path now go through transit (`100.64.13.2`)?

**Question 2.** At which hop does the delay to target1 begin? Which network does target2's path now cross?

<details class="answers" markdown="1">
<summary>Check your findings for Task 2 (reveal after running mtr)</summary>

```text
Sample output for target1 (mtr -n --report --report-cycles 50 10.40.10.10):
HOST: host1                       Loss%   Snt   Last   Avg  Best  Wrst StDev
  1.|-- 10.1.10.1                  0.0%    50    0.2   0.1   0.0   0.2   0.1
  2.|-- 10.1.1.1                   0.0%    50    0.2   0.1   0.0   0.2   0.1
  3.|-- 100.64.11.1                0.0%    50    0.2   0.2   0.0   0.6   0.1
  4.|-- 100.64.13.2                0.0%    50   26.7  21.8  17.5  27.4   2.5
  5.|-- 100.64.34.2                2.0%    50  380.1 127.2  43.3 401.0 114.3
  6.|-- 10.40.10.10                0.0%    50  447.0 133.8  41.9 447.0 127.9
```

```text
Sample output for target2 (mtr -n -r -c 20 10.50.10.10, 20 cycles):
HOST: host1                       Loss%   Snt   Last   Avg  Best  Wrst StDev
  1.|-- 10.1.10.1                  0.0%    20    0.2   0.1   0.1   0.2   0.0
  2.|-- 10.1.1.1                   0.0%    20    0.1   0.1   0.0   0.2   0.0
  3.|-- 100.64.11.1                0.0%    20    0.2   0.2   0.0   0.3   0.1
  4.|-- 100.64.13.2                0.0%    20   23.2  22.3  19.1  28.9   2.4
  5.|-- 100.64.99.50               0.0%    20   38.1  40.5  37.2  47.0   2.8
  6.|-- 10.50.10.10                0.0%    20   38.8  41.9  38.3  49.8   2.8
```

**Finding for target1:** hops 1 to 4 are normal. At hop 5, `100.64.34.2`, the average jumps from 21.8 ms to 127.2 ms. The worst reply reaches 401 ms. So the delay starts on the link from transit into dest-1.

Hop 5 shows 2% loss, but target1 shows none. Loss that does not continue to the destination is not loss on the path.

**Finding for target2:** hop 4 is now transit, `100.64.13.2`. In Activity 1, hop 4 was `100.64.99.50`, dest-2's port at the exchange. The path now crosses transit.

Hop 5 shows `100.64.99.50`. That does not mean your packets crossed the exchange. A router can answer from a different port than the one your packet arrived on. In Task 3, the autonomous system (AS) path shows which way your packets go.

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
> - Check whether the AS path of `10.40.0.0/16` has changed. In Activity 1 it was `65010 65030 65040`.
> - Check the AS path of `10.50.0.0/16` for AS prepending, which is one AS number repeated (`65010 65030 65050 65050 ...`).
> - In the route server's summary, find the session that reads `Active`. dest-1 has no session at the exchange in this lab. Your r2's session is down while peering is off.

**Question 3.** What do the BGP tables and the looking glass tell you about management's theory that the border link to upstream A is failing?

<details class="answers" markdown="1">
<summary>Check your findings for Task 3 (reveal after BGP inspection)</summary>

```text
Sample output on r1 for 10.40.0.0/16:
BGP routing table entry for 10.40.0.0/16, version 26
Paths: (1 available, best #1, table default)
  Advertised to non peer-group peers:
  10.1.255.2 10.1.255.3
  65010 65030 65040
    100.64.11.1 from 100.64.11.1 (10.10.255.1)
      Origin IGP, localpref 200, valid, external, best (First path received)
      Last update: Sat Oct  3 06:16:08 2026
```

```text
Sample output on r1 for 10.50.0.0/16:
BGP routing table entry for 10.50.0.0/16, version 27
Paths: (1 available, best #1, table default)
  Advertised to non peer-group peers:
  10.1.255.2 10.1.255.3
  65010 65030 65050 65050 65050 65050
    100.64.11.1 from 100.64.11.1 (10.10.255.1)
      Origin IGP, localpref 200, valid, external, best (First path received)
      Last update: Sat Oct  3 06:18:36 2026
```

```text
Sample output, route server sessions (IPv4 rows):
Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
100.64.99.10    4      65010        49        56        0    0    0 00:04:00       Active        0 N/A
100.64.99.20    4      65020        48        56        9    0    0 00:43:23            2        3 N/A
100.64.99.40    4      65040         0        20        0    0    0    never       Active        0 N/A
100.64.99.50    4      65050        47        56        9    0    0 00:43:21            1        3 N/A
100.64.99.100   4      65001         8        24        0    0    0 00:19:42       Active        0 N/A
```

```text
Sample output, upstream A's looking glass for 10.50.0.0/16:
BGP routing table entry for 10.50.0.0/16, version 23
Paths: (1 available, best #1, table default)
  Advertised to non peer-group peers:
  100.64.11.2
  65030 65050 65050 65050 65050
    100.64.13.2 from 100.64.13.2 (10.30.255.1)
      Origin IGP, valid, external, best (First path received)
      Last update: Sat Oct  3 05:39:16 2026
```

**Finding:**

* r1 still learns both prefixes from upstream A (`100.64.11.1`). The path to `10.40.0.0/16` is unchanged.
* The path to `10.50.0.0/16` now goes through transit. `65050` appears four times, so dest-2 adds its AS number three extra times. That makes this path look longer than a path across the exchange.
* At the route server, the session with upstream A (`100.64.99.10`) reads `Active`, so it is down. Upstream A now has only the path through transit to dest-2.
* The rows for dest-1 (`100.64.99.40`) and your r2 (`100.64.99.100`) also read `Active`. Both are down in the start state too.

The evidence does not support management's theory. Hop 3, upstream A's router, answers with no loss or added delay. r1 still learns routes from upstream A. The change is in upstream A's session at the exchange. The route server does not show which side ended that session.

</details>

## Task 4: Check a second exit, then write your incident summary

Your network has a second exit, through r2 and upstream B. Would a path through upstream B avoid either fault? Answer from the evidence. Do not change any routing.

Read r2's table. In the Control Portal, switch to the **r2** terminal and type `vtysh`. Or run `podman exec -it clab-measlab-r2 vtysh`. Use these commands:

```
show bgp ipv4 unicast 10.40.0.0/16
show bgp ipv4 unicast 10.50.0.0/16
```

Then read upstream B's view through the looking glass:

```bash
sudo ./scripts/lg.sh upstream-b "show bgp ipv4 unicast 10.50.0.0/16"
```

**Question 4.** Would a path through upstream B avoid either fault? Use the AS paths to answer.

<details class="answers" markdown="1">
<summary>Check your findings for Task 4 (reveal after reading the tables)</summary>

```text
Sample output on r2 for 10.40.0.0/16 (captured in the start state, before Scenario 3):
BGP routing table entry for 10.40.0.0/16, version 10
Paths: (2 available, best #1, table default)
  Not advertised to any peer
  65010 65030 65040
    10.1.255.1 (metric 10) from 10.1.255.1 (10.1.255.1)
      Origin IGP, localpref 200, valid, internal, best (Local Pref)
      Last update: Sat Oct  3 05:39:29 2026
  65020 65030 65040
    100.64.22.1 from 100.64.22.1 (10.20.255.1)
      Origin IGP, valid, external
      Last update: Sat Oct  3 05:39:16 2026
```

```text
Sample output on r2 for 10.50.0.0/16 (captured during Scenario 1, which Scenario 3 also turns on):
BGP routing table entry for 10.50.0.0/16, version 21
Paths: (2 available, best #1, table default)
  Not advertised to any peer
  65010 65030 65050 65050 65050 65050
    10.1.255.1 (metric 10) from 10.1.255.1 (10.1.255.1)
      Origin IGP, localpref 200, valid, internal, best (Local Pref)
      Last update: Sat Oct  3 06:03:39 2026
  65020 65050
    100.64.22.1 from 100.64.22.1 (10.20.255.1)
      Origin IGP, valid, external
      Last update: Sat Oct  3 05:39:16 2026
```

```text
Sample output, upstream B's looking glass for 10.50.0.0/16 (during Scenario 3):
BGP routing table entry for 10.50.0.0/16, version 6
Paths: (2 available, best #1, table default)
  Advertised to non peer-group peers:
  100.64.22.2
  65050
    100.64.99.50 from 100.64.99.1 (100.64.99.1)
      Origin IGP, metric 0, valid, external, best (AS Path)
      Last update: Sat Oct  3 05:39:17 2026
  65030 65050 65050 65050 65050
    100.64.23.2 from 100.64.23.2 (10.30.255.1)
      Origin IGP, valid, external
      Last update: Sat Oct  3 05:39:17 2026
```

**Finding for target2:** yes. Upstream B's best path to `10.50.0.0/16` is `65050`, learned from the route server across the exchange. Your router r2 also has this path, as `65020 65050`. It uses the path through r1, because that path has the higher local preference (`best (Local Pref)`).

**Finding for target1:** no. Every path you can see to `10.40.0.0/16` ends `65030 65040`. dest-1 has no session at the exchange. So every path crosses the link from transit into dest-1, where the delay starts.

Which exit to use is a decision for the team that runs your network. Your report gives them the evidence.

</details>

Restore baseline when finished by clicking **Scenario 3 off** in the Control Portal (or run):

```bash
sudo ./scripts/scenario.sh 3 off
```

### Your incident summary

Write it before reading the model answer below. Cover these points:

* whether the two symptoms share a cause
* where the evidence places each fault, and how sure you are
* what the evidence does not show
* whom you would tell, and which measurement will show recovery

<details class="answers" markdown="1">
<summary>Model incident summary (reveal after writing your own)</summary>

```text
Key evidence:

target1, statistics and ping summary (ping -c 100 -i 0.2 10.40.10.10):
t1 count: 99 mean: 131.73 median: 53.6 p95: 387 min: 42.5 max: 418
100 packets transmitted, 99 received, 1% packet loss, time 20090ms
rtt min/avg/max/mdev = 42.489/131.748/418.140/120.858 ms, pipe 3

target1, hop 5 in mtr (mtr -n --report --report-cycles 50 10.40.10.10):
  5.|-- 100.64.34.2                2.0%    50  380.1 127.2  43.3 401.0 114.3

target1, AS path on r1:
  65010 65030 65040

target2, statistics and ping summary (ping -c 100 -i 0.2 10.50.10.10):
t2 count: 100 mean: 41.282 median: 40.4 p95: 47.8 min: 36.1 max: 53.4
100 packets transmitted, 100 received, 0% packet loss, time 20074ms
rtt min/avg/max/mdev = 36.093/41.282/53.390/3.364 ms

target2, AS path on r1:
  65010 65030 65050 65050 65050 65050

Route server, the session with upstream A:
100.64.99.10    4      65010        49        56        0    0    0 00:04:00       Active        0 N/A
```

> **Context.** Users reported that target1 was slow and lost packets. They also reported that target2 had become slower. Management suspected the border link to upstream A. You measured both targets from host1 over a few minutes.
>
> **Method.** 100 pings to each target, with the median, p95 and loss. Ping's `mdev` as the jitter figure. An mtr report to each target. The AS paths on r1 and r2. The route server, upstream A and upstream B through the looking glass.
>
> **Findings.**
>
> * target1: minimum 42.5 ms and median 53.6 ms, near the baseline. Mean 131.7 ms, p95 387 ms, `mdev` 120.9 ms. Loss 1%.
> * target1: the delay starts at hop 5, dest-1's router. The AS path is unchanged.
> * target2: no loss. The minimum and median rose by about 30 ms, to 36.1 ms and 40.4 ms. `mdev` 3.4 ms.
> * target2: the path now crosses transit. The AS path is `65010 65030 65050 65050 65050 65050`, with dest-2's prepending.
> * The route server shows its session with upstream A down. Hops 1 to 3, up to upstream A's router, answer with no loss or added delay.
>
> **Conclusions.** The two symptoms have different causes. For target1, the evidence strongly indicates queuing delay on the link from transit (AS 65030) into dest-1 (AS 65040). For target2, it strongly indicates a path change. Upstream A's session at the exchange is down. So its route to dest-2 now crosses transit.
>
> The evidence does not support a fault on the link between your network and upstream A.
>
> The data comes from one vantage point (host1) over a few minutes, with one prefix per destination. The route server does not show which side ended upstream A's session, or why.
>
> A path through upstream B would avoid the detour to target2. No path you can see avoids the delay to target1.
>
> **Next Steps.**
>
> * Send the target1 evidence to the operators of transit (AS 65030) and dest-1 (AS 65040). The delay starts on the link between them.
> * Send the target2 evidence to upstream A. Ask them to check their session at the exchange.
> * Give the team that runs your network the Task 4 finding about upstream B. That team decides whether to change anything.
> * To confirm recovery, repeat the ping statistics for both targets. For target1, look for the mean and p95 to fall back near the median. For target2, look for the median to return to about 10 ms.

</details>

Latency is more than one number. Slow performance can also have more than one cause. A rise in the minimum points to a longer path. A rise in the mean and p95, with a steady minimum, points to queuing.
