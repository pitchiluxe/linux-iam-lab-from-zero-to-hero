---
id: m04-acl
module: m04
title: Read-only access for the auditor (ACLs)
minutes: 30
prereqs: m04-shared-dir
---
## Ticket
**AUD-4004** - *Approved by: Hana Lopez (HR Manager)* - "Internal Audit (Riley Morgan, `rmorgan`) needs **read-only** access to the performance reviews in `/srv/hr/reviews`, including reviews we add later, until the audit ends. Riley must **not** join the HR group and must not see anything else in `/srv/hr`."

## Objective
Grant a precise, individual exception with POSIX ACLs - including inheritance for future files and traverse-only access on the parent - and test it from both sides.

## Before you start
Linux terminal with `sudo`. `/srv/hr` and `/srv/hr/reviews` are `2770 root:hr`. HR staff: `hlopez`. Auditor: `rmorgan`. Outsider: `dpatel`.

## Concepts and commands
```linux
sudo -u rmorgan cat /srv/hr/reviews/2026-q4-reviews.txt
```
```text
cat: /srv/hr/reviews/2026-q4-reviews.txt: Permission denied
```

```linux
sudo setfacl -m u:rmorgan:--x /srv/hr
```
Traverse only: rmorgan can pass **through** `/srv/hr` to reach `reviews`, but cannot list `/srv/hr` or open other files there.

```linux
sudo setfacl -R -m u:rmorgan:rX /srv/hr/reviews
```
`-R` applies to the folder and everything already in it; `rX` = read, plus execute on directories only (so files do not become executable).

```linux
sudo setfacl -d -m u:rmorgan:rX /srv/hr/reviews
```
`-d` default ACL: files created later inherit read access for rmorgan.

```linux
getfacl /srv/hr/reviews
ls -l /srv/hr/reviews
```
```text
user::rwx
user:rmorgan:r-x
group::rwx
mask::rwx
other::---
default:user::rwx
default:user:rmorgan:r-x
default:group::rwx
default:mask::rwx
default:other::---
```
`ls -l` shows a `+` after the mode of entries that carry an ACL.

```linux
sudo setfacl -x u:rmorgan /srv/hr
```
For later: `-x` removes a single entry - how you revoke the access when the audit ends (`-R` and `-d` variants for the folder).

## Your task
1. rmorgan can read every existing file in `/srv/hr/reviews` and any **new** file created there later.
2. rmorgan cannot modify anything there.
3. rmorgan cannot list `/srv/hr` or read other HR files (for example `/srv/hr/salaries-2026.txt`).
4. rmorgan is **not** added to `hr`. HR staff keep their access; `dpatel` stays out.

## Verify
As rmorgan: `cat` a review (works), `ls /srv/hr` (denied), `cat /srv/hr/salaries-2026.txt` (denied), append to a review (denied). **Check my work** also creates a brand-new review as hlopez and reads it as rmorgan.

## If it fails
- *rmorgan cannot reach reviews*: the parent `/srv/hr` needs `x` for rmorgan.
- *rmorgan can list /srv/hr*: you gave `r` on `/srv/hr`; use `--x` only.
- *new reviews unreadable*: add the **default** ACL (`-d`).
- *rmorgan can write*: you granted `rw`; set `rX` instead (`setfacl -R -m u:rmorgan:rX ...`).

## Hints
### Hint 1
You need three ACL changes: one on `/srv/hr`, two on `/srv/hr/reviews` (current content and future content).
### Hint 2
Parent: `u:rmorgan:--x`. Reviews: `-R -m u:rmorgan:rX` and `-d -m u:rmorgan:rX`.
### Hint 3
`sudo setfacl -m u:rmorgan:--x /srv/hr && sudo setfacl -R -m u:rmorgan:rX /srv/hr/reviews && sudo setfacl -d -m u:rmorgan:rX /srv/hr/reviews`.

## Walkthrough
```linux
sudo setfacl -m u:rmorgan:--x /srv/hr
sudo setfacl -R -m u:rmorgan:rX /srv/hr/reviews
sudo setfacl -d -m u:rmorgan:rX /srv/hr/reviews
getfacl /srv/hr/reviews
sudo -u rmorgan cat /srv/hr/reviews/2026-q4-reviews.txt
sudo -u rmorgan ls /srv/hr
sudo -u rmorgan cat /srv/hr/salaries-2026.txt
sudo -u rmorgan sh -c 'echo x >> /srv/hr/reviews/2026-q4-reviews.txt'
id rmorgan
lab check m04-acl
```
```text
Q4 reviews (fictional)
ls: cannot open directory '/srv/hr': Permission denied
cat: /srv/hr/salaries-2026.txt: Permission denied
sh: 1: cannot create /srv/hr/reviews/2026-q4-reviews.txt: Permission denied
uid=2007(rmorgan) gid=2007(rmorgan) groups=2007(rmorgan),3005(auditors)
```
**Why it matters:** ACLs are precise but invisible in a plain `ls -l` (only a `+`). Access reviews must include `getfacl -R`, or exceptions like this one are never revoked.
