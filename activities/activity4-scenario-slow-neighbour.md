# Activity 4, Scenario 1: The Slow Neighbour

**Maps to:** Module 2.6 (Troubleshooting with Measurements)
**Time:** 30 minutes, plus 10 for the optional mitigation
**Start state:** lab deployed, `lab-check.sh` all green, congestion stopped, peering down.
**Do not read** the files under `scripts/scenarios/`; they contain the answer.

From here on, the training wheels come off. Nobody tells you what broke. You get a symptom report, your own four machines, the looking glass, and the measurement skills from Activities 1 to 3. Your deliverable is not a fix, because the fault is not in your network and you cannot log in to anyone else's. Your deliverable is an incident summary that names the responsible network and proves it with measurements. That is the daily reality of operating a network: most problems you observe live in somebody else's AS, and your job is knowing whom to call, with what evidence.

## The ticket

> Since this morning, users report that target2 (10.50.10.10 / 3fff:50:10::10) feels sluggish. It worked fine yesterday. target1 seems unaffected. Please investigate.

Start the incident by clicking **Scenario 1 on** in the Control Portal (or run on your own machine in the lab folder):

```
sudo ./scripts/scenario.sh 1 on
```

Wait a minute, then investigate. Work through your own method before reading the suggested one below.

## Task 1: Replicate and quantify the symptom

Confirm the symptom first: ping and traceroute to target2 from host1 (via the **host1** terminal in the Control Portal or `podman exec -it clab-measlab-host1 bash`), in both address families, and compare against your Activity 1 and 3 records.

```bash
traceroute -n 10.50.10.10
ping -c 10 10.50.10.10
```

Then bracket the fault: measure target1 the same way (`traceroute -n 10.40.10.10` and `ping -c 10 10.40.10.10`). A complaint is a hypothesis; a measurement is a fact.

> [!TIP]
> **Where to look in the traceroute:** Compare the hop count and round-trip times against Activity 1. In Activity 1, target2 took only 5 hops with <2 ms latency directly across the IXP peering LAN (`100.64.99.50`). Check which new network hops appear now at hop 4 and 5.

**Question 1.** What is the new round-trip time to target2, and at which hop does the large latency jump occur? What does comparing this with target1 tell you?

<details class="answers" markdown="1">
<summary>Check your findings for Task 1 (reveal after measuring)</summary>

```text
Sample output (traceroute -n 10.50.10.10):
 1  10.1.10.1      0.11 ms   (r3)
 2  10.1.1.1       0.22 ms   (r1)
 3  100.64.11.1    0.51 ms   (ra - Upstream A)
 4  100.64.13.2   20.85 ms   (rt - Transit carrier entry!)
 5  100.64.35.2   50.92 ms   (rd2 backup transit link)
 6  10.50.10.10   51.15 ms   (target2)
```

**Finding:** Round-trip time to target2 jumped from under 2 ms to ~51 ms, entering transit at hop 4 (`100.64.13.2`). Meanwhile, target1 measures completely normal (~46 ms). This proves your own network and the shared border links are healthy; the degradation is specific to dest-2 or upstream A.

</details>

## Task 2: Inspect the routing path and BGP prepending

Your traceroute to target2 changed. Read the AS path for `10.50.0.0/16` on your border router r1 (using the **r1** terminal in the Control Portal with `vtysh`, or `podman exec -it clab-measlab-r1 vtysh`):

```
show bgp ipv4 unicast 10.50.0.0/16
```

> [!TIP]
> **What to look for in the AS Path:** Check the sequence of AS numbers. Look at the tail of the path: why is an AS number repeated multiple times?

**Question 2.** What AS path does r1 show for 10.50.0.0/16, and what does the repeated AS number signify?

<details class="answers" markdown="1">
<summary>Check your findings for Task 2 (reveal after checking BGP)</summary>

```text
Sample output (show bgp ipv4 unicast 10.50.0.0/16 on r1):
Paths: (1 available, best #1)
  65010 65030 65050 65050 65050 65050
    100.64.11.1 from 100.64.11.1 (ra.measlab)
```

**Finding:** The path is `65010 65030 65050 65050 65050 65050`. dest-2 (AS 65050) has prepended its own AS four times on this route. BGP prepending artificially inflates the path length to make it an unattractive path of last resort. The fact that the Internet is using it anyway means its primary, preferred route must be broken.

</details>

## Task 3: Query the looking glass to isolate the fault

You cannot log in to other networks, but you can read them. In the Control Portal, use the **Looking glass** section (or run from the lab folder):

```bash
sudo ./scripts/lg.sh route-server "show bgp summary"
sudo ./scripts/lg.sh upstream-a "show bgp ipv4 unicast 10.50.0.0/16"
```

The route server's summary is the IXP's member list with session states.

> [!TIP]
> **Where to look in the Route Server summary:** Check the `State/PfxRcd` column for Upstream A (`100.64.99.10`) versus dest-2 (`100.64.99.50`) and Upstream B (`100.64.99.20`). Remember: an integer indicates Established/UP; text like `Active` or `Idle` indicates DOWN.

**Question 3.** Which peer session is down on the route server, and what does this prove about the root cause?

<details class="answers" markdown="1">
<summary>Check your findings for Task 3 (reveal after looking glass check)</summary>

```text
Sample output (route-server show bgp summary):
Neighbor        V    AS MsgRcvd MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd
100.64.99.10    4 65010       0       0        0    0    0 00:04:12 Active
100.64.99.20    4 65020    1452    1450        0    0    0 01:12:30        1
100.64.99.50    4 65050    1455    1452        0    0    0 01:12:30        1
```

**Finding:** Upstream A's session (`100.64.99.10`) is in state `Active` (trying to reconnect / session down!), while dest-2 and Upstream B are established (`1`). Upstream A (AS 65010) dropped out of the IXP, so every route it previously learned across the peering LAN fell back to transit!

</details>

## Task 4: Mitigate locally and formulate your incident report

The fault is not yours, but the routing policy that steers your traffic into it is. Your r2 learns a clean route to dest-2 through upstream B, yet r1's higher local preference for upstream A wins. Lower it and watch your traffic escape the detour.

In the Control Portal, switch to the **r1** terminal and type `vtysh` (or run `podman exec -it clab-measlab-r1 vtysh` from your host terminal), then apply the policy:

```
configure terminal
route-map FROM-UPSTREAM-A permit 10
 set local-preference 90
exit
exit
clear bgp * soft in
```

Measure target2 again, confirm the recovery through upstream B, then restore the value to 200 the same way (and `clear bgp * soft in` again). You diagnosed remotely and mitigated locally, which is precisely the shape of real incident response between networks.

Close the scenario by clicking **Scenario 1 off** in the Control Portal (or run):

```bash
sudo ./scripts/scenario.sh 1 off
```

### Your incident summary

Write it before reading the model answer below. Cover: the symptom quantified, the path change, the network you hold responsible, the evidence, and whom you would contact.

<details class="answers" markdown="1">
<summary>Model incident summary (reveal after writing your own)</summary>

```text
Key diagnostic evidence:

1. Detoured traceroute (traceroute -n 10.50.10.10):
 1  10.1.10.1      0.11 ms   (r3)
 2  10.1.1.1       0.22 ms   (r1)
 3  100.64.11.1    0.51 ms   (ra - Upstream A)
 4  100.64.13.2   20.85 ms   (rt - Transit carrier entry)
 5  100.64.35.2   50.92 ms   (rd2 backup transit link)
 6  10.50.10.10   51.15 ms   (target2 - RTT rose from <2 ms to ~51 ms)

2. BGP path prepending on r1 (show bgp ipv4 unicast 10.50.0.0/16):
Paths: (1 available, best #1)
  65010 65030 65050 65050 65050 65050
    100.64.11.1 from 100.64.11.1 (ra.measlab)

3. Looking glass on route-server (show bgp summary):
Neighbor        V    AS MsgRcvd MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd
100.64.99.10    4 65010       0       0        0    0    0 00:04:12 Active
100.64.99.20    4 65020    1452    1450        0    0    0 01:12:30        1
100.64.99.50    4 65050    1455    1452        0    0    0 01:12:30        1
```

> **Symptom.** Round-trip time to target2 rose from under 2 ms to roughly 50 ms in both IPv4 and IPv6, with no packet loss. target1 measures unchanged, so the fault sits outside our network and outside the shared portion of the two paths.
>
> **Path change.** Traffic to dest-2 previously crossed upstream A's port at the IXP directly to dest-2. It now detours through the transit carrier AS 65030 and enters dest-2 through its backup transit link (entering via 100.64.35.2 instead of 100.64.99.50; note that depending on Linux kernel ICMP address selection with asymmetric return routing via upstream B, traceroute hop 5 may report either 100.64.99.50 or 100.64.35.2, but with the elevated ~30-50 ms transit RTT). The BGP path for 10.50.0.0/16 reads 65010 65030 65050 65050 65050 65050: dest-2 prepends its AS on this route to mark it as a path of last resort, and the Internet is nevertheless using it.
>
> **Root cause attribution.** The IXP route server shows upstream A's sessions down while all other members remain established. Upstream A (AS 65010) has lost its presence at the exchange, so every route it previously learned across the peering LAN, including dest-2's, fell back to transit.
>
> **Action.** Contact our account team at upstream A with this evidence and a request for their ETA. As local mitigation, we can prefer upstream B for the affected prefixes until the exchange sessions return.

</details>

The name for this pattern is tromboning: traffic between two nearby networks detours through a distant third, out and back like the slide of a trombone. In Unit 3 you will find real trombones in RIPE Atlas traceroutes, and the evidence chain you built here, symptom, path, AS attribution, is the one you will use there.
