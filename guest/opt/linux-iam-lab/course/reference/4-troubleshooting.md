---
title: IAM troubleshooting guide
---
A symptom-first guide for access tickets on Linux. Always: **reproduce as the user**, **read the log**, **change the smallest thing**, **re-test allowed and denied**.

### Method: the five questions
1. **Who exactly?** `id USER`, `getent passwd USER` - right account, right UID, local or directory?
2. **Is the account usable?** `sudo passwd -S USER`, `sudo chage -l USER`, `sudo faillock --user USER`, shell in `getent passwd`.
3. **Is it authentication or authorization?** Wrong password/key (auth) vs "not allowed" (account phase, AllowGroups, sudo rule, file permission).
4. **What does the server log say?** `sudo journalctl -u ssh -n 50`, `sudo grep USER /var/log/auth.log | tail`, `sudo journalctl _COMM=sudo`, `sudo journalctl -u sssd`.
5. **What changed?** Recent tickets, `sudo ausearch -k identity -i --start today`, file modification times (`ls -l --time-style=full-iso`).

### "Permission denied" reading or writing a file
- Reproduce: `sudo -u USER cat FILE` / `sudo -u USER touch DIR/test`.
- `namei -l /full/path/FILE`: every directory needs `x` for the user's class (owner/group/other); the file needs `r` (read) or `w` (write).
- `id USER`: is the user in the file's group? Group changes need a **new login** for interactive users.
- `getfacl FILE`: an ACL `mask` can reduce effective rights (`#effective:` in the output).
- Fix narrowly (`chmod g+x DIR`, `setfacl -m u:USER:r FILE`), never `chmod 777`.

### New files in a team folder are not editable by teammates
Missing setgid on the folder (files get the creator's group) and/or users' `umask 022`. Fix: `chmod 2770 DIR` and `setfacl -d -m g:GROUP:rwX DIR`.

### SSH: "Permission denied (publickey)"
Read the server log first: `sudo journalctl -u ssh -n 30 --no-pager`.

| Log line | Cause | Fix |
|---|---|---|
| `Authentication refused: bad ownership or modes for ...` | home / `.ssh` / `authorized_keys` writable by others, or wrong owner | `chmod go-w ~USER`, `chmod 700 ~/.ssh`, `chmod 600 authorized_keys`, `chown USER:` |
| `User X from Y not allowed because none of user's groups are listed in AllowGroups` | not in the SSH access group | add to the group (if approved) |
| `User account has expired` / `Account X has expired` | account expiry in the past | renew only with approval: `chage -E DATE` |
| no line about the user's key at all | key not in `authorized_keys`, or a different key | compare `ssh-keygen -lf` of both |
| `Failed publickey ... ED25519 SHA256:...` then `refusing previously-used key`/`revoked` | key in `RevokedKeys` | by design |
| `User X not allowed because shell /usr/sbin/nologin does not exist`/ client: `This account is currently not available` | nologin shell | intended for disabled/service accounts |
Client side detail: `ssh -v USER@HOST` shows which keys were offered.

### SSH: "REMOTE HOST IDENTIFICATION HAS CHANGED"
The server's host key differs from the remembered one. Verify the new fingerprint with the server owner (`ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub` on the server) **before** removing the old entry (`ssh-keygen -R HOST`). For this lab the key is pinned by the installer; this message after a reinstall means the VM was rebuilt - re-run the installer.

### SSH: locked yourself out after changing sshd_config
Use a console path (here: the portal web terminal, which does not use SSH). `sudo sshd -t` shows the error; `sudo sshd -T -C user=YOU,host=x,addr=10.0.2.2` shows effective `allowgroups`/`allowusers`. Lab break-glass: `lab rescue sshd`.

### Password login fails
- `sudo faillock --user USER`: locked by failures? Reset after verifying identity.
- `sudo passwd -S USER`: `L` = locked password.
- `sudo chage -l USER`: expired account or expired password (`password must be changed`).
- Directory user: `sudo sssctl user-checks USER`; `journalctl -u sssd`.

### Correct password but "access denied" (directory user)
Authorization in the PAM account phase. Check `/etc/sssd/sssd.conf` `access_provider` / `simple_allow_groups`, the user's groups in the directory (`ldapsearch ... '(memberUid=USER)'`), then `sudo sss_cache -E`.

### Directory user not found by `id` / `getent`
`grep sss /etc/nsswitch.conf`; `systemctl status sssd`; `sudo sssctl domain-status iamlab.test`; TLS problems appear as `Could not start TLS encryption` in `journalctl -u sssd` (certificate name must match `ldap.iamlab.test`). Clear the cache: `sudo sss_cache -E`.

### sudo: "USER is not in the sudoers file" / "not allowed to execute"
`sudo -l -U USER` lists rules; check group rules (`%group`) with `id USER`. Commands match **exact paths and arguments** - `/usr/bin/systemctl restart x` does not cover `systemctl restart x.service` unless written that way.

### sudo: "parse error" / "syntax error"
`sudo visudo -c` names the file and line; fix with `sudo visudo -f FILE`. If sudo refuses to run: console/root access, or in the lab `lab rescue sudoers`.

### sudo asks for a password in a script
Use `sudo -n` to fail instead of hanging; grant `NOPASSWD:` only for narrowly scoped automation commands.

### Leaver can still log in with an SSH key
A password lock does not stop keys. Expire the account (`chage -E 0`), set shell `nologin`, remove `authorized_keys`, kill sessions (`pkill -KILL -u USER`).

### Account changes "don't apply"
The user's existing session keeps its old groups - log out/in, or check with a fresh `sudo -u USER id`. For directory users, SSSD caches: `sudo sss_cache -E`.

### Audit rules not recording
`sudo auditctl -l` (rules active?), `systemctl status auditd`, rules files in `/etc/audit/rules.d/` loaded with `sudo augenrules --load`. Search by key: `sudo ausearch -k KEY -i`.

### Lab-specific: the portal or terminal is not working
On Windows: run **Start Linux IAM Lab** again (it waits for all services). In Linux: `lab status`, `lab rescue terminal`. Still broken: **Reset Linux IAM Lab** (exports your work first). Install/Start logs: `%LOCALAPPDATA%\LinuxIAMLab\logs`.

### Lab-specific: the tutor says it is offline
Lessons, hints and checks keep working. In Linux: `systemctl status ollama`, `ollama list` (model present?), `sudo lab tutor-pull` (needs internet once). The tutor runs on CPU: answers can take 10-60 seconds.
