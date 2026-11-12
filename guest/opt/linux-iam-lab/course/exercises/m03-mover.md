---
id: m03-mover
module: m03
title: Ben moves from Engineering to Web Operations (mover)
minutes: 20
prereqs: m03-inspect-identities
---
## Ticket
**HR-3003** - *Approved by: Head of Web Operations* - "Ben Tran (`btran`) transfers from Engineering to Web Operations effective today. Remove his Engineering role, give him the Web Operations role. He stays on Project Falcon and keeps remote access (`ssh-users`)."

## Objective
Change role membership without collateral damage, and prove the old access is gone and the new access works.

## Before you start
Linux terminal with `sudo`. Folders `/srv/lab03/engineering-design` (group `engineering`) and `/srv/lab03/webops-runbooks` (group `webops`) exist for testing.

## Concepts and commands
```linux
id btran
```
```text
uid=2003(btran) gid=2003(btran) groups=2003(btran),3003(engineering),3006(proj-falcon),3008(ssh-users)
```

```linux
sudo gpasswd -d btran engineering
```
`gpasswd -d USER GROUP` removes one user from one group and nothing else.
```text
Removing user btran from group engineering
```

```linux
sudo usermod -aG webops btran
```
`-G` sets supplementary groups; `-a` makes it **append**. Without `-a` the command replaces the whole list, silently removing `proj-falcon` and `ssh-users` too. `sudo gpasswd -a btran webops` does the same as `usermod -aG` for a single group.

```linux
sudo -u btran ls /srv/lab03/webops-runbooks
sudo -u btran ls /srv/lab03/engineering-design
```
Test both directions. A process started *before* the change keeps the old groups - that is why real users must log out and in again, and why leavers' sessions must be killed.

## Your task
1. Remove `btran` from `engineering`.
2. Add `btran` to `webops`.
3. Keep `proj-falcon` and `ssh-users`.
4. Prove: he can list `/srv/lab03/webops-runbooks` and can no longer list `/srv/lab03/engineering-design`.

## Verify
`id btran` and the two `sudo -u btran ls` tests. Then **Check my work**.

## If it fails
- *lost proj-falcon or ssh-users*: you used `usermod -G` without `-a`. Add them back: `sudo usermod -aG proj-falcon,ssh-users btran`.
- *still in engineering*: `sudo gpasswd -d btran engineering`.
- *webops folder still denied*: check `id btran` shows `webops`; check the folder with `ls -ld /srv/lab03/webops-runbooks`.

## Hints
### Hint 1
One command removes a single group membership, another appends one. Look at `gpasswd -d` and `usermod -aG`.
### Hint 2
Never use `usermod -G` without `-a` for a mover - it replaces the entire list.
### Hint 3
`sudo gpasswd -d btran engineering && sudo usermod -aG webops btran && id btran`.

## Walkthrough
```linux
id btran
sudo gpasswd -d btran engineering
sudo usermod -aG webops btran
id btran
```
```text
uid=2003(btran) gid=2003(btran) groups=2003(btran),3006(proj-falcon),3007(webops),3008(ssh-users)
```
```linux
sudo -u btran ls /srv/lab03/webops-runbooks
sudo -u btran ls /srv/lab03/engineering-design
```
```text
restart-falcon.md
ls: cannot open directory '/srv/lab03/engineering-design': Permission denied
```
```linux
lab check m03-mover
```
**Why it matters:** "privilege creep" - movers who keep every old role - is one of the most common access-review findings.
