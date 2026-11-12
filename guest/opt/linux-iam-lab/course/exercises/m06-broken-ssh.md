---
id: m06-broken-ssh
module: m06
title: "Permission denied (publickey)" for Hana
minutes: 25
prereqs: m06-key-login
---
## Ticket
**HELP-6002** - *From: Hana Lopez* - "My SSH key worked last week. Now I get `Permission denied (publickey)`. Someone 'fixed' my home folder permissions over the weekend so the team could drop files in. I haven't changed my key."

## Objective
Diagnose a failed key login from the **server-side log**, and fix the root cause without weakening security.

## Before you start
Linux terminal with `sudo`. Hana's key is installed in `/home/hlopez/.ssh/authorized_keys`. **Check my work** logs in with her key.

## Concepts and commands
```linux
sudo journalctl -u ssh -n 30 --no-pager | grep -i hlopez
```
The server tells you exactly why it ignored the key (the client only says "Permission denied"):
```text
sshd[4242]: Authentication refused: bad ownership or modes for directory /home/hlopez
```

```linux
sudo namei -l /home/hlopez/.ssh/authorized_keys
```
Shows owner and mode of every step - the home folder, `.ssh`, and the file.
```text
drwxrwxrwx hlopez hlopez hlopez
drwxrwxrwx hlopez hlopez .ssh
-rw-rw-rw- root   root   authorized_keys
```
Three problems: world-writable home, world-writable `.ssh`, and a world-writable key file owned by root. Anyone on the server could add their own key and become Hana.

```linux
sudo chmod 750 /home/hlopez
sudo chmod 700 /home/hlopez/.ssh
sudo chown hlopez:hlopez /home/hlopez/.ssh/authorized_keys
sudo chmod 600 /home/hlopez/.ssh/authorized_keys
```

## Your task
1. Find the reason in the server log.
2. Fix ownership and modes so StrictModes accepts the key: home not group/world-writable, `.ssh` `700`, `authorized_keys` `600`, both owned by `hlopez`.
3. Do **not** disable `StrictModes`. Team file drops belong in a shared folder (module 4), not in someone's home.

## Verify
`sudo namei -l /home/hlopez/.ssh/authorized_keys`, then **Check my work** (real login with her key).

## If it fails
- *still refused*: read the newest log line again - it names the next bad path.
- *you changed sshd_config*: undo it; the fix is file permissions.

## Hints
### Hint 1
The client never says why; the server log does. Search the ssh service log for hlopez.
### Hint 2
Three paths are involved: `/home/hlopez`, `/home/hlopez/.ssh`, `/home/hlopez/.ssh/authorized_keys`. Check owner and mode of each.
### Hint 3
`chmod 750` on the home, `chmod 700` on `.ssh`, `chown hlopez:hlopez` and `chmod 600` on `authorized_keys`.

## Walkthrough
```linux
sudo journalctl -u ssh -n 50 --no-pager | grep -i 'hlopez'
sudo namei -l /home/hlopez/.ssh/authorized_keys
sudo chmod 750 /home/hlopez
sudo chmod 700 /home/hlopez/.ssh
sudo chown hlopez:hlopez /home/hlopez/.ssh/authorized_keys
sudo chmod 600 /home/hlopez/.ssh/authorized_keys
sudo namei -l /home/hlopez/.ssh/authorized_keys
lab check m06-broken-ssh
```
```text
drwxr-x--- hlopez hlopez hlopez
drwx------ hlopez hlopez .ssh
-rw------- hlopez hlopez authorized_keys
```
**Why sshd is strict:** if others can write your `authorized_keys`, they can log in as you. Weak permissions on credential files are an identity compromise waiting to happen.
