---
id: m05-delegate
module: m05
title: Let the helpdesk restart Falcon - nothing more
minutes: 30
prereqs: m05-sudo-review
---
## Ticket
**OPS-5002** - *Approved by: Head of IT Operations* - "The helpdesk team must be able to **restart** the falcon-web service and **view its status** outside office hours. Nothing else. Replace the legacy vim rule found in AUD-5001. Grant it to the helpdesk **group**, with their own password, so new helpdesk staff get it automatically."

## Objective
Write a least-privilege, command-scoped sudo rule with `visudo`, remove an over-broad one, notice which part of the request needs **no** sudo at all, and verify with both `sudo -l -U` and a real allowed/denied test.

## Before you start
Linux terminal with `sudo`. `dpatel` is the only member of `helpdesk`. Keep this terminal open while you work; if sudo breaks, see the module lesson ("If you lock yourself out").

## Concepts and commands
```linux
sudo visudo -f /etc/sudoers.d/50-helpdesk-falcon
```
Creates the file safely. Type the rule, save (`Ctrl+O`, Enter), exit (`Ctrl+X`). If you made a syntax error visudo asks *What now?* - press `e` to fix it.
```text
# OPS-5002: helpdesk may restart the Falcon web service only
Cmnd_Alias FALCON_OPS = /usr/bin/systemctl restart falcon-web.service
Defaults!FALCON_OPS noexec
%helpdesk ALL=(root) FALCON_OPS
```
- `Cmnd_Alias NAME = cmd1, cmd2` names a list of commands (alias names are UPPERCASE). It keeps the rule readable and lets you attach options to exactly those commands.
- Each command has its **exact arguments**, so `systemctl stop ...` or `systemctl restart sshd` do not match.
- No `NOPASSWD:` - people re-enter their own password, which also confirms it is really them.
- `Defaults!FALCON_OPS noexec` - defense in depth: the allowed command may not start other programs, so it cannot be turned into a shell.

**What about "view its status"?** It needs no sudo: any user can run `systemctl status falcon-web.service`. Putting it in the rule would make things *worse*: run as root, `systemctl status` opens a **pager** (`less`), and in `less` typing `!sh` starts a shell - as root. (Ubuntu 24.04's systemd switches to a "secure" pager under sudo, but older systems did not: CVE-2023-26604.) Part of least privilege is noticing when a request needs no privilege at all.
```linux
systemctl status falcon-web.service --no-pager
```
Run it as yourself, without sudo: it works. The helpdesk does the same.

```linux
sudo rm /etc/sudoers.d/40-legacy-helpdesk
sudo visudo -c
ls -l /etc/sudoers.d/
```
`visudo -c` must report `parsed OK` for every file. Files should be `-r--r----- root root` (0440); visudo creates them that way.

```linux
sudo -l -U dpatel
sudo -l -U dpatel /usr/bin/systemctl stop falcon-web.service; echo "exit code $?"
```
```text
User dpatel may run the following commands on iamlab01:
    (root) /usr/bin/systemctl restart falcon-web.service
exit code 1
```
Exit code `1` with no output = not allowed.

## Your task
1. Remove the legacy rule `/etc/sudoers.d/40-legacy-helpdesk`.
2. Create `/etc/sudoers.d/50-helpdesk-falcon` with visudo granting group `helpdesk` exactly `systemctl restart falcon-web.service`, as root, **with** password.
3. Do **not** put `systemctl status` in the rule: it needs no sudo, and as root it opens a pager that can start a shell. Confirm dpatel can see the status without sudo.
4. Confirm `sudo visudo -c` passes and check dpatel's rights.

## Verify
`sudo -l -U dpatel` shows exactly one command and no `NOPASSWD`. **Check my work** then logs in as dpatel with his password and really restarts the service (allowed), tries to stop it and to read `/etc/shadow` (both denied), confirms `systemctl status` is **not** in his sudo rights, and that he can see the status without sudo.

## If it fails
- *`>>> /etc/sudoers.d/50-helpdesk-falcon: syntax error near line N <<<`*: commas between commands, closing `)` after `root`, `\` must be the last character on its line.
- *dpatel still allowed vim*: the legacy file still exists.
- *restart denied*: the path must be `/usr/bin/systemctl` and the unit exactly `falcon-web.service` (users must type the same form: `sudo systemctl restart falcon-web.service`).
- *NOPASSWD found*: remove it; the ticket asks for password re-entry.
- *dpatel may run systemctl status as root*: take `status` out of the rule. It works without sudo, and as root it opens a pager.

## Hints
### Hint 1
Two changes: delete one file in `/etc/sudoers.d/`, create another with `sudo visudo -f`.
### Hint 2
A group rule starts with `%helpdesk`. Use the full path and exact arguments. Before you add "status" to it, try `systemctl status falcon-web.service` without sudo.
### Hint 3
File content: `%helpdesk ALL=(root) /usr/bin/systemctl restart falcon-web.service` - one command; status needs no sudo.

## Walkthrough
```linux
sudo rm /etc/sudoers.d/40-legacy-helpdesk
sudo visudo -f /etc/sudoers.d/50-helpdesk-falcon
```
Type:
```text
# OPS-5002: helpdesk may restart the Falcon web service only
# (status needs no sudo; as root it would open a pager that can start a shell)
Cmnd_Alias FALCON_OPS = /usr/bin/systemctl restart falcon-web.service
Defaults!FALCON_OPS noexec
%helpdesk ALL=(root) FALCON_OPS
```
```linux
sudo visudo -c
ls -l /etc/sudoers.d/
sudo -l -U dpatel
sudo -l -U dpatel /usr/bin/systemctl stop falcon-web.service; echo "exit code $?"
sudo -l -U dpatel /usr/bin/vim /etc/hosts; echo "exit code $?"
sudo -u dpatel systemctl status falcon-web.service --no-pager | head -3
lab check m05-delegate
```
```text
/etc/sudoers: parsed OK
/etc/sudoers.d/00-labctl: parsed OK
/etc/sudoers.d/50-helpdesk-falcon: parsed OK
```
**Evidence:** the rule file, `visudo -c`, `sudo -l -U dpatel`, and the check output showing one ALLOWED and two DENIED tests.
