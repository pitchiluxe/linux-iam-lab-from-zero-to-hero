---
id: m03-onboard
module: m03
title: Onboard a new finance analyst (joiner)
minutes: 25
prereqs: m03-inspect-identities
---
## Ticket
**HR-3002** - *Approved by: Amara Okafor (Finance Manager)* - "Fatima Garcia joins Finance as an analyst on Monday. Create her Linux account with the standard finance role. She is on probation until 31 Dec 2027, so the account must expire then unless renewed. Set a temporary password and make her choose her own at first login. No admin rights."

| Field | Value |
|---|---|
| Username | `fgarcia` |
| Comment (GECOS) | `Fatima Garcia - Finance Analyst` |
| Shell | `/bin/bash` |
| Home | `/home/fgarcia`, private (mode `750`) |
| Role groups | `finance` only |
| Account expiry | `2027-12-31` |
| Password | temporary, must be changed at first login |

## Objective
Create a user correctly the first time with `useradd`, set and expire a temporary password with `passwd` and `chage`, and prove the access works - and only that access.

## Before you start
Linux terminal; you need `sudo`. Group `finance` exists. Choose any temporary password (it is a fictional account). Never put real passwords in tickets or chat.

## Concepts and commands
```linux
sudo useradd -m -c "Fatima Garcia - Finance Analyst" -s /bin/bash -G finance -e 2027-12-31 fgarcia
```
- `-m` create the home folder (copied from `/etc/skel`).
- `-c` the comment / full name field (quote it: it contains spaces).
- `-s` login shell.
- `-G finance` supplementary group(s), comma-separated. The primary group `fgarcia` is created automatically.
- `-e YYYY-MM-DD` account expiry date.
No output means success. Errors look like `useradd: user 'fgarcia' already exists`.

```linux
sudo passwd fgarcia
```
Sets the password interactively (typed twice, not shown).
```text
New password:
Retype new password:
passwd: password updated successfully
```

```linux
sudo chage -d 0 fgarcia
sudo chage -l fgarcia
```
`chage -d 0` sets "last password change" to the beginning of time, so the password is treated as expired and must be changed at the next login. `chage -l` shows the result:
```text
Last password change                                    : password must be changed
Password expires                                        : password must be changed
Account expires                                         : Dec 31, 2027
```

```linux
sudo passwd -S fgarcia
ls -ld /home/fgarcia
```
`passwd -S` prints a status line; the 2nd field is `P` (usable password), `L` (locked) or `NP` (no password).
```text
fgarcia P 01/01/1970 0 99999 7 -1
drwxr-x--- 2 fgarcia fgarcia 4096 Nov 11 10:30 /home/fgarcia
```

```linux
sudo -u fgarcia cat /srv/finance/budget-2027.csv
sudo -u fgarcia ls /srv/hr
```
`sudo -u USER CMD` runs a command **as that user** - the standard way to test access. The first should work, the second must fail with `Permission denied`.

## Your task
1. Create `fgarcia` exactly as specified in the table.
2. Give her a temporary password and force a change at first login.
3. Test as `fgarcia`: she can read `/srv/finance/budget-2027.csv` and cannot list `/srv/hr`.

## Verify
`id fgarcia`, `getent passwd fgarcia`, `sudo chage -l fgarcia`, `sudo passwd -S fgarcia`, `ls -ld /home/fgarcia`, and the two `sudo -u fgarcia` tests. Then **Check my work**.

## If it fails
- *useradd: user already exists*: you ran it twice. Fix the existing account with `usermod` (same options) instead of deleting it.
- *Wrong comment*: `sudo usermod -c "Fatima Garcia - Finance Analyst" fgarcia`.
- *Not in finance*: `sudo usermod -aG finance fgarcia` (remember `-a`).
- *Expiry wrong*: `sudo chage -E 2027-12-31 fgarcia`.
- *Home mode not 750*: `sudo chmod 750 /home/fgarcia`.
- *password must be changed is missing*: run `sudo chage -d 0 fgarcia` **after** `passwd` (setting a password resets that date).
- Want to start over? **Retry exercise** deletes `fgarcia`.

## Hints
### Hint 1
One `useradd` command with five options can do almost everything in the table. Then two more commands handle the password.
### Hint 2
Options: `-m`, `-c "..."`, `-s /bin/bash`, `-G finance`, `-e 2027-12-31`. Then `sudo passwd fgarcia`, then `sudo chage -d 0 fgarcia` (order matters).
### Hint 3
`sudo useradd -m -c "Fatima Garcia - Finance Analyst" -s /bin/bash -G finance -e 2027-12-31 fgarcia && sudo passwd fgarcia && sudo chage -d 0 fgarcia`, then check `ls -ld /home/fgarcia` shows `drwxr-x---`.

## Walkthrough
```linux
sudo useradd -m -c "Fatima Garcia - Finance Analyst" -s /bin/bash -G finance -e 2027-12-31 fgarcia
sudo passwd fgarcia
sudo chage -d 0 fgarcia
sudo chmod 750 /home/fgarcia
id fgarcia
```
```text
uid=2010(fgarcia) gid=2010(fgarcia) groups=2010(fgarcia),3001(finance)
```
```linux
sudo chage -l fgarcia
sudo passwd -S fgarcia
sudo -u fgarcia cat /srv/finance/budget-2027.csv
sudo -u fgarcia ls /srv/hr
```
```text
cost_center,owner,amount
CC-100,aokafor,125000
CC-200,jkim,48000
ls: cannot open directory '/srv/hr': Permission denied
```
```linux
lab check m03-onboard
```
**Evidence for the ticket:** paste the `id`, `chage -l` and the two access tests (one allowed, one denied). Testing both directions is what separates "I created an account" from "I granted exactly the approved access".
