# Activity 2: When the Path Gets Busy

**Maps to:** Modules 2.6 (Core Performance Metrics: Jitter, Loss and the Whole Picture), 2.7 (Bandwidth, Congestion, Time of Day) and 2.8 (Interpreting Data, Detecting Anomalies)
**Time:** 30 minutes
**Start state:** lab deployed, `lab-check.sh` passing every check, congestion stopped, peering down.
**You need:** two terminals: one shell inside host1, and one on your own machine in the lab folder (or use the Control Portal at `http://localhost:8080`).

In Activity 1 you found where the delay sits on a path. This activity adds time. Real links carry other people's traffic. That load rises and falls through the day.

In this lab, a switch that you control stands in for the busy hours. You measure the same path when it is quiet and when it is busy. Then you compare which statistics change.

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
> **What each summary statistic shows:**
>
> | Statistic | What it shows |
> |---|---|
> | `count` | Replies received. Each lost ping is missing. |
> | `mean` | The average round trip. Slow replies pull it up. |
> | `median` | The middle value: the typical round trip. |
> | `p95` | 95% of round trips were at or below this value. |
> | `min` | Fastest round trip: the floor of the path. |
> | `max` | Slowest round trip in this sample. |
>
> On a quiet path the mean and the median sit close together. The spread comes from the variable delay built into the lab's long links. You measured it in Activity 1.

**Question 1a.** Inspect your baseline statistics. Do `mean` and `median` match closely? How far above the median does `p95` sit, and what causes that spread on a quiet path?

<details class="answers" markdown="1">
<summary>Check your answers for Task 1 (reveal after writing your own)</summary>

```text
Sample output (sort -n baseline.txt | awk ...):
count: 100
mean: 51.945
median: 51.7
p95: 59.2
min: 42.1
max: 64.9

Sample output (the same statistics for baseline6.txt):
count: 100
mean: 51.73
median: 51.0
p95: 59.5
min: 43.6
max: 61.2
```

**1a.** Yes. The mean (51.945 ms) and the median (51.7 ms) are almost the same. No slow tail pulls the mean up.

The p95 (59.2 ms) sits about 7.5 ms above the median. That spread comes from the variable delay built into the lab's long links. Queuing adds to it only under load. IPv6 gives almost the same figures.

</details>

## Task 2: Load the path

In the Control Portal, click **Start congestion** (or on your own machine in the lab folder, run):

```bash
sudo ./scripts/congestion.sh start
```

A host inside upstream A's network now sends bursts of heavy traffic. They cross the same transit link that your traffic uses.

You did not cause this traffic and you cannot stop it. You can only measure what it does to your traffic. Wait thirty seconds for the queue to build.

> [!TIP]
> **How to check that congestion is running:**
>
> Run a quick 3-packet ping from `host1`:
> ```bash
> ping -c 3 10.40.10.10
> ```
> The congestion comes in bursts. Some replies stay near the quiet figure of about 52 ms. Others take hundreds of milliseconds. If all three look normal, run the ping again. The Control Portal status bar shows **Congestion: Active (bursts)**.

<details class="answers" markdown="1">
<summary>Check your setup for Task 2 (reveal after starting congestion)</summary>

```text
Sample output (quick check from host1):
64 bytes from 10.40.10.10: icmp_seq=1 ttl=59 time=58.1 ms
64 bytes from 10.40.10.10: icmp_seq=2 ttl=59 time=54.8 ms
64 bytes from 10.40.10.10: icmp_seq=3 ttl=59 time=257 ms
```

Two replies sit near the quiet figure. The third took 257 ms. A burst of cross traffic most likely filled the queue ahead of it.

</details>

## Task 3: Measure the busy path

From host1, repeat the exact measurement into a new file:

```
ping -c 100 -i 0.2 10.40.10.10 | grep -oE 'time=[0-9.]+' | cut -d= -f2 > busy.txt
```

Run the same statistics on `busy.txt`. Note the count as well. A ping that receives no reply produces no line, so a smaller count shows loss. Then run mtr for the per-hop view:

```
mtr -n --report --report-cycles 100 10.40.10.10
```

**Question 3a.** Compare baseline and busy: which moved more, the mean or the median? Which single statistic changed the most?

**Question 3b.** In Activity 1 you explained the baseline latency with distance. Distance has not changed. Name the delay component that has, and state where along the path it lives (use the mtr output as evidence).

**Question 3c.** Did loss change, and at the same hop as in Activity 1 or elsewhere?

<details class="answers" markdown="1">
<summary>Check your answers for Task 3 (reveal after writing your own)</summary>

```text
Sample output (the same statistics for busy.txt):
count: 100
mean: 87.575
median: 54.7
p95: 333
min: 45.0
max: 411

Sample output (mtr -n --report --report-cycles 100 10.40.10.10, under congestion):
HOST: host1                       Loss%   Snt   Last   Avg  Best  Wrst StDev
  1.|-- 10.1.10.1                  0.0%   100    0.0   0.1   0.0   0.3   0.0
  2.|-- 10.1.1.1                   0.0%   100    0.1   0.1   0.0   0.3   0.1
  3.|-- 100.64.11.1                0.0%   100    0.1   0.1   0.0   0.3   0.1
  4.|-- 100.64.13.2                0.0%   100   17.7  22.5  17.7  32.8   3.3
  5.|-- 100.64.34.2                2.0%   100   42.0 113.3  42.0 409.7 115.6
  6.|-- 10.40.10.10                2.0%   100   50.9 115.3  42.8 450.3 122.1
```

| Statistic | Baseline (ms) | Busy (ms) |
|---|---|---|
| `count` | 100 | 100 |
| `min` | 42.1 | 45.0 |
| `median` | 51.7 | 54.7 |
| `mean` | 51.945 | 87.575 |
| `p95` | 59.2 | 333 |
| `max` | 64.9 | 411 |

**3a.** The mean moved more. It rose by about 36 ms, and the median rose by 3 ms. The minimum stayed near the baseline. Most packets still met a short queue, and a burst delayed the rest by hundreds of milliseconds.

The maximum changed most, from 64.9 to 411 ms. The p95 came close, from 59.2 to 333 ms. The maximum is one packet. The p95 shows that the slowest 5% of round trips took 333 ms or more.

These are the signs of congestion from Module 2.7. The typical round trip barely moves. The mean, the p95 and the spread rise. Your figures will differ, but the pattern should be the same.

**3b.** Queuing delay. Packets wait in the queue of the busy transit link towards dest-1. The mtr report shows where the rise starts:

- Hop 4 (100.64.13.2) averages 22.5 ms, as on the quiet path.
- Hop 5 (100.64.34.2) averages 113.3 ms.

Propagation delay depends on distance and stays fixed. Queuing delay changes with load.

**3c.** A little, at the same place. Ping lost no packets in 100. The mtr report shows 2.0% loss at hop 5 and at target1. In Activity 1 the sample showed 0.0% at hop 5 and 1.0% at target1.

The loss sits at the same hop as the delay. One run with so few lost packets cannot separate the loss built into the link from loss caused by a full queue.

</details>

## Task 4: Report honestly

Switch the load off by clicking **Stop congestion** in the Control Portal (or run `sudo ./scripts/congestion.sh stop` from your host terminal):

```
sudo ./scripts/congestion.sh stop
```

Then confirm recovery from host1 with a short ping:

```
ping -c 20 10.40.10.10
```

**Question 4a.** Your monitoring system samples this path once per hour with a single ping. Sketch what its latency graph would show across a day with two busy periods, and name what it would miss.

**Question 4b.** You may report exactly two numbers per measurement window to describe this path. Which two do you choose, and why those?

**Question 4c.** On the real Internet, load on a link follows the waking hours of the people behind it. Express in two sentences why a measurement campaign for this path must span at least 24 hours. Say also what a measurement taken only at 04:00 would falsely conclude.

<details class="answers" markdown="1">
<summary>Check your answers for Task 4 (reveal after writing your own)</summary>

```text
Sample output (ping -c 20 10.40.10.10 after stopping congestion, last lines):
--- 10.40.10.10 ping statistics ---
20 packets transmitted, 20 received, 0% packet loss, time 19122ms
rtt min/avg/max/mdev = 44.042/53.479/61.553/4.881 ms
```

The path recovers at once. The average is back near the quiet figure of about 52 ms.

**4a.** The graph would show mostly flat baseline values. It might show one or two high samples, if the hourly ping landed inside a busy period. Even then, in this lab most busy pings still came back near the baseline, so a single ping can miss the busy period completely.

The graph would miss when each busy period starts, how long it lasts and how bad it gets. How often you measure is your sampling rate (Module 1.4). It limits what a measurement can see.

**4b.** The median and the 95th percentile. The median describes the typical round trip and ignores a few slow packets. The p95 shows how slow the slowest 5% get, and users feel those as slowness (Module 2.8).

In this activity the median moved from 51.7 to 54.7 ms and the p95 from 59.2 to 333 ms.

Mean plus maximum is the common wrong answer. A few slow packets pull the mean, and the maximum is a single packet.

**4c.** Load follows the daily cycle, so only a full day of measurements covers the quiet hours and the busy ones. A campaign that measures only at 04:00 would report a quiet path of about 52 ms and miss the busy hours.

</details>
