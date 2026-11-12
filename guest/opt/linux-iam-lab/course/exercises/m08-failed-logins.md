---
id: m08-failed-logins
module: m08
title: Investigate failed logins and a sudo denial
minutes: 25
start: yes
---
## Ticket
**SEC-8001** - *From: SOC* - "Our SIEM flagged `iamlab01`: repeated password failures and a blocked privileged command in the last hour. Find which account had the failed passwords, who tried to use sudo for something they are not allowed to, and what exactly they tried. Also confirm the lockout threshold. Answers in `~/lab/m08/investigation.txt`."

## Objective
Find authentication failures and sudo denials in `auth.log` and the journal, and extract exact facts for an incident ticket.

## Before you start
Linux terminal with `sudo`. **Start scenario** generates the events now (or `lab reset m08-failed-logins`).

## Concepts and commands
```linux
sudo grep 'authentication failure' /var/log/auth.log | tail -5
```
```text
2026-11-11T10:20:01 iamlab01 pamtester: pam_unix(sshd:auth): authentication failure; logname= uid=0 euid=0 tty= ruser= rhost=  user=aokafor
```
(The lab simulates the attempts with a PAM test tool, so the program name is `pamtester`; on a real server it would be `sshd`.)

```linux
sudo grep 'authentication failure' /var/log/auth.log | grep -oE 'user=[^ ]+' | sort | uniq -c | sort -rn
```
Counts failures per user - the pipeline skills from module 2.

```linux
sudo journalctl _COMM=sudo --since "1 hour ago" --no-pager | grep -iE 'not allowed|NOT in sudoers'
```
```text
sudo[3210]:   dpatel : command not allowed ; TTY=unknown ; PWD=/ ; USER=root ; COMMAND=/usr/bin/cat /etc/shadow
```
Format: `WHO : RESULT ; TTY ; PWD ; USER=target ; COMMAND=what`.

```linux
grep -E '^(deny|fail_interval|unlock_time)' /etc/security/faillock.conf
```

## Your task
Create `~/lab/m08/investigation.txt`:
```text
most_failed_user=<account with the most password failures in this scenario>
sudo_denied_user=<who was refused by sudo>
sudo_denied_command=<the exact command they tried, full path and arguments>
faillock_deny=<how many failures lock an account on this server>
```

## Verify
Re-check each fact in the log. **Check my work** compares with the generated events.

## If it fails
- *most_failed_user*: count only `authentication failure` lines; earlier exercises may have added other users' failures, so count, do not guess.
- *sudo_denied_command*: copy everything after `COMMAND=`.

## Hints
### Hint 1
Two searches: one for `authentication failure` (count per `user=`), one for `not allowed` in sudo's messages.
### Hint 2
The `COMMAND=` field holds the exact command. The threshold is the `deny` line in `/etc/security/faillock.conf`.
### Hint 3
In this scenario: `most_failed_user=aokafor`, `sudo_denied_user=dpatel`, `sudo_denied_command=/usr/bin/cat /etc/shadow`, `faillock_deny=5`.

## Walkthrough
```linux
sudo grep 'authentication failure' /var/log/auth.log | grep -oE 'user=[^ ]+' | sort | uniq -c | sort -rn | head -3
sudo journalctl _COMM=sudo --since "1 hour ago" --no-pager | grep -iE 'not allowed|NOT in sudoers'
grep '^deny' /etc/security/faillock.conf
mkdir -p ~/lab/m08
cat > ~/lab/m08/investigation.txt <<'EOF'
most_failed_user=aokafor
sudo_denied_user=dpatel
sudo_denied_command=/usr/bin/cat /etc/shadow
faillock_deny=5
EOF
lab check m08-failed-logins
```
**Next steps a SOC would expect:** was there a success after the failures (`grep 'Accepted\|session opened' ...`), is the account now locked (`faillock --user aokafor`), and does dpatel's manager know he tried to read password hashes?
