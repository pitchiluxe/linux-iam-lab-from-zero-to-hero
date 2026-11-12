# Linux Access Report

> A read-only Bash script that answers the first question of every access review: **who can log in to this server, with which groups, and who has sudo?** One CSV per run, timestamped, never overwritten.

## What it checks

For every human account (UID 1000–59999):

| Column | Source | Why an auditor cares |
| --- | --- | --- |
| `user`, `uid` | `getent passwd` | who exists, including directory (LDAP/SSSD) users |
| `primary_group`, `groups` | `id` | role membership: is it still right for the job? |
| `shell` | `getent passwd` | `/usr/sbin/nologin` means no interactive login |
| `password_status` | `passwd -S` | `P` usable, `L` locked, `NP` no password (a finding) |
| `account_expires` | `chage -l` | contractors must have an end date |
| `sudo` | `sudo -l -U` | anyone who can run anything as root |

## How to run it

```bash
chmod +x access-report.sh
sudo ./access-report.sh                 # writes to ~/reports/
sudo ./access-report.sh /srv/audit/q4   # or any folder
```

Output:

```
/root/reports/access-report-20261112-155610.csv
```

Every run creates a new timestamped file and refreshes `access-report-latest.csv`, so you can compare this quarter with last quarter (`diff`).

## Why it changes nothing

- It only **reads**: `getent`, `id`, `passwd -S`, `chage -l`, `sudo -l -U`.
- It only **writes** its own CSV files, in the output folder.
- `set -euo pipefail`: it stops at the first error instead of producing a half-right report.
- Tested: SHA-256 of `/etc/passwd`, `/etc/group`, `/etc/shadow` and `/etc/gshadow` is identical before and after two runs.

It needs `sudo` only because `passwd -S` and `chage -l` read `/etc/shadow` for other users.

## Sample output (real run, fictional people)

[`sample/access-report-sample.csv`](sample/access-report-sample.csv), from the lab VM:

```csv
user,uid,primary_group,groups,shell,password_status,account_expires,sudo
dpatel,2006,dpatel,helpdesk,/bin/bash,P,never,yes
jlee,2010,jlee,,/usr/sbin/nologin,L,1970-01-02,no
kwright,2009,kwright,proj-falcon,/bin/bash,P,2025-12-31,no
rmorgan,2007,rmorgan,auditors,/bin/bash,P,never,yes
```

What a reviewer reads from those four lines:

- **jlee**: offboarded correctly. Locked, expired, no shell, no groups, no sudo, account kept for the audit trail.
- **kwright**: contract ended 2025-12-31, so the expiry blocks login, but he is still in `proj-falcon` with a usable password and a shell. Clean-up finding.
- **dpatel**, **rmorgan**: sudo = yes. Check with `sudo -l -U <user>` that it is the narrow, approved rule, not full root.

## Limits (on purpose)

- One server at a time; for a fleet, run it with Ansible or ship the CSV to a central place.
- `sudo` = yes/no only. Use `sudo -l -U <user>` for the exact commands.
- Directory users appear only if SSSD enumerates them, or if they have logged in.

---
Built in the *Linux IAM Lab From Zero To Hero*. Tested on Ubuntu Server 24.04. All accounts in the sample are fictional.
