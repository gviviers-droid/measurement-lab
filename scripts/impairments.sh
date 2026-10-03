#!/usr/bin/env bash
# Base impairments. Run once after "containerlab deploy". Run with sudo.
# netem applies per link, so IPv4 and IPv6 experience identical conditions.
#
# Ground truth (update the model answers in the task sheets when you change this):
#   transit <-> upstream A (rt eth1) : 20 ms delay, 3 ms jitter          long-haul link
#   transit <-> dest-1     (rt eth3) : 25 ms delay, 2 ms jitter, 1% loss,
#                                      10 Mbit/s capacity, 200-packet    congested far-end link
#                                      queue (about 230 ms of buffer)
#   transit <-> dest-2     (rt eth4) : 30 ms delay, 2 ms jitter          backup path, used by trombone scenario
# The IXP peering LAN stays clean: peering is fast, which is the point.

set -euo pipefail
LAB=measlab

containerlab tools netem set --runtime podman -n clab-${LAB}-rt -i eth1 --delay 20ms --jitter 3ms
containerlab tools netem set --runtime podman -n clab-${LAB}-rt -i eth3 --delay 25ms --jitter 2ms --loss 1 --rate 10000
# netem's default queue holds 10,000 packets: seconds of delay at 10 Mbit/s, where a real router buffers a few
# hundred milliseconds. Capped at 200 packets, so congestion shows the delay and spread Module 2.7 teaches.
docker exec clab-${LAB}-rt tc qdisc change dev eth3 root netem limit 200 delay 25ms 2ms loss 1% rate 10Mbit
containerlab tools netem set --runtime podman -n clab-${LAB}-rt -i eth4 --delay 30ms --jitter 2ms

echo "Base impairments applied. See script header for the ground truth."
