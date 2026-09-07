# Lab Guide

## What this is

A small Internet you run on your own computer: seven networks speaking real BGP, an Internet Exchange Point, and impaired long-haul links. You operate one of the networks, AS 65001, and measure the rest from the outside, the way a real operator measures the Internet.

## The rules

You may log in to your own four machines: routers r1, r2 and r3, and the workstation host1. Every other network carries your traffic but stays closed to you. You measure it, reason about it, and build evidence; you never get anyone else's passwords. A looking glass gives you read-only visibility into other networks, exactly as real operators publish.

## Ways to run the lab

**In your browser, nothing installed (GitHub Codespaces).** Open the lab repository on GitHub, press the green Code button, choose Codespaces, and create one. A cloud machine with everything pre-installed opens in your browser, terminal included. The free allowance covers all six activities comfortably.

**As a pre-packaged Virtual Machine Appliance.** Download the pre-built VM image (`.ova` for VirtualBox/VMware or `.qcow2` for UTM on Apple Silicon). Start the VM and open `http://localhost:8080` in your host browser. All 14 containers and the Control Portal run inside the VM with no host installation needed.

**On your own machine with VS Code.** Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) and [VS Code](https://code.visualstudio.com/) with the Dev Containers extension, open the lab folder, and accept the prompt to reopen it in the container. This works on Windows, macOS and Linux.

**One-command script / Natively on Linux.** Run `./install.sh` on macOS/Linux or `.\install.ps1` on Windows.

## Start, check, stop

All routes end at the same commands, run in the lab folder (or accessible directly via the Control Portal):

```
sudo ./lab.sh up
sudo ./lab.sh check
sudo ./lab.sh down
```

`up` deploys the network and applies the link conditions. `check` verifies the whole environment and must show every line as PASS before you begin an activity. `down` removes everything. `sudo ./lab.sh docs` serves this guide at http://localhost:8080 if you prefer it over opening the file directly.

## If something looks wrong

Every activity assumes the base state: check green, congestion stopped, peering down, scenarios off. Reset to it with:

```
sudo ./lab.sh reset
```

Then run `sudo ./lab.sh check` again. If a check still fails, `sudo ./lab.sh down` followed by `sudo ./lab.sh up` rebuilds the world from scratch; the lab keeps no state you can lose.

## The network

![Lab topology](topology-diagram.svg)
