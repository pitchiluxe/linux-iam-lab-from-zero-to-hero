---
id: m06-revoke-key
module: m06
title: A laptop was stolen - revoke its SSH key
minutes: 25
prereqs: m06-key-login
---
## Ticket
**SEC-6004** - *Priority: High* - "Eli Novak's laptop was stolen at the airport. Revoke the key on it (`enovak_laptop`, fingerprint in `/opt/lab-data/tickets/SEC-6004.txt`) on `iamlab01` **now**. His tablet key must keep working. Make sure the stolen key cannot be re-added by mistake later."

## Objective
Identify a specific key among several by fingerprint, remove it, block it server-wide with `RevokedKeys`, and prove the stolen key is denied while the legitimate one works.

## Before you start
Linux terminal with `sudo`. Eli has two keys in `/home/enovak/.ssh/authorized_keys`. The lab holds copies of both private keys to test them.

## Concepts and commands
```linux
cat /opt/lab-data/tickets/SEC-6004.txt
sudo ssh-keygen -lf /home/enovak/.ssh/authorized_keys
```
Run against an `authorized_keys` file, `ssh-keygen -lf` prints one fingerprint per line, in file order - so you can match line numbers to fingerprints.
```text
256 SHA256:aaaa... enovak_laptop (ED25519)
256 SHA256:bbbb... enovak_tablet (ED25519)
```

```linux
sudo grep -n enovak_laptop /home/enovak/.ssh/authorized_keys
sudo sed -i '/enovak_laptop$/d' /home/enovak/.ssh/authorized_keys
```
`grep -n` shows line numbers. `sed -i '/PATTERN/d'` deletes matching lines **in place**. Comments can be edited by anyone who can edit the file, so confirm by fingerprint afterwards, not only by comment.

```linux
sudo install -m 644 /dev/null /etc/ssh/revoked_keys
sudo cp /opt/lab-data/keys/enovak_laptop.pub /tmp/stolen.pub
cat /tmp/stolen.pub | sudo tee -a /etc/ssh/revoked_keys
```
`RevokedKeys` is a server-wide deny list of public keys: a listed key is refused for **every** account, even if someone adds it back to an `authorized_keys` file.

```linux
echo 'RevokedKeys /etc/ssh/revoked_keys' | sudo tee /etc/ssh/sshd_config.d/20-revoked-keys.conf
sudo sshd -t && sudo systemctl reload ssh
sudo sshd -T | grep -i revokedkeys
```

## Your task
1. Identify the stolen key by fingerprint and remove it from enovak's `authorized_keys`; keep the tablet key.
2. Add the stolen public key to `/etc/ssh/revoked_keys` and enable `RevokedKeys /etc/ssh/revoked_keys` in a drop-in config file. Validate and reload.

## Verify
`sudo ssh-keygen -lf /home/enovak/.ssh/authorized_keys` shows only the tablet. **Check my work** tries both keys for real, and also tries the stolen key after temporarily re-adding it (it must still be refused).

## If it fails
- *tablet key also denied*: you removed both lines, or `enovak` is not allowed by `AllowGroups` (he is in `ssh-users` - check `id enovak`).
- *stolen key still works after re-adding*: `RevokedKeys` is not active - check `sudo sshd -T | grep -i revokedkeys` and that the file contains the key.

## Hints
### Hint 1
Fingerprints first (`ssh-keygen -lf` on the ticket's key and on the authorized_keys file), then delete exactly one line.
### Hint 2
For the "cannot be re-added" part look at the sshd setting `RevokedKeys` (`man sshd_config`).
### Hint 3
`sudo sed -i '/enovak_laptop$/d' /home/enovak/.ssh/authorized_keys`; `cat /opt/lab-data/keys/enovak_laptop.pub | sudo tee -a /etc/ssh/revoked_keys`; `echo 'RevokedKeys /etc/ssh/revoked_keys' | sudo tee /etc/ssh/sshd_config.d/20-revoked-keys.conf`; `sudo sshd -t && sudo systemctl reload ssh`.

## Walkthrough
```linux
cat /opt/lab-data/tickets/SEC-6004.txt
sudo ssh-keygen -lf /home/enovak/.ssh/authorized_keys
sudo sed -i '/enovak_laptop$/d' /home/enovak/.ssh/authorized_keys
sudo ssh-keygen -lf /home/enovak/.ssh/authorized_keys
cat /opt/lab-data/keys/enovak_laptop.pub | sudo tee -a /etc/ssh/revoked_keys
sudo chmod 644 /etc/ssh/revoked_keys
echo 'RevokedKeys /etc/ssh/revoked_keys' | sudo tee /etc/ssh/sshd_config.d/20-revoked-keys.conf
sudo sshd -t && sudo systemctl reload ssh
sudo sshd -T | grep -i revokedkeys
lab check m06-revoke-key
```
```text
revokedkeys /etc/ssh/revoked_keys
```
**Also in a real incident:** check the auth log for logins with that fingerprint since the theft (`sudo journalctl -u ssh | grep 'SHA256:...'`), revoke the same key on every other server (automation!), and record it all in the ticket.
