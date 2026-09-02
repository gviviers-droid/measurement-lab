#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "==> Waiting for cloud-init to finish..."
while [ ! -f /var/lib/cloud/instance/boot-finished ]; do
  sleep 2
done

echo "==> Updating package repositories..."
apt-get update -qq
apt-get upgrade -y -qq

echo "==> Installing required packages..."
apt-get install -y -qq \
  docker.io \
  python3 \
  python3-markdown \
  bridge-utils \
  iproute2 \
  iputils-ping \
  traceroute \
  mtr-tiny \
  curl \
  wget \
  git \
  jq \
  net-tools \
  sudo \
  ca-certificates \
  qemu-guest-agent

# Install ttyd (distro package or official static binary fallback)
if ! apt-get install -y ttyd 2>/dev/null; then
  echo "==> Installing ttyd from GitHub release..."
  ARCH="$(uname -m)"
  case "${ARCH}" in
    x86_64) BIN_ARCH=x86_64 ;;
    aarch64|arm64) BIN_ARCH=aarch64 ;;
    *) echo "Unsupported arch: ${ARCH}"; exit 1 ;;
  esac
  curl -sL "https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.${BIN_ARCH}" -o /usr/local/bin/ttyd
  chmod +x /usr/local/bin/ttyd
fi

echo "==> Configuring Docker..."
systemctl enable --now docker
usermod -aG docker learner

echo "==> Installing Containerlab..."
curl -sL https://get.containerlab.dev | bash

echo "==> Pre-pulling container images..."
docker pull quay.io/frrouting/frr:10.2.1
docker pull ghcr.io/srl-labs/network-multitool

echo "==> Setting up measurement-lab in /home/learner..."
mkdir -p /home/learner/measurement-lab/.measlab
cat << 'CONFIG' > /home/learner/measurement-lab/.measlab/runtime.env
MEASLAB_HOP=direct
CONFIG

chmod +x /home/learner/measurement-lab/*.sh || true
chmod +x /home/learner/measurement-lab/scripts/*.sh || true
chmod +x /home/learner/measurement-lab/scripts/scenarios/*.sh || true

echo "==> Pre-warming and verifying lab deployment..."
cd /home/learner/measurement-lab
sudo ./lab.sh up
echo "==> Base state verify:"
sudo ./lab.sh check
sudo ./lab.sh down

echo "==> Installing systemd services and banners..."
if [ -f /tmp/measlab-portal.service ]; then
  install -m 644 /tmp/measlab-portal.service /etc/systemd/system/measlab-portal.service
  systemctl daemon-reload
  systemctl enable measlab-portal.service
fi

if [ -f /tmp/motd-measlab.sh ]; then
  install -m 755 /tmp/motd-measlab.sh /etc/profile.d/99-measlab.sh
fi

if [ -f /tmp/issue ]; then
  install -m 644 /tmp/issue /etc/issue
fi

# Fix ownership
chown -R learner:learner /home/learner

echo "==> Provisioning complete!"
