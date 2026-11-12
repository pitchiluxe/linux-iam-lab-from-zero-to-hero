---
id: m04-shared-dir
module: m04
title: Build a shared folder for the finance team
minutes: 30
prereqs: m04-permissions
---
## Ticket
**FIN-4003** - *Approved by: Finance Manager* - "Create `/srv/finance-team` where everyone in `finance` can create files and edit **each other's** files. Nobody outside finance may even list it. Last time we tried, Jae couldn't edit Amara's files."

## Objective
Combine group ownership, the **setgid** bit and a **default ACL** so collaboration works regardless of each user's `umask`; test it as two finance members and one outsider.

## Before you start
Linux terminal with `sudo`. Finance members: `aokafor`, `jkim`. Outsider: `btran`.

## Concepts and commands
```linux
sudo mkdir /srv/finance-team
sudo chown root:finance /srv/finance-team
sudo chmod 2770 /srv/finance-team
ls -ld /srv/finance-team
```
```text
drwxrws--- 2 root finance 4096 Nov 11 10:00 /srv/finance-team
```
`2770`: owner and group get `rwx`, others nothing, and the leading `2` sets **setgid** - shown as `s` in the group triplet. New files inside will belong to group `finance` instead of the creator's own private group.

Why that is not enough: users have `umask 022`, so a new file is `rw-r--r--` - the group can read but **not write**. That is the "Jae couldn't edit" bug.

```linux
sudo setfacl -d -m g:finance:rwX /srv/finance-team
getfacl /srv/finance-team
```
`-d` sets a **default ACL**: every new file and folder created inside inherits it, and the creator's umask no longer strips the group's write bit. `rwX`: read, write, and execute only for directories.
```text
# file: srv/finance-team
# owner: root
# group: finance
# flags: -s-
user::rwx
group::rwx
other::---
default:user::rwx
default:group::rwx
default:group:finance:rwx
default:mask::rwx
default:other::---
```

```linux
sudo -u aokafor sh -c 'echo "draft" > /srv/finance-team/forecast.txt'
ls -l /srv/finance-team/forecast.txt
sudo -u jkim sh -c 'echo "edited by jkim" >> /srv/finance-team/forecast.txt'
sudo -u btran ls /srv/finance-team
```
Create as one member, edit as another, list as an outsider.

## Your task
1. Create `/srv/finance-team` owned by `root:finance`, mode `2770`.
2. Make sure files created inside by any finance member are writable by the other members (default ACL).
3. Test: aokafor creates a file, jkim appends to it, btran cannot list the folder. Clean up your test files afterwards if you like.

## Verify
`ls -ld`, `getfacl`, and the three tests. **Check my work** repeats the tests with new files.

## If it fails
- *new file has group aokafor*: the setgid bit is missing (`chmod g+s`).
- *jkim cannot append*: the default ACL is missing - `getfacl` must show `default:group:finance:rwx`.
- *btran can list*: others have permissions; `chmod o-rwx`.

## Hints
### Hint 1
Three ingredients: the right group owner, the setgid bit on the folder, and a default ACL.
### Hint 2
`chmod 2770` gives the setgid bit plus rwx for owner and group. `setfacl -d -m g:finance:rwX DIR` handles the write bit for future files.
### Hint 3
`sudo mkdir -p /srv/finance-team && sudo chown root:finance /srv/finance-team && sudo chmod 2770 /srv/finance-team && sudo setfacl -d -m g:finance:rwX /srv/finance-team`.

## Walkthrough
```linux
sudo mkdir -p /srv/finance-team
sudo chown root:finance /srv/finance-team
sudo chmod 2770 /srv/finance-team
sudo setfacl -d -m g:finance:rwX /srv/finance-team
getfacl /srv/finance-team
sudo -u aokafor sh -c 'echo draft > /srv/finance-team/forecast.txt'
sudo ls -l /srv/finance-team
sudo -u jkim sh -c 'echo "edited by jkim" >> /srv/finance-team/forecast.txt'
sudo -u btran ls /srv/finance-team
lab check m04-shared-dir
```
```text
-rw-rw----+ 1 aokafor finance 6 Nov 11 10:05 forecast.txt
ls: cannot open directory '/srv/finance-team': Permission denied
```
The `+` shows the file inherited an ACL; the group is `finance` thanks to setgid.
