---
id: m08-evidence
module: m08
title: Package evidence for the quarterly access review
minutes: 30
prereqs: m08-access-report
---
## Ticket
**AUD-8004** - *From: Internal Audit* - "For the Q4 access review of `iamlab01`, give us one archive `~/evidence/access-review-2026Q4.tar.gz` containing a folder `access-review-2026Q4/` with: the access report CSV, the sudo rules, the members of every role group, the SSH keys authorized for each user (fingerprints only), and a `SHA256SUMS` file so we can prove nothing was changed after collection."

Required files inside `access-review-2026Q4/`:
| File | Content |
|---|---|
| `access-report.csv` | output of your `access-report.sh` (module 8) |
| `sudo-rules.txt` | every effective sudo rule (from `/etc/sudoers` and `/etc/sudoers.d/`, comments removed) |
| `group-members.txt` | `getent group` lines for `finance hr engineering helpdesk auditors proj-falcon webops ssh-users sudo` |
| `ssh-keys.txt` | for each user with `~/.ssh/authorized_keys`: the user name and key fingerprints |
| `SHA256SUMS` | checksums of the four files above |

## Objective
Collect evidence reproducibly, protect its integrity with checksums, and package it.

## Before you start
Linux terminal with `sudo`. Your `~/bin/access-report.sh` from AUD-8003 should work.

## Concepts and commands
```linux
D=~/evidence/access-review-2026Q4
mkdir -p "$D"
sudo ~/bin/access-report.sh /tmp/q4 && cp /tmp/q4/access-report-latest.csv "$D/access-report.csv"
```

```linux
sudo sh -c "grep -hv '^\s*#' /etc/sudoers /etc/sudoers.d/*" | grep -v '^\s*$' > "$D/sudo-rules.txt"
```
`-h` omit file names, `-v '^\s*#'` drop comment lines; the second grep drops empty lines.

```linux
getent group finance hr engineering helpdesk auditors proj-falcon webops ssh-users sudo > "$D/group-members.txt"
```

```linux
sudo sh -c 'for f in /home/*/.ssh/authorized_keys; do echo "## $f"; ssh-keygen -lf "$f"; done' > "$D/ssh-keys.txt"
```
A `for` loop over every matching file. It runs inside `sudo sh -c '...'` because you (student) cannot even *see* other users' `.ssh` folders, so the `*` would not expand without root. The output is redirected once, as you, into your evidence folder.

```linux
cd "$D" && sha256sum access-report.csv sudo-rules.txt group-members.txt ssh-keys.txt > SHA256SUMS
sha256sum -c SHA256SUMS
```
```text
access-report.csv: OK
sudo-rules.txt: OK
group-members.txt: OK
ssh-keys.txt: OK
```

```linux
cd ~/evidence && tar -czf access-review-2026Q4.tar.gz access-review-2026Q4
tar -tzf access-review-2026Q4.tar.gz
```

## Your task
Build `~/evidence/access-review-2026Q4/` with the five files and package it as `~/evidence/access-review-2026Q4.tar.gz`. Make sure `sha256sum -c` passes **inside the archive**.

## Verify
`tar -tzf` shows five files under `access-review-2026Q4/`. **Check my work** extracts the archive to a temporary folder and runs `sha256sum -c`.

## If it fails
- *checksum mismatch*: you edited a file after creating `SHA256SUMS` - regenerate it, then re-create the archive.
- *paths in the archive start with /home*: run `tar` from `~/evidence` with a relative folder name.
- *files owned by root*: fine for the check; `sudo chown -R student: ~/evidence` if you want to edit them.

## Hints
### Hint 1
Collect the four data files first, then the checksum file, then the archive - in that order.
### Hint 2
The commands in "Concepts and commands" do it step by step; run them in order.
### Hint 3
See the Walkthrough for a single copy-paste sequence.

## Walkthrough
```linux
D=~/evidence/access-review-2026Q4
rm -rf "$D"; mkdir -p "$D"
sudo ~/bin/access-report.sh /tmp/q4 >/dev/null && cp /tmp/q4/access-report-latest.csv "$D/access-report.csv"
sudo sh -c "grep -hv '^\s*#' /etc/sudoers /etc/sudoers.d/*" | grep -v '^\s*$' > "$D/sudo-rules.txt"
getent group finance hr engineering helpdesk auditors proj-falcon webops ssh-users sudo > "$D/group-members.txt"
sudo sh -c 'for f in /home/*/.ssh/authorized_keys; do echo "## $f"; ssh-keygen -lf "$f"; done' > "$D/ssh-keys.txt"
cd "$D" && sha256sum access-report.csv sudo-rules.txt group-members.txt ssh-keys.txt > SHA256SUMS && sha256sum -c SHA256SUMS
cd ~/evidence && tar -czf access-review-2026Q4.tar.gz access-review-2026Q4
tar -tzf access-review-2026Q4.tar.gz
lab check m08-evidence
```
In a real review you would also record **who** collected it and **when** (a `README.txt` with your name, date and the commands), and store the archive somewhere the administrators of this server cannot modify.
