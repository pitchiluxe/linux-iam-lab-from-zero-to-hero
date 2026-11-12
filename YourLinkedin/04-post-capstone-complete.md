# Post: capstone complete (the "post once" from the homework; pin it to Featured)

**Image:** a screenshot of an **allowed** and a **denied** test. Use [`images/allowed-denied-sudo-test.png`](images/allowed-denied-sudo-test.png), or better, your own `lab check m09-capstone` result. Crop out your Windows username and browser tabs.
**First comment:** `Runbook, sudo rule and the full test report: https://github.com/pitchiluxe/linux-contractor-access-lifecycle`

---

A contractor joins on Monday. The contract ends in March.
Here's the part most teams get wrong: everything in between, and the day after.

I just finished the capstone of my Linux IAM lab, end to end, on my own Ubuntu server:

1️⃣ Onboard: key-only SSH, an expiry date, two groups, and one sudo rule for one command
2️⃣ Troubleshoot: "he can't log in". The log said [your error]. Root cause: [your root cause].
3️⃣ Revoke: lock, expire, remove the shell, groups, sudo rule, key, processes and cron jobs. Archive the home folder. Keep the account for the audit.
4️⃣ Evidence: a test report an auditor can read

Every step was tested as the contractor:
✅ ALLOWED: SSH with his key, write to the project share, restart the web app
⛔ DENIED: Finance files, HR files, stopping the service, /etc/shadow, password login
⛔ After revocation: everything

The one thing it taught me: [one sentence, e.g. "Revocation isn't one command, it's a checklist. The account was locked, but his cron job would have kept running."]

Next: [LFCS / CompTIA Linux+].

Runbook and test report in the comments 👇

#IAM #Linux #IdentityAndAccessManagement #CyberSecurity #LeastPrivilege
