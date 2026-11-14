# Linux IAM Lab - design and implementation choices

## Goals that drove the design

1. Real Linux, real commands, real access tests - no simulation.
2. Never disturb the learner's active Windows Server IAM lab (`IAMZ2H-DC01`, VirtualBox).
3. One PowerShell entry point, three desktop shortcuts, rerunnable and recoverable.
4. Works offline after the first install; the AI tutor is optional and private.

## Architecture

```
Windows host (standard user, no admin)
├── Install-LinuxIAMLab.ps1 ─┐  windows\LinuxIAMLab.Common.ps1 (identity gate, logging, SSH, payload)
├── Desktop: Start / Stop / Reset Linux IAM Lab  →  %LOCALAPPDATA%\LinuxIAMLab\app\windows\*.ps1
├── %LOCALAPPDATA%\LinuxIAMLab\  state.json, logs\, keys\, cache\ (image), known_hosts, ssh_config
├── Documents\LinuxIAMLab\  Reference\ (offline), Exports\ (progress + learner files)
└── VirtualBox (existing install)
    └── LinuxIAM-Lab01  (own UUID, own folder, own per-VM NAT, 127.0.0.1-only port forwards)
        Ubuntu Server 24.04 LTS cloud image + cloud-init NoCloud seed
        ├── sshd                      host 127.0.0.1:2422 → 22   (ssh linux-iam-lab)
        ├── lab-portal  (labportal)   host 127.0.0.1:8471 → 8080 (course portal, token cookie)
        ├── lab-terminal (ttyd, as student) host 127.0.0.1:8472 → 7681 (secret path)
        ├── lab-agent   (root, Unix socket, fixed operations only)
        ├── ollama      127.0.0.1:11434 only (tutor model qwen2.5:1.5b)
        ├── slapd + SSSD  dc=iamlab,dc=test with StartTLS (disposable, fictional people)
        ├── auditd, pam_faillock, falcon-web demo service
        └── snapshot "LinuxIAMLab-Baseline" (known-good state for Reset)
```

## Key decisions

| Decision | Why |
|---|---|
| **VirtualBox** (not Hyper-V/WSL) for the lab VM | Already installed and used by the learner; Windows 11 **Home** has no Hyper-V Manager. Creating a VM needs no admin rights and no Windows feature changes. Works on top of the active Windows hypervisor (slower, supported), which the installer reports but never changes. |
| **Per-VM NAT** + port forwards bound to `127.0.0.1` | Isolated network: no host-only adapter, no NAT network, no bridged NIC, nothing shared with the Windows Server VM, nothing reachable from the LAN. |
| **Ubuntu Server 24.04 LTS** cloud image | Supported LTS until 2029 with mature `sudo`, OpenSSH, SSSD, OpenLDAP, auditd and ttyd packages. Ubuntu 26.04 replaces `sudo` with `sudo-rs` and coreutils with Rust versions; the course teaches the classic, most widely deployed tools. The image file is configurable. |
| Image verification: **GPG + SHA-256** | `SHA256SUMS` is verified against Ubuntu's cloud-image signing key (fingerprint `D2EB 4462 6FDD C30B 513D 5BB7 1A5D 6C4C 7DB8 7C81`, key file shipped in `windows\keys\`), then the image hash is checked. gpg from Git for Windows or Gpg4win; without gpg the installer falls back to HTTPS + SHA-256 and says so. |
| **cloud-init NoCloud ISO** built with Windows' IMAPI2 COM | Unattended first boot with no extra tools: hostname, accounts, SSH keys, **pinned SSH host key**. The seed ISO (it contains the VM host private key) is detached and deleted after install. |
| **Pinned host key** | The installer generates the VM's ed25519 host key, so every SSH connection (automation and learner) is verified (`StrictHostKeyChecking yes`) from the first connection. |
| Identity gate: **UUID + name + install-id extradata** | Every lifecycle script calls `Assert-LabVm`, which refuses to act unless all three match `state.json`. The VM UUID is chosen and recorded *before* `createvm`, so an interrupted install can be resumed and never mistaken for another VM. No script lists other VMs in order to act on them. |
| Learner password chosen at install | Stored nowhere on Windows and never logged; sent to `chpasswd` over SSH **stdin**. The automation account `labctl` is key-only. |
| Provisioning as a **transient systemd unit** | A closed window or dropped SSH session does not kill provisioning; the installer reattaches and tails the log on rerun. `provision.sh` is idempotent. |
| **Reset = VirtualBox snapshot restore** (lab VM only) | Restores working access even if the learner broke sudo, SSH, PAM or a service. Before restoring, the Reset script exports progress, `/home/student` and evidence to `Documents\LinuxIAMLab\Exports`, and re-imports checkmarks afterwards unless declined. If the course payload is newer than the baseline, it is re-applied after restore. |
| **Retry exercise** = exercise-level reset through the root agent | Each exercise script has `do_setup` (with `RESET=1`), `do_check`, `do_solve`. Retry recreates only that exercise's users, files and settings. |
| Root **agent** on a Unix socket | The portal runs unprivileged (`labportal`, `ProtectSystem=strict`). It can only ask the agent to run fixed operations (check/reset/rescue/capstone) for validated exercise IDs; callers are authenticated with `SO_PEERCRED`. The agent never executes client-supplied commands. |
| **Break-glass** `lab rescue` | Safe practice of risky topics (sudoers, sshd, faillock). Quarantines invalid files rather than deleting them, logs every action. |
| Checks **act as the users** | `runuser`, real SSH key logins to localhost, PAM authentication with `pamtester` (same stack as sshd), real `sudo -S` with the persona's password. Every exercise asserts both ALLOWED and DENIED outcomes. |
| **ttyd** web terminal behind a secret path | Gives a browser terminal without Windows tools; `--check-origin`, runs as `student`, unguessable base path delivered only to an authenticated portal session. `ssh linux-iam-lab` is the "real job" route. |
| Portal in **Python standard library** + vanilla JS | Nothing to download at runtime; works offline. Host-header allow-list (DNS-rebinding defence), HttpOnly SameSite=Strict cookie, custom-header CSRF guard. |
| Tutor model **qwen2.5:1.5b** (Ollama) | ~1 GB, ~1.5 GB RAM while answering, good instruction-following for its size; measured 3.5 tokens/s on 1 vCPU. Ollama + model are downloaded on Windows, SHA-256 verified, and moved into the VM on a virtual disc. Ollama is bound to `127.0.0.1` inside the VM; the portal is its only client. Configurable in `windows\lab.config.json`. |
| **1 vCPU, paravirt `minimal`, `no_timer_check`** when the Windows hypervisor is active | VirtualBox then runs through Hyper-V (NEM); multi-vCPU Linux guests hang and early timer checks can panic. Start/installer also power-cycle the lab VM (max 3) if a boot panic is detected. |
| Automatic upgrades off inside the lab VM | the VM is localhost-only and restored from a snapshot; background upgrades would change the baseline and lock dpkg for long periods on slow hosts |
| Tutor safety | No tool use or command execution. System prompt forbids handling secrets and handing out solutions; the portal **redacts** private keys, password hashes, `password=`/`token=` values and the lab's own tokens from anything shared, and tells the learner how many items were removed. Lessons, hints and checks never depend on the tutor. |
| faillock `unlock_time = 0` with records in `/var/lib/faillock` | Lockout scenarios survive reboots and snapshot restore; mirrors "helpdesk must unlock" policies. Learner self-lockout is recoverable with one click / `lab rescue faillock`. |
| Lab directory = **OpenLDAP inside the lab VM** | Satisfies the centralized-identity module with disposable identities and services owned by this lab. No dependency on, or network path to, the Windows Server domain controller. |

## What runs where (privileges)

| Component | Runs as | Can |
|---|---|---|
| Installer / shortcuts | the Windows user (no admin) | manage only the recorded VM; write `%LOCALAPPDATA%\LinuxIAMLab`, Desktop shortcuts, `~\.ssh\config` block |
| `labctl` | VM automation account, key-only, NOPASSWD sudo | used by Windows scripts for provisioning, export, selftest, shutdown |
| `student` | learner, member of `sudo` | everything a Linux admin does |
| `lab-agent` | root | fixed exercise operations and rescue actions |
| `lab-portal` | `labportal` (no shell, read-only filesystem) | serve content, call agent, call Ollama |
| `ttyd` | `student` | the browser terminal |
| `ollama` | `ollama` | the tutor model, loopback only |

**Rule for root code (agent, exercise setup/reset/check, export):** the learner controls
`/home/student` and can plant symlinks there, so root never writes, deletes, `chown`s or unpacks
anything in it. Those operations run as the learner (`as_student` in `lib/common.sh`). The one
place where learner-written code needs root, the m08 access-report check, runs a private copy
in a systemd sandbox (`sandbox_root`): read-only system, private `/tmp`, no network, no
systemd/D-Bus, lab secrets hidden, only the capabilities needed to read account data. This keeps
the agent from becoming a way around the learner's own sudo password.
`tests/guest/run-security-regression.sh` tries each of these attacks as the learner.

## Files

- `Install-LinuxIAMLab.ps1` - entry point.
- `windows\` - common library, Start/Stop/Reset/Export/Uninstall scripts, config, Ubuntu signing key.
- `guest\provision.sh` - in-VM provisioning; `guest\systemd\` - units.
- `guest\opt\linux-iam-lab\` - `bin\` (lab CLI, agent, portal), `lib\` (helpers, baseline, directory, selftest, exercise runner), `exercises\` (35 exercise scripts), `course\` (9 lessons, 35 exercises, 4 references), `portal\static\` (UI).
- `tests\` - host tests, guest exercise and platform test harnesses, WSL test helper.
- `tools\build_offline_reference.py` - builds the single-file offline reference.
- `docs\` - this file, the test report, offline reference.
