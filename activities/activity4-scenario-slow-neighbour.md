# Activity 4, Scenario 1: The Slow Neighbour

**Maps to:** Module 2.6 (Troubleshooting with Measurements)
**Time:** 30 minutes, plus 10 for the optional mitigation
**Start state:** lab deployed, `lab-check.sh` all green, congestion stopped, peering down.
**Do not read** the files under `scripts/scenarios/`; they contain the answer.

From here on, the training wheels come off. Nobody tells you what broke. You get a symptom report, your own four machines, the looking glass, and the measurement skills from Activities 1 to 3. Your deliverable is not a fix, because the fault is not in your network and you cannot log in to anyone else's. Your deliverable is an incident summary that names the responsible network and proves it with measurements. That is the daily reality of operating a network: most problems you observe live in somebody else's AS, and your job is knowing whom to call, with what evidence.

## The ticket

> Since this morning, users report that target2 (10.50.10.10 / 3fff:50:10::10) feels sluggish. It worked fine yesterday. target1 seems unaffected. Please investigate.

Start the incident on your own machine in the lab folder:

```
sudo ./scripts/scenario.sh 1 on
```

Wait a minute, then investigate. Work through your own method before reading the suggested one below.

## Suggested investigation, if you want structure

Confirm the symptom first: ping and traceroute to target2, both families, and compare against your Activity 1 and 3 records. A complaint is a hypothesis; a measurement is a fact.

Bracket the fault second: measure target1 the same way. One destination degraded and one clean already excludes large parts of the path, including your own AS.

Read the path third: your traceroute to target2 changed. Label every hop with its AS, note the new round-trip time, and read the AS path for 10.50.0.0/16 on r1. Something about that AS path looks artificial; it is a deliberate signal from dest-2, and worth explaining in your summary.

Use the looking glass fourth: you cannot log in to other networks, but you can read them:

```
sudo ./scripts/lg.sh upstream-a "show bgp ipv4 unicast 10.50.0.0/16"
sudo ./scripts/lg.sh route-server "show bgp summary"
```

The route server's summary is the IXP's member list with session states. Compare what you see there against the topology diagram.

## Your incident summary

Write it before reading the model answer. Cover: the symptom quantified, the path change, the network you hold responsible, the evidence, and whom you would contact.

**Optional mitigation.** The fault is not yours, but the routing policy that steers your traffic into it is. Your r2 learns a clean route to dest-2 through upstream B, yet r1's higher local preference for upstream A wins. Lower it and watch your traffic escape the detour:

```
docker exec -it clab-measlab-r1 vtysh
configure terminal
route-map FROM-UPSTREAM-A permit 10
 set local-preference 90
exit
exit
clear bgp * soft in
```

Measure target2 again, confirm the recovery through upstream B, then restore the value to 200 the same way (and `clear bgp * soft in` again). You diagnosed remotely and mitigated locally, which is precisely the shape of real incident response between networks.

Close the scenario:

```
sudo ./scripts/scenario.sh 1 off
```

## Model incident summary

Reveal after writing your own.

> **Symptom.** Round-trip time to target2 rose from under 2 ms to roughly 50 ms in both IPv4 and IPv6, with no packet loss. target1 measures unchanged, so the fault sits outside our network and outside the shared portion of the two paths.
>
> **Path change.** Traffic to dest-2 previously crossed upstream A's port at the IXP directly to dest-2. It now detours through the transit carrier AS 65030 and enters dest-2 through its backup transit link (traceroute hop 100.64.35.2 instead of 100.64.99.50). The BGP path for 10.50.0.0/16 reads 65010 65030 65050 65050 65050 65050: dest-2 prepends its AS on this route to mark it as a path of last resort, and the Internet is nevertheless using it.
>
> **Root cause attribution.** The IXP route server shows upstream A's sessions down while all other members remain established. Upstream A (AS 65010) has lost its presence at the exchange, so every route it previously learned across the peering LAN, including dest-2's, fell back to transit.
>
> **Action.** Contact our account team at upstream A with this evidence and a request for their ETA. As local mitigation, we can prefer upstream B for the affected prefixes until the exchange sessions return.

The name for this pattern is tromboning: traffic between two nearby networks detours through a distant third, out and back like the slide of a trombone. In Unit 3 you will find real trombones in RIPE Atlas traceroutes, and the evidence chain you built here, symptom, path, AS attribution, is the one you will use there.
