# Repo "About" box: description + topics

Paste into each repo's ⚙️ About settings (top right of the repo page).

## linux-contractor-access-lifecycle
**Description:** Onboard, troubleshoot, revoke and evidence a contractor's access on Linux: one sudo rule, key-only SSH, expiry, and allowed/denied tests run as the user.
**Topics:** `iam` `linux` `identity-lifecycle` `least-privilege` `sudo` `openssh` `access-control` `offboarding`

## linux-access-report
**Description:** Read-only Bash access report for Linux: who can log in, groups, password status, expiry and sudo, one timestamped CSV per run.
**Topics:** `bash` `linux` `access-review` `audit` `iam` `identity-governance` `automation`

## linux-ssh-sudo-hardening
**Description:** SSH and sudo least privilege on Linux: drop-in configs with a reason on every line, key revocation, and tests that prove allowed and denied.
**Topics:** `openssh` `sudo` `linux-hardening` `least-privilege` `security` `iam` `ubuntu`

## Pin order on your profile

1. `linux-contractor-access-lifecycle` (the capstone: strongest story)
2. `linux-access-report` (code a reviewer can run)
3. `linux-ssh-sudo-hardening`
4–6. Your Windows/Entra/Okta lab repos (`iam-jml-automation` first), if you published them.
