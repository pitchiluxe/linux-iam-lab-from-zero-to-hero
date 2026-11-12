# Profile → Projects section (one entry per repo)

Format for each: **Problem → What I did → Result**. Add the repo URL and one screenshot as media. Associate with "Linux IAM Lab From Zero To Hero".

---

## Linux Contractor Access Lifecycle
Contractors get access in a hurry and keep it after they leave. On my own Ubuntu server I onboarded a contractor with key-only SSH, an expiry date, two groups and one sudo rule for one command; diagnosed a broken login from the SSH log ([your root cause]); and revoked everything on the last day while keeping the account for the audit. Every step was tested as the contractor, allowed and denied, and summed up in a generated test report.
**Skills:** Linux · sudo · OpenSSH · Identity Lifecycle · Least Privilege
**URL:** https://github.com/pitchiluxe/linux-contractor-access-lifecycle

## Linux Access Report (Bash)
Access reviews start with "who can log in, and who has sudo?". I wrote a read-only Bash script that reports every human account's groups, shell, password status, expiry and sudo rights as a timestamped CSV, verified to change nothing on the system. In the lab it flagged an expired contractor who still had a group and a usable password.
**Skills:** Bash · Linux · Access Reviews · Audit · Automation
**URL:** https://github.com/pitchiluxe/linux-access-report

## Linux SSH and sudo Hardening
Too much sudo and open SSH are the two fastest ways to lose a Linux server. I replaced a helpdesk sudo rule that allowed an editor as root with one that allows a single service restart, applied an SSH baseline (no root login, group allow-list, limits), and revoked a stolen laptop's key so it stays refused even if re-added, then proved each change with allowed and denied tests.
**Skills:** sudo · OpenSSH · Linux Hardening · Least Privilege
**URL:** https://github.com/pitchiluxe/linux-ssh-sudo-hardening
