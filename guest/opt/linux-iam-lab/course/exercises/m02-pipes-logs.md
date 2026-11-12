---
id: m02-pipes-logs
module: m02
title: Count failed logins in last night's log
minutes: 25
prereqs: m01-files
---
## Ticket
**SEC-2001** - *From: Security Operations* - "We saw a spike of SSH failures on a server overnight. A copy of its auth log is in `/opt/lab-data/logs/auth-2026-11-10.log`. Tell us: how many failed password attempts were there, which username was tried most, which source IP was the noisiest, and which real users logged in successfully. Put the answers in `~/lab/m02/failed-logins.txt`."

## Objective
Answer access questions from a log with `grep`, `cut`/`awk`, `sort`, `uniq -c`, `wc -l`, pipes and redirection.

## Before you start
Linux terminal. The log is a fictional copy; IP addresses are from documentation ranges (`192.0.2.x`, `198.51.100.x`, `203.0.113.x`).

## Concepts and commands
```linux
LOG=/opt/lab-data/logs/auth-2026-11-10.log
head -5 "$LOG"
```
`LOG=...` stores the path in a shell variable so you do not retype it. `head -5` shows the first 5 lines. Typical lines:
```text
Nov 10 01:02:11 web01 sshd[2101]: Failed password for root from 203.0.113.45 port 50122 ssh2
Nov 10 01:02:15 web01 sshd[2103]: Failed password for invalid user oracle from 198.51.100.7 port 40022 ssh2
Nov 10 08:01:44 web01 sshd[3001]: Accepted publickey for btran from 192.0.2.10 port 50100 ssh2: ED25519 SHA256:...
```
Note the two shapes of failure: a real account (`for root`) and a non-existent one (`for invalid user oracle`). That shifts the word positions, so counting "the 9th word" is not reliable.

```linux
grep -c "Failed password" "$LOG"
```
`-c` counts matching lines instead of printing them.

```linux
grep "Failed password" "$LOG" | grep -oE 'for (invalid user )?[^ ]+' | awk '{print $NF}' | sort | uniq -c | sort -rn | head -3
```
- `grep -oE '...'` prints only the matched part, using an extended regular expression. `(invalid user )?` means "optionally this text"; `[^ ]+` means "one or more non-space characters".
- `awk '{print $NF}'` prints the last word (`NF` = number of fields), which is the username.
- `sort | uniq -c` counts each distinct name; `sort -rn` puts the biggest count first.
```text
     41 root
     12 oracle
      8 admin
```

```linux
grep "Accepted" "$LOG" | awk '{print $9}' | sort -u
```
For `Accepted ... for USER from ...` lines the username is always word 9. `sort -u` sorts and removes duplicates.

```linux
mkdir -p ~/lab/m02
echo "total_failed=57" > ~/lab/m02/failed-logins.txt
echo "top_user=root" >> ~/lab/m02/failed-logins.txt
```
`>` creates/replaces the file, `>>` appends. (These numbers are only examples.)

## Your task
Create `~/lab/m02/failed-logins.txt` with:
```text
total_failed=<number of "Failed password" lines>
top_user=<username with the most failed passwords>
top_ip=<source IP with the most failed passwords>
accepted_users=<users with an "Accepted" login, sorted, comma-separated, e.g. alice,bob>
```

## Verify
`cat ~/lab/m02/failed-logins.txt`, re-run your pipelines and compare. Then **Check my work**.

## If it fails
- *total_failed is wrong*: make sure you search for exactly `Failed password` (capital F) and count with `-c` or `wc -l`.
- *top_user is wrong*: did you handle `invalid user NAME` lines? Print the usernames before counting to see what you are counting.
- *top_ip is wrong*: extract the address after `from`, not the port.
- *accepted_users*: commas, no spaces, alphabetical.

## Hints
### Hint 1
Build pipelines step by step: run `grep "Failed password" "$LOG" | head` first, then add one command at a time and look at the output.
### Hint 2
For IPs: `grep "Failed password" "$LOG" | grep -oE 'from [0-9.]+' | sort | uniq -c | sort -rn | head -1`. For accepted users, `paste -sd, -` joins lines with commas.
### Hint 3
Usernames: `grep "Failed password" "$LOG" | grep -oE 'for (invalid user )?[^ ]+' | awk '{print $NF}' | sort | uniq -c | sort -rn | head -1`. Accepted: `grep Accepted "$LOG" | awk '{print $9}' | sort -u | paste -sd, -`.

## Walkthrough
```linux
LOG=/opt/lab-data/logs/auth-2026-11-10.log
mkdir -p ~/lab/m02
TOTAL=$(grep -c "Failed password" "$LOG")
TOPUSER=$(grep "Failed password" "$LOG" | grep -oE 'for (invalid user )?[^ ]+' | awk '{print $NF}' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
TOPIP=$(grep "Failed password" "$LOG" | grep -oE 'from [0-9.]+' | awk '{print $2}' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
ACCEPTED=$(grep "Accepted" "$LOG" | awk '{print $9}' | sort -u | paste -sd, -)
printf 'total_failed=%s\ntop_user=%s\ntop_ip=%s\naccepted_users=%s\n' "$TOTAL" "$TOPUSER" "$TOPIP" "$ACCEPTED" > ~/lab/m02/failed-logins.txt
cat ~/lab/m02/failed-logins.txt
lab check m02-pipes-logs
```
`$(command)` runs a command and substitutes its output. `printf` writes the four lines in one go.

**Why it matters:** "which accounts are being attacked, from where, and did anyone get in" is the first question in every authentication incident.
