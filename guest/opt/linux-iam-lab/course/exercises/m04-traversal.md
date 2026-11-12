---
id: m04-traversal
module: m04
title: Ben can't open the Falcon spec (directory traversal)
minutes: 20
prereqs: m04-permissions
---
## Ticket
**ENG-4002** - *From: Ben Tran* - "I'm on Project Falcon but `cat /srv/lab04/falcon/specs/spec-v2.txt` says Permission denied. The file itself looks fine?!" - *Note from the data owner:* only `proj-falcon` members may get in; Dev from Helpdesk (`dpatel`) must stay out.

## Objective
Diagnose a "Permission denied" that is caused by a **directory** in the path, using `namei -l`, and fix it without opening access to others.

## Before you start
Linux terminal with `sudo`. `btran` is in `proj-falcon`; `dpatel` is not.

## Concepts and commands
```linux
sudo -u btran cat /srv/lab04/falcon/specs/spec-v2.txt
```
```text
cat: /srv/lab04/falcon/specs/spec-v2.txt: Permission denied
```

```linux
namei -l /srv/lab04/falcon/specs/spec-v2.txt
```
`namei` walks the path one component at a time; `-l` shows each one's permissions and owners. Read it top to bottom as btran: which step does not grant him `x` (directories) or `r` (the file)?
```text
f: /srv/lab04/falcon/specs/spec-v2.txt
drwxr-xr-x root root        /
drwxr-xr-x root root        srv
drwxr-xr-x root root        lab04
drwxrw---- root proj-falcon falcon
drwxrws--- root proj-falcon specs
-rw-r----- root proj-falcon spec-v2.txt
```
`falcon` gives the group `rw-` but **no `x`**: btran can see the names inside but cannot pass through.

```linux
sudo chmod g+x /srv/lab04/falcon
```
Adds only the group execute (traverse) bit. Others stay at `---`.

```linux
stat -c '%A %a %U:%G %n' /srv/lab04/falcon
```
`stat -c` prints chosen fields: symbolic mode, octal mode, owner:group, name.

## Your task
1. Find which path component blocks `btran`.
2. Fix it so proj-falcon members can read `spec-v2.txt`.
3. Do not give anything to "others": `dpatel` must still be denied.

## Verify
`sudo -u btran cat ...` works; `sudo -u dpatel cat ...` is denied. **Check my work**.

## If it fails
- *dpatel can read too*: you added permissions for others (`o+x`/`o+r`). Remove them: `sudo chmod o-rwx /srv/lab04/falcon`.
- *still denied for btran*: run `namei -l` again and check every directory has `x` for the group, and that `id btran` lists `proj-falcon`.

## Hints
### Hint 1
The file's own permissions are fine. Look at the folders above it with `namei -l`.
### Hint 2
On a directory, `r` lists names but `x` is what lets you go through it. One folder is missing `x` for its group.
### Hint 3
`sudo chmod g+x /srv/lab04/falcon`.

## Walkthrough
```linux
sudo -u btran cat /srv/lab04/falcon/specs/spec-v2.txt
namei -l /srv/lab04/falcon/specs/spec-v2.txt
sudo chmod g+x /srv/lab04/falcon
namei -l /srv/lab04/falcon/specs/spec-v2.txt
sudo -u btran cat /srv/lab04/falcon/specs/spec-v2.txt
sudo -u dpatel cat /srv/lab04/falcon/specs/spec-v2.txt
lab check m04-traversal
```
```text
Falcon spec v2 (fictional)
cat: /srv/lab04/falcon/specs/spec-v2.txt: Permission denied
```
**Why it matters:** many "access broken" tickets are a single missing `x` on a parent folder. Fix the narrowest thing; never "fix" it with `chmod -R 777`.
