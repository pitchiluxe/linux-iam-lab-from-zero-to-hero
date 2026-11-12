---
id: m08-access-report
module: m08
title: Script a repeatable access report
minutes: 45
prereqs: m02-bash-script
---
## Ticket
**AUD-8003** - *From: Internal Audit* - "We want the same access report every month, produced by a script, not by hand. Write `~/bin/access-report.sh`. Run with sudo, it writes a CSV of every **human** local account (UID 1000-59999) to a new timestamped file in the folder given as its first argument (default `~/reports`), updates `access-report-latest.csv` there, and prints the path of the new report. It must never change the system and must be safe to run again and again."

CSV header, exactly:
```text
user,uid,primary_group,groups,shell,password_status,account_expires,sudo
```
| Column | Value |
|---|---|
| `groups` | supplementary groups, sorted, separated by `;` (a comma would break the CSV) |
| `password_status` | 2nd field of `passwd -S`: `P`, `L` or `NP` |
| `account_expires` | `never`, or the date as `YYYY-MM-DD` |
| `sudo` | `yes` if `sudo -l -U USER` lists any rule for the user, else `no` |

## Objective
Write a robust, read-only, rerunnable Bash script that turns identity data into audit evidence.

## Before you start
Linux terminal with `sudo`. Review module 2 (scripts) and module 3 (identity files). This is the longest exercise so far - build it step by step.

## Concepts and commands
```linux
getent passwd | awk -F: '$3>=1000 && $3<60000 {print $1}'
```
Human accounts by UID range. `getent` (not `cat /etc/passwd`) so directory users configured to enumerate would be included too.

```linux
sudo passwd -S btran | awk '{print $2}'
sudo chage -l kwright | awk -F': ' '/Account expires/ {print $2}'
date -d "Dec 31, 2025" +%F
```
```text
P
Dec 31, 2025
2025-12-31
```

```linux
sudo -l -U dpatel >/dev/null 2>&1; sudo -l -U dpatel | grep -q 'may run the following' && echo yes || echo no
```
`sudo -l -U` prints `User X may run the following commands` when the user has any rule, or `User X is not allowed to run sudo` otherwise.

```linux
id -nG btran | tr ' ' '\n' | grep -vx "$(id -gn btran)" | sort | paste -sd';' -
```
Supplementary groups joined with `;`.

A skeleton to start from:
```linux
#!/usr/bin/env bash
# access-report.sh - AUD-8003 monthly local access report (read-only)
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }
outdir="${1:-$HOME/reports}"
mkdir -p "$outdir"
out="$outdir/access-report-$(date +%Y%m%d-%H%M%S).csv"
echo "user,uid,primary_group,groups,shell,password_status,account_expires,sudo" > "$out"
getent passwd | awk -F: '$3>=1000 && $3<60000' | sort -t: -k1,1 | while IFS=: read -r user _ uid gid _ _ shell; do
  # ... compute each column here ...
  echo "$user,$uid,..." >> "$out"
done
cp "$out" "$outdir/access-report-latest.csv"
echo "$out"
```
- `while IFS=: read -r ...` splits each passwd line into variables; `_` throws away fields you do not need.
- With sudo, `$HOME` is still `/home/student` on Ubuntu, so the default lands in your home.

## Your task
1. Complete `~/bin/access-report.sh` to the specification. Make it executable.
2. Run it twice with `sudo`; you should get two timestamped files and one `latest` copy.
3. Read the CSV. Do you spot anything a reviewer should question?

## Verify
```linux
sudo ~/bin/access-report.sh ~/reports
column -s, -t ~/reports/access-report-latest.csv | less -S
```
**Check my work** runs your script twice into a temporary folder and compares every row with the live system, and confirms the script changed nothing.

## If it fails
- *header mismatch*: copy the header exactly; no spaces.
- *row wrong for kwright*: expiry must be `2025-12-31`, not `Dec 31, 2025`.
- *script modified the system*: the check hashes `/etc/passwd`, `/etc/group`, `/etc/shadow` before and after - do not call `usermod`, `chage -E`, etc.
- *second run overwrote the first*: include seconds in the timestamp (`%H%M%S`).
- *`sudo: unable to execute ... Permission denied`*: `chmod +x ~/bin/access-report.sh`.

## Hints
### Hint 1
Start from the skeleton; add one column at a time and run the script after each change.
### Hint 2
Per user: `primary=$(id -gn "$user")`, `groups=$(id -nG "$user" | tr ' ' '\n' | grep -vx "$primary" | sort | paste -sd';' -)`, `pw=$(passwd -S "$user" | awk '{print $2}')`, `exp=$(chage -l "$user" | awk -F': ' '/Account expires/ {print $2}')` then convert unless it is `never`.
### Hint 3
For sudo: `if sudo -l -U "$user" 2>/dev/null | grep -q 'may run the following'; then s=yes; else s=no; fi`. The full script is in the Walkthrough.

## Walkthrough
```linux
mkdir -p ~/bin
cat > ~/bin/access-report.sh <<'EOF'
#!/usr/bin/env bash
# access-report.sh - AUD-8003 monthly local access report. Read-only; safe to rerun.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "access-report: run with sudo" >&2; exit 1; }
outdir="${1:-$HOME/reports}"
mkdir -p "$outdir"
out="$outdir/access-report-$(date +%Y%m%d-%H%M%S).csv"
echo "user,uid,primary_group,groups,shell,password_status,account_expires,sudo" > "$out"
getent passwd | awk -F: '$3>=1000 && $3<60000' | sort -t: -k1,1 | while IFS=: read -r user _ uid _ _ _ shell; do
  primary=$(id -gn "$user")
  groups=$(id -nG "$user" | tr ' ' '\n' | grep -vx "$primary" | sort | paste -sd';' - || true)
  pw=$(passwd -S "$user" | awk '{print $2}')
  exp=$(chage -l "$user" | awk -F': ' '/Account expires/ {print $2}')
  [ "$exp" = "never" ] || exp=$(date -d "$exp" +%F)
  if sudo -l -U "$user" 2>/dev/null | grep -q 'may run the following'; then s=yes; else s=no; fi
  echo "$user,$uid,$primary,$groups,$shell,$pw,$exp,$s" >> "$out"
done
cp "$out" "$outdir/access-report-latest.csv"
echo "$out"
EOF
chmod +x ~/bin/access-report.sh
sudo ~/bin/access-report.sh ~/reports
sleep 1; sudo ~/bin/access-report.sh ~/reports
ls -l ~/reports
column -s, -t ~/reports/access-report-latest.csv
lab check m08-access-report
```
Things a reviewer should question: `kwright` (expired contractor) still exists, `student` is a full admin, which accounts have `sudo=yes`, any account with `NP` (no password).

The files are owned by root (the script ran with sudo); `sudo chown -R student: ~/reports` if you want to edit them.
