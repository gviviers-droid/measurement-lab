# Activity 1: Measure the Path

**Maps to:** Modules 2.1 (Active Measurement) and 2.3 (Core Performance Metrics)
**Time:** 30 to 40 minutes
**You need:** the lab deployed and checked (see README.md), plus a terminal.

## The rules of this lab

You run the network of AS 65001: routers r1, r2 and r3, and the workstation host1. You may log in to these four machines and inspect anything on them.

The rest of the lab plays the role of the Internet. Other networks carry your traffic, and you can measure them from the outside, but you cannot log in to them. This mirrors your position as a real network operator: when a problem sits in another AS, you diagnose it with measurements and evidence, then contact the operator responsible. You never get their passwords. Some operators publish a looking glass, a public page for running read-only commands on their routers; this lab has one too (`scripts/lg.sh`), and a later activity uses it.

## The network

Your AS holds 10.1.0.0/16 and the IPv6 allocation 3fff:1::/32, a /32 like every AS in this lab. You connect to two upstream providers. Upstream A (AS 65010) and upstream B (AS 65020) both buy transit from AS 65030 and both peer at an Internet Exchange Point. Two destination networks exist: dest-1 (AS 65040), a hosting network reached through transit, and dest-2 (AS 65050), a content network present at the IXP. Your border router r2 has a port at the IXP as well, but no peering sessions run on it yet. See `../topology-diagram.svg`.

| Address (IPv4 / IPv6) | Machine | Network |
|---|---|---|
| 10.1.10.10 / 3fff:1:10::10 | host1, your workstation | AS 65001 (yours) |
| 10.1.10.1 / 3fff:1:10::1 | r3, your LAN router | AS 65001 (yours) |
| 10.1.1.1 / 3fff:1:0:1::1 | r1, your border router to upstream A | AS 65001 (yours) |
| 10.1.2.1 / 3fff:1:0:2::1 | r2, your border router to upstream B | AS 65001 (yours) |
| 100.64.11.1 / 3fff:10:0:11::1 | upstream A router | AS 65010 |
| 100.64.13.2 / 3fff:30:0:13::2 | transit router, side facing upstream A | AS 65030 |
| 100.64.34.2 / 3fff:30:0:34::2 | dest-1 router | AS 65040 |
| 10.40.10.10 / 3fff:40:10::10 | target1, server in dest-1 | AS 65040 |
| 100.64.99.50 / 3fff:ff::50 | dest-2 router, IXP-facing port | AS 65050 |
| 10.50.10.10 / 3fff:50:10::10 | target2, server in dest-2 | AS 65050 |

Addresses starting with 100.64.99 or 3fff:ff: sit on the IXP peering LAN, a single shared subnet where all members connect.

Open a shell on your workstation (in the Control Portal, switch to the **host1** terminal, or run from your host shell):

```
podman exec -it clab-measlab-host1 bash
```

## Task 1: Discover both paths, in both address families

Run four traceroutes from host1 and keep the outputs:

```
traceroute -n 10.40.10.10
traceroute -n -6 3fff:40:10::10
traceroute -n 10.50.10.10
traceroute -n -6 3fff:50:10::10
```

Using the address table, label every hop with its machine and AS number.

> [!TIP]
> **How to read traceroute output:**
>
> ```text
> Hop #   IP address        Probe 1      Probe 2      Probe 3
>  1      10.1.10.1         0.118 ms     0.095 ms     0.088 ms    <- host1 gateway (r3)
>  2      10.1.1.1          0.231 ms     0.210 ms     0.198 ms    <- Border router A (r1)
>  3      100.64.11.1       0.512 ms     0.485 ms     0.462 ms    <- Upstream A (ra)
>  4      100.64.13.2       20.851 ms    20.720 ms    20.690 ms   <- Transit entry (rt)
>  5      100.64.34.2       45.920 ms    45.810 ms    45.750 ms   <- Dest-1 gateway (rd1)
>  6      10.40.10.10       46.150 ms    46.020 ms    45.980 ms   <- Target 1
> ```

**Question 1a.** How many ASes does your traffic cross to reach target1? And to reach target2?

**Question 1b.** For each target, do IPv4 and IPv6 follow the same sequence of machines?

**Question 1c.** The path to target2 crosses the IXP. Which single hop in the traceroute tells you that, and what is odd about how the exchange itself appears?

<details class="answers" markdown="1">
<summary>Check your answers for Task 1 (reveal after writing your own)</summary>

```text
Sample output (traceroute -n 10.40.10.10):
 1  10.1.10.1    0.118 ms  0.095 ms  0.088 ms
 2  10.1.1.1     0.231 ms  0.210 ms  0.198 ms
 3  100.64.11.1  0.512 ms  0.485 ms  0.462 ms
 4  100.64.13.2  20.851 ms 20.720 ms 20.690 ms
 5  100.64.34.2  45.920 ms 45.810 ms 45.750 ms
 6  10.40.10.10  46.150 ms 46.020 ms 45.980 ms

Sample output (traceroute -n 10.50.10.10):
 1  10.1.10.1     0.115 ms  0.092 ms  0.085 ms
 2  10.1.1.1      0.228 ms  0.205 ms  0.192 ms
 3  100.64.11.1   0.508 ms  0.480 ms  0.458 ms
 4  100.64.99.50  1.482 ms  1.420 ms  1.390 ms  (dest-2 IXP port)
 5  10.50.10.10   1.750 ms  1.690 ms  1.650 ms
```

**1a.** target1: four ASes, your 65001, upstream A (65010), transit (65030) and 65040. target2: three, your 65001, upstream A (65010) and 65050.

**1b.** Yes. In this lab's base state, IPv4 and IPv6 cross the same machines for both targets, which you can verify by matching each v6 hop to the same router's v4 address in the table. On the real Internet the two families sometimes take different paths; a later activity creates that situation.

**1c.** The hop 100.64.99.50 (IPv6: 3fff:ff::50) is dest-2's port on the IXP peering LAN, so your packet went straight from upstream A's IXP port to dest-2's. The odd part: the exchange itself never appears. An IXP is a shared LAN, a layer-2 fabric, so it adds no router hop of its own and, as Task 5 shows, no AS either.

</details>

## Task 2: Locate the latency

Ping both targets, ten packets each, and note the average round-trip times:

```
ping -c 10 10.40.10.10
ping -c 10 10.50.10.10
```

Then walk the target1 path: ping each hop from Task 1 in order and record the average per hop.

**Question 2a.** Between which two hops does the round-trip time to target1 make its first large jump? And its second?

**Question 2b.** target2 sits behind the same upstream as target1, yet answers far faster. Using your per-hop data, express in two sentences why.

**Question 2c.** A colleague concludes that the router at the first jump is overloaded, because latency rises there. Give an alternative explanation for a latency jump between two hops that has nothing to do with router load.

<details class="answers" markdown="1">
<summary>Check your answers for Task 2 (reveal after writing your own)</summary>

```text
Sample output (ping -c 10 10.40.10.10):
--- 10.40.10.10 ping statistics ---
10 packets transmitted, 10 received, 0% packet loss, time 9014ms
rtt min/avg/max/mdev = 45.812/46.104/47.230/0.412 ms

Sample output (ping -c 10 10.50.10.10):
--- 10.50.10.10 ping statistics ---
10 packets transmitted, 10 received, 0% packet loss, time 9012ms
rtt min/avg/max/mdev = 1.450/1.620/1.890/0.125 ms
```

**2a.** First jump: between upstream A (100.64.11.1) and the transit router (100.64.13.2), where the average rises by roughly 20 ms. Second jump: between the transit router and the dest-1 router (100.64.34.2), roughly 25 ms more.

**2b.** target2 skips transit. Traffic crosses the IXP peering LAN directly from upstream A to dest-2, avoiding both impaired long-haul links, so the round trip stays within a few milliseconds. Peering shortens paths, and your measurements have now quantified by how much.

**2c.** Distance. A link spanning a long physical distance adds propagation delay on every packet regardless of how busy the routers at either end are. In this lab the two jumps represent long-haul links, and both were injected on purpose; the routers themselves are idle.

</details>

## Task 3: Jitter and loss

A ping average hides variation. Run mtr, which probes every hop at once and keeps per-hop statistics:

```
mtr -n --report --report-cycles 100 10.40.10.10
```

This takes about two minutes. Read the columns: `Loss%`, `Avg`, `Best`, `Wrst` (worst) and `StDev` (the spread of round-trip times, one way to express jitter). Repeat for target2 and compare.

> [!TIP]
> **Anatomy of an MTR report:**
>
> ```text
> HOST: host1                       Loss%   Snt   Last   Avg  Best  Wrst StDev
>   1.|-- 10.1.10.1                  0.0%   100    0.1   0.1   0.1   0.2   0.0
>   2.|-- 10.1.1.1                   0.0%   100    0.2   0.2   0.2   0.3   0.0
>   3.|-- 100.64.11.1                0.0%   100    0.5   0.5   0.4   0.7   0.1
>   4.|-- 100.64.13.2                0.0%   100   20.7  20.8  20.4  21.9   0.3
>   5.|-- 100.64.34.2                1.0%   100   45.8  46.0  45.5  48.2   0.6
>   6.|-- 10.40.10.10                1.0%   100   46.1  46.2  45.8  47.9   0.5
>                                    ^^^^               ^^^               ^^^^^
>                                 Packet loss         Average            Jitter
>                               (starts hop 5)        latency          (Std Dev)
> ```

**Question 3a.** On the target1 path, at which hop does packet loss first appear, and does it persist to the destination?

**Question 3b.** Which hop shows the largest StDev? Express in one sentence what that number tells you about the path beyond that hop.

<details class="answers" markdown="1">
<summary>Check your answers for Task 3 (reveal after writing your own)</summary>

```text
Sample output (mtr -n --report --report-cycles 100 10.40.10.10):
HOST: host1                       Loss%   Snt   Last   Avg  Best  Wrst StDev
  1.|-- 10.1.10.1                  0.0%   100    0.1   0.1   0.1   0.2   0.0
  2.|-- 10.1.1.1                   0.0%   100    0.2   0.2   0.2   0.3   0.0
  3.|-- 100.64.11.1                0.0%   100    0.5   0.5   0.4   0.7   0.1
  4.|-- 100.64.13.2                0.0%   100   20.8  20.8  20.4  22.1   0.3
  5.|-- 100.64.34.2                1.0%   100   45.9  46.0  45.5  48.2   0.6
  6.|-- 10.40.10.10                1.0%   100   46.1  46.2  45.8  48.5   0.5

Sample output (mtr -n --report --report-cycles 100 10.50.10.10):
HOST: host1                       Loss%   Snt   Last   Avg  Best  Wrst StDev
  1.|-- 10.1.10.1                  0.0%   100    0.1   0.1   0.1   0.2   0.0
  2.|-- 10.1.1.1                   0.0%   100    0.2   0.2   0.2   0.3   0.0
  3.|-- 100.64.11.1                0.0%   100    0.5   0.5   0.4   0.7   0.1
  4.|-- 100.64.99.50               0.0%   100    1.4   1.4   1.3   1.8   0.1
  5.|-- 10.50.10.10                0.0%   100    1.7   1.7   1.5   2.1   0.1
```

**3a.** Loss of around 1% first appears at the dest-1 router (100.64.34.2) and persists to target1. Loss that starts at one hop and continues to the destination points at a real problem on the path. Loss appearing at a single middle hop and then vanishing usually means that router deprioritises replies addressed to itself while forwarding your traffic without harm. The target2 path shows no loss.

**3b.** The final hops of the target1 path show the largest StDev, because they sit behind both jittery links and jitter accumulates along a path. The number tells you how much individual round-trip times swing around the average: unstable delivery, even when the average looks acceptable.

</details>

## Task 4: One ping is not a measurement

Send a longer stream to target1 and read the summary line:

```
ping -c 100 -i 0.2 10.40.10.10
```

The final line reports `min/avg/max/mdev`.

**Question 4a.** How far apart are your minimum and maximum? If you had sent one ping and it happened to hit the maximum, how wrong would your latency estimate have been?

**Question 4b.** For this path, which single number would you report to a colleague as "the latency", and why? Keep your answer; Module 2.5 and the next activity return to this question with better tools.

<details class="answers" markdown="1">
<summary>Check your answers for Task 4 (reveal after writing your own)</summary>

```text
Sample output (ping -c 100 -i 0.2 10.40.10.10 summary):
100 packets transmitted, 99 received, 1% packet loss, time 20025ms
rtt min/avg/max/mdev = 45.712/46.185/58.420/1.340 ms
```

**4a.** Expect a spread of roughly 10 to 20 ms between minimum and maximum. A single ping landing at the maximum would have overstated typical latency by around a quarter to a third.

**4b.** There is no single correct answer, and that is the point. The minimum approximates the clean path latency, the average reflects typical experience, and neither captures the spread. Any honest report needs at least two numbers.

</details>

## Task 5: Read your own BGP table

Your routers learned all these paths through BGP. Open the CLI of your border router r1 (in the Control Portal, switch to the **r1** terminal and type `vtysh`, or run from your host shell):

```
podman exec -it clab-measlab-r1 vtysh
```

Look up both destinations in both address families:

```
show bgp ipv4 unicast 10.40.0.0/16
show bgp ipv6 unicast 3fff:40::/32
show bgp ipv4 unicast 10.50.0.0/16
show bgp ipv6 unicast 3fff:50::/32
```

> [!TIP]
> **How to read BGP routing entries (`show bgp ipv4 unicast <prefix>`):**
>
> ```text
> BGP routing table entry for 10.40.0.0/16
> Paths: (1 available, best #1)
>   65010 65030 65040                         <-- AS Path (read right to left: origin -> transit -> upstream)
>     100.64.11.1 from 100.64.11.1 (ra.measlab) <-- Next hop router and advertising peer
>       Origin IGP, metric 0, valid, external, best (First path received)
> ```

**Question 5a.** Read the AS path attribute for each destination. Which ASes appear, in what order, and does the IXP appear?

**Question 5b.** Compare the AS paths with your traceroutes from Task 1. The traceroute shows individual routers; the AS path shows networks. Do the two views agree?

**Question 5c.** Every AS in this lab announces one IPv4 /16 and one IPv6 /32. A /16 holds 65,536 addresses. Using prefix arithmetic, how many /64 subnets fit in your 3fff:1::/32?

Type `exit` to return to the container shell (or twice to exit if you used `podman exec`).

<details class="answers" markdown="1">
<summary>Check your answers for Task 5 (reveal after writing your own)</summary>

```text
Sample output (show bgp ipv4 unicast 10.40.0.0/16):
BGP routing table entry for 10.40.0.0/16
Paths: (1 available, best #1)
  65010 65030 65040
    100.64.11.1 from 100.64.11.1 (ra.measlab)
      Origin IGP, metric 0, valid, external, best (First path received)

Sample output (show bgp ipv4 unicast 10.50.0.0/16):
BGP routing table entry for 10.50.0.0/16
Paths: (1 available, best #1)
  65010 65050
    100.64.11.1 from 100.64.11.1 (ra.measlab)
      Origin IGP, metric 0, valid, external, best (First path received)
```

**5a.** dest-1: `65010 65030 65040` in both address families. dest-2: `65010 65050`. The IXP's route server (AS 65100) appears in neither path: route servers pass routes between members without inserting themselves, so the exchange stays invisible at the BGP level too.

**5b.** Yes. Each group of traceroute hops falls inside one AS from the BGP path, in the same order, with the IXP LAN forming the invisible seam between 65010 and 65050. BGP gives you the network-level map; traceroute fills in the routers. Unit 3 builds on both views: RIPE Atlas gives you traceroutes from thousands of vantage points, and RIPEstat and RIS give you the BGP view of the whole Internet.

**5c.** A /32 leaves 32 bits before the /64 boundary, so 2^32 subnets: 4,294,967,296 /64s, each holding more host addresses than the entire IPv4 Internet. Your single IPv6 allocation contains as many /64 networks as IPv4 has addresses in total.

</details>
