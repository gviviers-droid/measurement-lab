# Activity 5: A Route That Comes and Goes

**Maps to:** Module 2.9 (Systematic Troubleshooting), with a direct bridge to Unit 3 (RIS and BGPlay)
**Time:** 30 minutes
**Start state:** lab deployed, `lab-check.sh` all green, congestion stopped, peering down, Scenario 1 off.
**Do not read** the files under `scripts/scenarios/`. They contain the answer.

Activity 4 gave you a slower path. This scenario gives you a fault that comes and goes while you look at it. Intermittent problems are hard to catch, because a single measurement can land in a good moment. To find this one, measure over time and read the routing tables.

## The ticket

> target1 (10.40.10.10 / 3fff:40:10::10) keeps dropping out. It works, then it does not, then it works again. Monitoring shows the pattern started 20 minutes ago. target2 is fine. Please investigate and say which network the problem is in.

Start the incident by clicking **Scenario 2 on** in the Control Portal (or run on your own machine in the lab folder):

```
sudo ./scripts/scenario.sh 2 on
```

Wait a minute, then investigate. Try your own approach first.

## Task 1: Measure over time with mtr

A single ping can land in a moment when the route is up. From host1 (via the **host1** terminal in the Control Portal or `podman exec -it clab-measlab-host1 bash`), run a 100-cycle mtr to target1:

```bash
mtr -n --report --report-cycles 100 10.40.10.10
```

> [!TIP]
> **Where to look in the mtr report:** Compare the `Loss%` column from hop to hop. Loss on one link starts at one hop. The hops before it keep answering. Check which hop the loss starts at.

**Question 1.** What loss does mtr report at each hop, and where does the loss start? Why can a single ping miss this fault?

<details class="answers" markdown="1">
<summary>Check your findings for Task 1 (reveal after measuring)</summary>

```text
Sample output (mtr -n --report --report-cycles 100 10.40.10.10):
HOST: host1                       Loss%   Snt   Last   Avg  Best  Wrst StDev
  1.|-- 10.1.10.1                 42.0%   100    0.1   0.2   0.0   0.3   0.1
  2.|-- 10.1.1.1                  41.0%   100    0.2   0.2   0.0   0.3   0.1
  3.|-- 100.64.11.1               41.0%   100    0.2   0.2   0.1   0.4   0.1
        10.1.10.1                        
  4.|-- 100.64.13.2               41.0%   100   26.0  24.1   0.2  33.0   4.9
        10.1.10.1                        
```

**Finding:** Every hop lost about the same share of replies, 41 to 42%. The loss starts at hop 1, which is r3, your own gateway. Loss on one link would leave the earlier hops answering.

Your report may stop at hop 4, as this one does. The extra `10.1.10.1` lines mean that r3 also answered at hops 3 and 4. A 60-cycle run a few minutes later reached all six hops, and each lost 58 to 60%.

A single ping that lands while the route is up gets a normal reply, about 53 ms. Only measurement over time shows the outages.

</details>

## Task 2: Distinguish link loss from routing table withdrawal

Read the failure closely. Run a continuous ping to target1:

```bash
ping 10.40.10.10
```

Let it run for about two minutes. Watch the replies stop and start again. Press `Ctrl + C` to stop.

> [!TIP]
> **Reading ping's output on host1:**  
> - **No reply:** ping prints nothing for that packet, so the `icmp_seq` numbers skip. A packet lost on a link looks like this.  
> - **From [address] ... Destination Net Unreachable:** the router at that address has no route to the destination. It sends this error back to you.

**Question 2.** What error does ping print during an outage? Which machine sends it?

<details class="answers" markdown="1">
<summary>Check your findings for Task 2 (reveal after ping check)</summary>

```text
Sample output, start of the run (ping -c 120 -i 1 10.40.10.10):
PING 10.40.10.10 (10.40.10.10) 56(84) bytes of data.
From 10.1.10.1 icmp_seq=1 Destination Net Unreachable
From 10.1.10.1 icmp_seq=2 Destination Net Unreachable
From 10.1.10.1 icmp_seq=3 Destination Net Unreachable
From 10.1.10.1 icmp_seq=4 Destination Net Unreachable
64 bytes from 10.40.10.10: icmp_seq=23 ttl=59 time=46.1 ms
64 bytes from 10.40.10.10: icmp_seq=24 ttl=59 time=51.6 ms
64 bytes from 10.40.10.10: icmp_seq=25 ttl=59 time=44.4 ms
```

```text
Sample output, the end of an up period and the next outage:
64 bytes from 10.40.10.10: icmp_seq=57 ttl=59 time=49.0 ms
64 bytes from 10.40.10.10: icmp_seq=58 ttl=59 time=54.2 ms
64 bytes from 10.40.10.10: icmp_seq=59 ttl=59 time=55.2 ms
From 10.1.10.1 icmp_seq=60 Destination Net Unreachable
From 10.1.10.1 icmp_seq=61 Destination Net Unreachable
From 10.1.10.1 icmp_seq=62 Destination Net Unreachable
From 10.1.10.1 icmp_seq=63 Destination Net Unreachable
64 bytes from 10.40.10.10: icmp_seq=102 ttl=59 time=63.9 ms
64 bytes from 10.40.10.10: icmp_seq=103 ttl=59 time=55.1 ms
```

```text
Sample summary after 120 packets:
120 packets transmitted, 55 received, +8 errors, 54.1667% packet loss, time 120796ms
rtt min/avg/max/mdev = 43.006/53.652/66.771/4.984 ms
```

**Finding:** The error is `Destination Net Unreachable`, and it comes from `10.1.10.1`. That is r3, host1's gateway and the first router on your path. It has no route to `10.40.0.0/16`. So the withdrawal has reached your own network.

In this run, ping printed the error for the first four packets of each outage. After that it printed nothing until the route came back. So look for the gaps in `icmp_seq`: 4 to 23, then 63 to 102.

A packet lost on a link gets no reply at all. Here a router answered that it had no route. So the problem is a missing route, not a lossy link. Over 120 packets, ping reports 54% loss.

</details>

## Task 3: Observe route flaps on the control plane and looking glass

On r1, check the route every 10 seconds for two minutes. In the Control Portal, switch to the **r1** terminal and type `vtysh`. Or run `podman exec -it clab-measlab-r1 vtysh`. Use this command:

```
show bgp ipv4 unicast 10.40.0.0/16
```

Then query the looking glass (use the **Looking glass** section in the Control Portal, or run from your host machine):

```bash
sudo ./scripts/lg.sh transit "show bgp ipv4 unicast 10.40.0.0/16"
sudo ./scripts/lg.sh route-server "show bgp summary"
```

Then list transit's BGP sessions:

```bash
sudo ./scripts/lg.sh transit "show bgp summary"
```

> [!TIP]
> **Where to look in BGP lookups:**
> * On `r1`: when the route is there, note the date and time after `Last update`. Run the command again later. Each time the route comes back, that time moves forward. When the route is gone, r1 prints `% Network not in table`.
> * In the looking glass: check whether transit also loses the route to dest-1. Transit is autonomous system (AS) 65030, and dest-1 is AS 65040. In transit's session list, find the row for `100.64.34.2`, its session with dest-1.

<details class="answers" markdown="1">
<summary>Check your findings for Task 3 (reveal after checking BGP)</summary>

```text
Sample output on r1 (route present):
BGP routing table entry for 10.40.0.0/16, version 20
Paths: (1 available, best #1, table default)
  Advertised to non peer-group peers:
  10.1.255.2 10.1.255.3
  65010 65030 65040
    100.64.11.1 from 100.64.11.1 (10.10.255.1)
      Origin IGP, localpref 200, valid, external, best (First path received)
      Last update: Sat Oct  3 06:12:44 2026
```

```text
Sample output on r1, the next time the route was present (lines cut):
BGP routing table entry for 10.40.0.0/16, version 22
      Last update: Sat Oct  3 06:14:05 2026
```

```text
Sample output on r1 (route gone):
% Network not in table
```

```text
Sample output, transit looking glass (route present):
BGP routing table entry for 10.40.0.0/16, version 13
Paths: (1 available, best #1, table default)
  Advertised to non peer-group peers:
  100.64.13.1 100.64.23.1 100.64.34.2 100.64.35.2
  65040
    100.64.34.2 from 100.64.34.2 (10.40.255.1)
      Origin IGP, metric 0, valid, external, best (First path received)
      Last update: Sat Oct  3 06:12:44 2026
```

```text
Sample output, transit sessions (IPv4 rows):
Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
100.64.13.1     4      65010        44        68       16    0    0 00:35:33            2        5 N/A
100.64.23.1     4      65020        40        54       16    0    0 00:35:34            2        5 N/A
100.64.34.2     4      65040        60        82        0    0    0 00:00:05       Active        0 N/A
100.64.35.2     4      65050        39        55       16    0    0 00:35:32            1        5 N/A
```

```text
Sample output, route server sessions (IPv4 rows):
Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
100.64.99.10    4      65010        43        50        8    0    0 00:07:18            2        4 N/A
100.64.99.20    4      65020        40        47        8    0    0 00:35:34            2        4 N/A
100.64.99.40    4      65040         0        16        0    0    0    never       Active        0 N/A
100.64.99.50    4      65050        39        47        8    0    0 00:35:32            1        4 N/A
100.64.99.100   4      65001         8        21        0    0    0 00:11:53       Active        0 N/A
```

**Finding:** `10.40.0.0/16` is withdrawn for about 40 seconds, then announced for about 40 seconds, over and over. In this run the route came back at 06:12:44 and again at 06:14:05. The IPv6 prefix, `3fff:40::/32`, changed at the same moments.

What the looking glass shows:

* Transit loses and regains the route at the same moments. Its path is `65040` alone, learned from dest-1.
* Transit's session with dest-1, `100.64.34.2`, reads `Active`. Its `Up/Down` time reads `00:00:05`, so the session went down five seconds before the query.
* At the route server, the sessions with upstream A, upstream B and dest-2 had been up for 7 minutes or more.
* dest-1 has no session at the exchange in this lab, so its row reads `never`. Your r2's row reads `Active` because peering is off.

The evidence points to the connection between dest-1 and transit.

</details>

## Task 4: Formulate your incident summary

Close the scenario by clicking **Scenario 2 off** in the Control Portal (or run):

```bash
sudo ./scripts/scenario.sh 2 off
```

Then ping target1 again for a minute or more. The outages should stop.

### Your incident summary

Write it before reading the model answer. Cover these points:

* the symptom, with numbers
* the evidence that this is a routing problem, not a lossy link
* the network the evidence points to, and how sure you are
* what the evidence does not show
* whom you would tell, and which measurement will show recovery

<details class="answers" markdown="1">
<summary>Model incident summary (reveal after writing your own)</summary>

```text
Key evidence:

1. mtr over 100 cycles to target1 (mtr -n --report --report-cycles 100 10.40.10.10):
HOST: host1                       Loss%   Snt   Last   Avg  Best  Wrst StDev
  1.|-- 10.1.10.1                 42.0%   100    0.1   0.2   0.0   0.3   0.1
  2.|-- 10.1.1.1                  41.0%   100    0.2   0.2   0.0   0.3   0.1
  3.|-- 100.64.11.1               41.0%   100    0.2   0.2   0.1   0.4   0.1
        10.1.10.1                        
  4.|-- 100.64.13.2               41.0%   100   26.0  24.1   0.2  33.0   4.9
        10.1.10.1                        

   A later run over 60 cycles (mtr -n -r -c 60 10.40.10.10):
HOST: host1                       Loss%   Snt   Last   Avg  Best  Wrst StDev
  1.|-- 10.1.10.1                 60.0%    60    0.2   0.1   0.1   0.3   0.1
  2.|-- 10.1.1.1                  58.3%    60    0.2   0.2   0.1   0.3   0.1
        10.1.10.1                        
  3.|-- 100.64.11.1               60.0%    60    0.3   0.2   0.1   0.3   0.1
  4.|-- 100.64.13.2               60.0%    60   17.8  23.4  17.8  29.9   3.5
  5.|-- 100.64.34.2               60.0%    60   51.2  53.0  45.9  60.4   4.6
  6.|-- 10.40.10.10               60.0%    60   57.0  54.1  44.0  65.4   3.8

2. ping to target1 over two minutes (ping -c 120 -i 1 10.40.10.10):
From 10.1.10.1 icmp_seq=60 Destination Net Unreachable
120 packets transmitted, 55 received, +8 errors, 54.1667% packet loss, time 120796ms

3. r1 (show bgp ipv4 unicast 10.40.0.0/16), checked every 10 seconds:
      Last update: Sat Oct  3 06:12:44 2026
% Network not in table
      Last update: Sat Oct  3 06:14:05 2026

4. Transit's session with dest-1 (lg.sh transit "show bgp summary"):
100.64.34.2     4      65040        60        82        0    0    0 00:00:05       Active        0 N/A
```

> **Context.** The ticket reports that target1 (10.40.10.10, 3fff:40:10::10) keeps dropping out. target2 is fine. You measured from host1 over about six minutes.
>
> **Method.** An mtr report over 100 cycles to target1, and a ping over two minutes. Repeated lookups of `10.40.0.0/16`, on r1 and through transit's looking glass. The session lists of transit and the route server.
>
> **Findings.**
>
> * target1 answers for about 40 seconds, then goes silent for about 40 seconds, over and over.
> * ping reports 54% loss over 120 packets. Each hop in mtr lost about the same share, starting at hop 1.
> * During each outage, r3 (10.1.10.1) answers `Destination Net Unreachable`.
> * r1 and transit lose `10.40.0.0/16` at the same moments, then learn it again.
> * Transit's session with dest-1 read `Active`, five seconds after it went down. The route server's sessions with upstream A, upstream B and dest-2 stayed up.
>
> **Conclusions.** The evidence strongly indicates a routing fault, not a lossy link. Your own gateway answered that it had no route, and the route left the routing tables. The evidence suggests the fault is in the session between dest-1 (AS 65040) and transit (AS 65030).
>
> The data comes from one vantage point (host1) and one looking glass. It covers one prefix over about six minutes. The queries here do not show which side ended the session, or why.
>
> **Next Steps.** Send the evidence to dest-1's operator (AS 65040), and send a copy to transit (AS 65030). Ask them to check the session between their networks. To confirm recovery, ping target1 for a few minutes. In this lab, 90 pings after Scenario 2 off got 90 replies.

</details>

The name for this pattern is a route flap. In Modules 2.3 and 2.9, a flapping route switched between two paths. So the round-trip time jumped between two levels.

In this lab, dest-1 has only one path, through transit. So each withdrawal leaves no route at all, and ping reports `Destination Net Unreachable`.

RIPE RIS records announcements and withdrawals like these from the networks that peer with its route collectors. RIS holds only what those peers send it.

Some routers use route flap damping, which stops them passing on a prefix that flaps often. In Unit 3 you use RIS data and BGPlay to look for routing changes like this one.
