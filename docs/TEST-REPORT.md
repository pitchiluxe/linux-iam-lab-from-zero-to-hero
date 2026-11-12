# Linux IAM Lab - test report

Date: 2026-11-12. All runtime tests below ran on the **real target**: the dedicated VirtualBox VM
`LinuxIAM-Lab01` {078bd032-7a7c-4349-a0cf-0e904894c9bd} created by `Install-LinuxIAMLab.ps1` on the
learner's Windows 11 Home host (VirtualBox 7.2.12, 8 logical CPUs, 23.7 GB RAM, Windows hypervisor
active because of WSL2/Docker). The Windows Server IAM lab VM `IAMZ2H-DC01` was powered off by its
owner before testing and was never started, stopped, modified or snapshotted by any script
(verified: still `poweroff` after every lifecycle test).

Raw results: [`docs/test-results/`](test-results/).

## Summary

| Area | Result | Evidence |
|---|---|---|
| Static checks (6 PowerShell scripts in PS 5.1 + 7, all Bash, all Python) | PASS | parse/`bash -n`/`py_compile`, course loader: 9 modules, 32 exercises, 4 references, every exercise has ticket, objective, prerequisites, commands, task, verify, troubleshooting, 3 hints, walkthrough |
| Host component tests (`tests/Test-HostComponents.ps1`) | PASS 13/13 | seed ISO (ISO9660+Joliet, label CIDATA), empty-passphrase keys, log redaction, payload hash, identity gate refuses without state |
| Preflight refuses safely | PASS | with 3.9 GB free it stopped before any change: "will NOT stop or pause your other VMs" |
| Fresh install (real VM) | PASS after fixes | see "Defects found and fixed"; final run exit 0 |
| Recovery from interrupted setup | PASS | ~10 interrupted/failed runs (signature check, boot hang, provisioning errors) each resumed with the same VM UUID and finished on rerun |
| Installer rerun on a complete install | PASS (8 min) | identity verified, course updated in place, baseline and learner password kept, portal check from Windows |
| **Start** shortcut script | PASS (168 s from power-off) | identity verified, pinned host key matched, all services active, portal ready |
| **Stop** shortcut script | PASS (36 s) | clean `systemctl poweroff`; other VM untouched |
| **Reset** shortcut script | PASS (4.6 min) | see "Reset test" below |
| **Lab inside the Linux VM window** (default) | PASS | Stop → Start shortcut: VirtualBox window (`SessionName=GUI/Qt`), XFCE autologin as student, one Lab Terminal + one course portal window in the Linux browser, progress and green status shown; screenshot `docs/test-results/linux-vm-desktop.png` |
| Portal in a browser (Windows, `http://127.0.0.1:8471`, optional) | PASS | token sign-in, module map + restored progress, exercise page, progressive hints, Check my work from the page, live web terminal running `id`/`ls` as `student@iamlab01`, tutor answer in the UI |
| Exercise suite in the VM (`tests/guest/run-exercise-tests.sh`) | **132/133**, then the 1 failure fixed and re-tested 8/8 | every exercise: reset → check FAILS (negative control) → walkthrough → check PASSES → retry restores start; capstone through all 4 stages incl. injected fault |
| Platform suite in the VM (`tests/guest/run-platform-tests.sh`) | **40/40** (after one fix) | portal auth/CSRF/Host guard, agent socket permissions, web terminal secret path + runs as student, Ollama loopback-only, real tutor answer, secret redaction, tutor-offline fallback, break-glass recovery of sudoers/sshd/sssd/faillock, exercise reset repairs broken permissions, selftest after breakage |
| auditd exercise | PASS in the VM | (was not runnable in the earlier WSL attempt) |

## Reset test

Before Reset the lab was deliberately damaged the way a learner might: invalid sudo policy
(`/etc/sudoers.d/99-broken`), `/srv/finance` set to mode `000`, `sssd` and `slapd` stopped; one
exercise had been passed and a learner file `/home/student/my-notes.txt` created.

`Reset-LinuxIAMLab.ps1 -Yes` (the shortcut's script; `-Yes` replaces the typed RESET):
1. exported to `Documents\LinuxIAMLab\Exports\<time>-before-reset` - `progress.json`, `student-home.tar.gz` (contains `my-notes.txt`; private keys `.ssh/id_*` excluded);
2. stopped and restored the baseline snapshot of the lab VM only;
3. re-applied the newer installed course files;
4. restored the checkmarks (`lab list` shows `[done] m01-orientation`);
5. self-test passed.

Verified afterwards: `visudo -c` OK, `/srv/finance` `2770 root:finance`, `sssd`/`slapd` active, directory lookups work, learner file cleared from the VM (as documented) and present in the export.
Finding: Reset re-applies the course from the *installed* app copy; after fixing a bug in the
repository, the installer must be re-run so the installed copy (and therefore Reset) picks it up. Done.

## Allowed and denied access (examples verified for real)

Each check acts as the affected user (`runuser`, real SSH key logins to the VM, PAM password
authentication through the sshd stack, `sudo -S` with the persona's password):

- m04-permissions: aokafor read+write ALLOWED, jkim read ALLOWED / write DENIED, btran read DENIED.
- m05-delegate: dpatel `sudo systemctl restart falcon-web.service` ALLOWED (service PID changed), `stop` DENIED, `cat /etc/shadow` DENIED.
- m06-sshd-hardening: SSH key login aokafor ALLOWED, jkim DENIED by `AllowGroups`.
- m06-revoke-key: tablet key ALLOWED, stolen key DENIED - also after being re-added (RevokedKeys).
- m07-directory-access: directory user pshah password login ALLOWED after group change; tcole (correct password) DENIED by authorization.
- m09-capstone: contractor key login, Falcon write and NOPASSWD restart ALLOWED; Finance/HR data, `stop`, `cat /etc/shadow`, password login DENIED; after revocation every access DENIED. Injected CAP-9002 fault in the recorded run: login shell set to nologin.

## Tutor

| Measurement (1 vCPU VM on Hyper-V) | Value |
|---|---|
| Model | qwen2.5:1.5b (Q4_K_M), 986 MB on disk |
| Download | ~2.5 GB total (Ollama runtime 1.55 GB + model), fetched on Windows at ~35 MB/s, verified, moved in by virtual disc |
| RAM while answering | ~1.5 GB (VM: 1.56 GB used of 3.9 GB during generation) |
| Generation speed (warm) | 3.5-3.6 tokens/s |
| First answer after VM start (cold, without warm-up) | 272-478 s |
| Following answers (≤260 tokens) | ~100 s via the API; 3-4 min observed in the browser UI right after other load, streamed word by word |
| Quality sample | `docs/test-results/tutor-sample-explain.txt` - correct flag-by-flag explanation of `usermod -aG` |
| Redaction | password=, private key block and `$6$` hash removed before reaching the model (3 items), none echoed back |
| Offline fallback | with Ollama stopped: friendly message, checks and course still work |

Start now pre-loads the model in the background, so the learner's first question avoids the load time.
On a host without the Windows hypervisor the VM can use 2+ vCPUs and answers are several times faster.

## Timings

| Step | Measured |
|---|---|
| Ubuntu cloud image download (590 MB) on Windows | 18 s (~35 MB/s) |
| Ollama + model download on Windows (2.5 GB) | ~2 min |
| Fresh install end to end on this host | ~45-60 min (Linux package install inside the 1-vCPU VM dominates); final resumed runs 11 min |
| Installer rerun on a finished install | 8 min |
| Start (from power-off) | ~3 min |
| Stop | 36 s |
| Reset (export, restore, re-apply course, restore progress, self-test) | 4.6 min |

## Defects found by testing and fixed

| # | Symptom | Cause | Fix |
|---|---|---|---|
| 1 | Image signature check failed | Git-for-Windows gpg (MSYS) misread `C:/...` paths | convert to `/c/...` for MSYS gpg |
| 2 | VM hung at boot (timers stalled) | VirtualBox runs through Hyper-V (NEM); multi-vCPU Linux guests hang | 1 vCPU when the Windows hypervisor is active; paravirt `minimal` |
| 3 | Occasional kernel panic "IO-APIC + timer doesn't work" | same host constraint | kernel option `no_timer_check` + automatic power-cycle of the lab VM only (max 3) |
| 4 | Provisioning stopped creating personas | `head -c` in a pipe under `pipefail` | `openssl rand ... | cut` |
| 5 | Ollama download inside VM cut off | VM NAT ~1 MB/s and drops long transfers | download + verify on Windows, copy in via virtual disc |
| 6 | IMAPI kept files open | COM objects not released | release COM objects; non-fatal cleanup |
| 7 | "model missing" false negative | `$HOME` unset under systemd-run; `grep -q` + `pipefail` | `HOME=/root`; no `| grep -q` pipes under pipefail |
| 8 | learner password not set | PowerShell 5.1 sent a UTF-8 BOM on stdin | BOM-less stdin bytes |
| 9 | apt lock held 10+ min | Ubuntu unattended-upgrades on slow VM | skip apt when installed; disable auto-upgrades in the lab VM |
| 10 | web terminal would not start | Ubuntu's own `ttyd.service` held port 7681 | disable the package's default service |
| 11 | exercise retry could not delete an account | test `su -` left a session; `userdel` exit 8 | `remove_user` ends sessions, `userdel -f` |
| 12 | portal/learner could not reach the agent | socket folder `root:root 0750` | folder `root:labagent 0750` |
| 13 | tutor answers took up to 8 min | long replies, large context, cold model | replies capped at ~260 tokens, smaller context, Start pre-loads the model |
| 14 | portal action bar covered page text | sticky positioning | normal in-page bar |
| 15 | blank portal in the Windows browser | an apostrophe broke a JavaScript string; the browser cached it | fixed and checked with `node --check`; Ctrl+F5 reloads |
| 16 | extra blank browser windows at desktop login | Epiphany restored its old session / `--new-window` added a start page | session restore off, saved session cleared, launched with the URL only |

## Remaining limitations

- Tutor answers are slow on this host (see above) because the Windows hypervisor forces 1 vCPU; lessons, hints, walkthroughs and checks do not depend on it.
- Interactive pieces verified by script rather than by a person clicking: desktop shortcut targets were run directly with the same command lines the shortcuts use; the typed `RESET` confirmation and the password prompt were exercised with their non-interactive switches (`-Yes`, `-StudentPasswordFile`).
