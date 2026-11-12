---
id: m05-lockout-recovery
module: m05
title: Sudo broke after a bad edit - recover and fix it
minutes: 25
prereqs: m05-delegate
start: yes
---
## Ticket
**SEC-5003** - *From: Change Advisory Board* - "A colleague added a rule for Internal Audit by editing `/etc/sudoers.d/60-auditors-logs` with a normal editor. Since then `sudo` prints errors. Restore a valid policy and implement what they intended: members of `auditors` may run **exactly** `journalctl -u ssh.service --no-pager` as root."

## Objective
Recognise and locate a sudoers syntax error, recover safely (including the break-glass path if sudo refuses to work), and implement the intended rule correctly with `visudo`.

## Before you start
This exercise **breaks sudo on purpose**. Press **Start scenario** (or run `lab reset m05-lockout-recovery`) to create the faulty file. Open a second Linux terminal tab as a safety net (the portal's "pop out" link, or `ssh linux-iam-lab` from Windows Terminal).

## Concepts and commands
```linux
sudo -v
```
`-v` just refreshes your sudo credentials - a harmless way to test sudo.
```text
>>> /etc/sudoers.d/60-auditors-logs: syntax error near line 2 <<<
sudo: parse error in /etc/sudoers.d/60-auditors-logs near line 2
```
Depending on the sudo version, sudo then either continues without the broken rule or refuses to run at all.

```linux
sudo visudo -c
```
Lists every file and marks the broken one.

```linux
sudo visudo -f /etc/sudoers.d/60-auditors-logs
```
Opens the file safely. Find the mistake, fix it, save; visudo re-checks before writing.

```linux
lab rescue sudoers
```
**Break-glass** (only if `sudo` itself refuses to run): the lab agent - standing in for "console access as root" - runs `visudo -c` on every file and moves invalid ones to `/var/lib/linux-iam-lab/quarantine/`. Everything it does is logged. After that, re-create the intended rule properly.

```linux
sudo -l -U rmorgan /usr/bin/journalctl -u ssh.service --no-pager; echo "exit $?"
sudo -l -U rmorgan /usr/bin/journalctl; echo "exit $?"
```
The first must print the command and exit 0; the second (no arguments = the whole journal) must exit 1.

## Your task
1. Start the scenario, observe the error, find the faulty file and line.
2. Recover: fix it with `visudo -f` (preferred) or use the break-glass path if sudo does not work.
3. Make sure `/etc/sudoers.d/60-auditors-logs` exists, is valid, mode `0440`, and allows `%auditors` to run exactly `/usr/bin/journalctl -u ssh.service --no-pager` as root (with password).

## Verify
`sudo visudo -c` parses OK, `sudo -v` is silent, and the two `sudo -l -U rmorgan` tests behave as described. **Check my work** also runs the command as `rmorgan` with his password.

## If it fails
- *still a syntax error*: compare brackets: `ALL=(root) /usr/bin/...` - every `(` needs a `)`.
- *rmorgan may run journalctl with any arguments*: you dropped the arguments; list them exactly.
- *file missing after rescue*: rescue moves broken files away; re-create the rule with `sudo visudo -f /etc/sudoers.d/60-auditors-logs`.

## Hints
### Hint 1
`sudo visudo -c` names the file and line. Open exactly that file with `sudo visudo -f`.
### Hint 2
Look at the part after `ALL=`. The "run as" user must be in brackets: `(root)`.
### Hint 3
Correct line: `%auditors ALL=(root) /usr/bin/journalctl -u ssh.service --no-pager`.

## Walkthrough
```linux
lab reset m05-lockout-recovery
sudo -v
sudo visudo -c
sudo visudo -f /etc/sudoers.d/60-auditors-logs
```
The file contains:
```text
# AUD-5003: auditors may read the SSH service log
%auditors ALL=(root /usr/bin/journalctl -u ssh.service --no-pager
```
Change the second line to:
```text
%auditors ALL=(root) /usr/bin/journalctl -u ssh.service --no-pager
```
Save and exit, then:
```linux
sudo visudo -c
ls -l /etc/sudoers.d/60-auditors-logs
sudo -l -U rmorgan /usr/bin/journalctl -u ssh.service --no-pager; echo "exit $?"
sudo -l -U rmorgan /usr/bin/journalctl; echo "exit $?"
lab check m05-lockout-recovery
```
If `sudo` refused to run at all: `lab rescue sudoers`, then `sudo visudo -f /etc/sudoers.d/60-auditors-logs` and type the corrected two lines.

**Lesson:** never edit sudoers files with a plain editor, always keep a second root session open while changing privileged access, and know your break-glass procedure *before* you need it.
