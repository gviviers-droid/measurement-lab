# Activity 5, Scenario 2: Now You See It, Now You Don't

**Maps to:** Module 2.6 (Troubleshooting with Measurements), with a direct bridge to Unit 3 (RIS and BGPlay)
**Time:** 30 minutes
**Start state:** lab deployed, `lab-check.sh` all green, congestion stopped, peering down, Scenario 1 off.
**Do not read** the files under `scripts/scenarios/`; they contain the answer.

Activity 4 gave you a degraded path. This scenario gives you something meaner: a fault that keeps disappearing while you look at it. Intermittent problems are the hardest class of network incident, because a single measurement can land in a good moment and declare everything healthy. Your tools against them are measurement over time and the routing control plane itself.

## The ticket

> target1 (10.40.10.10 / 3fff:40:10::10) keeps dropping out. It works, then it does not, then it works again. Monitoring shows the pattern started 20 minutes ago. target2 is fine. Please investigate and tell us whose problem this is.

Start the incident on your own machine in the lab folder:

```
sudo ./scripts/scenario.sh 2 on
```

Wait a minute, then investigate. Try your own approach first.

## Suggested investigation, if you want structure

Measure over time, not once. A 100-cycle mtr to target1 spans about two minutes, longer than one bad or good period, so its loss column tells the truth a single ping cannot:

```
mtr -n --report --report-cycles 100 10.40.10.10
```

Read the failure mode. During an outage window, ping target1 and look at the exact error. A timeout means your packet left and nothing came back; a "Network unreachable" means your own router had no route to offer. The two point at different layers, and this detail decides your whole diagnosis.

Watch your control plane. On r1, check the route repeatedly for a few minutes:

```
docker exec -it clab-measlab-r1 vtysh
show bgp ipv4 unicast 10.40.0.0/16
```

Run it during a good window and a bad window. Also look at r1's BGP log messages (`show logging` in vtysh, or repeat the lookup and note the changing age of the route). A route whose age keeps resetting to seconds is telling you its history.

Attribute it. The looking glass shows you where the instability enters the Internet:

```
sudo ./scripts/lg.sh transit "show bgp ipv4 unicast 10.40.0.0/16"
sudo ./scripts/lg.sh route-server "show bgp summary"
```

If the transit carrier's route to dest-1 also comes and goes while the IXP looks healthy, the boundary of the fault is drawn for you.

## Your incident summary

Write it before reading the model answer: symptom with numbers, the evidence that this is a routing problem rather than a lossy link, the responsible network, and whom you would contact. Then close the scenario:

```
sudo ./scripts/scenario.sh 2 off
```

## Model incident summary

Reveal after writing your own.

> **Symptom.** target1 alternates between full reachability and total outage in a regular cycle of roughly 40 seconds each way, in both address families. Over a two-minute mtr, loss to target1 reads near 50%, while every intermediate hop up to the transit carrier stays clean. target2 is unaffected.
>
> **This is routing, not a lossy link.** During outage windows our own routers hold no route to 10.40.0.0/16 or 3fff:40::/32 at all: pings fail with "Network unreachable" from our first hop rather than timing out, and the BGP table entry for the prefix vanishes and reappears with an age of seconds. Packet loss degrades a path; a withdrawn route removes it. We observed removal.
>
> **Root cause attribution.** The transit carrier's own view (via its looking glass) shows its route to dest-1 appearing and disappearing on the same cycle, learned on its direct session to AS 65040. The IXP route server shows all member sessions stable. The instability therefore originates at dest-1's connection to its transit provider: either the dest-1 router, the link between them, or a misbehaving policy repeatedly resetting the session. From outside, we cannot distinguish which, and honest attribution stops at the boundary the evidence supports: AS 65040's transit connection.
>
> **Action.** This is not our network and not our upstream's. We would report the evidence to dest-1's operations contact, and note that every network on the Internet observing this prefix sees the same churn.

The name for this pattern is a route flap, and its signature, a prefix rhythmically announced and withdrawn, propagates through the routing system to every observer. That last point is the doorway to Unit 3: RIPE RIS records exactly these announcements and withdrawals from hundreds of vantage points, and BGPlay animates them, so the flap you just diagnosed from one AS with a looking glass is the flap you will next watch ripple across the whole Internet.
