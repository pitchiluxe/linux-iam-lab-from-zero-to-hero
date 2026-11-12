---
id: m07-authn-authz
module: m07
title: Map how Linux decides who you are
minutes: 25
---
## Ticket
**IAM-7001** - *From: IAM Architect* - "Before we connect more servers to the directory, document how `iamlab01` resolves and authenticates users. Answer the questions in `~/lab/m07/stack.txt`."

## Objective
Read `nsswitch.conf` and the PAM stack, tell local and directory users apart, and explain the difference between an authentication and an authorization failure.

## Before you start
Linux terminal; `sudo` for logs and `sssctl`. Directory users: `nwalker`, `pshah`, `tcole`, `mfischer`.

## Concepts and commands
```linux
grep '^passwd' /etc/nsswitch.conf
getent passwd nwalker
getent -s files passwd nwalker; echo "files: exit $?"
getent -s sss passwd nwalker
```
`getent -s SOURCE` asks one source. Exit code `2` = not found there.
```text
nwalker:*:10001:10000:Nadia Walker:/home/nwalker:/bin/bash
files: exit 2
nwalker:*:10001:10000:Nadia Walker:/home/nwalker:/bin/bash
```
`nwalker` exists only in the directory (via SSSD), not in `/etc/passwd`.

```linux
grep -v '^#' /etc/pam.d/sshd | grep -v '^$'
grep -v '^#' /etc/pam.d/common-auth | grep -v '^$'
```
```text
@include common-auth
account    required     pam_nologin.so
@include common-account
...
auth    requisite                       pam_faillock.so preauth
auth    [success=2 default=ignore]      pam_unix.so nullok
auth    [success=1 default=ignore]      pam_sss.so use_first_pass
auth    [default=die]                   pam_faillock.so authfail
...
```
Read top-down: lockout check first, then local passwords, then the directory.

```linux
sudo sssctl user-checks tcole
```
Runs the account (authorization) checks for `tcole` through PAM and shows the result:
```text
pam_acct_mgmt: Permission denied
```
```linux
sudo grep -E 'pam_sss.*tcole' /var/log/auth.log | tail -3
```
```text
pam_sss(sshd:account): Access denied for user tcole: 6 (Permission denied)
```
`tcole` typed the right password (the auth phase succeeded - the lab's self-test does this) but the **account** phase denied him: `simple_allow_groups = linux-login` in `/etc/sssd/sssd.conf`.

## Your task
Create `~/lab/m07/stack.txt`:
```text
passwd_sources=<the sources on the passwd: line of nsswitch.conf, space-separated, in order>
nwalker_source=<files or sss: where nwalker is defined>
nwalker_uid=<nwalker's UID>
sshd_auth_stack=<the stack file /etc/pam.d/sshd includes for authentication, e.g. common-xxx>
lockout_module=<the PAM module that locks accounts after failed passwords>
tcole_failure=<authentication or authorization>
tcole_rule=<the sssd.conf setting that denies tcole>
```

## Verify
Re-run the commands; **Check my work** reads the live files.

## If it fails
- *passwd_sources*: copy the words after `passwd:` exactly, single spaces.
- *sshd_auth_stack*: look for `@include` lines in `/etc/pam.d/sshd`.
- *tcole_rule*: the setting name only (left of `=`).

## Hints
### Hint 1
Everything is in three places: `/etc/nsswitch.conf`, `/etc/pam.d/sshd` + `common-auth`, and `/etc/sssd/sssd.conf` (`sudo cat`).
### Hint 2
`getent -s files passwd nwalker` returns nothing - so where does `getent passwd nwalker` get him from? The lockout module's name contains "fail".
### Hint 3
`passwd_sources=files systemd sss`, `nwalker_source=sss`, `nwalker_uid=10001`, `sshd_auth_stack=common-auth`, `lockout_module=pam_faillock`, `tcole_failure=authorization`, `tcole_rule=simple_allow_groups`.

## Walkthrough
```linux
grep '^passwd' /etc/nsswitch.conf
getent -s files passwd nwalker; getent -s sss passwd nwalker
grep '@include' /etc/pam.d/sshd
grep faillock /etc/pam.d/common-auth
sudo sssctl user-checks tcole
sudo grep simple_allow /etc/sssd/sssd.conf
mkdir -p ~/lab/m07
cat > ~/lab/m07/stack.txt <<'EOF'
passwd_sources=files systemd sss
nwalker_source=sss
nwalker_uid=10001
sshd_auth_stack=common-auth
lockout_module=pam_faillock
tcole_failure=authorization
tcole_rule=simple_allow_groups
EOF
lab check m07-authn-authz
```
