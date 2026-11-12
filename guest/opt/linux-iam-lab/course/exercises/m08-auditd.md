---
id: m08-auditd
module: m08
title: Watch identity and sudo files with auditd
minutes: 30
prereqs: m08-failed-logins
---
## Ticket
**SEC-8002** - *From: Compliance* - "Control AC-7 requires that every change to local identities and to sudo policy is recorded with **who** did it. Add persistent audit rules on `iamlab01` for `/etc/passwd`, `/etc/group`, `/etc/shadow`, `/etc/gshadow` (key `identity`) and `/etc/sudoers` plus `/etc/sudoers.d/` (key `privilege`). Prove it by recording a test account creation."

## Objective
Write persistent auditd rules, load them, generate a test event, and find it with `ausearch` - including the original login user (auid).

## Before you start
Linux terminal with `sudo`. auditd is running (`systemctl status auditd`).

## Concepts and commands
```linux
sudo auditctl -l
```
Lists the rules currently active in the kernel (`No rules` at first).

```linux
sudo nano /etc/audit/rules.d/50-iam.rules
```
```conf
## SEC-8002 identity and privilege changes
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/sudoers -p wa -k privilege
-w /etc/sudoers.d/ -p wa -k privilege
```
`-w` watch path, `-p wa` write or attribute change, `-k` key to search by. A trailing `/` watches a directory tree.

```linux
sudo augenrules --load
sudo auditctl -l
```
`augenrules` merges `/etc/audit/rules.d/*.rules` into `/etc/audit/audit.rules` and loads them. Files in `rules.d` are what survive a reboot.
```text
-w /etc/passwd -p wa -k identity
...
-w /etc/sudoers.d -p wa -k privilege
```

```linux
sudo useradd -M -s /usr/sbin/nologin audit-test-user
sudo userdel audit-test-user
sudo ausearch -k identity -i --start recent | tail -20
```
`-M` no home folder. `ausearch -k KEY` finds events by key; `-i` interprets numbers into names; `--start recent` = last 10 minutes.
```text
type=SYSCALL ... auid=student uid=root ... comm=useradd exe=/usr/sbin/useradd key=identity
```
`uid=root` (sudo made it root) but `auid=student`: the audit trail remembers **who logged in**.

```linux
sudo aureport -m --start today
```
Account-modification summary.

## Your task
1. Create `/etc/audit/rules.d/50-iam.rules` with the six watches and keys above.
2. Load the rules and confirm with `auditctl -l`.
3. Create and delete a test user, then find the events with `ausearch -k identity`.

## Verify
`sudo auditctl -l` lists six watches; `sudo ausearch -k identity -i --start today` shows events with `auid=student`. **Check my work** also changes a watched file itself and looks for the event.

## If it fails
- *rules not active*: run `sudo augenrules --load`. If it says `The audit system is in immutable mode`, rules can only change after a reboot (not set in this lab).
- *ausearch: <no matches>*: create the test user **after** loading the rules.
- *auditd not running*: `sudo systemctl status auditd`.

## Hints
### Hint 1
One file in `/etc/audit/rules.d/`, six lines, each `-w PATH -p wa -k KEY`.
### Hint 2
Load with `sudo augenrules --load`, check with `sudo auditctl -l`, search with `sudo ausearch -k identity -i`.
### Hint 3
Copy the six lines from "Concepts and commands" into `/etc/audit/rules.d/50-iam.rules`, then `sudo augenrules --load && sudo useradd -M audit-test-user && sudo userdel audit-test-user && sudo ausearch -k identity -i --start recent`.

## Walkthrough
```linux
sudo tee /etc/audit/rules.d/50-iam.rules > /dev/null <<'EOF'
## SEC-8002 identity and privilege changes
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/sudoers -p wa -k privilege
-w /etc/sudoers.d/ -p wa -k privilege
EOF
sudo augenrules --load
sudo auditctl -l
sudo useradd -M -s /usr/sbin/nologin audit-test-user
sudo userdel audit-test-user
sudo ausearch -k identity -i --start recent | grep -E 'SYSCALL' | tail -3
sudo aureport -m --start today
lab check m08-auditd
```
