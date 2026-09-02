# Running the Lab on Windows & Linux with Oracle VirtualBox

This guide walks you through importing and running the pre-packaged **Internet Measurements Lab** `.ova` virtual appliance on Windows 10/11 or Linux using **Oracle VirtualBox**.

---

## 1. Prerequisites

1. **Oracle VirtualBox**: Download and install [VirtualBox 7.0+](https://www.virtualbox.org/wiki/Downloads) (free and open-source).
2. **Lab Appliance**: Download `measlab-x86_64.ova` from the course materials / releases.

---

## 2. Importing the Appliance into VirtualBox

1. Launch **Oracle VirtualBox**.
2. Click **File** $\to$ **Import Appliance...** (or press `Ctrl + I`).
3. Click the folder icon and select the downloaded **`measlab-x86_64.ova`** file.
4. Click **Next**.
5. Review Appliance Settings:
   * **CPU:** 4 cores
   * **RAM:** 4096 MB (4 GB)
   * All port forwarding rules (`8080`, `7681-7684`, `2222`) are pre-configured in the `.ova`.
6. Click **Finish** (or **Import**). VirtualBox will import the virtual disk in about 1–2 minutes.

---

## 3. Starting the Lab

1. In the VirtualBox manager list, select **`measlab-x86_64`** (or `Internet Measurements Lab`).
2. Click the green **Start** button.
3. A VM console window will open. Wait ~15 seconds for the system to boot.
4. Once the login prompt appears, the appliance is fully operational:
   ```
   =================================================================
          Internet Measurements Lab Appliance (RIPE NCC Academy)
   =================================================================
   Open your laptop browser to: http://localhost:8080
   Login: learner / measlab (or SSH via port 2222)
   =================================================================
   ```
5. Open your web browser on Windows/Linux (Edge, Chrome, Firefox) and navigate to:
   👉 **[http://localhost:8080](http://localhost:8080)**

---

## 4. Optional: SSH Access from PowerShell or Linux Terminal

If you prefer working in PowerShell or Windows Terminal instead of the browser console:

```powershell
ssh -p 2222 learner@localhost
```
* Password: `measlab`
* Directory: `cd ~/measurement-lab`

---

## 5. Troubleshooting & Tips

### Virtualization is disabled in BIOS
* **Symptom:** VirtualBox gives a VT-x/AMD-V error on startup.
* **Fix:** Enter your computer's BIOS/UEFI settings and enable **Intel VT-x** or **AMD-V / SVM Support**.

### Port 8080 collision
* **Symptom:** `http://localhost:8080` doesn't load because another service on your host uses port 8080.
* **Fix:** In VirtualBox, go to **Settings** $\to$ **Network** $\to$ **Advanced** $\to$ **Port Forwarding**, and change the **Host Port** for the Portal rule from `8080` to `8088` (then visit `http://localhost:8088`).

### Taking Snapshots
* Before starting a complex scenario (e.g. Activities 4 & 5), you can click **Machine** $\to$ **Take Snapshot...** in VirtualBox. If you make unwanted configuration changes, you can roll back to the clean baseline in seconds.

---

## 6. Shutting Down

* When finished, click **Machine** $\to$ **Close...** $\to$ **Send the shutdown signal**, or execute `sudo shutdown -h now` in any lab terminal.
