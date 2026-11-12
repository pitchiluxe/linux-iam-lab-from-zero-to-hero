---
id: m04-permissions
module: m04
title: The payroll file is readable by everyone
minutes: 20
---
## Ticket
**FIN-4001** - *From: Amara Okafor (Finance Manager)* - "`/srv/lab04/payroll-2026-11.csv` was copied to the server by root and **anyone** can read it. I own this data. I must be able to edit it, my finance team may read it, nobody else may see it."

## Objective
Fix ownership and permissions with `chown` and `chmod`, then prove the result as three different users.

## Before you start
Linux terminal with `sudo`. Users: `aokafor` (owner, finance), `jkim` (finance), `btran` (not finance).

## Concepts and commands
```linux
ls -l /srv/lab04/payroll-2026-11.csv
```
```text
-rw-r--r-- 1 root root 96 Nov 11 10:00 /srv/lab04/payroll-2026-11.csv
```
Owner `root`, group `root`, and `r--` for others: everyone can read.

```linux
sudo chown aokafor:finance /srv/lab04/payroll-2026-11.csv
```
`chown OWNER:GROUP FILE` - changes both at once. Only root can give a file away.

```linux
sudo chmod 640 /srv/lab04/payroll-2026-11.csv
```
`6` = `rw-` for the owner, `4` = `r--` for the group, `0` = `---` for others. Symbolic equivalent: `chmod u=rw,g=r,o= FILE`.

```linux
sudo -u jkim cat /srv/lab04/payroll-2026-11.csv
sudo -u btran cat /srv/lab04/payroll-2026-11.csv
```
```text
cat: /srv/lab04/payroll-2026-11.csv: Permission denied
```
The second must be denied.

```linux
sudo -u jkim sh -c 'echo test >> /srv/lab04/payroll-2026-11.csv'
```
Tests **write** access as jkim (it should be denied). `sh -c '...'` is needed so the `>>` redirection runs as jkim, not as you.

## Your task
1. Owner `aokafor`, group `finance`.
2. Owner read+write, group read only, others nothing.
3. Prove: aokafor can read and write; jkim can read but not write; btran cannot read.

## Verify
`ls -l` should show `-rw-r----- 1 aokafor finance`. Run the tests above. **Check my work** runs them for you.

## If it fails
- *`chown: changing ownership ... Operation not permitted`*: you forgot `sudo`.
- *jkim denied reading*: is jkim in finance (`id jkim`)? Is the group `finance`?
- *btran can read*: others still have `r` - remove it (`chmod o-r`).

## Hints
### Hint 1
Two commands: one changes owner and group, one changes the mode.
### Hint 2
The mode is three digits: owner rw (4+2), group r (4), others none (0).
### Hint 3
`sudo chown aokafor:finance /srv/lab04/payroll-2026-11.csv && sudo chmod 640 /srv/lab04/payroll-2026-11.csv`.

## Walkthrough
```linux
ls -l /srv/lab04/payroll-2026-11.csv
sudo chown aokafor:finance /srv/lab04/payroll-2026-11.csv
sudo chmod 640 /srv/lab04/payroll-2026-11.csv
ls -l /srv/lab04/payroll-2026-11.csv
sudo -u aokafor cat /srv/lab04/payroll-2026-11.csv
sudo -u jkim cat /srv/lab04/payroll-2026-11.csv
sudo -u jkim sh -c 'echo test >> /srv/lab04/payroll-2026-11.csv'
sudo -u btran cat /srv/lab04/payroll-2026-11.csv
lab check m04-permissions
```
```text
-rw-r----- 1 aokafor finance 96 Nov 11 10:00 /srv/lab04/payroll-2026-11.csv
sh: 1: cannot create /srv/lab04/payroll-2026-11.csv: Permission denied
cat: /srv/lab04/payroll-2026-11.csv: Permission denied
```
