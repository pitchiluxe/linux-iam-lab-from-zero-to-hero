---
id: m09-capstone
module: m09
title: Contractor Jordan Lee - onboard, fix, revoke, evidence
minutes: 90
prereqs: m03-offboard, m05-delegate, m06-key-login, m08-evidence
---
## Ticket
Four tickets arrive one after another. The check moves you to the next one when the current one is done.

**CAP-9001 - Onboard contractor** - *Approved by: Ben Tran (Falcon project lead) and Head of IT Operations*
"Jordan Lee joins Project Falcon as a contractor until **31 March 2027**.
- Account `jlee`, comment `Jordan Lee - Contractor (Falcon) CAP-9001`, shell `/bin/bash`, private home folder.
- Roles: `proj-falcon` and `ssh-users`. Nothing else.
- **Key-only** login: no usable password. Public key: `/opt/lab-data/capstone/jlee_laptop.pub` (verify the fingerprint in `/opt/lab-data/capstone/CAP-9001.txt`).
- Jordan may restart the Falcon web service without a password (`systemctl restart falcon-web.service`) - nothing else as root. Put the rule in `/etc/sudoers.d/70-cap9001-jlee`.
- Must be able to create and edit files in `/srv/projects/falcon`. Must **not** see Finance or HR data."

**CAP-9002 - "Permission denied (publickey)"** - arrives after CAP-9001. Jordan reports that the key login stopped working. Find the cause and fix it without granting anything extra.

**CAP-9003 - Contract terminated** - arrives after CAP-9002. Revoke all of Jordan's access today. Keep the account and archive the home folder to `/srv/archive/offboarded/jlee-home.tar.gz` (legal hold).

**CAP-9004 - Evidence** - Write `~/capstone/evidence/notes.md` describing what you did for each ticket (mention CAP-9001, CAP-9002 including the **root cause**, and CAP-9003), then run `lab capstone evidence` to generate the test report.

## Objective
Demonstrate the full identity lifecycle on Linux for a privileged contractor: grant exactly the approved access, troubleshoot from evidence, revoke completely, and prove each step with allowed **and** denied tests.

## Before you start
Linux terminal with `sudo`. `lab capstone status` prints the current ticket. Every requirement maps to something you practised; the hints point to the module.

## Concepts and commands
The check runs this **test matrix** as Jordan, for real:

| Stage | Must be ALLOWED | Must be DENIED |
|---|---|---|
| after CAP-9001 / CAP-9002 | SSH login with Jordan's key; create a file in `/srv/projects/falcon`; `sudo -n systemctl restart falcon-web.service` | read `/srv/finance/budget-2027.csv`; list `/srv/hr`; `sudo -n systemctl stop falcon-web.service`; `sudo -n cat /etc/shadow`; password login |
| after CAP-9003 | (nothing) | SSH key login; any sudo; writing to `/srv/projects/falcon` |

Run the same tests yourself while you work:
```linux
sudo -u jlee touch /srv/projects/falcon/jlee-test.txt
sudo -u jlee cat /srv/finance/budget-2027.csv
sudo -l -U jlee
sudo -u jlee sudo -n /usr/bin/systemctl restart falcon-web.service
sudo -u jlee sudo -n /usr/bin/systemctl stop falcon-web.service
```
`sudo -u jlee sudo -n ...` runs sudo **as Jordan**; `-n` (non-interactive) fails instead of asking for a password, which proves the NOPASSWD scope.

```linux
lab capstone status
lab check m09-capstone
lab capstone evidence
```

## Your task
Complete CAP-9001 to CAP-9004 in order. Run **Check my work** after each ticket.

## Verify
Each successful check prints the stage's ALLOWED/DENIED results and saves them under `/var/lib/linux-iam-lab/capstone-results/`. The final report lands in `~/capstone/evidence/`.

## If it fails
- *CAP-9001 groups wrong*: exactly `proj-falcon` and `ssh-users` (plus Jordan's private group).
- *password login allowed*: lock it - `usermod -L` - and do not set one.
- *sudo restart asks for a password*: `NOPASSWD:` must be in the rule; validate with `visudo -cf`.
- *CAP-9002*: start with `sudo journalctl -u ssh -n 30 --no-pager`, then `sudo chage -l jlee`, `getent passwd jlee`, `sudo namei -l /home/jlee/.ssh/authorized_keys`, and compare fingerprints.
- *CAP-9003 key login still works*: expire the account and remove the key; check `sshd` logs.

## Hints
### Hint 1
CAP-9001 is module 3 (`useradd -m -c ... -s ... -G ... -e ...`, then `usermod -L`), module 6 (`install` the key with 700/600 owned by jlee) and module 5 (`visudo -f /etc/sudoers.d/70-cap9001-jlee`). CAP-9003 is the leaver procedure from m03-offboard plus deleting the sudo rule.
### Hint 2
The sudo rule is one line: `jlee ALL=(root) NOPASSWD: /usr/bin/systemctl restart falcon-web.service`. For CAP-9002 the server log names the problem; four kinds of fault are possible (key file permissions, account expiry, login shell, wrong key).
### Hint 3
See the Walkthrough. It covers CAP-9001 and CAP-9003 completely, and how to diagnose each possible CAP-9002 fault.

## Walkthrough
**CAP-9001**
```linux
cat /opt/lab-data/capstone/CAP-9001.txt
ssh-keygen -lf /opt/lab-data/capstone/jlee_laptop.pub
sudo useradd -m -c "Jordan Lee - Contractor (Falcon) CAP-9001" -s /bin/bash -G proj-falcon,ssh-users -e 2027-03-31 jlee
sudo usermod -L jlee
sudo chmod 750 /home/jlee
sudo install -d -m 700 -o jlee -g jlee /home/jlee/.ssh
sudo install -m 600 -o jlee -g jlee /opt/lab-data/capstone/jlee_laptop.pub /home/jlee/.ssh/authorized_keys
echo 'jlee ALL=(root) NOPASSWD: /usr/bin/systemctl restart falcon-web.service' | sudo tee /tmp/70-cap9001-jlee
sudo visudo -cf /tmp/70-cap9001-jlee && sudo install -m 440 -o root -g root /tmp/70-cap9001-jlee /etc/sudoers.d/70-cap9001-jlee
sudo visudo -c
sudo -u jlee touch /srv/projects/falcon/jlee-test.txt
sudo -u jlee cat /srv/finance/budget-2027.csv
sudo -u jlee sudo -n /usr/bin/systemctl restart falcon-web.service
sudo -u jlee sudo -n /usr/bin/systemctl stop falcon-web.service
lab check m09-capstone
```
**CAP-9002** - read the log, then match the symptom:
```linux
sudo journalctl -u ssh -n 30 --no-pager | grep -i jlee
sudo namei -l /home/jlee/.ssh/authorized_keys
sudo chage -l jlee | grep 'Account expires'
getent passwd jlee | cut -d: -f7
sudo ssh-keygen -lf /home/jlee/.ssh/authorized_keys; ssh-keygen -lf /opt/lab-data/capstone/jlee_laptop.pub
```
| Log / finding | Fix |
|---|---|
| `bad ownership or modes` | `sudo chown -R jlee:jlee /home/jlee/.ssh && sudo chmod 700 /home/jlee/.ssh && sudo chmod 600 /home/jlee/.ssh/authorized_keys` |
| `User account has expired` / expiry in the past | `sudo chage -E 2027-03-31 jlee` |
| shell `/usr/sbin/nologin` | `sudo usermod -s /bin/bash jlee` |
| fingerprints differ | `sudo install -m 600 -o jlee -g jlee /opt/lab-data/capstone/jlee_laptop.pub /home/jlee/.ssh/authorized_keys` |
```linux
lab check m09-capstone
```
**CAP-9003**
```linux
sudo usermod -L -e 1 -s /usr/sbin/nologin jlee
sudo usermod -G "" jlee
sudo rm /etc/sudoers.d/70-cap9001-jlee && sudo visudo -c
sudo rm -f /home/jlee/.ssh/authorized_keys
sudo crontab -r -u jlee 2>/dev/null; sudo pkill -KILL -u jlee
sudo mkdir -p /srv/archive/offboarded && sudo tar -czf /srv/archive/offboarded/jlee-home.tar.gz -C /home jlee
sudo -l -U jlee
lab check m09-capstone
```
**CAP-9004**
```linux
mkdir -p ~/capstone/evidence
nano ~/capstone/evidence/notes.md
```
```text
# Capstone evidence - Jordan Lee (jlee)
## CAP-9001 onboarding
Created jlee (expires 2027-03-31), roles proj-falcon + ssh-users, key-only (password locked),
sudo rule /etc/sudoers.d/70-cap9001-jlee: restart falcon-web only. Tested allowed and denied actions.
## CAP-9002 broken login
Root cause: <what the log showed>. Fix: <command>. Re-tested key login.
## CAP-9003 revocation
Locked + expired, shell nologin, groups removed, sudo rule deleted, key removed, sessions killed,
home archived to /srv/archive/offboarded/jlee-home.tar.gz. Account kept for legal hold.
```
```linux
lab capstone evidence
lab check m09-capstone
```
