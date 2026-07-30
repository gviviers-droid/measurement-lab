# Cheatsheet

## Getting into your machines

| Where | Command |
|---|---|
| Workstation shell | `docker exec -it clab-measlab-host1 bash` |
| Router CLI (r1) | `docker exec -it clab-measlab-r1 vtysh` |
| Router CLI (r2) | `docker exec -it clab-measlab-r2 vtysh` |
| Router CLI (r3) | `docker exec -it clab-measlab-r3 vtysh` |
| Leave a router CLI | `exit` (twice) |

Only r1, r2, r3 and host1 are yours. Everything else refuses you, by design.

## Measuring

| Purpose | Command |
|---|---|
| Reachability and round-trip time | `ping -c 10 10.40.10.10` |
| Same, IPv6 | `ping -c 10 3fff:40:10::10` |
| Faster probing (5 per second) | `ping -c 100 -i 0.2 <target>` |
| Path discovery | `traceroute -n 10.40.10.10` |
| Path discovery, IPv6 | `traceroute -n -6 3fff:40:10::10` |
| Per-hop loss, jitter and latency | `mtr -n --report --report-cycles 100 <target>` |

The `-n` flag skips name lookups and shows raw addresses. In `mtr` output, `StDev` expresses jitter and `Wrst` is the worst round trip seen.

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

A shrinking count is your loss figure: lost pings produce no line.

## Reading your routers

Run these inside `vtysh` on r1, r2 or r3.

| Purpose | Command |
|---|---|
| All BGP sessions and their state | `show bgp summary` |
| Best path and alternatives, one prefix | `show bgp ipv4 unicast 10.40.0.0/16` |
| Same, IPv6 | `show bgp ipv6 unicast 3fff:40::/32` |
| Everything learned at the IXP | `show bgp ipv4 unicast` |
| The routing table actually in use | `show ip route` / `show ipv6 route` |
| Your OSPF neighbours | `show ip ospf neighbor` |
| Recent log messages | `show logging` |

In BGP output, read the AS path right to left: the rightmost AS originated the prefix. `Idle (Admin)` means an operator shut the session on purpose; a session cycling between states on its own means trouble.

## The looking glass

Read-only `show` commands on the Internet routers, from the lab folder:

```
sudo ./scripts/lg.sh upstream-a "show bgp ipv4 unicast 10.50.0.0/16"
sudo ./scripts/lg.sh transit "show bgp summary"
sudo ./scripts/lg.sh route-server "show bgp summary"
```

Routers: `upstream-a`, `upstream-b`, `transit`, `route-server`. The route server's summary is the IXP member list with session states.

## Lab controls

Run from the lab folder on your own machine.

| Purpose | Command |
|---|---|
| Deploy, impair, verify | `sudo ./lab.sh up` |
| Health check | `sudo ./lab.sh check` |
| Back to base state | `sudo ./lab.sh reset` |
| Tear down | `sudo ./lab.sh down` |
| Background load on or off | `sudo ./scripts/congestion.sh start` / `stop` |
| Your IXP peering on or off | `sudo ./scripts/peering.sh up` / `down` |
| Start or clear a fault scenario | `sudo ./scripts/scenario.sh <1|2> on` / `off` |

Do not read the files under `scripts/scenarios/` before finishing Activities 4 and 5: they name the faults.

## Addresses that matter

| Machine | IPv4 | IPv6 | Network |
|---|---|---|---|
| host1 (you) | 10.1.10.10 | 3fff:1:10::10 | AS 65001 |
| r3, LAN router | 10.1.10.1 | 3fff:1:10::1 | AS 65001 |
| r1, border A | 10.1.1.1 | 3fff:1:0:1::1 | AS 65001 |
| r2, border B | 10.1.2.1 | 3fff:1:0:2::1 | AS 65001 |
| upstream A | 100.64.11.1 | 3fff:10:0:11::1 | AS 65010 |
| transit, side facing A | 100.64.13.2 | 3fff:30:0:13::2 | AS 65030 |
| dest-1 router | 100.64.34.2 | 3fff:30:0:34::2 | AS 65040 |
| target1 | 10.40.10.10 | 3fff:40:10::10 | AS 65040 |
| dest-2, IXP port | 100.64.99.50 | 3fff:ff::50 | AS 65050 |
| target2 | 10.50.10.10 | 3fff:50:10::10 | AS 65050 |

Addresses beginning 100.64.99 or 3fff:ff: sit on the IXP peering LAN. Each AS holds one IPv4 /16 and one IPv6 /32 from 3fff::/20.
