# Test guide: running the lab on Windows 11 in UTM

**Purpose:** Verify that a learner on a fresh Windows 11 machine can install and run the Internet Measurements lab.
**Date:** 27 July 2026
**Tester:** ____________________
**Result:** ____________________

---

## 0. Read this first: the one thing that can block the whole test

Containers need a Linux kernel. On Windows that means WSL2, and WSL2 runs on Hyper-V, which is itself a hypervisor. Running it inside a Windows VM therefore requires **nested virtualisation**: a hypervisor running inside a hypervisor.

This is a property of your Mac and UTM, not of the lab. Three cases:

| Your host | Nested virtualisation | What to expect |
|---|---|---|
| Apple Silicon M3 or newer, macOS 15 or newer | Supported by Apple's framework | May work. UTM enabled it for Linux guests first; support for Windows guests has been tracked separately, so verify before relying on it |
| Apple Silicon M1 or M2 | Not supported by the hardware | WSL2 will not start inside the VM. This test cannot succeed on this machine |
| Intel Mac | Possible via QEMU, but slow | Likely to be too slow to be a fair test |

**Do the pre-flight check in section 3 before anything else.** If it fails, jump to section 9, which gives you two fallbacks that still produce a valid test result.

One further consequence of testing on Apple Silicon: your Windows 11 guest will be the ARM64 edition, so WSL will run ARM64 Linux and the lab will pull ARM64 container images. FRR publishes multi-architecture images, so this should work, but confirm the multitool image also resolves for ARM64 — note the result in section 8, because it tells you something real about learners on ARM hardware.

## 1. Prepare the VM in UTM

Before booting Windows, check the VM settings. The lab runs fourteen containers, and WSL2 and Windows both want memory of their own.

| Setting | Minimum | Recommended |
|---|---|---|
| Memory | 8 GB | 12 GB |
| CPU cores | 4 | 6 |
| Disk | 64 GB | 80 GB |

In UTM, open the VM's settings, and under **System** check that nested virtualisation is enabled if the option is offered for this guest type. Note in your test record whether the option appeared at all.

## 2. Complete Windows setup

Boot the VM and finish the Windows 11 out-of-box setup. Nothing special is needed. Once at the desktop, apply pending Windows updates and reboot, since WSL depends on current components.

## 3. Pre-flight check: can this VM run WSL2?

Open **PowerShell as Administrator** (right-click the Start button, choose Terminal (Admin)) and run:

```
systeminfo
```

Scroll to the **Hyper-V Requirements** section at the bottom.

- If it reports that a hypervisor has been detected or that Hyper-V requirements are met, nested virtualisation is working. Continue to section 4.
- If it reports that firmware virtualisation support is absent, nested virtualisation is not available to this guest. **Stop and go to section 9.**

Record what this command printed. It is the single most useful line in the whole test report.

## 4. Install WSL2

Still in the administrator terminal:

```
wsl --install
```

This enables the required Windows features, installs the WSL2 kernel and installs Ubuntu as the default distribution. Reboot when prompted.

After the reboot, Ubuntu opens automatically and asks you to create a username and password. Choose anything; note it in your test record, since you will need the password for `sudo`.

Confirm you are on version 2:

```
wsl --list --verbose
```

The VERSION column must read 2. If it reads 1, run `wsl --set-version Ubuntu 2`.

**If `wsl --install` fails here** with a virtualisation error, the pre-flight check gave a false positive. Go to section 9.

## 5. Install the container engine inside WSL

Open the Ubuntu terminal (Start menu → Ubuntu). Everything from here on happens inside Linux.

WSL2 does not run systemd by default, and the container engine needs it. Enable it first:

```
sudo tee /etc/wsl.conf > /dev/null <<'EOF'
[boot]
systemd=true
EOF
```

Then, back in **PowerShell**, restart WSL:

```
wsl --shutdown
```

Reopen the Ubuntu terminal and install Docker Engine (the open source engine, not Docker Desktop):

```
sudo apt update
sudo apt install -y docker.io
sudo usermod -aG docker $USER
```

Close and reopen the Ubuntu terminal so the group membership takes effect, then verify:

```
docker run --rm hello-world
```

If this prints a greeting, the container engine works. If it reports permission denied, run `wsl --shutdown` in PowerShell once more and reopen Ubuntu.

*Alternative worth trying if you have time:* srl-labs publishes a ready-made WSL distribution with Containerlab pre-installed, under the Apache 2.0 licence: [github.com/srl-labs/wsl-containerlab](https://github.com/srl-labs/wsl-containerlab). If it works, it collapses sections 5 and 6 into one step and would be a much better learner experience. Check its README for the current install command, and record whether it worked on ARM64.

## 6. Install Containerlab

In the Ubuntu terminal:

```
bash -c "$(curl -sL https://get.containerlab.dev)"
```

Verify:

```
containerlab version
```

## 7. Get the lab into the VM

Two routes. Use whichever matches how learners will receive it.

**Route A, the way a learner will do it.** In Windows, open a browser, download the lab archive, and extract it to your Windows desktop. Then reach it from Ubuntu:

```
cd /mnt/c/Users/<your-windows-username>/Desktop/measurement-lab
```

Note that running from `/mnt/c` is slower than the Linux filesystem. If the lab feels sluggish, copy it across first:

```
cp -r /mnt/c/Users/<your-windows-username>/Desktop/measurement-lab ~/
cd ~/measurement-lab
```

**Route B, if you have the repository.** Clone it directly inside Ubuntu, which avoids the filesystem boundary entirely.

Make the scripts executable, since Windows filesystems do not preserve the permission:

```
chmod +x lab.sh scripts/*.sh scripts/scenarios/*.sh
```

## 8. Run the lab

```
sudo ./lab.sh up
```

The first run downloads the container images, which takes a few minutes. Afterwards the same command takes seconds.

When it finishes, the health check runs automatically. **Record the output.** Every line should read PASS.

Then work through the first activity as a learner would:

```
docker exec -it clab-measlab-host1 bash
traceroute -n 10.40.10.10
ping -c 10 3fff:40:10::10
mtr -n --report --report-cycles 20 10.40.10.10
```

Open the activity sheets in a browser. From the Ubuntu terminal:

```
sudo ./lab.sh docs
```

Then open `http://localhost:8080` in the Windows browser. WSL2 forwards localhost automatically, so this should just work. Confirm the copy buttons, the answer panels and the task checkboxes behave.

Finally, tear down:

```
sudo ./lab.sh down
```

### What to record

| Check | Result |
|---|---|
| `systeminfo` Hyper-V requirements line | |
| WSL2 installed and reporting version 2 | |
| Container engine runs hello-world | |
| Containerlab version installed | |
| Images pulled for ARM64 without error | |
| `lab.sh up` completes | |
| Health check: all PASS? If not, which failed | |
| Time from `lab.sh up` to green check, first run | |
| Time on a second run | |
| Traceroute and ping produce sensible output | |
| IPv6 works as well as IPv4 | |
| Frontend opens at localhost:8080 | |
| Peak memory use of the VM during the lab | |
| Total wall-clock time for a beginner to reach a running lab | |

That last row is the number that decides whether this is a viable learner experience.

## 9. If nested virtualisation is unavailable

The test is still worth doing; it just moves to a platform that can run it.

**Fallback A, and the better test anyway: a Linux VM in UTM.** Containers are not virtual machines, so running them inside a Linux VM needs no nested virtualisation at all. Create an Ubuntu Desktop ARM64 VM in UTM with 8 GB of memory, install Docker Engine and Containerlab with the commands in sections 5 and 6, and run the lab. This exercises everything except the Windows-specific layer, and it will tell you whether the lab itself is sound on ARM hardware.

**Fallback B: a real Windows machine.** Any Windows 11 PC with virtualisation enabled in its firmware runs WSL2 natively, with no nesting involved. This is the only way to test the genuine Windows learner path, and it is worth borrowing a machine for an hour to do it.

Note in your test record which fallback you used, because "we could not test Windows-in-UTM because of an Apple Silicon limitation" is a legitimate and useful finding rather than a failed test.

## 10. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `wsl --install` reports a virtualisation error | Nested virtualisation unavailable | Section 9 |
| Docker reports permission denied | Group membership not yet applied | `wsl --shutdown` in PowerShell, reopen Ubuntu |
| Docker daemon not running | systemd not enabled in WSL | Check `/etc/wsl.conf`, then `wsl --shutdown` |
| `./lab.sh` reports permission denied | Executable bit lost via the Windows filesystem | `chmod +x lab.sh scripts/*.sh scripts/scenarios/*.sh` |
| Image pull fails with a manifest or platform error | No ARM64 build of that image | Record which image. This is a genuine finding affecting all ARM learners |
| Health check fails on BGP sessions | Containers still converging | Wait 60 seconds, run `sudo ./lab.sh check` again |
| Health check fails on latency thresholds | Impairments not applied | Run `sudo ./scripts/impairments.sh`, then check again |
| Lab is very slow | Running from `/mnt/c` | Copy the folder into the Linux home directory |
| localhost:8080 does not open in Windows | Port forwarding not active | Try `http://127.0.0.1:8080`, or open the HTML file directly |
