# Cheatsheet

## Getting into your machines

| Where | Control Portal | CLI Command (Podman) |
|---|---|---|
| Workstation shell | **host1** terminal | `podman exec -it clab-measlab-host1 bash` |
| Router CLI (r1) | **r1** terminal (`vtysh`) | `podman exec -it clab-measlab-r1 vtysh` |
| Router CLI (r2) | **r2** terminal (`vtysh`) | `podman exec -it clab-measlab-r2 vtysh` |
| Router CLI (r3) | **r3** terminal (`vtysh`) | `podman exec -it clab-measlab-r3 vtysh` |
| Leave a router CLI | `exit` | `exit` |

Only r1, r2, r3 and host1 are yours. Everything else refuses you, by design.

## Measuring

| Purpose | Command |
|---|---|
| Reachability and round-trip time | `ping -c 10 10.40.10.10` |
| Same, IPv6 | `ping -c 10 3fff:40:10::10` |
| Faster probing (5 per second) | `ping -c 100 -i 0.2 <target>` |
| Path discovery | `traceroute -n 10.40.10.10` |
| Path discovery, IPv6 | `traceroute -n -6 3fff:40:10::10` |
| Per-hop loss, round-trip time and spread | `mtr -n --report --report-cycles 100 <target>` |

The `-n` flag skips name lookups and shows the addresses only.

In `mtr` output, `StDev` is the standard deviation of each hop's round trips. `Wrst` is the slowest round trip seen. For a jitter figure, read the `mdev` value at the end of ping's output.

Use ping for timing. The lab's traceroute prints times such as 0.002 ms on hops with no added delay. Ping measures r3 and r1 at about 0.1 to 0.2 ms.

## Statistics one-liners

Collect one hundred round-trip times into a file:

```
ping -c 100 -i 0.2 10.40.10.10 | grep -oE 'time=[0-9.]+' | cut -d= -f2 > rtt.txt
```

Mean, median, p95, min and max from that file:

```
sort -n rtt.txt | awk '{a[NR]=$1; s+=$1}
  END {print "count:", NR;
       print "mean:", s/NR;
       print "median:", a[int((NR+1)/2)];
       print "p95:", a[int(NR*0.95)];
       print "min:", a[1];
       print "max:", a[NR]}'
```

A lost ping produces no line, so a count below 100 shows loss. The median shows the typical round trip. 95% of round trips were at or below the p95 value.

## Reading your routers

Run these inside `vtysh` on r1, r2 or r3.

| Purpose | Command |
|---|---|
| All BGP sessions and their state | `show bgp summary` |
| Best path and alternatives, one prefix | `show bgp ipv4 unicast 10.40.0.0/16` |
| Same, IPv6 | `show bgp ipv6 unicast 3fff:40::/32` |
| Routes r2 learned from the route server | `show bgp ipv4 unicast neighbors 100.64.99.1 routes` |
| Same, IPv6 | `show bgp ipv6 unicast neighbors 3fff:ff::1 routes` |
| The routing table in use | `show ip route` / `show ipv6 route` |
| Your OSPF neighbours | `show ip ospf neighbor` |

The route server rows work on r2 only, and only while your peering is up.

In BGP output, read the autonomous system (AS) path from right to left. The rightmost AS originated the prefix. `Idle (Admin)` means an operator shut the session on purpose. A session that keeps changing state on its own points to a problem.

## The looking glass

Read-only `show` commands on the Internet routers, from the lab folder:

```
sudo ./scripts/lg.sh upstream-a "show bgp ipv4 unicast 10.50.0.0/16"
sudo ./scripts/lg.sh transit "show bgp summary"
sudo ./scripts/lg.sh route-server "show bgp summary"
```

Routers: `upstream-a`, `upstream-b`, `transit`, `route-server`. The route server's summary lists the exchange members and the state of each session.

In the base state, two route server rows read `Active`, which means the session is not up. One is dest-1 at 100.64.99.40. The other is your own r2 at 100.64.99.100, because your peering is down.

## Lab controls

Run from the lab folder on your own machine.

| Purpose | Command |
|---|---|
| Deploy, impair, verify | `sudo ./lab.sh up` |
| Health check | `sudo ./lab.sh check` |
| Back to base state | `sudo ./lab.sh reset` |
| Tear down | `sudo ./lab.sh down` |
| Background load on or off | `sudo ./scripts/congestion.sh start` / `stop` |
| Continuous CSV logger | `sudo ./scripts/logger.sh start` / `stop` / `dump` |
| Your peering at the exchange on or off | `sudo ./scripts/peering.sh up` / `down` |
| Start or clear a fault scenario | `sudo ./scripts/scenario.sh <1|2|3> on` / `off` |

Do not read the files under `scripts/scenarios/` before finishing Activities 4, 5 and 6: they name the faults.

## Addresses & DNS Names that matter

| Machine | DNS Name | IPv4 | IPv6 | Network |
|---|---|---|---|---|
| host1 (you) | `host1.measlab` | 10.1.10.10 | 3fff:1:10::10 | AS 65001 |
| r3, LAN router | `r3.measlab` | 10.1.10.1 | 3fff:1:10::1 | AS 65001 |
| r1, border A | `r1.measlab` | 10.1.1.1 | 3fff:1:0:1::1 | AS 65001 |
| r2, border B | `r2.measlab` | 10.1.2.1 | 3fff:1:0:2::1 | AS 65001 |
| upstream A | `ra.measlab` | 100.64.11.1 | 3fff:10:0:11::1 | AS 65010 |
| transit, side facing A | `rt.measlab` | 100.64.13.2 | 3fff:30:0:13::2 | AS 65030 |
| dest-1 router | `rd1.measlab` | 100.64.34.2 | 3fff:30:0:34::2 | AS 65040 |
| target1 | `target1.measlab` | 10.40.10.10 | 3fff:40:10::10 | AS 65040 |
| dest-2, exchange port | `rd2.measlab` | 100.64.99.50 | 3fff:ff::50 | AS 65050 |
| target2 | `target2.measlab` | 10.50.10.10 | 3fff:50:10::10 | AS 65050 |

Each network except the route server holds one IPv4 /16 and one IPv6 /32. The IPv6 /32s come from 3fff::/20.

Addresses beginning 100.64 are on the links between networks. Those beginning 100.64.99 or 3fff:ff: are on the exchange's peering LAN. No network announces the 100.64 addresses, so a ping to one from host1 returns `Destination Net Unreachable` from 10.1.10.1.

Each name resolves to both its IPv4 and its IPv6 address. Reverse lookups work for both.
