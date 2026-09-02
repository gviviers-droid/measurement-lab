# Running the Lab with VMware Workstation Pro / VMware Fusion Pro

Broadcom makes **VMware Workstation Pro** (for Windows & Linux) and **VMware Fusion Pro** (for macOS) free for personal use. This guide explains how to import and run the lab appliance.

---

## 1. Prerequisites

1. **VMware App**: Download [VMware Workstation Pro](https://www.vmware.com/products/desktop-hypervisors/workstation-pro) (Windows/Linux) or [VMware Fusion Pro](https://www.vmware.com/products/desktop-hypervisors/fusion-pro) (Mac).
2. **Lab Image**:
   * Windows / Linux / Intel Mac: Download `measlab-x86_64.ova`.
   * Apple Silicon Mac: Download `measlab-arm64.qcow2` (or convert to `.vmdk`/`.vmx` via `qemu-img`).

---

## 2. Importing the OVA Appliance

1. Launch VMware Workstation / Fusion.
2. Click **File** $\to$ **Open...** and select `measlab-x86_64.ova`.
3. Give the virtual machine a name and choose a storage directory.
4. Click **Import**.
5. Ensure the Network Adapter is set to **NAT**.

---

## 3. Configure Port Forwarding (if not using Bridged Networking)

If your VMware NAT does not pass host traffic automatically:
1. In VMware, open the **Virtual Network Editor** (Edit $\to$ Virtual Network Editor).
2. Select **NAT (VMnet8)** $\to$ **NAT Settings...**
3. Add a port forwarding rule:
   * **Host Port:** `8080`
   * **Virtual machine IP address:** Enter the VM's internal IP (shown on the VM console screen)
   * **Virtual machine port:** `8080`
4. Click **OK**.

---

## 4. Starting and Accessing the Lab

1. Power on the VM.
2. Once the console banner appears, open your host browser to:
   👉 **[http://localhost:8080](http://localhost:8080)** (or `http://<vm-ip>:8080`)
3. Access all activity sheets, buttons, and terminals directly in your browser.
