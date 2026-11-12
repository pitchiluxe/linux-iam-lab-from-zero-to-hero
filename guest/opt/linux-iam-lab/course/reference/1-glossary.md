---
title: Glossary
---
Linux and IAM terms used in this course, A to Z. Use the filter box to jump to a term.

### ACL (access control list)
Extra permission entries on a file or folder for named users or groups, beyond owner/group/others. Set with `setfacl`, read with `getfacl`. A `+` after the mode in `ls -l` shows a file has one.

### Access review (recertification)
A periodic check that every account still needs every entitlement it has. Evidence: reports of users, groups, sudo rules and keys, plus the reviewer's decisions.

### Account expiry
The date after which an account cannot log in at all (any method). Set with `chage -E YYYY-MM-DD`; `chage -E 0` expires now. Different from **password** expiry.

### AllowGroups / AllowUsers
sshd settings that restrict which accounts may log in over SSH. Anyone not matched is refused even with a valid key.

### auid (audit user ID)
The login user recorded by the audit system. It stays the same after `sudo` or `su`, so it shows who really acted.

### auditd
The Linux audit daemon. Records kernel-level events (file watches, commands, logins) to `/var/log/audit/audit.log`. Tools: `auditctl`, `augenrules`, `ausearch`, `aureport`.

### Authentication (authN)
Proving who you are: password, key, token, MFA. In Linux: the PAM `auth` phase.

### Authorization (authZ)
Deciding what an authenticated identity may do: log in here, read this file, run that command. In Linux: PAM `account` phase, sshd `AllowGroups`, sudo rules, file permissions.

### authorized_keys
`~/.ssh/authorized_keys`: the list of public keys allowed to log in as that user. One key per line.

### Break-glass
A controlled, logged emergency path to regain administrative access when normal paths fail. In the lab: `lab rescue ...`.

### Directory (LDAP directory)
A central database of people, groups and devices (Active Directory, OpenLDAP, FreeIPA). Servers look identities up instead of keeping their own copies.

### DN (distinguished name)
The full name of an LDAP entry, read right to left from the top of the tree: `uid=pshah,ou=people,dc=iamlab,dc=test`.

### Entitlement
A specific permission or role granted to an identity (a group membership, a sudo rule, an ACL entry).

### Expiry (password)
When a password must be changed. `chage -M` (max days), `chage -d 0` (must change now).

### faillock (pam_faillock)
The PAM module that counts failed passwords and locks an account after a threshold. `faillock --user NAME [--reset]`.

### Fingerprint
A short hash of a public key (`SHA256:...`) used to verify it over another channel. `ssh-keygen -lf FILE`.

### GECOS / comment
The 5th field of `/etc/passwd`, normally the full name and role. Use it to document who an account belongs to.

### GID (group ID)
The number the kernel uses for a group. Primary GID is in `/etc/passwd`; group names and members in `/etc/group`.

### Group (primary vs supplementary)
**Primary**: one per user, owns the files they create. **Supplementary**: extra groups listed in `/etc/group`; used as roles.

### Home directory
A user's personal folder, usually `/home/NAME`. Should not be writable by others (sshd StrictModes checks this).

### Host key
The SSH server's own key pair. Clients remember its fingerprint in `known_hosts` to detect impersonation.

### IAM (identity and access management)
The discipline of making sure the right identities have the right access, for the right reasons, for the right time - and that it is provably so.

### Joiner-Mover-Leaver (JML)
The identity lifecycle: create with correct access (joiner), change roles and remove old ones (mover), disable promptly and completely (leaver).

### Least privilege
Grant only the access needed for the task, for only as long as needed.

### Locked account / locked password
`passwd -l` / `usermod -L` puts `!` before the password hash: password logins fail. **SSH keys may still work** - expire the account to stop everything.

### Login shell
The program started when a user logs in interactively (field 7 of `/etc/passwd`). `/usr/sbin/nologin` refuses interactive logins.

### LDIF
Text format for LDAP entries and changes, used by `ldapadd` / `ldapmodify`.

### Mask (ACL mask)
The ACL entry that limits the maximum permissions of named users, named groups and the owning group.

### Non-human identity (service account)
An account used by software, not a person. Should have a system UID, no login shell, no usable password, a documented owner.

### NSS (Name Service Switch)
How Linux finds users and groups. `/etc/nsswitch.conf` lists sources (`files`, `systemd`, `sss`). `getent` queries it.

### Orphaned file
A file whose owner UID no longer matches any account (shown as a number in `ls -l`). Find with `find -nouser`.

### PAM (Pluggable Authentication Modules)
The framework programs use to authenticate users, check accounts, open sessions and change passwords. Config in `/etc/pam.d/`.

### Permission bits
`r` read, `w` write, `x` execute/traverse, for owner, group and others. Octal: r=4, w=2, x=1.

### Privilege creep
Accumulating access over time (usually via moves) that is no longer needed.

### Private key / public key
A key pair: the private key stays with its owner and proves identity; the public key is shared and placed in `authorized_keys`.

### Revocation
Removing access: deleting a key, a group membership, a sudo rule, or expiring an account. Must be complete and verified.

### RevokedKeys
sshd setting pointing to a file of public keys that are refused for every account.

### Root
The superuser, UID 0. Can do anything. Use `sudo` for specific tasks instead of logging in as root.

### Service
A background program managed by systemd (`systemctl status NAME`). Runs as the account in its unit file's `User=`.

### setgid (directory)
Bit `2xxx` / `g+s`: new files in the folder inherit the folder's group. Used for team folders.

### Shadow file
`/etc/shadow`: password hashes and ageing data. Readable only by root and group `shadow`.

### SSSD
System Security Services Daemon: connects NSS and PAM to a directory, caches identities, enforces access rules.

### StartTLS / TLS
Encryption for network protocols. `ldapsearch -ZZ` requires StartTLS; SSSD verifies the directory's certificate.

### Sticky bit
Bit `1xxx` / `+t` on a folder: only a file's owner can delete it (e.g. `/tmp`).

### StrictModes
sshd setting (default yes) that ignores `authorized_keys` if the home, `.ssh` or the file are writable by others.

### sudo
Runs a command as another user (usually root) according to rules in `/etc/sudoers` and `/etc/sudoers.d/`, and logs it.

### sudoers / visudo
The sudo policy files and the safe editor that refuses to save syntax errors.

### UID (user ID)
The number the kernel uses for a user. `0` root, `1-999` system, `1000+` people (Ubuntu). This lab: staff `2001+`, directory `10001+`.

### umask
The permission bits removed from newly created files. `022` → files `644`; `027` → files `640`.

### UPG (user private group)
Ubuntu creates a primary group with the same name as each new user.

### World-writable
Writable by "others" (any account): mode ends in `2`, `3`, `6` or `7`. Almost always a finding for data files.
