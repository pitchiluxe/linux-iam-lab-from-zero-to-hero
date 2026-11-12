---
id: m06-sshd-hardening
module: m06
title: Harden the SSH server and restrict who may log in
minutes: 35
prereqs: m06-key-login
---
## Ticket
**SEC-6003** - *Approved by: CISO* - "Apply the SSH baseline to `iamlab01`: no root login, at most 3 authentication attempts, 30-second login grace time, no X11 forwarding, and **only members of `ssh-users` may log in over SSH**. Amara Okafor (`aokafor`) needs remote access from now on; Jae Kim (`jkim`) must not have it. Put the settings in `/etc/ssh/sshd_config.d/10-hardening.conf`."

## Objective
Change sshd safely: write a drop-in file, validate with `sshd -t`, inspect the effective config with `sshd -T`, reload, and prove allowed and denied logins - without locking out administrators.

## Before you start
Linux terminal with `sudo`. **Safety first:** keep this terminal open. Check that the accounts that must keep access are in `ssh-users`: `getent group ssh-users`. The lab's automation account `labctl` and your `student` account already are.

## Concepts and commands
```linux
getent group ssh-users
sudo usermod -aG ssh-users aokafor
```
Add people **before** turning on `AllowGroups`, otherwise you deny them.

```linux
sudo nano /etc/ssh/sshd_config.d/10-hardening.conf
```
```conf
# SEC-6003 SSH baseline
PermitRootLogin no
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
AllowGroups ssh-users
```
Drop-in files are read in name order and **the first value wins**, so `10-...` beats the lab's `50-...` and Ubuntu's `60-...` files.

```linux
sudo sshd -t && echo "config OK"
```
`-t` test mode: prints errors such as `/etc/ssh/sshd_config.d/10-hardening.conf line 3: Bad configuration option: MaxAuthTry` and exits non-zero. Never reload an invalid config.

```linux
sudo sshd -T -C user=jkim,host=laptop,addr=10.0.2.2 | grep -Ei 'permitrootlogin|maxauthtries|logingracetime|x11forwarding|allowgroups'
```
`-T` prints the effective settings; `-C` evaluates them for a hypothetical connection (user, client host name, address).
```text
permitrootlogin no
maxauthtries 3
logingracetime 30
x11forwarding no
allowgroups ssh-users
```

```linux
sudo systemctl reload ssh
sudo journalctl -u ssh -n 5 --no-pager
```
`reload` re-reads the config without dropping existing connections.

```linux
ssh -i ~/.ssh/id_ed25519 student@localhost hostname
```
Test that **you** can still get in, from a new connection, before you close anything.

## Your task
1. Add `aokafor` to `ssh-users`. Do not add `jkim`.
2. Create `/etc/ssh/sshd_config.d/10-hardening.conf` with the five settings.
3. Validate, reload, and confirm with `sshd -T`.
4. Confirm you (student) can still log in over SSH.

## Verify
**Check my work** validates the config and performs real key logins: `aokafor` allowed, `jkim` denied, `labctl` still allowed.

## If it fails
- *`sshd -t` error*: the message names the file and line; fix the spelling.
- *aokafor denied*: `id aokafor` must show `ssh-users`.
- *`ssh linux-iam-lab` from Windows stopped working*: your account is not in `ssh-users` or the file has a typo in the group name. Use the portal terminal (it does not use SSH) to fix it, or `lab rescue sshd`.

## Hints
### Hint 1
Order matters: group membership first, config second, `sshd -t` third, reload last.
### Hint 2
The five settings are `PermitRootLogin no`, `MaxAuthTries 3`, `LoginGraceTime 30`, `X11Forwarding no`, `AllowGroups ssh-users`.
### Hint 3
`sudo usermod -aG ssh-users aokafor`, write the file with `sudo nano`, then `sudo sshd -t && sudo systemctl reload ssh`.

## Walkthrough
```linux
getent group ssh-users
sudo usermod -aG ssh-users aokafor
sudo tee /etc/ssh/sshd_config.d/10-hardening.conf > /dev/null <<'EOF'
# SEC-6003 SSH baseline
PermitRootLogin no
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
AllowGroups ssh-users
EOF
sudo sshd -t && echo "config OK"
sudo sshd -T -C user=jkim,host=laptop,addr=10.0.2.2 | grep -Ei 'permitrootlogin|maxauthtries|logingracetime|x11forwarding|allowgroups'
sudo systemctl reload ssh
ssh -i ~/.ssh/id_ed25519 student@localhost hostname
lab check m06-sshd-hardening
```
`sudo tee FILE > /dev/null` writes text as root (a plain `sudo cat > FILE` would not work, because the `>` redirection runs as you). After the check, look at the denial in the log: `sudo journalctl -u ssh -n 20 --no-pager | grep jkim`.
```text
sshd[5120]: User jkim from 127.0.0.1 not allowed because none of user's groups are listed in AllowGroups
```
