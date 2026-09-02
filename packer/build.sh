#!/usr/bin/env bash
# Helper script to build Internet Measurements Lab VM appliances with Packer.
#
# Usage:
#   ./build.sh arm64       # Build ARM64 appliance for UTM / Apple Silicon / QEMU
#   ./build.sh x86-vbox    # Build x86_64 OVA appliance for VirtualBox / VMware
#   ./build.sh x86-qemu    # Build x86_64 qcow2 appliance for KVM / QEMU / Proxmox
#   ./build.sh all         # Build all targets

set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${DIR}"

command -v packer >/dev/null 2>&1 || {
  echo "Error: 'packer' command not found. Install HashiCorp Packer: https://developer.hashicorp.com/packer/install" >&2
  exit 1
}

echo "==> Initializing Packer plugins..."
packer init measlab.pkr.hcl

TARGET="${1:-}"

case "${TARGET}" in
  arm64)
    echo "==> Building ARM64 Appliance (QEMU / UTM)..."
    packer build -var-file=pkrvars/arm64.pkrvars.hcl -only="qemu.measlab-arm64" measlab.pkr.hcl
    ;;
  x86-vbox)
    echo "==> Building x86_64 Appliance (VirtualBox OVA)..."
    packer build -var-file=pkrvars/x86_64.pkrvars.hcl -only="virtualbox-iso.measlab-x86_64" measlab.pkr.hcl
    ;;
  x86-qemu)
    echo "==> Building x86_64 Appliance (QEMU / KVM)..."
    packer build -var-file=pkrvars/x86_64.pkrvars.hcl -only="qemu.measlab-x86_64" measlab.pkr.hcl
    ;;
  all)
    echo "==> Building all targets..."
    packer build -var-file=pkrvars/arm64.pkrvars.hcl -only="qemu.measlab-arm64" measlab.pkr.hcl
    packer build -var-file=pkrvars/x86_64.pkrvars.hcl -only="virtualbox-iso.measlab-x86_64" measlab.pkr.hcl
    ;;
  *)
    echo "Usage: $0 {arm64|x86-vbox|x86-qemu|all}"
    exit 1
    ;;
esac

echo "==> Build complete. Check output-* directories for generated VM images."
