---
id: m06-key-login
module: m06
title: Set up SSH key login (for Ben and for yourself)
minutes: 30
---
## Ticket
**IAM-6001** - *From: Ben Tran* - "Please enable key login for my account `btran`. My public key is in `/opt/lab-data/keys/btran_laptop.pub`. Its fingerprint is in the attached note `/opt/lab-data/tickets/IAM-6001.txt` - please verify before installing." *Team lead adds:* "And while you're at it, set up your own key so you can log in to this server as `student` without a password."

## Objective
Verify a public key by fingerprint, install it with correct ownership and modes, create your own key pair, and log in with it.

## Before you start
Linux terminal with `sudo`. You do not have Ben's private key (only Ben does); **Check my work** tests his login with the copy the lab holds.

## Concepts and commands
```linux
cat /opt/lab-data/tickets/IAM-6001.txt
ssh-keygen -lf /opt/lab-data/keys/btran_laptop.pub
```
`-l` shows the fingerprint, `-f` names the key file. Compare it character by character with the ticket. A mismatch means the key file was swapped - stop and ask.
```text
256 SHA256:Q9b1...uM btran_laptop (ED25519)
```

```linux
sudo install -d -m 700 -o btran -g btran /home/btran/.ssh
sudo install -m 600 -o btran -g btran /opt/lab-data/keys/btran_laptop.pub /home/btran/.ssh/authorized_keys
sudo ls -la /home/btran/.ssh
```
`install` copies a file (or creates a folder with `-d`) and sets mode (`-m`), owner (`-o`) and group (`-g`) in one step - fewer chances to forget a `chown`. If `authorized_keys` already had keys you would **append** instead: `cat key.pub | sudo tee -a /home/btran/.ssh/authorized_keys`.

```linux
ssh-keygen -t ed25519 -C "student@iamlab01"
```
Creates your own pair. Press Enter to accept `~/.ssh/id_ed25519`; set a passphrase (recommended in real life; for this lab you may leave it empty).
```text
Your identification has been saved in /home/student/.ssh/id_ed25519
Your public key has been saved in /home/student/.ssh/id_ed25519.pub
```

```linux
cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
ssh -i ~/.ssh/id_ed25519 student@localhost hostname
```
`>>` appends your public key to your own `authorized_keys` (the Windows lab key is already there - do not overwrite it with `>`). The first connection to `localhost` shows the server's fingerprint: compare it with `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub` before typing `yes`.

## Your task
1. Verify Ben's key fingerprint against the ticket.
2. Install it as Ben's only authorized key with correct owner and modes (`700` folder, `600` file, owned by `btran`).
3. Create your own ed25519 key pair and add **its public key** to `~/.ssh/authorized_keys` (keep the existing line).
4. Log in to `student@localhost` with your new key.

## Verify
`sudo ls -la /home/btran/.ssh`, `ls -la ~/.ssh`, and your successful `ssh` command. **Check my work** really logs in as btran with his key.

## If it fails
- *btran's login refused*: read `sudo journalctl -u ssh -n 20`. "bad ownership or modes" = fix modes/owner.
- *your own login asks for a password*: the public key is not in `~/.ssh/authorized_keys`, or you used `>` and overwrote it - re-add both keys.
- *"lost" the Windows key*: you overwrote `authorized_keys`. Use **Reset Linux IAM Lab** if `ssh linux-iam-lab` from Windows stops working, or re-add the line from `C:\Users\you\.ssh\linux-iam-lab_student_ed25519.pub`.

## Hints
### Hint 1
Fingerprint: `ssh-keygen -lf FILE`. Installing for another user needs `sudo` plus the right owner - `install` does both.
### Hint 2
`sudo install -d -m 700 -o btran -g btran /home/btran/.ssh` then `sudo install -m 600 -o btran -g btran /opt/lab-data/keys/btran_laptop.pub /home/btran/.ssh/authorized_keys`.
### Hint 3
For yourself: `ssh-keygen -t ed25519` (Enter for defaults), `cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys`, `ssh -i ~/.ssh/id_ed25519 student@localhost hostname`.

## Walkthrough
```linux
cat /opt/lab-data/tickets/IAM-6001.txt
ssh-keygen -lf /opt/lab-data/keys/btran_laptop.pub
sudo install -d -m 700 -o btran -g btran /home/btran/.ssh
sudo install -m 600 -o btran -g btran /opt/lab-data/keys/btran_laptop.pub /home/btran/.ssh/authorized_keys
sudo ls -la /home/btran/.ssh
ssh-keygen -t ed25519 -C "student@iamlab01" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
ssh -i ~/.ssh/id_ed25519 student@localhost hostname
lab check m06-key-login
```
```text
The authenticity of host 'localhost (127.0.0.1)' can't be established.
ED25519 key fingerprint is SHA256:....
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
iamlab01
```
`-N ""` sets an empty passphrase non-interactively (lab only).
