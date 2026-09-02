# Running the Lab on macOS with UTM (Apple Silicon M1/M2/M3/M4)

This guide walks you through importing and running the pre-packaged **Internet Measurements Lab** virtual machine image on an Apple Silicon Mac using the free and open-source **UTM** hypervisor.

---

## 1. Prerequisites

1. **UTM Virtual Machine App**: Download and install [UTM for Mac](https://mac.getutm.app/) (free download).
2. **Lab Image**: Download the pre-built `measlab-arm64.qcow2` image from the course materials / releases.

---

## 2. Setting Up the VM in UTM

1. Open **UTM** and click the **`+` (Create a New Virtual Machine)** button.
2. Select **Virtualize** *(do not select Emulate)*.
3. Select **Linux**.
4. Check **Skip ISO boot** (or select "Import Existing Image") and click **Next**.
5. Set Hardware Resources:
   * **Memory:** `4096 MB` (4 GB)
   * **CPU Cores:** `4`
   * Click **Next**.
6. Set Storage:
   * Select **Existing Drive** and choose your downloaded `measlab-arm64.qcow2` file.
   * Click **Next**.
7. In the Summary screen, name the VM **`Internet Measurements Lab`** and click **Save**.

---

## 3. Configure Port Forwarding

To access the web Control Portal and terminals directly from your Mac's browser:

1. Right-click the newly created VM in UTM and select **Edit**.
2. Click **Network** in the left sidebar.
3. Ensure Network Mode is set to **Shared Network** (NAT).
4. Click **Port Forwarding** and add the following port rules:

| Rule Name | Protocol | Guest Port | Host Port | Purpose |
|---|---|---|---|---|
| **Portal** | TCP | `8080` | `8080` | Control Portal & Web Sheets |
| **host1** | TCP | `7681` | `7681` | Workstation Terminal |
| **r1** | TCP | `7682` | `7682` | Router 1 Terminal |
| **r2** | TCP | `7683` | `7683` | Router 2 Terminal |
| **r3** | TCP | `7684` | `7684` | Router 3 Terminal |
| **SSH** | TCP | `22` | `2222` | Terminal SSH (optional) |

5. Click **Save**.

---

## 4. Starting the Lab

1. Click the **Play (Start)** button on the VM in UTM.
2. The VM will boot in 10–20 seconds. The login console will display:
   ```
   =================================================================
          Internet Measurements Lab Appliance (RIPE NCC Academy)
   =================================================================
   Open your laptop browser to: http://localhost:8080
   Login: learner / measlab (or SSH via port 2222)
   =================================================================
   ```
3. Open your Mac's web browser (Safari, Chrome, Firefox) and navigate to:
   👉 **[http://localhost:8080](http://localhost:8080)**

The **Control Portal**, **Activity Sheets**, and **Live Terminals** are immediately ready to use.

---

## 5. Optional: SSH Access from macOS Terminal

If you prefer using your Mac's native Terminal rather than the browser terminals:

```bash
ssh -p 2222 learner@localhost
```
* Password: `measlab`
* Working folder: `cd ~/measurement-lab`

---

## 6. Saving Progress and Stopping the VM

* **To Pause / Resume**: Use UTM's pause button.
* **To Take a Snapshot**: In UTM, create a snapshot before starting an activity so you can instantly revert if needed.
* **To Shut Down**: Run `sudo shutdown -h now` inside the VM, or click UTM's power button.
