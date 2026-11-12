---
id: m02-find-files
module: m02
title: Find risky files on the shared drive
minutes: 20
prereqs: m02-pipes-logs
---
## Ticket
**SEC-2002** - *From: Internal Audit* - "Before the quarterly review, list (1) every file under `/srv/lab02/share` that **anyone** on the server can modify, and (2) every file there whose owner account **no longer exists**. Save the lists, one absolute path per line, sorted, in `~/lab/m02/world-writable.txt` and `~/lab/m02/orphans.txt`."

## Objective
Use `find` with permission and ownership tests, sort its output and save it with redirection.

## Before you start
Linux terminal. `/srv/lab02/share` is readable by everyone, so no `sudo` is needed.

## Concepts and commands
```linux
ls -l /srv/lab02/share/reports
```
```text
-rw-rw-rw- 1 btran  btran  44 Nov 11 10:00 q3-summary.txt
-rw-r--r-- 1   2999   2999 51 Nov 11 10:00 vendor-contacts.csv
```
The last `w` in `rw-rw-rw-` means **others** (everyone) can write. A **number instead of a name** in the owner column means the UID has no account any more: an *orphaned* file. Orphans are an audit finding because a new account that later receives UID 2999 would silently own them.

```linux
find /srv/lab02/share -type f -perm -o+w
```
- `-type f` regular files only (not folders).
- `-perm -o+w` files where the "others write" bit is set. The leading `-` means "at least these bits", so `666` and `777` both match.
```text
/srv/lab02/share/reports/q3-summary.txt
/srv/lab02/share/tmp/upload.sh
```

```linux
find /srv/lab02/share -type f -nouser
```
`-nouser` matches files whose owner UID is not in the account database (`-nogroup` does the same for groups).

```linux
find /srv/lab02/share -type f -perm -o+w | sort > ~/lab/m02/world-writable.txt
```
Pipe to `sort` for a stable order, then `>` to save. `wc -l FILE` counts the lines.

```linux
find /srv/lab02/share -type f -perm -o+w -ls
```
`-ls` prints details like `ls -l` - useful for the report.

## Your task
1. `~/lab/m02/world-writable.txt`: absolute paths of all **regular files** under `/srv/lab02/share` that are writable by others, sorted, one per line.
2. `~/lab/m02/orphans.txt`: absolute paths of all **regular files** under `/srv/lab02/share` whose owner does not exist, sorted, one per line.
Do not change the files - this is an investigation only.

## Verify
`cat` both files and spot-check a few entries with `ls -l`. Then **Check my work**.

## If it fails
- *extra entries*: you forgot `-type f` and listed folders too.
- *missing entries*: start `find` at `/srv/lab02/share`, not a subfolder.
- *relative paths*: start the search with the absolute path so the output is absolute.
- *the file changed permissions*: you were asked not to fix them yet. Press **Retry exercise**.

## Hints
### Hint 1
Two `find` commands, both starting at `/srv/lab02/share` with `-type f`. One test checks a permission bit, the other checks ownership.
### Hint 2
`-perm -o+w` finds files writable by others; `-nouser` finds files with no owner account.
### Hint 3
`find /srv/lab02/share -type f -perm -o+w | sort > ~/lab/m02/world-writable.txt` and `find /srv/lab02/share -type f -nouser | sort > ~/lab/m02/orphans.txt`.

## Walkthrough
```linux
mkdir -p ~/lab/m02
find /srv/lab02/share -type f -perm -o+w -ls
find /srv/lab02/share -type f -perm -o+w | sort > ~/lab/m02/world-writable.txt
find /srv/lab02/share -type f -nouser -ls
find /srv/lab02/share -type f -nouser | sort > ~/lab/m02/orphans.txt
wc -l ~/lab/m02/world-writable.txt ~/lab/m02/orphans.txt
lab check m02-find-files
```
In a real review you would now open a remediation ticket: remove the world-write bit (`chmod o-w`) and reassign orphans to the data owner (`chown`), which module 4 teaches.
