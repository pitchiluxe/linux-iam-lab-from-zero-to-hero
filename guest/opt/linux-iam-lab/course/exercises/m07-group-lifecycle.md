---
id: m07-group-lifecycle
module: m07
title: Manage a project group's lifecycle in the directory
minutes: 35
prereqs: m07-directory-access
---
## Ticket
**IAM-7005** - *Approved by: Head of Engineering* - "Project Atlas starts Monday. Create the directory group `proj-atlas` (GID `10014`) with a description, add **Nadia Walker** (`nwalker`) and **Mia Fischer** (`mfischer`), and confirm Linux sees it. While you are there: the access review flagged `tmp-migration` as expired - delete it."

## Objective
Run the full group lifecycle in a central directory: **create** a group, **assign** members, **verify** from the Linux side, and **delete** an expired group. This is the same job FreeIPA, Active Directory or Entra ID admins do every day - only the tool changes.

## Before you start
Linux terminal with `sudo`. You can read the admin password file `/etc/linux-iam-lab/ldap-admin.pw` (use it with `-y`, never print it).

## Concepts and commands
**Same job, different tools.** If you meet FreeIPA at work, the commands map one to one:

| Task | FreeIPA (`ipa` CLI) | This lab (OpenLDAP) |
|---|---|---|
| create group | `ipa group-add proj-atlas --desc="..."` | `ldapadd` an entry with `objectClass: posixGroup` |
| add members | `ipa group-add-member proj-atlas --users=nwalker` | `ldapmodify` with `add: memberUid` |
| list / show | `ipa group-find`, `ipa group-show proj-atlas` | `ldapsearch '(cn=proj-atlas)'` |
| remove member | `ipa group-remove-member ...` | `ldapmodify` with `delete: memberUid` |
| delete group | `ipa group-del tmp-migration` | `ldapdelete DN` |
| what Linux sees | `id`, `getent group` (via SSSD) | `id`, `getent group` (via SSSD) |

FreeIPA (and AD) build these entries for you and add policy on top, but underneath it is still an LDAP directory and SSSD on the client.

Find what exists before you change anything:
```linux
ldapsearch -LLL -x -ZZ -H ldap://ldap.iamlab.test -b ou=groups,dc=iamlab,dc=test '(objectClass=posixGroup)' cn gidNumber description memberUid
```
Check the GID you plan to use is free - two groups with one GID is a classic, painful mistake:
```linux
ldapsearch -LLL -x -ZZ -H ldap://ldap.iamlab.test -b dc=iamlab,dc=test '(gidNumber=10014)' dn
getent group 10014
```
No output = free.

Create the group (empty, or with its first members):
```text
dn: cn=proj-atlas,ou=groups,dc=iamlab,dc=test
objectClass: posixGroup
cn: proj-atlas
gidNumber: 10014
description: Project Atlas engineers - owner Nadia Walker
```
A **description** with purpose and owner is what makes a group reviewable: in an access review nobody can defend a group whose purpose is unknown.

Add members to an existing group with `ldapmodify`:
```text
dn: cn=proj-atlas,ou=groups,dc=iamlab,dc=test
changetype: modify
add: memberUid
memberUid: nwalker
memberUid: mfischer
```

Delete a whole entry:
```linux
ldapdelete -x -ZZ -H ldap://ldap.iamlab.test -D cn=admin,dc=iamlab,dc=test -y /etc/linux-iam-lab/ldap-admin.pw cn=tmp-migration,ou=groups,dc=iamlab,dc=test
```
There is no recycle bin. Look at the entry (`ldapsearch ... '(cn=tmp-migration)'`) before you delete it, and keep that output in the ticket.

Then make Linux forget its cache and verify:
```linux
sudo sss_cache -E
getent group proj-atlas
id nwalker
```
```text
proj-atlas:*:10014:nwalker,mfischer
uid=10001(nwalker) gid=10000(dir-staff) groups=10000(dir-staff),10010(linux-login),10011(dir-engineering),10014(proj-atlas)
```

## Your task
1. Confirm GID `10014` is unused.
2. Create `cn=proj-atlas,ou=groups,dc=iamlab,dc=test` (`posixGroup`, GID `10014`, a `description`).
3. Members: exactly `nwalker` and `mfischer`.
4. Delete `cn=tmp-migration,ou=groups,dc=iamlab,dc=test` (look at it first).
5. Flush the SSSD cache and verify with `getent group` and `id`. No local group in `/etc/group`.

## Verify
`getent group proj-atlas` shows both members, `getent group tmp-migration` shows nothing. **Check my work** reads the directory and resolves through SSSD.

## If it fails
- *`Already exists (68)`*: the group exists - use `ldapmodify` to fix it instead of `ldapadd`.
- *`Type or value exists (20)`*: that member is already in the group.
- *`No such object (32)`* on delete: already gone, or a typo in the DN.
- *Linux shows old data*: `sudo sss_cache -E`.

## Hints
### Hint 1
One `ldapadd` for the new group (you can put the `memberUid:` lines straight into it), one `ldapdelete` for the old one, then `sudo sss_cache -E`.
### Hint 2
Bind for both with `-D cn=admin,dc=iamlab,dc=test -y /etc/linux-iam-lab/ldap-admin.pw`.
### Hint 3
See the Walkthrough.

## Walkthrough
```linux
ldapsearch -LLL -x -ZZ -H ldap://ldap.iamlab.test -b dc=iamlab,dc=test '(gidNumber=10014)' dn
ldapsearch -LLL -x -ZZ -H ldap://ldap.iamlab.test -b ou=groups,dc=iamlab,dc=test '(cn=tmp-migration)'
mkdir -p ~/lab/m07
cat > ~/lab/m07/atlas.ldif <<'EOF'
dn: cn=proj-atlas,ou=groups,dc=iamlab,dc=test
objectClass: posixGroup
cn: proj-atlas
gidNumber: 10014
description: Project Atlas engineers - owner Nadia Walker
memberUid: nwalker
memberUid: mfischer
EOF
ldapadd -x -ZZ -H ldap://ldap.iamlab.test -D cn=admin,dc=iamlab,dc=test -y /etc/linux-iam-lab/ldap-admin.pw -f ~/lab/m07/atlas.ldif
ldapdelete -x -ZZ -H ldap://ldap.iamlab.test -D cn=admin,dc=iamlab,dc=test -y /etc/linux-iam-lab/ldap-admin.pw cn=tmp-migration,ou=groups,dc=iamlab,dc=test
rm ~/lab/m07/atlas.ldif
sudo sss_cache -E
getent group proj-atlas
getent group tmp-migration
id nwalker
lab check m07-group-lifecycle
```
**Leaver note:** when Nadia or Mia leaves the project, remove their `memberUid` (`ldapmodify`, `delete: memberUid`). When the project ends, delete the group - that is how `tmp-migration` should have been handled.
