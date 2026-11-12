---
id: m05-sudo-review
module: m05
title: Who can run what as root?
minutes: 25
---
## Ticket
**AUD-5001** - *From: Internal Audit* - "Privileged access review for `iamlab01`: who are the full administrators, what can the helpdesk analyst Dev Patel run as root, and is any rule risky? Answers in `~/lab/m05/sudo-review.txt`."

## Objective
Enumerate sudo rights from group membership and rule files, query a user's rights with `sudo -l -U`, and recognise a privilege-escalation risk.

## Before you start
Linux terminal with `sudo`. This exercise only **reads**; the next one fixes what you find.

## Concepts and commands
```linux
getent group sudo
```
```text
sudo:x:27:student
```
Members of `sudo` match `%sudo ALL=(ALL:ALL) ALL` in `/etc/sudoers`.

```linux
sudo ls -l /etc/sudoers.d/
sudo cat /etc/sudoers.d/40-legacy-helpdesk
```
```text
# Legacy rule from 2019 - "helpdesk needs to edit hosts"
dpatel ALL=(root) NOPASSWD: /usr/bin/vim /etc/hosts
```

```linux
sudo -l -U dpatel
```
```text
User dpatel may run the following commands on iamlab01:
    (root) NOPASSWD: /usr/bin/vim /etc/hosts
```

**Why this is risky:** inside vim, `:!bash` starts a shell - *as root*. `vim` can also `:e /etc/shadow`. A rule for "edit one file" is really full root. The safe pattern is `sudoedit /etc/hosts` (it edits a temporary copy as the user).

## Your task
Create `~/lab/m05/sudo-review.txt`:
```text
sudo_group_members=<members of group sudo, comma-separated, sorted>
dpatel_command=<the program dpatel may run as root, full path, without arguments>
dpatel_needs_password=<yes or no>
risky_rule_file=<full path of the file that contains dpatel's rule>
why_risky=<a few words: why that rule is dangerous>
```

## Verify
Re-run `sudo -l -U dpatel` and `getent group sudo`. **Check my work** compares your answers to the live configuration.

## If it fails
- *sudo_group_members*: only the 4th field of `getent group sudo`.
- *dpatel_command*: just the program path, e.g. `/usr/bin/something`.
- *why_risky*: mention that the editor can start a shell / escape to root.

## Hints
### Hint 1
`getent group sudo` and `sudo -l -U dpatel` answer most questions. `NOPASSWD:` answers one.
### Hint 2
`sudo grep -l dpatel /etc/sudoers.d/*` tells you which file contains the rule.
### Hint 3
`dpatel_command=/usr/bin/vim`, `dpatel_needs_password=no`, `risky_rule_file=/etc/sudoers.d/40-legacy-helpdesk`, `why_risky=vim can run a shell escape as root`.

## Walkthrough
```linux
getent group sudo
sudo ls -l /etc/sudoers.d/
sudo grep -l dpatel /etc/sudoers.d/*
sudo -l -U dpatel
mkdir -p ~/lab/m05
cat > ~/lab/m05/sudo-review.txt <<'EOF'
sudo_group_members=student
dpatel_command=/usr/bin/vim
dpatel_needs_password=no
risky_rule_file=/etc/sudoers.d/40-legacy-helpdesk
why_risky=vim can run a shell escape (:!bash) as root, so the rule equals full root
EOF
lab check m05-sudo-review
```
