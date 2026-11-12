# Post: the stolen laptop (after Module 6)

**Image:** a redacted terminal screenshot of the revoked key being refused, or a simple 3-box diagram: laptop → authorized_keys → RevokedKeys.
**First comment:** `Config files with a reason on every line: https://github.com/pitchiluxe/linux-ssh-sudo-hardening`

---

An engineer's laptop gets stolen. It has his SSH key on it.

Most people delete the key from authorized_keys and close the ticket.

But anyone with his password can log in and add the key straight back.

What I did in my Linux IAM lab:
🔑 Removed the stolen key from his account
🚫 Added it to sshd's RevokedKeys list, so the server refuses it for every account, even if it is added back
✅ Tested his new key: ALLOWED
⛔ Tested the stolen key, after re-adding it on purpose: DENIED

And the baseline that should be on every server anyway:
• No direct root login
• 3 attempts, 30 seconds to log in
• Only members of one group may use SSH

The habit that saved me: sshd -t before every reload, and a second session open. [Or your own "I locked myself out" story.]

Details in the comments 👇

#Linux #SSH #IAM #CyberSecurity #AccessManagement
