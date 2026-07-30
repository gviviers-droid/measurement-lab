# Lab Guide

## What this is

A small Internet you run on your own computer: seven networks speaking real BGP, an Internet Exchange Point, and impaired long-haul links. You operate one of the networks, AS 65001, and measure the rest from the outside, the way a real operator measures the Internet.

## The rules

You may log in to your own four machines: routers r1, r2 and r3, and the workstation host1. Every other network carries your traffic but stays closed to you. You measure it, reason about it, and build evidence; you never get anyone else's passwords. A looking glass gives you read-only visibility into other networks, exactly as real operators publish.

## Three ways to run the lab

**In your browser, nothing installed (GitHub Codespaces).** Open the lab repository on GitHub, press the green Code button, choose Codespaces, and create one. A cloud machine with everything pre-installed opens in your browser, terminal included. The free allowance covers all five activities comfortably.

**On your own machine with VS Code.** Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) and [VS Code](https://code.visualstudio.com/) with the Dev Containers extension, open the lab folder, and accept the prompt to reopen it in the container. This works on Windows, macOS and Linux and installs nothing besides Docker and VS Code themselves.

**Natively on Linux.** Install Docker Engine and [Containerlab](https://containerlab.dev/install/), then work straight in the lab folder.

## Start, check, stop

All three routes end at the same three commands, run in the lab folder:

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
