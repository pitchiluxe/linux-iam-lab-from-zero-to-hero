---
id: m07-ldap-basics
module: m07
title: Build a directory branch with ldapadd
minutes: 40
prereqs: m07-directory-lookup
---
## Ticket
**IAM-7004** - *From: IAM Team lead* - "We are starting an IAM analyst pod. Create a new branch `ou=iam` in the directory, add our new analyst **Rosa Lopez** (`rlopez`, UID `10020`) and a group `iam-analysts` (GID `10020`) with her in it. Prove it with `ldapsearch`, save the proof to `~/lab/m07/iam-verify.txt`, and clean up your LDIF files."

## Objective
Write LDIF files for an organizational unit, a user and a group; load them with `ldapadd` using a password **file**; verify with `ldapsearch` and with Linux (`getent`, `id`); learn how to remove entries safely with `ldapdelete`.

## Before you start
Linux terminal. You are in `diradmins`, so you can read `/etc/linux-iam-lab/ldap-admin.pw`. Use it with `-y` and never print it.

## Concepts and commands
The directory is a tree. A new **OU** (organizational unit) is a branch you can put people and groups under:
```text
dc=iamlab,dc=test
├── ou=people      (baseline people)
├── ou=groups      (baseline groups)
└── ou=iam         <- you create this
    ├── uid=rlopez
    └── cn=iam-analysts
```
A parent must exist **before** its children, so you add the OU first and you delete it last.

```linux
mkdir -p ~/lab/m07 && cd ~/lab/m07
cat > ou.ldif <<'EOF'
dn: ou=iam,dc=iamlab,dc=test
objectClass: organizationalUnit
ou: iam
EOF
ldapadd -x -ZZ -H ldap://ldap.iamlab.test -D cn=admin,dc=iamlab,dc=test -y /etc/linux-iam-lab/ldap-admin.pw -f ou.ldif
```
```text
adding new entry "ou=iam,dc=iamlab,dc=test"
```
- `ldapadd` creates **new** entries (an LDIF without `changetype:` lines). `ldapmodify` changes existing ones.
- `-D` the admin DN to bind as, `-y FILE` read the password from a file.
- **Why not `-w password`?** A password on the command line is visible to every user in `ps` and is saved in your shell history. Tutorials often show `-w`; in real work use `-y` or `-W` (prompt).

A user that Linux can use needs `posixAccount` (UID, GID, home, shell) and usually `inetOrgPerson` (name, mail, title):
```text
dn: uid=rlopez,ou=iam,dc=iamlab,dc=test
objectClass: inetOrgPerson
objectClass: posixAccount
uid: rlopez
cn: Rosa Lopez
sn: Lopez
uidNumber: 10020
gidNumber: 10000
homeDirectory: /home/rlopez
loginShell: /bin/bash
```
No `userPassword` here: the account exists but nobody can log in with a password. That is the safe default until onboarding is approved.

A POSIX group lists members by username:
```text
dn: cn=iam-analysts,ou=iam,dc=iamlab,dc=test
objectClass: posixGroup
cn: iam-analysts
gidNumber: 10020
memberUid: rlopez
```

Verify in the directory and on Linux:
```linux
ldapsearch -LLL -x -ZZ -H ldap://ldap.iamlab.test -b ou=iam,dc=iamlab,dc=test dn
sudo sss_cache -E
getent passwd rlopez
id rlopez
```
- `-LLL` prints plain LDIF without comments, good for saving as evidence.
- SSSD searches the whole `dc=iamlab,dc=test` tree, so a user in your new OU becomes a Linux identity too.

Removing entries (**do not** do this before the check - it is how you would clean up afterwards):
```linux
ldapdelete -x -ZZ -H ldap://ldap.iamlab.test -D cn=admin,dc=iamlab,dc=test -y /etc/linux-iam-lab/ldap-admin.pw \
  uid=rlopez,ou=iam,dc=iamlab,dc=test cn=iam-analysts,ou=iam,dc=iamlab,dc=test ou=iam,dc=iamlab,dc=test
```
Children first, then the OU. Deleting a non-empty OU fails with `Operation not allowed on non-leaf (66)`.

## Your task
1. Create `ou=iam,dc=iamlab,dc=test`.
2. Create `uid=rlopez,ou=iam,dc=iamlab,dc=test`: `cn: Rosa Lopez`, UID `10020`, GID `10000`, home `/home/rlopez`, shell `/bin/bash`, object classes `inetOrgPerson` and `posixAccount`.
3. Create `cn=iam-analysts,ou=iam,dc=iamlab,dc=test`: `posixGroup`, GID `10020`, member `rlopez`.
4. Save `ldapsearch -LLL ... -b ou=iam,dc=iamlab,dc=test dn` output to `~/lab/m07/iam-verify.txt`.
5. Delete your `.ldif` files from `~/lab/m07`.

## Verify
`getent passwd rlopez` shows UID 10020 and `id rlopez` lists `iam-analysts`. **Check my work** reads the directory live and resolves the user through SSSD.

## If it fails
- *`Already exists (68)`*: the entry is there already - check it with `ldapsearch` instead of adding again.
- *`No such object (32)`* on the user: you have not created `ou=iam` yet.
- *`Object class violation (65)`*: a required attribute is missing (`sn` for inetOrgPerson, `homeDirectory` for posixAccount...) or an object class is misspelled.
- *`ldap_bind: Invalid credentials (49)`*: wrong `-D` DN or password file path.
- *`getent` shows nothing*: run `sudo sss_cache -E` and try again.

## Hints
### Hint 1
Three LDIF files (or one file with three entries separated by a blank line), three objects, in order: OU, user, group.
### Hint 2
One `ldapadd ... -y /etc/linux-iam-lab/ldap-admin.pw -f FILE` per file. Then `ldapsearch -LLL -x -ZZ -H ldap://ldap.iamlab.test -b ou=iam,dc=iamlab,dc=test dn > ~/lab/m07/iam-verify.txt`.
### Hint 3
See the Walkthrough. Remember `rm ~/lab/m07/*.ldif` at the end.

## Walkthrough
```linux
mkdir -p ~/lab/m07 && cd ~/lab/m07
cat > iam.ldif <<'EOF'
dn: ou=iam,dc=iamlab,dc=test
objectClass: organizationalUnit
ou: iam

dn: uid=rlopez,ou=iam,dc=iamlab,dc=test
objectClass: inetOrgPerson
objectClass: posixAccount
uid: rlopez
cn: Rosa Lopez
givenName: Rosa
sn: Lopez
title: IAM Analyst
mail: rlopez@iamlab.test
uidNumber: 10020
gidNumber: 10000
homeDirectory: /home/rlopez
loginShell: /bin/bash

dn: cn=iam-analysts,ou=iam,dc=iamlab,dc=test
objectClass: posixGroup
cn: iam-analysts
gidNumber: 10020
memberUid: rlopez
EOF
ldapadd -x -ZZ -H ldap://ldap.iamlab.test -D cn=admin,dc=iamlab,dc=test -y /etc/linux-iam-lab/ldap-admin.pw -f iam.ldif
ldapsearch -LLL -x -ZZ -H ldap://ldap.iamlab.test -b ou=iam,dc=iamlab,dc=test dn > ~/lab/m07/iam-verify.txt
cat ~/lab/m07/iam-verify.txt
sudo sss_cache -E
getent passwd rlopez
id rlopez
rm ~/lab/m07/*.ldif
lab check m07-ldap-basics
```
**Cleanup afterwards:** run the `ldapdelete` command from *Concepts* (children first, then the OU), or use **Retry exercise**, which removes the branch for you.
