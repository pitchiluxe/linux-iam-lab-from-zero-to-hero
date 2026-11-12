# Post: starting the lab

**Image:** [`images/linux-lab-desktop.png`](images/linux-lab-desktop.png) (the lab VM with the terminal and the course open), or a photo of your setup.

---

Most servers that run the internet are Linux.
Most IAM training only covers Windows and the cloud.

So for the next [N] weeks I'm learning Identity & Access Management on Linux, by building it, not by reading about it.

The setup:
🐧 My own Ubuntu Server VM
🏢 A fictional company with real accounts, groups and shared folders
🔑 sudo, SSH keys, PAM and an LDAP directory through SSSD
✅ 32 tickets, each checked by testing the access as the user

The goal is the work an IAM analyst does with Linux in year one:
1️⃣ Onboard, move and offboard people properly
2️⃣ Get file permissions and ACLs right
3️⃣ Delegate one command with sudo, not the whole server
4️⃣ Lock down SSH and revoke a stolen key
5️⃣ Audit it all, and automate the report

It ends with a capstone: onboard a contractor, fix their broken login, revoke everything, hand over the evidence.

I'll post what I build, what breaks, and what I learn.

If you work in IAM or Linux: what's one thing you wish juniors knew on day one? 👇

#IAM #Linux #CyberSecurity #IdentityAndAccessManagement #LearningInPublic
