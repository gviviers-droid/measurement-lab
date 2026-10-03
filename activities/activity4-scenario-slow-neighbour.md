# Activity 4, Scenario 1: The Slow Neighbour

**Maps to:** Module 2.9 (Systematic Troubleshooting)
**Time:** 35 minutes
**Start state:** lab deployed, `lab-check.sh` all green, congestion stopped, peering down.
**Do not read** the files under `scripts/scenarios/`. They contain the answer.

From here on, nobody tells you what broke. You get a report from users and the four machines of your network, autonomous system (AS) 65001. You also get the looking glass and the measurement skills from Activities 1 to 3.

You cannot log in to other networks, so your measurements are the evidence. Your deliverable is an incident summary. It says where the evidence places the fault, how sure you are and whom you would tell.

## The ticket

> Since this morning, users report that target2 (10.50.10.10 / 3fff:50:10::10) feels slow. It worked fine yesterday. target1 seems unaffected. Please investigate.

Start the incident. Click **Scenario 1 on** in the Control Portal, or run this on your own machine in the lab folder:

```
sudo ./scripts/scenario.sh 1 on
```

Wait one minute, then investigate. Work through your own method before you read the suggested one below.

## Task 1: Measure the symptom

Confirm the symptom first. Open a shell on host1: use the **host1** terminal in the Control Portal, or run `podman exec -it clab-measlab-host1 bash`. Run ping and traceroute to target2 in both address families.

Compare the results with your records from Activities 1 and 3. In those activities, traffic to target2 crossed the Internet Exchange Point (IXP).

```bash
traceroute -n 10.50.10.10
ping -c 10 10.50.10.10
```

Then measure target1 the same way (`traceroute -n 10.40.10.10` and `ping -c 10 10.40.10.10`). This shows which part of the path is affected.

> [!TIP]
> **Where to look in the traceroute:** Compare the hop count and the round-trip times with Activity 1. In Activity 1, target2 was 5 hops away and ping measured about 10 ms.
>
> Hop 4 was the IXP port of dest-2, `100.64.99.50`. Look at the addresses at hops 4 and 5 now.
>
> The traceroute in this lab prints times under 1 ms that are not reliable. Use ping for timing.

**Question 1.** What is the new round-trip time to target2? At which hop does the time rise? What does the comparison with target1 tell you?

<details class="answers" markdown="1">
<summary>Check your findings for Task 1 (reveal after measuring)</summary>

```text
Sample output (traceroute -n 10.50.10.10):
traceroute to 10.50.10.10 (10.50.10.10), 30 hops max, 46 byte packets
 1  10.1.10.1  0.003 ms  0.003 ms  0.002 ms
 2  10.1.1.1  0.002 ms  0.003 ms  0.003 ms
 3  100.64.11.1  0.002 ms  0.002 ms  0.003 ms
 4  100.64.13.2  18.796 ms  22.224 ms  26.475 ms
 5  100.64.99.50  43.167 ms  40.725 ms  42.859 ms
 6  10.50.10.10  44.622 ms  45.201 ms  42.908 ms

Sample output (traceroute -6 -n 3fff:50:10::10):
traceroute to 3fff:50:10::10 (3fff:50:10::10), 30 hops max, 72 byte packets
 1  3fff:1:10::1  0.004 ms  0.003 ms  0.002 ms
 2  3fff:1:0:1::1  0.002 ms  0.001 ms  0.002 ms
 3  3fff:10:0:11::1  0.002 ms  0.002 ms  0.003 ms
 4  3fff:30:0:13::2  22.666 ms  27.154 ms  26.627 ms
 5  3fff:30:0:35::2  43.683 ms  48.198 ms  49.658 ms
 6  3fff:50:10::10  51.213 ms  44.413 ms  49.756 ms

Sample output (a run of 50 pings to target2, ping -c 50 -i 0.2):
--- 10.50.10.10 ping statistics ---
50 packets transmitted, 50 received, 0% packet loss, time 10021ms
rtt min/avg/max/mdev = 36.942/44.307/53.129/3.922 ms

--- 3fff:50:10::10 ping statistics ---
50 packets transmitted, 50 received, 0% packet loss, time 10031ms
rtt min/avg/max/mdev = 38.211/46.292/53.965/4.299 ms

Sample output (ping -c 10 10.40.10.10):
--- 10.40.10.10 ping statistics ---
10 packets transmitted, 10 received, 0% packet loss, time 9043ms
rtt min/avg/max/mdev = 45.325/51.572/60.461/4.724 ms
```

**Finding:** The round-trip time to target2 rose from about 10 ms to about 44 ms in IPv4 and 46 ms in IPv6. No packets were lost. The path now has six hops instead of five.

The first big rise is at hop 4, `100.64.13.2`. That is the transit router (AS 65030). It was not on the path to target2 in Activity 1.

Hop 5 shows `100.64.99.50`, the IXP port of dest-2. That does not mean your packets crossed the IXP. A router can answer from a different port than the one your packet arrived on. In IPv4, a Linux router answers from the port it sends the reply out of.

Traceroute shows only the forward path, and the reply can come back another way (Module 2.9). In IPv6 the same hop shows `3fff:30:0:35::2`, the address of dest-2 on its link to transit. The AS path in Task 2 shows which way your packets go.

target1 measures about 52 ms, the same as in Activity 1. Its path crosses the same first four hops as the new path to target2. So the links from host1 to the transit router behave as before. What changed is that traffic to target2 now goes through the transit router.

</details>

## Task 2: Inspect the routing path and BGP prepending

Your traceroute to target2 changed. Read the AS path for `10.50.0.0/16` on your border router r1. Use the **r1** terminal in the Control Portal with `vtysh`, or run `podman exec -it clab-measlab-r1 vtysh`:

```
show bgp ipv4 unicast 10.50.0.0/16
```

> [!TIP]
> **What to look for in the AS path:** Read the AS numbers in order. Look at the end of the path. Why does one AS number appear more than once?

**Question 2.** What AS path does r1 show for 10.50.0.0/16? What does the repeated AS number mean?

<details class="answers" markdown="1">
<summary>Check your findings for Task 2 (reveal after checking BGP)</summary>

```text
Sample output (show bgp ipv4 unicast 10.50.0.0/16 on r1):
BGP routing table entry for 10.50.0.0/16, version 13
Paths: (1 available, best #1, table default)
  Advertised to non peer-group peers:
  10.1.255.2 10.1.255.3
  65010 65030 65050 65050 65050 65050
    100.64.11.1 from 100.64.11.1 (10.10.255.1)
      Origin IGP, localpref 200, valid, external, best (First path received)
      Last update: Sat Oct  3 06:03:39 2026
```

**Finding:** The path is `65010 65030 65050 65050 65050 65050`. Your traffic goes to upstream A (AS 65010), then transit (AS 65030), then dest-2 (AS 65050).

dest-2 added its AS number three extra times, so 65050 appears four times. This is AS path prepending. BGP prefers the shorter AS path when other attributes are equal. So dest-2 uses prepending to mark this path through transit as a backup.

Upstream A now uses this backup path. That suggests upstream A no longer has the shorter path across the IXP. It does not show that the connection of dest-2 to the IXP is down.

</details>

## Task 3: Query the looking glass to find where the fault is

You cannot log in to other networks, but you can read their routing. In the Control Portal, use the **Looking glass** section. Or run this from the lab folder:

```bash
sudo ./scripts/lg.sh route-server "show bgp summary"
sudo ./scripts/lg.sh upstream-a "show bgp ipv4 unicast 10.50.0.0/16"
```

The route server's summary lists the IXP members and the state of each session.

> [!TIP]
> **Where to look in the route server summary:** Check the `State/PfxRcd` column for each member. A number means that the session is up. A state name such as `Active` or `Idle` means that it is down.
>
> Two rows show `Active` whenever the lab is in its start state:
>
> * dest-1 (`100.64.99.40`), which has no session at the IXP in this lab
> * your r2 (`100.64.99.100`), because your peering is down

**Question 3.** Which other session on the route server is down? What does this tell you, and what does it not tell you?

<details class="answers" markdown="1">
<summary>Check your findings for Task 3 (reveal after looking glass check)</summary>

```text
Sample output (route server, show bgp summary, IPv4 table):
IPv4 Unicast Summary:
Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
100.64.99.10    4      65010        31        35        0    0    0 00:01:48       Active        0 N/A
100.64.99.20    4      65020        31        37        7    0    0 00:26:14            2        3 N/A
100.64.99.40    4      65040         0        12        0    0    0    never       Active        0 N/A
100.64.99.50    4      65050        30        37        7    0    0 00:26:12            1        3 N/A
100.64.99.100   4      65001         8        19        0    0    0 00:02:33       Active        0 N/A

Sample output (upstream-a, show bgp ipv4 unicast 10.50.0.0/16):
BGP routing table entry for 10.50.0.0/16, version 9
Paths: (1 available, best #1, table default)
  Advertised to non peer-group peers:
  100.64.11.2
  65030 65050 65050 65050 65050
    100.64.13.2 from 100.64.13.2 (10.30.255.1)
      Origin IGP, valid, external, best (First path received)
      Last update: Sat Oct  3 05:39:16 2026
```

**Finding:** The route server shows its session with upstream A (`100.64.99.10`) as `Active`, so that session is down. The IPv6 table shows the same for `3fff:ff::10`. The sessions with upstream B (2 prefixes) and dest-2 (1 prefix) are up.

Upstream A's looking glass shows one path to 10.50.0.0/16: `65030 65050 65050 65050 65050`, through transit. So upstream A has no path to dest-2 across the IXP.

The data does not show which side ended the session, or why. You checked only one prefix.

</details>

## Task 4: Check a second view, then write your incident summary

Your network has a second exit, through upstream B on r2. Check whether a path through that exit avoids the fault you found. On r2, type `vtysh` in the Control Portal **r2** terminal. Or run `podman exec -it clab-measlab-r2 vtysh`:

```
show bgp ipv4 unicast 10.50.0.0/16
```

Then read upstream B's view in the looking glass. Or run this from the lab folder:

```bash
sudo ./scripts/lg.sh upstream-b "show bgp ipv4 unicast 10.50.0.0/16"
```

**Question 4.** Does upstream B still reach dest-2 across the IXP? Which fault would a path through upstream B avoid? Why does your traffic not use that path now?

<details class="answers" markdown="1">
<summary>Check your findings for Task 4 (reveal after checking both views)</summary>

```text
Sample output (show bgp ipv4 unicast 10.50.0.0/16 on r2):
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

Sample output (upstream-b, show bgp ipv4 unicast 10.50.0.0/16):
BGP routing table entry for 10.50.0.0/16, version 6
Paths: (2 available, best #1, table default)
  Advertised to non peer-group peers:
  100.64.22.2
  65050
    100.64.99.50 from 100.64.99.1 (100.64.99.1)
      Origin IGP, metric 0, valid, external, best (AS Path)
      Last update: Sat Oct  3 05:39:16 2026
  65030 65050 65050 65050 65050
    100.64.23.2 from 100.64.23.2 (10.30.255.1)
      Origin IGP, valid, external
      Last update: Sat Oct  3 05:39:16 2026
```

**Finding:** Upstream B's best path to 10.50.0.0/16 is `65050`. It learned that path from the route server, so upstream B still reaches dest-2 across the IXP.

r2 holds two paths. One is `65020 65050` through upstream B, with no prepending. A path through upstream B does not depend on upstream A's session at the route server. So it would avoid the fault you found in Task 3.

Your traffic does not use it, because r1 gives routes from upstream A a local preference of 200. The path through upstream B shows no local preference, so it has the default value of 100. r2 marks the path from r1 `best (Local Pref)`.

These outputs do not show how fast the path through upstream B would be. Which exit to use is a decision for the team that runs your network. Your report gives them the evidence.

</details>

Close the scenario. Click **Scenario 1 off** in the Control Portal, or run:

```bash
sudo ./scripts/scenario.sh 1 off
```

Wait one minute, then run the ping to target2 again. Compare it with your Activity 1 record. This is the measurement that shows recovery.

### Your incident summary

Write it before you read the model answer below. Use the five sections from Module 2.10:

1. **Context:** the ticket, and what you measured from where.
2. **Method:** the tools and commands you used.
3. **Findings:** the symptom with numbers, the path change and the session states.
4. **Conclusions:** where the evidence places the fault, and how sure you are.
5. **Next steps:** whom you would tell, and which measurement will show recovery. Say what the evidence supports and what it does not.

<details class="answers" markdown="1">
<summary>Model incident summary (reveal after writing your own)</summary>

```text
Key evidence:

1. Traceroute to target2 (traceroute -n 10.50.10.10):
 4  100.64.13.2  18.796 ms  22.224 ms  26.475 ms
 5  100.64.99.50  43.167 ms  40.725 ms  42.859 ms
 6  10.50.10.10  44.622 ms  45.201 ms  42.908 ms

2. Ping to target2 (ping -c 50 -i 0.2 10.50.10.10):
rtt min/avg/max/mdev = 36.942/44.307/53.129/3.922 ms

3. AS path on r1 (show bgp ipv4 unicast 10.50.0.0/16):
  65010 65030 65050 65050 65050 65050

4. Route server (show bgp summary, IPv4 table, excerpt):
Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
100.64.99.10    4      65010        31        35        0    0    0 00:01:48       Active        0 N/A
100.64.99.20    4      65020        31        37        7    0    0 00:26:14            2        3 N/A
100.64.99.50    4      65050        30        37        7    0    0 00:26:12            1        3 N/A
```

> **Context.** Users reported that target2 (10.50.10.10, 3fff:50:10::10) had been slow since the morning. target1 seemed unaffected. All measurements were taken from host1, inside AS 65001.
>
> **Method.** ping and traceroute from host1 to target1 and target2, in IPv4 and IPv6. BGP lookups for 10.50.0.0/16 on r1 and r2. Looking glass queries on the route server, upstream A and upstream B.
>
> **Findings.**
>
> * The round-trip time to target2 rose from about 10 ms to about 44 ms in IPv4 and 46 ms in IPv6. No packets were lost.
> * target1 measured about 52 ms, the same as its baseline.
> * The path to target2 now crosses transit (AS 65030). On r1 the AS path reads `65010 65030 65050 65050 65050 65050`.
> * dest-2 adds its AS number three extra times on this path, which marks it as a backup.
> * The route server shows its session with upstream A as `Active`, so that session is down. Its sessions with upstream B and dest-2 are up.
> * Upstream A's only path to dest-2 goes through transit. Upstream B still reaches dest-2 across the IXP.
>
> **Conclusions.** The evidence strongly indicates that traffic to dest-2 detours through transit because upstream A's session at the route server is down.
>
> Three sources agree: the traceroute, the AS path on r1 and the looking glass. The limits are one vantage point (host1), one prefix per destination and one short time window.
>
> **Next steps.**
>
> * The evidence supports a report to upstream A, with the traceroute, the AS path and the route server's session state.
> * It does not show which side ended the session, or why.
> * Send the evidence to upstream A's support contact. Ask them to confirm the state of their session at the IXP.
> * Tell the team that runs your network that r2 holds a path to dest-2 through upstream B. That path does not cross transit. The choice of exit is theirs.
> * To confirm recovery, repeat the ping to target2. Recovery shows as a return to about 10 ms, the Activity 1 baseline. The AS path on r1 returns to `65010 65050`.

</details>

The name for this pattern is tromboning. Traffic between two networks at the same IXP takes a long detour through a distant third network. Module 1.3 introduced the term.

In Unit 3 you will run RIPE Atlas traceroutes from many vantage points. The same steps apply there: the symptom, the path and the AS path.
