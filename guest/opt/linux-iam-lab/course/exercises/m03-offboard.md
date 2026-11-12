---
id: m03-offboard
module: m03
title: Offboard Chloe Diaz (leaver)
minutes: 35
prereqs: m03-mover
---
## Ticket
**HR-3006** - *Approved by: Hana Lopez (HR Manager)* - "Chloe Diaz (`cdiaz`) leaves today at 17:00. Disable all her access now. Policy LV-1: **do not delete** the account for 30 days (legal hold). Archive her home folder to `/srv/archive/offboarded/cdiaz-home.tar.gz`, and hand any HR files she owns over to me (`hlopez`)."

## Objective
Run a complete, verifiable leaver procedure: block every way in (password, SSH key, scheduled jobs, running sessions), remove roles, preserve data and ownership, keep the account for retention.

## Before you start
Linux terminal with `sudo`. Chloe currently has: a password, an SSH key, the `hr` role, a scheduled job (crontab), a running process, and files under `/srv/hr`.

## Concepts and commands
```linux
id cdiaz; sudo chage -l cdiaz; sudo passwd -S cdiaz
sudo ls -la /home/cdiaz/.ssh
sudo crontab -l -u cdiaz
pgrep -u cdiaz -l
sudo find /srv/hr -user cdiaz
```
Inventory first: you cannot remove access you have not found. `crontab -l -u USER` lists a user's scheduled jobs; `pgrep -u USER -l` lists their running processes; `find -user` finds their files.

```linux
sudo usermod -L -e 1 -s /usr/sbin/nologin cdiaz
```
- `-L` locks the password (puts `!` in front of the hash).
- `-e 1` sets the account expiry to 2 Jan 1970 - expired. (`sudo chage -E 0 cdiaz` is equivalent.) **Expiry also blocks SSH key logins**, which a password lock alone does not.
- `-s /usr/sbin/nologin` removes the interactive shell.

```linux
sudo gpasswd -d cdiaz hr
```
Remove every supplementary role (check `id cdiaz` for all of them). `sudo usermod -G "" cdiaz` removes all at once.

```linux
sudo crontab -r -u cdiaz
sudo pkill -KILL -u cdiaz
```
`crontab -r` removes the scheduled jobs; `pkill -u` ends the user's processes (`-KILL` cannot be ignored). On systems with logind you can also use `sudo loginctl terminate-user cdiaz`.

```linux
sudo mkdir -p /srv/archive/offboarded
sudo tar -czf /srv/archive/offboarded/cdiaz-home.tar.gz -C /home cdiaz
sudo tar -tzf /srv/archive/offboarded/cdiaz-home.tar.gz | head
```
`tar -c` create, `-z` gzip, `-f` file name, `-C /home` change to `/home` first so the archive contains `cdiaz/...` rather than `/home/cdiaz/...`. `-t` lists the archive to verify it.

```linux
sudo find /srv/hr -user cdiaz -exec chown hlopez {} +
```
Transfers ownership of each file found. `{}` stands for the file names; `+` passes many names per `chown` call.

## Your task
Leave `cdiaz` **existing** but completely disabled:
1. Password locked, account expired, shell `/usr/sbin/nologin`.
2. No supplementary groups.
3. No crontab, no running processes.
4. Home archived to `/srv/archive/offboarded/cdiaz-home.tar.gz` (containing `cdiaz/...`).
5. No files under `/srv/hr` owned by `cdiaz`; they are owned by `hlopez` now.
6. Her SSH key must no longer work (test it via the check).

## Verify
Re-run the inventory commands from the first block; each should come back empty or show the disabled state. **Check my work** also tries a real SSH key login and a password login as `cdiaz` - both must be refused.

## If it fails
- *SSH key login still works*: a password lock (`-L`) does not stop keys. Expire the account (`chage -E 0`) and/or remove `~cdiaz/.ssh/authorized_keys`.
- *process still running*: `pgrep -u cdiaz -l`, then `sudo pkill -KILL -u cdiaz`.
- *archive check fails*: list it with `tar -tzf`. Paths must start with `cdiaz/`.
- *account deleted*: policy says keep it - press **Retry exercise**.

## Hints
### Hint 1
Work through the list in order and re-check each item: password, expiry, shell, groups, cron, processes, archive, file ownership.
### Hint 2
`usermod -L -e 1 -s /usr/sbin/nologin cdiaz` does the first three in one go; `crontab -r -u`, `pkill -KILL -u`, `tar -czf ... -C /home cdiaz`, and `find /srv/hr -user cdiaz -exec chown hlopez {} +` do the rest.
### Hint 3
See the Walkthrough - but try the inventory commands yourself first; finding *everything* is the real skill.

## Walkthrough
```linux
id cdiaz; sudo crontab -l -u cdiaz; pgrep -u cdiaz -l; sudo find /srv/hr -user cdiaz
sudo usermod -L -e 1 -s /usr/sbin/nologin cdiaz
sudo usermod -G "" cdiaz
sudo crontab -r -u cdiaz
sudo pkill -KILL -u cdiaz
sudo mkdir -p /srv/archive/offboarded
sudo tar -czf /srv/archive/offboarded/cdiaz-home.tar.gz -C /home cdiaz
sudo tar -tzf /srv/archive/offboarded/cdiaz-home.tar.gz | head -3
sudo find /srv/hr -user cdiaz -exec chown hlopez {} +
id cdiaz; sudo passwd -S cdiaz; sudo chage -l cdiaz | grep 'Account expires'; pgrep -u cdiaz -l
```
```text
uid=2004(cdiaz) gid=2004(cdiaz) groups=2004(cdiaz)
cdiaz L 11/11/2026 0 99999 7 -1
Account expires                                         : Jan 02, 1970
```
```linux
lab check m03-offboard
```
**Evidence for the ticket:** the before/after inventory, the archive listing, and the failed login tests. After 30 days, a second ticket deletes the account with `sudo userdel -r cdiaz`.
