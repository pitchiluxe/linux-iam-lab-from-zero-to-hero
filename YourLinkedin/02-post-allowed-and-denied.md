# Post: allowed AND denied (after Modules 4–5)

**Image:** [`images/allowed-denied-sudo-test.png`](images/allowed-denied-sudo-test.png) (real check output: one ALLOWED, two DENIED). Swap in your own screenshot if you have one.
**First comment:** `The sudo rule, with a note on every line: https://github.com/pitchiluxe/linux-ssh-sudo-hardening`

---

"Can you give the helpdesk sudo so they can restart the web app?"

The fast answer adds them to the sudo group. Now they can do anything as root.

The IAM answer is one line:

%helpdesk ALL=(root) /usr/bin/systemctl restart falcon-web.service

Then you test it as the person, in both directions:
✅ ALLOWED: restart the web app
⛔ DENIED: stop it
⛔ DENIED: read /etc/shadow

The denied lines matter as much as the allowed one. "It works" only tells you the access is there. It doesn't tell you the access stops where it should.

3 things I learned:
1. Full paths and exact arguments, or sudo matches more than you meant.
2. Never put an editor or a pager in a sudo rule: vim can open a root shell.
3. [Your lesson]

Rule and tests in the comments 👇

#IAM #Linux #LeastPrivilege #sudo #CyberSecurity
