# Activity 3: Turn On Peering

**Maps to:** Modules 2.1 and 2.3, and the Unit 1 material on IXPs and Internet flattening
**Time:** 25 minutes
**Start state:** lab deployed, `lab-check.sh` all green, congestion stopped, peering down.
**You need:** a shell inside host1, a shell on your own machine in the lab folder, and access to r1 and r2.

Your AS has held a port at the IXP since the lab began, configured and paid for, carrying nothing. Today you become a peer. The measurement discipline: never change a network without a before picture, so the first half of this activity records the world as it is, and the second half enables the sessions and measures what changed. This before-and-after method is exactly how operators justify peering decisions with data.

## Task 1: The before picture

From host1, record path and latency to target2 in both families:

```
traceroute -n 10.50.10.10
traceroute -n -6 3fff:50:10::10
ping -c 20 10.50.10.10
ping -c 20 3fff:50:10::10
```

Then read your own routing. On r1 (`docker exec -it clab-measlab-r1 vtysh`):

```
show bgp ipv4 unicast 10.50.0.0/16
show bgp ipv6 unicast 3fff:50::/32
```

Note the AS path and which border router carries the traffic. Finally, look at the dormant sessions on r2 (`docker exec -it clab-measlab-r2 vtysh`):

```
show bgp summary
```

**Question 1a.** What state does r2 report for the two sessions towards 100.64.99.1 and 3fff:ff::1, and what does that state mean?

## Task 2: Become a peer

On your own machine in the lab folder:

```
sudo ./scripts/peering.sh up
```

Give BGP half a minute, then confirm on r2 that both sessions show as Established and count the prefixes received. Look at what arrived:

```
show bgp ipv4 unicast
show bgp ipv6 unicast
```

**Question 2a.** Which prefixes did the route server send you, and with what AS paths? One AS you expected to see in those paths is missing. Which, and why?

## Task 3: The after picture

Repeat every measurement from Task 1: both traceroutes, both pings, both BGP lookups.

**Question 3a.** Describe the new path to target2: which machines, how many hops, which of your border routers.

**Question 3b.** Quantify the improvement: round-trip time before versus after, in both address families.

**Question 3c.** Your router now knows two routes to 10.50.0.0/16. Read the BGP output on r2: which attribute makes the peering route win, and what is its value compared with the transit-learned route?

**Question 3d.** Measure target1 again. Did peering change anything for it? State the general rule this demonstrates.

## Task 4: The business case

Write three sentences a manager would understand: what you enabled, what measurably improved, and for which destinations. Then restore the base state for the next activity:

```
sudo ./scripts/peering.sh down
```

## Check your answers

**1a.** Idle (Admin): the sessions exist in configuration but an operator shut them down on purpose. Configured-but-disabled is a normal state on real routers, and it differs from a session that is down because of a fault.

**2a.** The route server passes you the prefixes of the other members: upstream A (10.10.0.0/16, 3fff:10::/32), upstream B, and dest-2 (10.50.0.0/16, 3fff:50::/32), each with a path of a single AS. Missing: AS 65100, the route server itself. A route server distributes routes between members without inserting its own AS number, so peering through it looks, in BGP, like a direct adjacency with every member.

**3a.** host1 to r3, then r2, then straight to dest-2's IXP port (100.64.99.50, or 3fff:ff::50), then target2. Four hops, leaving through r2, with upstream A no longer involved.

**3b.** Before: a few milliseconds via upstream A's peering (the path found in Activity 1). After: below a millisecond in both families, since the path now crosses only your own AS and the exchange fabric. The improvement is modest here because the before path was already peered at one remove; the structural gain is independence: your traffic to dest-2 no longer depends on upstream A at all, which Scenario 1 in the next activity makes valuable.

**3c.** Local preference. The peering route carries 250 against 200 for the transit-learned route via r1, so it wins before AS path length is even compared. Your own policy, not the Internet, made this choice, which is the point: routing is policy, and you just set one.

**3d.** Nothing changed for target1. dest-1 is not present at the exchange, so your new sessions offer no route to it. The rule: peering improves reachability only to networks that are also at the exchange; everything else still rides transit. Real peering decisions weigh exactly this: how much of my traffic goes to networks I could reach across this fabric?

**4.** Model answer: "We activated our existing port at the exchange and now exchange routes directly with the other members. Traffic to the content network there dropped from around 2 ms to under 1 ms and no longer depends on our upstream provider. The change affects only destinations present at the exchange; the rest of our traffic is unchanged."
