# Activity 2: When the Path Gets Busy

**Maps to:** Modules 2.3 (Core Performance Metrics) and 2.5 (Analysing Measurement Data)
**Time:** 30 minutes
**Start state:** lab deployed, `lab-check.sh` all green, congestion stopped, peering down.
**You need:** two terminals: one shell inside host1, and one on your own machine in the lab folder (or use the Control Portal at `http://localhost:8080`).

In Activity 1 you located latency along a path. This activity adds the dimension the Internet never holds still: time. Real links carry other people's traffic, and that load rises and falls with human activity through the day. Your lab compresses that daily cycle into a switch you control, so you can measure the same path under quiet and busy conditions and see which statistics survive the difference.

## Task 1: Establish the baseline

From host1 (switch to the **host1** terminal in the Control Portal, or run `podman exec -it clab-measlab-host1 bash`), capture one hundred round-trip times to target1 and store them:

```
ping -c 100 -i 0.2 10.40.10.10 | grep -oE 'time=[0-9.]+' | cut -d= -f2 > baseline.txt
```

Compute the summary statistics:

```
sort -n baseline.txt | awk '{a[NR]=$1; s+=$1}
  END {print "count:", NR;
       print "mean:", s/NR;
       print "median:", a[int((NR+1)/2)];
       print "p95:", a[int(NR*0.95)];
       print "min:", a[1];
       print "max:", a[NR]}'
```

Record all six numbers. Repeat for IPv6 (`ping -c 100 -i 0.2 3fff:40:10::10`, output to `baseline6.txt`) and confirm the two families measure alike.

> [!TIP]
> **How to interpret summary statistics:**
>
> ```text
> Metric    What it represents                            Expected baseline value
> count     Number of packets that received replies        100 (0% packet loss)
> mean      Arithmetic average of all round-trip times    ~46.1 ms
> median    50th percentile (typical packet experience)   ~46.0 ms (close to mean)
> p95       95th percentile (worst 5% tail latency)       ~47.1 ms (tight spread)
> min       Fastest packet (pure physical propagation)    ~45.8 ms
> max       Slowest packet in this 100-probe sample       ~48.9 ms
> ```
> On an idle, uncongested path, the distribution is tight and symmetrical: `mean` and `median` are virtually identical, and `p95` sits within 1–2 ms of the median because there is zero link queueing.

**Question 1a.** Inspect your baseline statistics. Do `mean` and `median` match closely? What does a tight spread between `median` and `p95` tell you about link queueing?

<details class="answers" markdown="1">
<summary>Check your answers for Task 1 (reveal after writing your own)</summary>

```text
Sample output (sort -n baseline.txt | awk ...):
count: 100
mean: 46.12
median: 46.05
p95: 47.10
min: 45.82
max: 48.91
```

**1a.** Yes, `mean` (~46.1 ms) and `median` (~46.0 ms) are almost identical. A tight spread between median and p95 confirms zero queueing delay: buffers along the path are empty, so packets experience only fixed propagation delay and immediate forwarding.

</details>

## Task 2: Load the path

In the Control Portal, click **Start congestion** (or on your own machine in the lab folder, run):

```bash
sudo ./scripts/congestion.sh start
```

Another network in upstream A now pushes a heavy stream across the same transit link your traffic uses. You did not cause it and cannot stop their traffic; you can only measure what it does to yours. Wait thirty seconds for the queue to build.

> [!TIP]
> **How to verify congestion is active:**  
> Run a quick 3-packet ping from `host1`:
> ```bash
> ping -c 3 10.40.10.10
> ```
> When congestion is active, you will immediately see RTT jump from the ~46 ms baseline to between 80 ms and 300+ ms, and the Control Portal status bar will show **Congestion: Active (10.5M)**.

<details class="answers" markdown="1">
<summary>Check your setup for Task 2 (reveal after starting congestion)</summary>

```text
Sample output (quick verification from host1):
64 bytes from 10.40.10.10: icmp_seq=1 ttl=59 time=138.4 ms
64 bytes from 10.40.10.10: icmp_seq=2 ttl=59 time=242.1 ms
64 bytes from 10.40.10.10: icmp_seq=3 ttl=59 time=94.7 ms
```

The latency jump confirms that cross-traffic buffers are filling up and queueing delay has begun.

</details>

## Task 3: Measure the busy path

From host1, repeat the exact measurement into a new file:

```
ping -c 100 -i 0.2 10.40.10.10 | grep -oE 'time=[0-9.]+' | cut -d= -f2 > busy.txt
```

Run the same statistics on `busy.txt`. Note the count as well: pings that received no reply produce no line, so a shrinking count is your loss figure. Then run mtr for the per-hop view:

```
mtr -n --report --report-cycles 100 10.40.10.10
```

**Question 3a.** Compare baseline and busy: which moved more, the mean or the median? Which single statistic changed the most?

**Question 3b.** In Activity 1 you explained the baseline latency with distance. Distance has not changed. Name the delay component that has, and state where along the path it lives (use the mtr output as evidence).

**Question 3c.** Did loss change, and at the same hop as in Activity 1 or elsewhere?

<details class="answers" markdown="1">
<summary>Check your answers for Task 3 (reveal after writing your own)</summary>

```text
Sample statistical comparison:
baseline.txt: count: 100 | mean:  46.12 | median: 46.05 | p95:  47.10 | min: 45.82 | max:  48.91
busy.txt:     count:  88 | mean: 115.42 | median: 68.10 | p95: 295.30 | min: 45.90 | max: 418.50

Sample MTR report under congestion (mtr -n --report --report-cycles 100 10.40.10.10):
HOST: host1                       Loss%   Snt   Last   Avg  Best  Wrst StDev
  1.|-- 10.1.10.1                  0.0%   100    0.1   0.1   0.1   0.2   0.0
  2.|-- 10.1.1.1                   0.0%   100    0.2   0.2   0.2   0.3   0.0
  3.|-- 100.64.11.1                0.0%   100    0.5   0.5   0.4   0.7   0.1
  4.|-- 100.64.13.2                0.0%   100   20.8  20.8  20.4  22.1   0.3
  5.|-- 100.64.34.2               12.0%   100  124.5 116.8  45.9 415.2  86.4
  6.|-- 10.40.10.10               12.0%   100  125.1 117.2  46.1 418.5  86.1
```

**3a.** The mean moves more than the median, because the mean absorbs the tail of queueing spikes while the median only shifts with the typical packet. The largest single change appears at the top of the distribution: p95 and max grow by far the most, from tens of milliseconds to potentially hundreds. Exact values vary between machines; the pattern does not.

**3b.** Queueing delay. Packets wait in the buffer of the loaded transit link before transmission, and the mtr report shows the inflation starting at the transit-to-dest-1 hop (100.64.34.2) while earlier hops keep their baseline figures. Propagation delay is physics and constant; queueing delay is load and variable. Telling them apart is one of the most useful skills in latency analysis.

**3c.** Yes. On top of the constant 1% you found in Activity 1, the loaded link drops packets whenever its queue overflows, so loss rises at the same hop and persists to the destination. Congestion loss and the baseline loss share a location but differ in behaviour: one vanishes when the load stops.

</details>

## Task 4: Report honestly

Switch the load off by clicking **Stop congestion** in the Control Portal (or run `sudo ./scripts/congestion.sh stop` from your host terminal), and confirm recovery with a short ping:

```
sudo ./scripts/congestion.sh stop
```

**Question 4a.** Your monitoring system samples this path once per hour with a single ping. Sketch what its latency graph would show across a day with two busy periods, and name what it would miss.

**Question 4b.** You may report exactly two numbers per measurement window to describe this path. Which two do you choose, and why those?

**Question 4c.** On the real Internet, load on a link follows the waking hours of the people behind it. Express in two sentences why a measurement campaign for this path must span at least 24 hours, and what a measurement taken only at 04:00 would falsely conclude.

<details class="answers" markdown="1">
<summary>Check your answers for Task 4 (reveal after writing your own)</summary>

**4a.** The graph would show mostly flat baseline values with, at best, one or two elevated samples, depending on whether the hourly probe happened to land inside a busy period. It would miss the shape, depth and duration of both congestion windows entirely, and could miss them altogether. Sampling frequency bounds what a measurement can see; Module 2.5 calls this the resolution of a measurement campaign, and RIPE Atlas anchors this lesson at Internet scale in Unit 3.

**4b.** Median and 95th percentile is the defensible pair: the median describes the typical experience and resists outliers, while p95 exposes the tail that users feel as slowness. Mean plus maximum is the common wrong answer, since one lucky or unlucky packet distorts both.

**4c.** A path measured only during quiet hours describes the link, and a path measured across a full day describes the service people receive from it. A campaign sampling only at 04:00 would conclude the path is fast, clean and stable, and it would be right about the cable and wrong about the Internet.

</details>
