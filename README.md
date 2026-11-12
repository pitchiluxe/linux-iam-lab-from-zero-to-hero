# Linux IAM Zero-to-Hero Lab

A hands-on Linux course for future **Identity and Access Management analysts and engineers**. You run real commands in your own dedicated Ubuntu Server VM, work realistic tickets, and the lab checks your work by testing access **as the affected users** - can they read the file, log in with the key, run the delegated command, and are they denied everything else?

- 9 modules, 32 ticket-based exercises, a 4-stage capstone
- Course portal with module map, progress, searchable reference, exercise checks, a Linux web terminal and a local AI tutor (Ollama)
- Offline after the first install; your other virtual machines are never touched

Landing page: <https://linux-iam-lab-from-zero-to-hero.vercel.app> (source in [`landing/`](landing/)).
After the capstone: ready-to-publish portfolio content in [`YourGithub/`](YourGithub/) and [`YourLinkedin/`](YourLinkedin/).

---

## 1. Requirements

| | Minimum | Notes |
|---|---|---|
| Windows | Windows 10 1809+ / Windows 11, 64-bit (Home is fine) | uses built-in OpenSSH client, `curl.exe`, `tar.exe` |
| Hypervisor | **Oracle VirtualBox 7.x** (already installed on this PC: 7.2.12) | runs on top of Hyper-V/WSL2 if those are on (slower, supported) |
| Privileges | **standard user** - no administrator rights needed | the installer does not change Windows features, drivers or networking |
| Free memory when you install/start | **5 GB available** (4 GB VM + 1 GB headroom); `-MemoryMB 3072` lowers it to 4 GB | the installer checks and **stops** if there is not enough - it never stops other VMs |
| Free disk | 25 GB on the drive holding `VirtualBox VMs` | actual use after install: about 9 GB (VM disk grows dynamically up to 40 GB) + 0.6 GB cached image |
| Internet | first install only (about 3.5 GB in total) | afterwards the course, checks and tutor work offline |
| Optional | Git for Windows or Gpg4win (`gpg.exe`) | enables GPG signature verification of the Ubuntu image (otherwise SHA-256 over HTTPS) |

## 2. Install

Open **Windows PowerShell** (not as administrator), go to this folder and run:

```powershell
cd "C:\Users\<you>\Documents\_My_Digital_Solutions\_Linux_Real_Lab_With_IAM"
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-LinuxIAMLab.ps1
```

What happens (every step is logged to `%LOCALAPPDATA%\LinuxIAMLab\logs\install-*.log`, without passwords or keys):

1. **Preflight** - checks Windows, VirtualBox, OpenSSH, memory, disk and free localhost ports. Changes nothing. (`-PreflightOnly` stops here.)
2. **Identity** - records the new VM's name and UUID before creating anything (so an interrupted install resumes safely).
3. **Keys** - creates the lab's automation key, your learner key (`~\.ssh\linux-iam-lab_student_ed25519`) and the VM's SSH host key (pinned).
4. **Image** - downloads `ubuntu-24.04-server-cloudimg-amd64.vmdk` (~590 MB), verifies Ubuntu's GPG signature on `SHA256SUMS` and the file's SHA-256. Resumes if interrupted.
5. **VM** - creates `LinuxIAM-Lab01` (4 GB RAM, 40 GB dynamic disk, private NAT, ports bound to 127.0.0.1 only; **1 vCPU** while the Windows hypervisor is active, because multi-vCPU Linux guests hang under VirtualBox-on-Hyper-V) and a cloud-init seed disc.
6. **Provisioning inside the VM** - Linux packages, the fictional company, the lab's own LDAP directory + SSSD, auditd, the portal, web terminal and every exercise scenario. Ollama (1.55 GB) and the tutor model (~1 GB) are downloaded **on Windows**, checked against their published SHA-256 sums, and handed to the VM on a virtual disc (the VM's nested network is too slow and drops long downloads). Progress lines start with `vm>`.
7. **Your Linux password** - you choose the password for the Linux account `student` (you will type it for `sudo`). It is set inside the VM only and never stored on Windows.
8. **Self-test**, then a powered-off **baseline snapshot** used by Reset.
9. **Shortcuts** on your desktop, the offline reference in `Documents\LinuxIAMLab\Reference`, and an SSH entry `linux-iam-lab` in `~\.ssh\config`.

Measured on this PC: fresh install 45-60 minutes (Linux package installation inside the 1-vCPU VM dominates); downloads on Windows about 3 minutes; a rerun on a finished install 6-8 minutes. Details: [the test report](docs/TEST-REPORT.md#timings). Re-running the same command is always safe: finished steps are skipped, an interrupted provisioning is resumed, and nothing is duplicated.

Options: `-MemoryMB 3072`, `-SkipTutorModel` (install the tutor model later with `sudo lab tutor-pull`), `-NoShortcuts`, `-NoSshConfig`, `-NoLaunch`.

## 3. Daily use

| Desktop shortcut | Does |
|---|---|
| **Start Linux IAM Lab** | verifies the VM is *this lab's* VM and opens it in a **VirtualBox window** (like your Windows Server VM). Linux logs in automatically as `student` and opens a **Lab Terminal** and the **course portal in a browser inside Linux**. You do the whole lab inside that window. |
| **Stop Linux IAM Lab** | clean shutdown of the lab VM only (asks before forcing) |
| **Reset Linux IAM Lab** | explains what will be cleared, exports your work, asks you to type `RESET`, restores the known-good baseline, restores your checkmarks (unless you decline), self-tests |

**First launch:** the VirtualBox window shows the Linux (XFCE) desktop, already logged in as `student`, with two windows: the **Lab Terminal** (`student@iamlab01:~$`) where you type the exercise commands, and the **course portal** (Linux browser) on **Start here**: "Where am I typing?", how exercises work, the course map, **Check my work**, hints and the **Tutor**. Reopen them any time from **Applications > Education** or by typing `lab portal`. The first boot to the desktop takes 1-3 minutes on this PC.

Optional: the same portal from Windows with `Start-LinuxIAMLab.ps1 -Browser`, and `ssh linux-iam-lab` from Windows Terminal.

### Manual SSH from Windows Terminal (the way you will work on the job)

```powershell
ssh linux-iam-lab
```
The installer configured the key and pinned the VM's host key (fingerprint shown at the end of the install and on the portal's *Progress & lab tools* page). Long form: `ssh -p 2422 -i $HOME\.ssh\linux-iam-lab_student_ed25519 student@127.0.0.1`.

### Inside Linux

```linux
lab help            # all lab commands
lab list            # progress
lab check m03-onboard
lab hint m03-onboard 2
lab reset m03-onboard      # retry one exercise
```

## 4. Reset and progress

| | Scope | Your progress | Your files in the VM |
|---|---|---|---|
| **Retry exercise** (portal button / `lab reset ID`) | only that exercise's users, files and settings | kept (earlier pass remembered) | kept |
| **Reset Linux IAM Lab** (desktop) | whole VM back to the install baseline - fixes broken sudo, SSH, PAM, services | exported, then restored (you can decline) | exported to `Documents\LinuxIAMLab\Exports\<time>-before-reset\`, then cleared |
| `windows\Export-LinuxIAMLabWork.ps1` | export only | copied | copied (`student-home.tar.gz`, private keys excluded) |

Break-glass while practising risky topics (portal *Progress & lab tools*, or `lab rescue sudoers|sshd|faillock|sssd|terminal`).

## 5. The tutor

- Model: **qwen2.5:1.5b** via Ollama, inside the VM, listening on `127.0.0.1:11434` only (not reachable from Windows or the network).
- Download ~2.5 GB once (runtime + model, fetched on Windows); uses ~1.5 GB RAM while answering. **Speed on this PC (1 vCPU under Hyper-V): about 3.5 tokens/s, so 1-4 minutes per answer**, streamed as it is written. Start pre-loads the model so the first question skips the load time. With the Windows hypervisor off (2+ vCPUs) it is several times faster.
- Modes: Ask, Explain a command (also an **Explain** button on every Linux command block), Explain an error, Nudge me, Quiz me.
- It sees the course text, the exercise you have open, and only the terminal output **you paste** into "Share terminal output". Private keys, password hashes, `password=`/`token=` values and the lab's own tokens are removed before the model sees anything, and you are told how many items were removed. It cannot run commands.
- If Ollama is down, lessons, hints, walkthroughs and checks keep working.

## 6. Course map

| Module | Exercises |
|---|---|
| 1 First day at the Linux terminal | orientation, files, help & mistakes |
| 2 Read and investigate a system | pipes & logs, find, processes & services, Bash script |
| 3 Manage the identity lifecycle | inspect identities, onboard, mover, service account, lockout, offboard |
| 4 Control access to files and directories | permissions, traversal, shared folder, ACLs |
| 5 Delegate administrative privileges | sudo review, command delegation, lockout recovery |
| 6 Secure remote access | key login, broken SSH, sshd hardening, key revocation |
| 7 Authentication and centralized identity | authN vs authZ (PAM/NSS), directory lookup, directory-based access |
| 8 Audit and automate IAM work | failed logins, auditd, access-report script, evidence package |
| 9 Capstone | contractor onboard → broken login (randomized) → revoke → evidence |

Every exercise has: ticket, objective, prerequisites, commands with flags explained and example output, the task, verification, troubleshooting, three progressive hints, and a full walkthrough (always available for review).

## 7. Safety and isolation

- The lab manages **only** the VM whose UUID, name **and** install-id tag match `%LOCALAPPDATA%\LinuxIAMLab\state.json`; scripts refuse otherwise.
- Separate VM, disk, folder (`VirtualBox VMs\Linux-IAM-Lab`), accounts, keys, and a per-VM NAT. No host-only adapter, NAT network or bridged adapter is created; forwards bind to `127.0.0.1`.
- No reboot, no Windows feature change, no admin rights. If something like that were needed, the installer stops and explains.
- Nothing in the lab refers to or connects to your Windows Server IAM lab. The directory module uses an OpenLDAP server **inside** the Linux VM with fictional people.
- All people, companies, IPs (documentation ranges) and data are fictional.

## 8. Troubleshooting setup

| Symptom | What to do |
|---|---|
| Preflight: not enough memory | close applications and re-run, or `-MemoryMB 3072`. The installer never stops other VMs. |
| Preflight: port in use | the installer picks the next free port automatically and records it |
| Download interrupted | re-run; `curl` resumes the `.part` file, then verifies it |
| "Provisioning inside the VM did not finish" | re-run the installer (it resumes); the last VM log lines are in the install log |
| Linux never answers SSH | `VirtualBox VMs\Linux-IAM-Lab\LinuxIAM-Lab01\serial-console.log` shows the boot console |
| "unexpected SSH host key" | the VM was replaced outside the installer - the scripts refuse to talk to it. Run `windows\Uninstall-LinuxIAMLab.ps1`, then install again. |
| VM very slow / tutor slow | Windows' hypervisor is active (WSL2/Docker/Memory integrity); VirtualBox then runs through Hyper-V with 1 vCPU. Supported, just slower. The installer does not change this. Closing other heavy apps (e.g. a local Ollama on Windows) helps a lot. |
| Boot shows "Kernel panic ... IO-APIC + timer" | known VirtualBox-on-Hyper-V timer issue; the lab boots with `no_timer_check`, and Start/installer automatically power-cycle the lab VM (up to 3 times) |
| Remove everything | `powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\LinuxIAMLab\app\windows\Uninstall-LinuxIAMLab.ps1"` (deletes only the lab VM; keeps your exports) |

More: [docs/DESIGN.md](docs/DESIGN.md) (architecture and choices) · [docs/TEST-REPORT.md](docs/TEST-REPORT.md) (what was tested and how) · offline reference: `docs/offline/LinuxIAMLab-Reference.html`.
