# Activity 1: Measure the Path

**Maps to:** Modules 2.2 (Active Measurement: Ping) and 2.3 (Traceroute and Advanced Tools)
**Time:** 30 to 40 minutes
**You need:** the lab deployed and checked (see `README.md`), plus a terminal.

## The rules of this lab

You run the network of autonomous system (AS) 65001. It has the routers r1, r2 and r3 and the workstation host1. You may log in to these four machines and inspect anything on them.

The rest of the lab plays the part of the Internet. Other networks carry your traffic. You can measure them from the outside, but you cannot log in to them.

A real network operator works the same way. When a problem sits in another AS, you find it with measurements. Then you send your evidence to the network it points to. You never get that network's passwords.

Some operators publish a looking glass. This is a public page that runs read-only commands on their routers. This lab has one too (`scripts/lg.sh`). A later activity uses it.

## The network

Your AS holds the IPv4 prefix 10.1.0.0/16 and the IPv6 prefix 3fff:1::/32. You connect to two upstream providers: upstream A (AS 65010) and upstream B (AS 65020). Both buy transit from AS 65030. Both also peer at an Internet Exchange Point (IXP).

Two destination networks exist:

- dest-1 (AS 65040) is a hosting network that you reach through transit.
- dest-2 (AS 65050) is a content network present at the IXP.

Your border router r2 also has a port at the IXP. No peering sessions run on it yet. See `../topology-diagram.svg`.

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

Addresses starting with 100.64.99 or 3fff:ff: sit on the IXP peering local area network (LAN). This is a single shared subnet where all members connect.

Open a shell on your workstation. In the Control Portal, switch to the **host1** terminal. Or run this from your host shell:

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
> traceroute to 10.40.10.10 (10.40.10.10), 30 hops max, 46 byte packets
>  1  10.1.10.1  0.003 ms  0.002 ms  0.002 ms
>  2  10.1.1.1  0.001 ms  0.001 ms  0.002 ms
>  3  100.64.11.1  0.001 ms  0.002 ms  0.002 ms
>  4  100.64.13.2  20.218 ms  19.681 ms  20.008 ms
>  5  100.64.34.2  44.840 ms  45.480 ms  44.900 ms
>  6  10.40.10.10  44.436 ms  61.217 ms  45.921 ms
> ```
>
> - The first column is the hop number.
> - The address is the router that answered at that hop.
> - The three times are the round trips of three probes.
>
> This lab runs the BusyBox version of traceroute. On the first hops it prints times such as 0.001 ms, which are too small to trust. Use ping to measure time.

**Question 1a.** How many ASes does your traffic cross to reach target1? And to reach target2?

**Question 1b.** For each target, do IPv4 and IPv6 follow the same sequence of machines?

**Question 1c.** The path to target2 crosses the IXP. Which single hop in the traceroute tells you that, and what is odd about how the exchange itself appears?

<details class="answers" markdown="1">
<summary>Check your answers for Task 1 (reveal after writing your own)</summary>

```text
Sample output (traceroute -n -6 3fff:40:10::10):
traceroute to 3fff:40:10::10 (3fff:40:10::10), 30 hops max, 72 byte packets
 1  3fff:1:10::1  0.003 ms  0.002 ms  0.002 ms
 2  3fff:1:0:1::1  0.001 ms  0.002 ms  0.002 ms
 3  3fff:10:0:11::1  0.002 ms  0.002 ms  0.002 ms
 4  3fff:30:0:13::2  19.272 ms  27.449 ms  17.454 ms
 5  3fff:30:0:34::2  47.595 ms  57.904 ms  53.553 ms
 6  3fff:40:10::10  54.297 ms  53.446 ms  47.717 ms

Sample output (traceroute -n 10.50.10.10):
traceroute to 10.50.10.10 (10.50.10.10), 30 hops max, 46 byte packets
 1  10.1.10.1  0.004 ms  0.003 ms  0.002 ms
 2  10.1.1.1  0.001 ms  0.003 ms  0.003 ms
 3  100.64.11.1  0.002 ms  0.003 ms  0.002 ms
 4  100.64.99.50  8.368 ms  7.219 ms  8.169 ms
 5  10.50.10.10  8.612 ms  11.348 ms  8.541 ms

Sample output (traceroute -n -6 3fff:50:10::10):
traceroute to 3fff:50:10::10 (3fff:50:10::10), 30 hops max, 72 byte packets
 1  3fff:1:10::1  0.003 ms  0.002 ms  0.002 ms
 2  3fff:1:0:1::1  0.002 ms  0.002 ms  0.003 ms
 3  3fff:10:0:11::1  0.002 ms  0.002 ms  0.003 ms
 4  3fff:ff::50  7.433 ms  10.937 ms  10.641 ms
 5  3fff:50:10::10  11.575 ms  11.489 ms  10.467 ms
```

**1a.** To target1, four ASes: your AS 65001, upstream A (65010), transit (65030) and dest-1 (65040). To target2, three ASes: your AS 65001, upstream A (65010) and dest-2 (65050).

**1b.** Yes. In this lab's base state, IPv4 and IPv6 cross the same machines to both targets. Match each IPv6 hop with the IPv4 address of the same router in the table to check. On the real Internet the two address families sometimes take different paths.

**1c.** Hop 4, 100.64.99.50 (IPv6: 3fff:ff::50). It is dest-2's port on the IXP peering LAN. Your packet went from upstream A across that LAN to dest-2.

The odd part: the exchange has no router hop of its own. It shows only as the address range of its peering LAN. Task 5 shows that it adds no AS either.

</details>

## Task 2: Locate the latency

Ping both targets with ten packets each. Note the average round-trip times:

```
ping -c 10 10.40.10.10
ping -c 10 10.50.10.10
```

Then walk the target1 path: ping each hop from Task 1 in order and record the average per hop. Start with upstream A in IPv4:

```
ping -c 10 100.64.11.1
```

Your own router r3 answers `Destination Net Unreachable`. No network announces the IPv4 link addresses (100.64.x.x), so r3 has no route to them. The IPv6 link addresses sit inside announced prefixes, so walk the path in IPv6:

```
ping -c 10 3fff:1:10::1
ping -c 10 3fff:1:0:1::1
ping -c 10 3fff:10:0:11::1
ping -c 10 3fff:30:0:13::2
ping -c 10 3fff:30:0:34::2
ping -c 10 3fff:40:10::10
```

**Question 2a.** Between which two hops does the round-trip time to target1 make its first large jump? And its second?

**Question 2b.** target2 sits behind the same upstream as target1, yet answers far faster. Using your per-hop data, express in two sentences why.

**Question 2c.** A colleague concludes that the router at the first jump is overloaded, because latency rises there. Give an alternative explanation for a latency jump between two hops that has nothing to do with router load.

<details class="answers" markdown="1">
<summary>Check your answers for Task 2 (reveal after writing your own)</summary>

```text
Sample output (ping -c 10 10.40.10.10, last lines):
--- 10.40.10.10 ping statistics ---
10 packets transmitted, 10 received, 0% packet loss, time 9033ms
rtt min/avg/max/mdev = 43.598/51.510/56.911/3.910 ms

Sample output (ping -c 100 -i 0.2 10.50.10.10, last lines):
--- 10.50.10.10 ping statistics ---
100 packets transmitted, 100 received, 0% packet loss, time 20266ms
rtt min/avg/max/mdev = 7.567/10.515/13.549/1.487 ms

Sample output (ping -c 10 100.64.11.1):
PING 100.64.11.1 (100.64.11.1) 56(84) bytes of data.
From 10.1.10.1 icmp_seq=1 Destination Net Unreachable
From 10.1.10.1 icmp_seq=2 Destination Net Unreachable
From 10.1.10.1 icmp_seq=3 Destination Net Unreachable
From 10.1.10.1 icmp_seq=4 Destination Net Unreachable

--- 100.64.11.1 ping statistics ---
10 packets transmitted, 0 received, +4 errors, 100% packet loss, time 9196ms

Sample output (the IPv6 hop walk, last line of each run):
--- 3fff:1:10::1 ping statistics ---
rtt min/avg/max/mdev = 0.040/0.157/0.209/0.046 ms
--- 3fff:1:0:1::1 ping statistics ---
rtt min/avg/max/mdev = 0.033/0.178/0.235/0.061 ms
--- 3fff:10:0:11::1 ping statistics ---
rtt min/avg/max/mdev = 0.041/0.233/0.309/0.074 ms
--- 3fff:30:0:13::2 ping statistics ---
rtt min/avg/max/mdev = 20.235/25.911/29.864/2.997 ms
--- 3fff:30:0:34::2 ping statistics ---
rtt min/avg/max/mdev = 47.440/54.621/60.049/4.037 ms
--- 3fff:40:10::10 ping statistics ---
rtt min/avg/max/mdev = 44.341/49.317/56.161/3.542 ms
```

The target2 sample comes from a run of 100 pings. Your run of 10 gives similar figures.

**2a.** The first jump is about 26 ms. It lies between upstream A (3fff:10:0:11::1, 0.233 ms) and the transit router (3fff:30:0:13::2, 25.911 ms).

The second jump is about 29 ms more. It lies between the transit router and the dest-1 router (3fff:30:0:34::2, 54.621 ms).

With ten pings per hop, a later hop can average less than an earlier one. In this sample target1 averages 49.317 ms, below the dest-1 router. Each hop varies by several milliseconds, so compare the jumps, not single values.

**2b.** target2's path does not cross transit. It goes from upstream A across the IXP peering LAN to dest-2, so it avoids both long links. Its round trip is about 10 ms, against about 52 ms for target1.

The IXP hop already shows about 8 ms, with no long link on the outward path. Traceroute shows only the outward path (Module 2.3), so that delay may sit on the way back. Activity 3 measures this path again.

**2c.** Propagation delay. A long link adds delay to every packet, however busy the routers at each end are. In this lab the delay is added to two long links on purpose. It is not added at the routers.

</details>

## Task 3: Jitter and loss

A ping average hides variation. Run mtr, which probes every hop at once and keeps per-hop statistics:

```
mtr -n --report --report-cycles 100 10.40.10.10
```

This takes about two minutes. Read the columns `Loss%`, `Avg`, `Best`, `Wrst` (worst) and `StDev`. `StDev` is the standard deviation of the round-trip times. It is the same kind of figure as ping's `mdev`. Repeat for target2 and compare.

> [!TIP]
> **Anatomy of an mtr report** (here 20 cycles to target2):
>
> ```text
> HOST: host1                       Loss%   Snt   Last   Avg  Best  Wrst StDev
>   1.|-- 10.1.10.1                  0.0%    20    0.1   0.2   0.1   0.3   0.1
>   2.|-- 10.1.1.1                   0.0%    20    0.3   0.2   0.1   0.4   0.1
>   3.|-- 100.64.11.1                0.0%    20    0.2   0.2   0.1   0.3   0.1
>   4.|-- 100.64.99.50               0.0%    20   10.1  10.9   8.3  12.6   1.5
>   5.|-- 10.50.10.10                0.0%    20   10.5  10.0   7.9  12.7   1.3
> ```
>
> - `Loss%` is the share of probes to that hop that got no reply.
> - `Snt` is the number of probes sent.
> - `Last`, `Avg`, `Best` and `Wrst` are round-trip times in milliseconds.
> - `StDev` shows how far the round-trip times spread around the average.

**Question 3a.** On the target1 path, at which hop does packet loss first appear? Does it persist to the destination?

**Question 3b.** Which hop shows the largest StDev? Express in one sentence what that number tells you about the path beyond that hop.

<details class="answers" markdown="1">
<summary>Check your answers for Task 3 (reveal after writing your own)</summary>

```text
Sample output (mtr -n --report --report-cycles 100 10.40.10.10):
HOST: host1                       Loss%   Snt   Last   Avg  Best  Wrst StDev
  1.|-- 10.1.10.1                  0.0%   100    0.2   0.1   0.0   0.3   0.1
  2.|-- 10.1.1.1                   0.0%   100    0.3   0.2   0.1   0.3   0.1
  3.|-- 100.64.11.1                0.0%   100    0.3   0.2   0.1   0.4   0.1
  4.|-- 100.64.13.2                0.0%   100   18.5  24.6  18.4  33.0   3.6
  5.|-- 100.64.34.2                0.0%   100   45.8  53.3  43.2  65.8   5.1
  6.|-- 10.40.10.10                1.0%   100   51.1  54.0  45.0  67.0   4.8
```

**3a.** In this sample, loss appears only at target1: 1.0%, one probe in 100. One lost probe is too few to place the loss at a hop. Your run may show it at hop 5, at hop 6 or not at all.

Read the pattern when loss is larger. Loss that starts at one hop and continues to the destination points at a real problem on the path.

Loss at a single middle hop that then disappears usually means that router gives low priority to replies addressed to itself. It still forwards your traffic. The target2 path shows no loss.

**3b.** Hop 5, the dest-1 router, at 5.1 ms, with target1 close behind at 4.8 ms. Hop 4 already shows 3.6 ms.

Each long link adds its own variation, so the spread grows along the path. The number tells you how far single round trips swing around the average beyond that point.

</details>

## Task 4: One ping is not a measurement

Send a longer stream to target1 and read the summary line:

```
ping -c 100 -i 0.2 10.40.10.10
```

The final line reports `min/avg/max/mdev`.

**Question 4a.** How far apart are your minimum and maximum? If you had sent one ping and it happened to hit the maximum, how wrong would your latency estimate have been?

**Question 4b.** For this path, which single number would you report to a colleague as "the latency", and why? Keep your answer. Module 2.8 and the next activity return to this question with better tools.

<details class="answers" markdown="1">
<summary>Check your answers for Task 4 (reveal after writing your own)</summary>

```text
Sample output (ping -c 100 -i 0.2 10.40.10.10, last lines):
--- 10.40.10.10 ping statistics ---
100 packets transmitted, 100 received, 0% packet loss, time 20323ms
rtt min/avg/max/mdev = 42.664/52.929/68.597/5.158 ms
```

**4a.** In this sample the minimum is 42.664 ms and the maximum 68.597 ms, about 26 ms apart. A single ping at the maximum would overstate the average of 52.929 ms by about 16 ms. That is about 30% too high.

**4b.** There is no single correct answer, and that is the point. The minimum is the floor of the path. The median shows the typical round trip (Module 2.8). Neither shows the spread. An honest report needs at least two numbers.

</details>

## Task 5: Read your own BGP table

Your routers learned all these paths through the Border Gateway Protocol (BGP). Open the command-line interface (CLI) of your border router r1. In the Control Portal, switch to the **r1** terminal and type `vtysh`, or run from your host shell:

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
> BGP routing table entry for 10.40.0.0/16, version 5
> Paths: (1 available, best #1, table default)
>   Advertised to non peer-group peers:
>   10.1.255.2 10.1.255.3
>   65010 65030 65040
>     100.64.11.1 from 100.64.11.1 (10.10.255.1)
>       Origin IGP, localpref 200, valid, external, best (First path received)
>       Last update: Sat Oct  3 05:39:16 2026
> ```
>
> - `Paths` gives how many paths r1 knows and which one it uses.
> - `Advertised to` lists the routers r1 passed the route to: r2 and r3.
> - `65010 65030 65040` is the AS path. The AS on the right created the route. The AS on the left sent it to you.
> - The next line gives the next hop, the peer that sent the route and that peer's router identifier.
> - `localpref 200` is the local preference that your own network sets. Activity 3 returns to it.
> - `Last update` is the time r1 received the route.

**Question 5a.** Read the AS path attribute for each destination. Which ASes appear and in what order? Does the IXP appear?

**Question 5b.** Compare the AS paths with your traceroutes from Task 1. The traceroute shows individual routers. The AS path shows networks. Do the two views agree?

**Question 5c.** Every network in this lab except the route server announces one IPv4 /16 and one IPv6 /32. A /16 holds 65,536 addresses. Using prefix arithmetic, how many /64 subnets fit in your 3fff:1::/32?

Type `exit` to leave vtysh.

<details class="answers" markdown="1">
<summary>Check your answers for Task 5 (reveal after writing your own)</summary>

```text
Sample output (show bgp ipv6 unicast 3fff:40::/32):
BGP routing table entry for 3fff:40::/32, version 5
Paths: (1 available, best #1, table default)
  Advertised to non peer-group peers:
  3fff:1::2 3fff:1::3
  65010 65030 65040
    3fff:10:0:11::1 from 3fff:10:0:11::1 (10.10.255.1)
    (fe80::a8c1:abff:fe51:fb70) (used)
      Origin IGP, localpref 200, valid, external, best (First path received)
      Last update: Sat Oct  3 05:39:15 2026

Sample output (show bgp ipv4 unicast 10.50.0.0/16):
BGP routing table entry for 10.50.0.0/16, version 6
Paths: (1 available, best #1, table default)
  Advertised to non peer-group peers:
  10.1.255.2 10.1.255.3
  65010 65050
    100.64.11.1 from 100.64.11.1 (10.10.255.1)
      Origin IGP, localpref 200, valid, external, best (First path received)
      Last update: Sat Oct  3 05:39:16 2026
```

**5a.** dest-1: `65010 65030 65040` in both address families. dest-2: `65010 65050` in both. The route server of the IXP (AS 65100) appears in neither path. A route server passes routes between members without adding its own AS number. So the exchange does not appear in BGP either.

**5b.** Yes. Each group of traceroute hops falls inside one AS of the BGP path, in the same order. The IXP LAN sits between 65010 and 65050 without an AS of its own. BGP shows you the networks. Traceroute shows the routers inside them.

Unit 3 builds on both views. RIPE Atlas runs traceroutes from probes in many networks. The Routing Information Service (RIS) records the routes that its peer networks send to its collectors. RIPEstat shows that data.

**5c.** A /32 leaves 32 bits before the /64 boundary. So it holds 2^32 subnets: 4,294,967,296 /64s. Each /64 holds more host addresses than the whole IPv4 Internet. Your single IPv6 prefix holds as many /64 networks as IPv4 has addresses.

</details>
