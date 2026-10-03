# Lab Guide

## What this is

The lab is a small Internet that runs on your own computer. Seven networks exchange routes with real BGP (Border Gateway Protocol). They meet at an Internet Exchange Point (IXP). Some links between them have added delay, jitter and loss.

You run one of the networks, autonomous system (AS) 65001. You measure the other networks from the outside. A real operator measures the Internet in the same way.

## The rules

You may log in to the four machines in your own network:

- the workstation host1
- the routers r1, r2 and r3

Every other network carries your traffic but stays closed to you. You never get a login on their machines. You measure those networks and build evidence from what you see.

A looking glass gives you read-only views of some routers in other networks. Real operators publish looking glasses for the same purpose.

## Ways to run the lab

**In your browser, nothing installed (GitHub Codespaces).** Open the lab repository on GitHub, press the green Code button, choose Codespaces and create one. A cloud machine with everything pre-installed opens in your browser, terminal included. The free allowance covers all six activities comfortably.

**As a pre-packaged virtual machine (VM).** Download the pre-built VM image (`.ova` for VirtualBox/VMware or `.qcow2` for UTM on Apple Silicon). Start the VM and open `http://localhost:8080` in your host browser. All 14 containers and the Control Portal run inside the VM with no host installation needed.

**On your own machine with Visual Studio Code (VS Code).** Install [Docker Desktop](https://www.docker.com/products/docker-desktop/). Then install [VS Code](https://code.visualstudio.com/) with the Dev Containers extension. Open the lab folder and accept the prompt to reopen it in the container. This works on Windows, macOS and Linux.

**One-command script / Natively on Linux.** Run `./install.sh` on macOS/Linux or `.\install.ps1` on Windows.

## Start, check, stop

All routes end at the same commands, run in the lab folder (or accessible directly via the Control Portal):

```
sudo ./lab.sh up
sudo ./lab.sh check
sudo ./lab.sh down
```

`up` deploys the network and applies the link conditions. `check` tests the whole environment. Every line must read `PASS` before you begin an activity. `down` removes everything.

`sudo ./lab.sh docs` serves these pages at http://localhost:8080. It shows the pages only. The Control Portal buttons and terminals need `./portal.sh`, which uses the same port. Run one or the other, not both.

## If something looks wrong

Every activity assumes the base state: the check passes, congestion is stopped, peering is down and all scenarios are off. This command restores it and then runs the check:

```
sudo ./lab.sh reset
```

## Tracking your progress

Each activity sheet has a checkbox next to every **Task** heading. Click the checkbox or the task title when you finish a task. Your browser saves your progress. The sidebar shows it.

## The network

![Lab topology](topology-diagram.svg)

Some parts of the lab behave in ways you need to know before you measure:

- **Each network holds one IPv4 /16 and one IPv6 /32.** The route server, AS 65100, holds none.
- **At the exchange, each network announces only its own routes and its customers' routes.** There, no network passes on routes it learned from its other neighbours.
- **In IPv4, the link addresses between networks do not answer a ping.** They begin 100.64, and no network announces them. A ping from host1 returns `Destination Net Unreachable` from 10.1.10.1, your router r3. The same routers still appear in traceroute and mtr.
- **In IPv6, the link addresses answer a ping.** The exception is 3fff:ff::50, the dest-2 port on the exchange. It does not answer.
- **Use ping for timing.** The lab's traceroute prints times such as 0.002 ms on hops with no added delay. Ping measures r3 and r1 at about 0.1 to 0.2 ms.
- **The background load in Activity 2 comes in bursts.** It does not run as a steady stream.
