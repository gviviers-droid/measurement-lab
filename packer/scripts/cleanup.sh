#!/usr/bin/env bash
set -euo pipefail

echo "==> Cleaning package cache and temporary files..."
apt-get autoremove -y --purge
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/* /var/tmp/* /var/log/journal/*

echo "==> Zeroing out free disk space for high compression..."
dd if=/dev/zero of=/EMPTY bs=1M count=20000 status=none || true
rm -f /EMPTY
sync

echo "==> Cleanup complete."
