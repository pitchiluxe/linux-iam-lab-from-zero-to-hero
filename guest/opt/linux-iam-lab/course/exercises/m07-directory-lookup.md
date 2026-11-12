---
id: m07-directory-lookup
module: m07
title: Look up a person in the directory
minutes: 25
prereqs: m07-authn-authz
---
## Ticket
**IAM-7002** - *From: Service Desk* - "Priya Shah says Linux shows her with the wrong title. Pull her record from the directory and from Linux, and tell us her username, UID, title, and directory groups. Answers in `~/lab/m07/pshah.txt`."

## Objective
Query an LDAP directory with `ldapsearch` (over StartTLS), compare it with what Linux sees through SSSD (`getent`, `id`), and read POSIX group membership.

## Before you start
Linux terminal. Anonymous read of names and groups is allowed in the lab directory; passwords are never returned.

## Concepts and commands
```linux
ldapsearch -x -ZZ -H ldap://ldap.iamlab.test -b ou=people,dc=iamlab,dc=test '(cn=Priya*)' uid uidNumber gidNumber title mail
```
- `-x` simple bind (anonymous here), `-ZZ` StartTLS and **fail** if TLS cannot be established, `-H` server, `-b` where to start searching.
- `'(cn=Priya*)'` is the filter: common name starting with Priya. Other filters: `'(uid=pshah)'`, `'(&(objectClass=posixAccount)(uidNumber>=10000))'`.
- The words after the filter are the attributes to show.
```text
dn: uid=pshah,ou=people,dc=iamlab,dc=test
uid: pshah
uidNumber: 10002
gidNumber: 10000
title: Finance Systems Analyst
mail: pshah@iamlab.test
```

```linux
ldapsearch -x -ZZ -H ldap://ldap.iamlab.test -b ou=groups,dc=iamlab,dc=test '(memberUid=pshah)' cn
```
Which groups list her as a member. Her **primary** group is the one whose `gidNumber` matches hers.

```linux
getent passwd pshah
id pshah
```
```text
pshah:*:10002:10000:Priya Shah:/home/pshah:/bin/bash
uid=10002(pshah) gid=10000(dir-staff) groups=10000(dir-staff),10012(dir-finance)
```
The same identity, as Linux resolves it via SSSD. If the directory changes and Linux still shows old data, the SSSD **cache** is the usual cause: `sudo sss_cache -E`.

## Your task
Create `~/lab/m07/pshah.txt`:
```text
uid=<her username>
uidnumber=<her UID>
title=<her title, exactly as in the directory>
groups=<ALL her groups as id shows them (primary and supplementary), sorted, comma-separated>
dn=<her full distinguished name>
```

## Verify
Compare `ldapsearch` and `id pshah`. **Check my work** queries the directory live.

## If it fails
- *`ldap_start_tls: Connect error`*: use the host name `ldap.iamlab.test` (the certificate is issued for it), not an IP.
- *groups wrong*: include the primary group (`dir-staff`), sort alphabetically.

## Hints
### Hint 1
Search people with a filter on `cn` or `uid`, then search groups with `(memberUid=pshah)`. `id pshah` shows the combined result.
### Hint 2
`id -nG pshah | tr ' ' '\n' | sort | paste -sd, -` gives the groups line.
### Hint 3
`uid=pshah`, `uidnumber=10002`, `title=Finance Systems Analyst`, `groups=dir-finance,dir-staff`, `dn=uid=pshah,ou=people,dc=iamlab,dc=test`.

## Walkthrough
```linux
ldapsearch -x -ZZ -H ldap://ldap.iamlab.test -b ou=people,dc=iamlab,dc=test '(uid=pshah)' uid uidNumber title
ldapsearch -x -ZZ -H ldap://ldap.iamlab.test -b ou=groups,dc=iamlab,dc=test '(memberUid=pshah)' cn
id pshah
mkdir -p ~/lab/m07
printf 'uid=pshah\nuidnumber=10002\ntitle=Finance Systems Analyst\ngroups=%s\ndn=uid=pshah,ou=people,dc=iamlab,dc=test\n' "$(id -nG pshah | tr ' ' '\n' | sort | paste -sd, -)" > ~/lab/m07/pshah.txt
cat ~/lab/m07/pshah.txt
lab check m07-directory-lookup
```
