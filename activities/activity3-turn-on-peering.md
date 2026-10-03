# Activity 3: Turn On Peering

**Maps to:** Modules 2.2 and 2.3, and the Unit 1 material on IXPs and Internet flattening (Module 1.3)
**Time:** 25 minutes
**Start state:** lab deployed, `lab-check.sh` all green, congestion stopped, peering down.
**You need:** a shell inside host1 and a shell on your own machine in the lab folder. You also need access to r1 and r2. The Control Portal at `http://localhost:8080` gives you all of these.

Your network is autonomous system (AS) 65001. Your border router r2 has a port at the Internet Exchange Point (IXP). The port has been configured since the lab began. No BGP sessions run on it yet. In this activity you turn those sessions on.

The method is before and after. First you record the network as it is. Then you turn on the sessions and repeat the same measurements. The two records show which destinations peering changed and which it did not.

## Task 1: Measure before the change

Open a shell on host1. Use the **host1** terminal in the Control Portal, or run `podman exec -it clab-measlab-host1 bash`. Record the path and the round-trip time to target2 in both address families:

```
traceroute -n 10.50.10.10
traceroute -n -6 3fff:50:10::10
ping -c 20 10.50.10.10
ping -c 20 3fff:50:10::10
```

Then read your own routing on r1. In the Control Portal **r1** terminal, type `vtysh`. Or run `podman exec -it clab-measlab-r1 vtysh`:

```
show bgp ipv4 unicast 10.50.0.0/16
show bgp ipv6 unicast 3fff:50::/32
```

Note the AS path and which border router carries the traffic. Then look at the sessions on r2 that are not in use yet. In the Control Portal **r2** terminal, type `vtysh`. Or run `podman exec -it clab-measlab-r2 vtysh`:

```
show bgp summary
```

> [!TIP]
> **How to read `show bgp summary`:**
>
> ```text
> IPv4 Unicast Summary:
> Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
> 100.64.22.1     4      65020        28        23       11    0    0 00:19:56            5        1 upstream-b
> ```
>
> * The router prints one table for IPv4 and one for IPv6. Each table starts with a title line, such as `IPv4 Unicast Summary:`.
> * `V` is the BGP version. It reads 4 in both tables, so it does not tell you the address family.
> * `AS` is the AS number of the neighbour.
> * When a session is up, `State/PfxRcd` shows a number. The number counts the prefixes received from that neighbour. The router does not print the word "Established".
> * When a session is down, the same column shows a state name, such as `Idle (Admin)`, `Active` or `Connect`.
> * `PfxSnt` counts the prefixes your router sends to that neighbour.
>
> In this example, r2's session with upstream B is up. r2 has received 5 prefixes from upstream B.

**Question 1a.** What state does r2 report for the two sessions towards 100.64.99.1 and 3fff:ff::1? What does that state mean?

<details class="answers" markdown="1">
<summary>Check your answer for Task 1 (reveal after writing your own)</summary>

```text
Sample output (show bgp summary on r2, excerpt):
IPv4 Unicast Summary:
Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
100.64.99.1     4      65100         0         0        0    0    0    never Idle (Admin)        0 IXP route server

IPv6 Unicast Summary:
Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
3fff:ff::1      4      65100         0         0        0    0    0    never Idle (Admin)        0 IXP route server
```

**1a.** Both sessions show `Idle (Admin)`. The sessions exist in r2's configuration. They are shut down on purpose. `never` in the `Up/Down` column means that the session has never been up.

A session that is shut down on purpose is normal on real routers. It is different from a session that is down because of a fault.

</details>

## Task 2: Become a peer

In the Control Portal, click **Enable peering**. Or, on your own machine in the lab folder, run:

```
sudo ./scripts/peering.sh up
```

Wait about 30 seconds for BGP. Then run `show bgp summary` on r2 again. Both sessions to the route server should now show a number in the `State/PfxRcd` column. Count the prefixes received. Then look at r2's routing table:

```
show bgp ipv4 unicast
show bgp ipv6 unicast
```

> [!TIP]
> **How to read the routing table (`show bgp ipv4 unicast`):**
>
> ```text
> Status codes:  s suppressed, d damped, h history, u unsorted, * valid, > best, = multipath,
>                i internal, r RIB-failure, S Stale, R Removed
> Origin codes:  i - IGP, e - EGP, ? - incomplete
>
>      Network          Next Hop            Metric LocPrf Weight Path
>  *>  10.50.0.0/16     100.64.99.50             0    250      0 65050 i
>  *                    100.64.22.1                            0 65020 65050 i
> ```
>
> * `*>` marks the best path to a prefix. A row with `*` alone is another valid path to the same prefix.
> * A row that starts with `*>i` or `* i` was learned from another router in your own network.
> * `LocPrf` shows the local preference, when one is set.
> * `Path` lists the AS numbers on the way to the prefix. The nearest AS comes first.
> * The last `i` in each row is the origin code, IGP. It does not mean internal.

**Question 2a.** Look for the rows whose next hop is on the IXP peering LAN (100.64.99.x or 3fff:ff::x). Those routes came from the route server. Which prefixes are they, and what are their AS paths? One AS number you might expect is missing. Which one, and why?

<details class="answers" markdown="1">
<summary>Check your answer for Task 2 (reveal after writing your own)</summary>

```text
Sample output (show bgp summary on r2, excerpt):
Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
100.64.99.1     4      65100         7         4       14    0    0 00:00:29            3        1 IXP route server
3fff:ff::1      4      65100         7         4       14    0    0 00:00:29            3        1 IXP route server

Sample output (show bgp ipv4 unicast on r2, excerpt):
     Network          Next Hop            Metric LocPrf Weight Path
 *>  10.1.0.0/16      0.0.0.0                  0         32768 i
 * i                  10.1.255.1               0    100      0 i
 *>  10.10.0.0/16     100.64.99.10             0    250      0 65010 i
 *                    100.64.22.1                            0 65020 65010 i
 *>  10.20.0.0/16     100.64.99.20             0    250      0 65020 i
 *                    100.64.22.1              0             0 65020 i
 *>i 10.30.0.0/16     10.1.255.1                    200      0 65010 65030 i
 *                    100.64.22.1                            0 65020 65030 i
 *>i 10.40.0.0/16     10.1.255.1                    200      0 65010 65030 65040 i
 *                    100.64.22.1                            0 65020 65030 65040 i
 *>  10.50.0.0/16     100.64.99.50             0    250      0 65050 i
 *                    100.64.22.1                            0 65020 65050 i

Displayed 6 routes and 12 total paths
```

**2a.** Both sessions are up, and each has received 3 prefixes. In IPv4 the route server sent you these routes:

* 10.10.0.0/16 from upstream A, with the path `65010`
* 10.20.0.0/16 from upstream B, with the path `65020`
* 10.50.0.0/16 from dest-2, with the path `65050`

In IPv6 it sent 3fff:10::/32, 3fff:20::/32 and 3fff:50::/32, with the same paths. Each path has one AS number: the network that holds the prefix.

The missing AS number is 65100, the route server's AS. A route server passes routes between members without adding its AS number. So in BGP, peering through a route server looks like a direct session with each member.

</details>

## Task 3: Measure after the change

Repeat every measurement from Task 1: both traceroutes, both pings and both BGP lookups on r1. Then measure target1 again with traceroute and ping, as you did in Activity 1.

**Question 3a.** Describe the new path to target2. Which machines does it cross? How many hops does it have? Which border router does it leave through?

**Question 3b.** Compare the round-trip time to target2 before and after, in both address families. Is the change larger than the spread inside each run?

**Question 3c.** r1 now knows two routes to 10.50.0.0/16. Read the BGP output on r1. Which attribute selects the best route? What are its values on the two routes?

**Question 3d.** Did peering change anything for target1? What does this tell you about which destinations peering changes?

<details class="answers" markdown="1">
<summary>Check your answers for Task 3 (reveal after writing your own)</summary>

```text
Sample output, before peering (traceroute -n 10.50.10.10):
traceroute to 10.50.10.10 (10.50.10.10), 30 hops max, 46 byte packets
 1  10.1.10.1  0.004 ms  0.003 ms  0.002 ms
 2  10.1.1.1  0.001 ms  0.003 ms  0.003 ms
 3  100.64.11.1  0.002 ms  0.003 ms  0.002 ms
 4  100.64.99.50  8.368 ms  7.219 ms  8.169 ms
 5  10.50.10.10  8.612 ms  11.348 ms  8.541 ms

Sample output, after peering (traceroute -n 10.50.10.10):
traceroute to 10.50.10.10 (10.50.10.10), 30 hops max, 46 byte packets
 1  10.1.10.1  0.004 ms  0.002 ms  0.004 ms
 2  10.1.2.1  0.002 ms  0.002 ms  0.004 ms
 3  100.64.99.50  0.002 ms  0.003 ms  0.003 ms
 4  10.50.10.10  0.002 ms  0.002 ms  0.003 ms
```

**3a.** The new path goes from host1 to r3 (10.1.10.1), then r2 (10.1.2.1). From r2 it goes to the IXP port of dest-2 (100.64.99.50), then to target2. That is four hops instead of five.

The traffic now leaves your network through r2. Upstream A is no longer on the forward path. The path crosses your AS, the IXP and the AS of dest-2.

In IPv6 the path is the same: 3fff:1:10::1, 3fff:1:0:2::1, 3fff:ff::50, then 3fff:50:10::10.

The traceroute in this lab prints times under 1 ms that are not reliable. Use ping for timing.

```text
Before peering, IPv4 (a run of 50 pings, ping -c 50 -i 0.2):
--- 10.50.10.10 ping statistics ---
50 packets transmitted, 50 received, 0% packet loss, time 10058ms
rtt min/avg/max/mdev = 7.382/10.199/13.052/1.549 ms

After peering, IPv4 (the same run of 50 pings):
--- 10.50.10.10 ping statistics ---
50 packets transmitted, 50 received, 0% packet loss, time 10249ms
rtt min/avg/max/mdev = 0.055/0.230/0.328/0.066 ms

Before peering, IPv6 (a run of 100 pings, ping -6 -c 100 -i 0.2):
--- 3fff:50:10::10 ping statistics ---
100 packets transmitted, 100 received, 0% packet loss, time 20279ms
rtt min/avg/max/mdev = 7.287/10.259/13.715/1.551 ms

After peering, IPv6 (ping -c 20):
--- 3fff:50:10::10 ping statistics ---
20 packets transmitted, 20 received, 0% packet loss, time 19501ms
rtt min/avg/max/mdev = 0.045/0.262/0.342/0.069 ms
```

**3b.** The round-trip time fell from about 10 ms to about 0.2 ms in both families:

* Before: an average of 10.199 ms in IPv4 and 10.259 ms in IPv6.
* After: an average of 0.230 ms in IPv4 and 0.262 ms in IPv6.

Before peering, the replies ranged from 7.287 ms to 13.715 ms. After peering, the slowest IPv4 reply took 0.328 ms. That is faster than the fastest reply before peering. The two runs do not overlap. So the change is far larger than the normal variation (Module 2.8).

These measurements show that the time changed. They do not show which link added the 10 ms before peering. The traceroute before peering shows the rise at hop 4. Traceroute shows only the forward path. Replies can come back another way (Module 2.9).

```text
Sample output (show bgp ipv4 unicast 10.50.0.0/16 on r1, after peering):
BGP routing table entry for 10.50.0.0/16, version 9
Paths: (2 available, best #1, table default)
  Not advertised to any peer
  65050
    10.1.255.2 (metric 10) from 10.1.255.2 (10.1.255.2)
      Origin IGP, metric 0, localpref 250, valid, internal, best (Local Pref)
      Last update: Sat Oct  3 06:00:26 2026
  65010 65050
    100.64.11.1 from 100.64.11.1 (10.10.255.1)
      Origin IGP, localpref 200, valid, external
      Last update: Sat Oct  3 05:39:17 2026
```

**3c.** The attribute is local preference. The route through r2 and the IXP has `localpref 250`. The route through upstream A has `localpref 200`. The router marks the winner `best (Local Pref)`. BGP compares local preference before AS path length, so the higher value wins.

The next hop 10.1.255.2 is r2, shown by its router identifier in brackets.

Your network's policy was already configured before this activity. r2 sets 250 on routes from the IXP. r1 sets 200 on routes from upstream A. Turning on peering gave r2 a new route, and the existing policy chose it.

```text
Sample output, after peering (traceroute -n 10.40.10.10):
traceroute to 10.40.10.10 (10.40.10.10), 30 hops max, 46 byte packets
 1  10.1.10.1  0.003 ms  0.002 ms  0.003 ms
 2  10.1.1.1  0.001 ms  0.001 ms  0.003 ms
 3  100.64.11.1  0.001 ms  0.002 ms  0.002 ms
 4  100.64.13.2  21.289 ms  24.038 ms  25.028 ms
 5  100.64.34.2  49.024 ms  49.426 ms  47.715 ms
 6  10.40.10.10  49.722 ms  51.344 ms  48.503 ms

Before peering (ping -c 50 10.40.10.10):
--- 10.40.10.10 ping statistics ---
50 packets transmitted, 50 received, 0% packet loss, time 49216ms
rtt min/avg/max/mdev = 44.245/54.482/68.001/5.393 ms

After peering (ping -c 50 10.40.10.10):
--- 10.40.10.10 ping statistics ---
50 packets transmitted, 50 received, 0% packet loss, time 49291ms
rtt min/avg/max/mdev = 43.820/53.654/67.870/4.984 ms
```

**3d.** Nothing changed for target1. The path is the same six hops, through r1, upstream A and transit. The median round-trip time was 53.7 ms before peering and 53.2 ms after. Each run spread over more than 20 ms. So a difference of 0.5 ms is inside the normal variation.

dest-1 (AS 65040) has no session at the IXP. The route server sent you no route to it. Peering changes the path only to networks that send their routes to the route server. Traffic to every other destination still goes through your upstream providers.

</details>

## Task 4: Summarise what changed

Write three short sentences for a reader who is not a network specialist. Say:

* what you turned on
* what changed in your measurements
* which destinations changed and which did not

Then restore the base state for the next activity. Click **Disable peering** in the Control Portal, or run:

```
sudo ./scripts/peering.sh down
```

<details class="answers" markdown="1">
<summary>Check your answer for Task 4 (reveal after writing your own)</summary>

**4.** Model answer: "AS 65001 turned on BGP sessions at the Internet Exchange Point. Round-trip time to dest-2 fell from about 10 ms to about 0.2 ms, in IPv4 and IPv6. Traffic to dest-1 did not change, because dest-1 has no session at the Internet Exchange Point."

</details>
