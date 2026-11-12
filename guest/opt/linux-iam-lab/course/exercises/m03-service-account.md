---
id: m03-service-account
module: m03
title: Create a service account for the reporting job
minutes: 20
prereqs: m03-onboard
---
## Ticket
**OPS-3004** - *Approved by: Finance Manager* - "The nightly finance report job must stop running as a person's account. Create a dedicated **non-interactive** service account `svc-reports` with a system UID, home folder `/var/lib/svc-reports` (private), no usable password and no login shell. It needs read access to the finance share."

## Objective
Understand the difference between human and service (non-human) accounts and create one that cannot be used to log in.

## Before you start
Linux terminal with `sudo`.

## Concepts and commands
```linux
sudo useradd --system --home-dir /var/lib/svc-reports --create-home --shell /usr/sbin/nologin --comment "Finance reporting job (OPS-3004)" svc-reports
```
- `--system` picks a UID below 1000 (from `SYS_UID_MIN`-`SYS_UID_MAX` in `/etc/login.defs`) and does not set password ageing.
- `--home-dir` + `--create-home` give the job a place for its files.
- `--shell /usr/sbin/nologin` blocks interactive logins: anyone who manages to log in is told *This account is currently not available*.
- No `passwd` step: the password field stays `!` (locked).

```linux
sudo usermod -aG finance svc-reports
sudo chmod 750 /var/lib/svc-reports
```
Grant the role, make the home private.

```linux
id svc-reports
getent passwd svc-reports
sudo passwd -S svc-reports
```
```text
uid=998(svc-reports) gid=998(svc-reports) groups=998(svc-reports),3001(finance)
svc-reports:x:998:998:Finance reporting job (OPS-3004):/var/lib/svc-reports:/usr/sbin/nologin
svc-reports L 11/11/2026 -1 -1 -1 -1
```
`L` = locked password. The UID on your VM may differ but is below 1000.

```linux
sudo -u svc-reports cat /srv/finance/budget-2027.csv
sudo su - svc-reports
```
The job itself is started by a scheduler or systemd **as** that user (like `sudo -u` does), so it works. `su -` tries to start the login shell, which is `nologin`, so it is refused.

## Your task
1. Create `svc-reports` as a system account: UID below 1000, home `/var/lib/svc-reports` owned by `svc-reports` with mode `750`, shell `/usr/sbin/nologin`, locked password.
2. Make it a member of `finance` and nothing else.
3. Prove it can read `/srv/finance/budget-2027.csv` but cannot read `/srv/hr`.

## Verify
`id svc-reports`, `sudo passwd -S svc-reports`, `ls -ld /var/lib/svc-reports`, then the access tests. **Check my work**.

## If it fails
- *UID is 1000 or more*: you forgot `--system`. Delete and recreate: `sudo userdel -r svc-reports`.
- *password is not locked*: `sudo usermod -L svc-reports` (and never set one).
- *shell*: `sudo usermod -s /usr/sbin/nologin svc-reports`.

## Hints
### Hint 1
`useradd` has options for a system account, a custom home folder and a shell. `man useradd`, search `/system`.
### Hint 2
`--system --home-dir /var/lib/svc-reports --create-home --shell /usr/sbin/nologin`, then `usermod -aG finance` and `chmod 750` on the home.
### Hint 3
`sudo useradd --system --home-dir /var/lib/svc-reports --create-home --shell /usr/sbin/nologin --comment "Finance reporting job" svc-reports && sudo usermod -aG finance svc-reports && sudo chmod 750 /var/lib/svc-reports`.

## Walkthrough
```linux
sudo useradd --system --home-dir /var/lib/svc-reports --create-home --shell /usr/sbin/nologin --comment "Finance reporting job (OPS-3004)" svc-reports
sudo usermod -aG finance svc-reports
sudo chmod 750 /var/lib/svc-reports
id svc-reports
sudo passwd -S svc-reports
sudo -u svc-reports cat /srv/finance/budget-2027.csv
sudo -u svc-reports ls /srv/hr
sudo su - svc-reports
```
```text
ls: cannot open directory '/srv/hr': Permission denied
This account is currently not available.
```
```linux
lab check m03-service-account
```
**Why it matters:** non-human identities usually outnumber people. Each should be owned, documented (the comment field), least-privileged and unable to log in interactively.
