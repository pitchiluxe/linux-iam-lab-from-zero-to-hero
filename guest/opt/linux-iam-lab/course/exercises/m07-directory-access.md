---
id: m07-directory-access
module: m07
title: Priya can't log in - grant access in the directory
minutes: 35
prereqs: m07-directory-lookup
---
## Ticket
**IAM-7003** - *Approved by: Finance Systems owner* - "Priya Shah (`pshah`) needs to log in to `iamlab01` to run finance reports. She says her password is right but she is refused. Grant **login** access the standard way (directory group `linux-login`). Do not create a local account and do not change SSSD settings. Tomas Cole (`tcole`) must stay without access."

## Objective
Prove a failure is authorization, not authentication; fix it at the source (directory group membership) with `ldapmodify`; flush the SSSD cache; verify allowed and denied users.

## Before you start
Linux terminal with `sudo`. You are in `diradmins`, so you can read the directory admin password file `/etc/linux-iam-lab/ldap-admin.pw`. Use it with `-y` - never print it, never paste it anywhere.

## Concepts and commands
```linux
sudo sssctl user-checks pshah
sudo grep 'pam_sss.*pshah' /var/log/auth.log | tail -2
```
```text
pam_sss(sshd:account): Access denied for user pshah: 6 (Permission denied)
```
`account` phase + "Access denied" = **authorization**. Her password is not the problem.

```linux
sudo grep -E 'access_provider|simple_allow' /etc/sssd/sssd.conf
ldapsearch -x -ZZ -H ldap://ldap.iamlab.test -b ou=groups,dc=iamlab,dc=test '(cn=linux-login)' memberUid
```
Who is allowed, and who is currently in that group.

```linux
cat > /tmp/add-pshah.ldif <<'EOF'
dn: cn=linux-login,ou=groups,dc=iamlab,dc=test
changetype: modify
add: memberUid
memberUid: pshah
EOF
ldapmodify -x -ZZ -H ldap://ldap.iamlab.test -D cn=admin,dc=iamlab,dc=test -y /etc/linux-iam-lab/ldap-admin.pw -f /tmp/add-pshah.ldif
```
- An **LDIF** change: which entry (`dn:`), what kind of change (`changetype: modify`), the operation (`add:` attribute) and the value.
- `-D` the DN to bind as, `-y` read its password from a file (so it never appears on the command line or in history), `-f` the LDIF file.
```text
modifying entry "cn=linux-login,ou=groups,dc=iamlab,dc=test"
```

```linux
sudo sss_cache -E
sudo sssctl user-checks pshah
```
SSSD caches group membership; `-E` expires everything so the next lookup asks the directory. The second check should now say `pam_acct_mgmt: Success`.

## Your task
1. Confirm from the logs/`sssctl` that `pshah`'s problem is authorization.
2. Add `pshah` to the directory group `linux-login` with `ldapmodify` (bind as `cn=admin,dc=iamlab,dc=test` using `-y`).
3. Flush the SSSD cache and verify.
4. Do not add `tcole`; do not change `/etc/sssd/sssd.conf`; do not create a local `pshah`.

## Verify
`sudo sssctl user-checks pshah` succeeds and `sudo sssctl user-checks tcole` is still denied. **Check my work** performs real password logins for both through the same PAM stack sshd uses.

## If it fails
- *`ldap_bind: Invalid credentials (49)`*: wrong `-D` DN or password file path.
- *`Type or value exists (20)`*: she is already a member - fine, move on.
- *still denied after the change*: you skipped `sss_cache -E`, or misspelled `memberUid: pshah`.
- *`ldap_start_tls: Connect error`*: use `ldap.iamlab.test`, keep `-ZZ`.

## Hints
### Hint 1
The fix is one attribute value on one directory entry: the group `cn=linux-login,ou=groups,dc=iamlab,dc=test`.
### Hint 2
Write an LDIF with `changetype: modify` / `add: memberUid` / `memberUid: pshah` and apply it with `ldapmodify ... -D cn=admin,dc=iamlab,dc=test -y /etc/linux-iam-lab/ldap-admin.pw -f FILE`. Then `sudo sss_cache -E`.
### Hint 3
See the Walkthrough. Afterwards remove the LDIF from `/tmp`.

## Walkthrough
```linux
sudo sssctl user-checks pshah
cat > /tmp/add-pshah.ldif <<'EOF'
dn: cn=linux-login,ou=groups,dc=iamlab,dc=test
changetype: modify
add: memberUid
memberUid: pshah
EOF
ldapmodify -x -ZZ -H ldap://ldap.iamlab.test -D cn=admin,dc=iamlab,dc=test -y /etc/linux-iam-lab/ldap-admin.pw -f /tmp/add-pshah.ldif
rm /tmp/add-pshah.ldif
sudo sss_cache -E
sudo sssctl user-checks pshah
sudo sssctl user-checks tcole
lab check m07-directory-access
```
**Why fix it in the directory:** a local exception on one server is invisible to access reviews and is forgotten when Priya leaves. A directory group is reviewed centrally and removed by the leaver process everywhere at once.
