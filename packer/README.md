# Internet Measurements Lab - Automated VM Appliance Builder

This directory contains **HashiCorp Packer** configurations to automatically build pre-packaged, offline-capable Virtual Machine appliances for the Internet Measurements Lab.

## What is inside the Appliance?

- **Base OS:** Minimal Ubuntu Server 24.04 LTS (Noble Numbat).
- **Pre-installed Tooling:** Docker Engine, Containerlab, `ttyd`, `python3`, `ping`, `traceroute`, `mtr`.
- **Pre-cached Images:** `quay.io/frrouting/frr:10.2.1` and `ghcr.io/srl-labs/network-multitool` (no container image downloads needed during workshops).
- **Default Credentials:** User `learner` / Password `measlab` (passwordless `sudo`).
- **Auto-Start Service:** Systemd unit (`measlab-portal.service`) automatically deploys the lab and starts `portal.sh` on VM boot.
- **Port Forwarding:**
  - `8080` -> Control Portal & Activity Sheets
  - `7681-7684` -> Web Terminal Sessions (`host1`, `r1`, `r2`, `r3`)
  - `2222` -> SSH into VM (`ssh -p 2222 learner@localhost`)

---

## Directory Structure

```
packer/
├── measlab.pkr.hcl              # Main Packer template
├── variables.pkr.hcl            # Variable declarations
├── build.sh                     # Maintainer build CLI wrapper
├── pkrvars/
│   ├── arm64.pkrvars.hcl        # Variables for ARM64 (Apple Silicon / UTM)
│   └── x86_64.pkrvars.hcl       # Variables for x86_64 (VirtualBox / VMware)
├── http/
│   ├── user-data                # Cloud-init unattended autoinstall configuration
│   └── meta-data                # Cloud-init metadata
├── files/
│   ├── measlab-portal.service   # Auto-start systemd service
│   ├── motd-measlab.sh          # Login terminal banner
│   └── issue                    # Console screen banner
└── scripts/
    ├── provision.sh             # System package, container, and lab setup script
    └── cleanup.sh               # Disk zeroing and cache purge for minimal compression size
```

---

## Prerequisites for Maintainers

1. Install [Packer](https://developer.hashicorp.com/packer/install) (1.9.0+):
   ```bash
   brew install packer     # macOS
   sudo apt install packer # Ubuntu / Debian
   ```
2. Hypervisor tools:
   - For **ARM64**: `qemu` (`brew install qemu` on macOS).
   - For **x86_64**: Oracle VirtualBox or QEMU/KVM.

---

## Building the Images

### 1. Build ARM64 Image (for Apple Silicon Macs & UTM)
```bash
./build.sh arm64
```
*Outputs:* `output-qemu-arm64/measlab-arm64.qcow2`

### 2. Build x86_64 Image (for Windows / Linux / VirtualBox / VMware)
```bash
./build.sh x86-vbox
```
*Outputs:* `output-vbox-x86_64/measlab-x86_64.ova`

### 3. Build x86_64 QEMU/KVM Image
```bash
./build.sh x86-qemu
```
*Outputs:* `output-qemu-x86_64/measlab-x86_64.qcow2`

---

## Testing the Exported VM

1. **VirtualBox (Windows / Linux / Intel Mac)**:
   - Double-click `measlab-x86_64.ova` -> Import Appliance -> Click **Start**.
   - Open browser on host: `http://localhost:8080`.
2. **UTM (Apple Silicon Mac)**:
   - Open UTM -> New VM -> Virtualize -> Linux -> Select `measlab-arm64.qcow2`.
   - Configure Port Forwarding (`8080` -> `8080`).
   - Start VM -> Open browser on Mac: `http://localhost:8080`.
