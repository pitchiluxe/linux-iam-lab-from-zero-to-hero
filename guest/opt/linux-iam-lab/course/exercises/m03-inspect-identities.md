---
id: m03-inspect-identities
module: m03
title: Answer an auditor's questions about accounts
minutes: 25
---
## Ticket
**IAM-3001** - *From: External auditor* - "Please confirm, from the server itself, the following facts about accounts on `iamlab01`. Answers in `~/lab/m03/identity-answers.txt`."

## Objective
Read `/etc/passwd`, `/etc/group` and `/etc/shadow` (with the right privilege), and use `id`, `getent` and `chage` to answer identity questions precisely.

## Before you start
Linux terminal. Some answers need `sudo` (reading `/etc/shadow` and `chage -l`). Type your own password when asked; it is not shown while you type.

## Concepts and commands
```linux
id btran
```
```text
uid=2003(btran) gid=2003(btran) groups=2003(btran),3003(engineering),3006(proj-falcon),3008(ssh-users)
```
`gid=` is the **primary** group; `groups=` lists the primary group first, then the **supplementary** groups.

```linux
getent passwd btran
getent group finance
```
`getent` asks the system's identity sources (local files *and* the directory, see module 7), so it is the right tool even when users do not live in `/etc/passwd`.
```text
btran:x:2003:2003:Ben Tran - Software Engineer:/home/btran:/bin/bash
finance:x:3001:aokafor,jkim
```
The last field of a group line lists its **supplementary** members.

```linux
ls -l /etc/shadow
sudo grep '^kwright:' /etc/shadow
sudo chage -l kwright
```
`ls -l` shows who may read the shadow file. `chage -l` turns the shadow numbers into dates:
```text
Last password change                                    : Nov 11, 2026
Password expires                                        : never
Account expires                                         : Dec 31, 2025
```

```linux
date -d "Dec 31, 2025" +%F
```
Converts a date to ISO format `YYYY-MM-DD` (`%F`).

## Your task
Create `~/lab/m03/identity-answers.txt`:
```text
btran_uid=<numeric UID of btran>
btran_primary_group=<name of btran's primary group>
btran_groups=<btran's SUPPLEMENTARY groups, sorted, comma-separated>
finance_members=<supplementary members of group finance, sorted, comma-separated>
kwright_expires=<kwright's account expiry date as YYYY-MM-DD>
svc_falcon_shell=<login shell of the service account svc-falcon>
shadow_readable_by_student=<yes or no: can student read /etc/shadow without sudo?>
```

## Verify
Re-run the commands and compare. **Check my work** recomputes every answer from the live system (so if you change accounts in later exercises, the answers change too).

## If it fails
- *btran_groups*: exclude the primary group `btran`; sort alphabetically; no spaces.
- *kwright_expires*: must be ISO format, e.g. `2025-12-31`.
- *shadow_readable_by_student*: try `cat /etc/shadow` without sudo and read the error.

## Hints
### Hint 1
`id btran` answers three questions. `getent group finance` answers one. `sudo chage -l kwright` answers one.
### Hint 2
`id -nG btran` prints only group names; drop the first one (primary) and sort the rest: `id -nG btran | tr ' ' '\n' | grep -vx btran | sort | paste -sd, -`.
### Hint 3
`getent passwd svc-falcon | cut -d: -f7` gives the shell. `cat /etc/shadow` as student says `Permission denied`, so the answer is `no`.

## Walkthrough
```linux
mkdir -p ~/lab/m03
id btran
id -nG btran | tr ' ' '\n' | grep -vx btran | sort | paste -sd, -
getent group finance
sudo chage -l kwright | grep 'Account expires'
date -d "Dec 31, 2025" +%F
getent passwd svc-falcon | cut -d: -f7
cat /etc/shadow
```
```text
cat: /etc/shadow: Permission denied
```
```linux
nano ~/lab/m03/identity-answers.txt
```
```text
btran_uid=2003
btran_primary_group=btran
btran_groups=engineering,proj-falcon,ssh-users
finance_members=aokafor,jkim
kwright_expires=2025-12-31
svc_falcon_shell=/usr/sbin/nologin
shadow_readable_by_student=no
```
```linux
lab check m03-inspect-identities
```
(Your values can differ if you already completed later exercises - always read the live system.)
