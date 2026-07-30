# Activity 2: When the Path Gets Busy

**Maps to:** Modules 2.3 (Core Performance Metrics) and 2.5 (Analysing Measurement Data)
**Time:** 30 minutes
**Start state:** lab deployed, `lab-check.sh` all green, congestion stopped, peering down.
**You need:** two terminals: one shell inside host1, and one on your own machine in the lab folder (where you ran `containerlab deploy`).

In Activity 1 you located latency along a path. This activity adds the dimension the Internet never holds still: time. Real links carry other people's traffic, and that load rises and falls with human activity through the day. Your lab compresses that daily cycle into a switch you control, so you can measure the same path under quiet and busy conditions and see which statistics survive the difference.

## Task 1: Establish the baseline

From host1, capture one hundred round-trip times to target1 and store them:

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

## Task 2: Load the path

In your other terminal, on your own machine in the lab folder, switch on the background load:

```
sudo ./scripts/congestion.sh start
```

Another network in upstream A now pushes a heavy stream across the same transit link your traffic uses. You did not cause it and cannot stop their traffic; you can only measure what it does to yours. Wait thirty seconds for the queue to build.

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

## Task 4: Report honestly

Switch the load off and confirm recovery with a short ping:

```
sudo ./scripts/congestion.sh stop
```

**Question 4a.** Your monitoring system samples this path once per hour with a single ping. Sketch what its latency graph would show across a day with two busy periods, and name what it would miss.

**Question 4b.** You may report exactly two numbers per measurement window to describe this path. Which two do you choose, and why those?

**Question 4c.** On the real Internet, load on a link follows the waking hours of the people behind it. Express in two sentences why a measurement campaign for this path must span at least 24 hours, and what a measurement taken only at 04:00 would falsely conclude.

## Check your answers

Reveal these after committing to your own answers.

**3a.** The mean moves more than the median, because the mean absorbs the tail of queueing spikes while the median only shifts with the typical packet. The largest single change appears at the top of the distribution: p95 and max grow by far the most, from tens of milliseconds to potentially hundreds. Exact values vary between machines; the pattern does not.

**3b.** Queueing delay. Packets wait in the buffer of the loaded transit link before transmission, and the mtr report shows the inflation starting at the transit-to-dest-1 hop (100.64.34.2) while earlier hops keep their baseline figures. Propagation delay is physics and constant; queueing delay is load and variable. Telling them apart is one of the most useful skills in latency analysis.

**3c.** Yes. On top of the constant 1% you found in Activity 1, the loaded link drops packets whenever its queue overflows, so loss rises at the same hop and persists to the destination. Congestion loss and the baseline loss share a location but differ in behaviour: one vanishes when the load stops.

**4a.** The graph would show mostly flat baseline values with, at best, one or two elevated samples, depending on whether the hourly probe happened to land inside a busy period. It would miss the shape, depth and duration of both congestion windows entirely, and could miss them altogether. Sampling frequency bounds what a measurement can see; Module 2.5 calls this the resolution of a measurement campaign, and RIPE Atlas anchors this lesson at Internet scale in Unit 3.

**4b.** Median and 95th percentile is the defensible pair: the median describes the typical experience and resists outliers, while p95 exposes the tail that users feel as slowness. Mean plus maximum is the common wrong answer, since one lucky or unlucky packet distorts both.

**4c.** A path measured only during quiet hours describes the link, and a path measured across a full day describes the service people receive from it. A campaign sampling only at 04:00 would conclude the path is fast, clean and stable, and it would be right about the cable and wrong about the Internet.
