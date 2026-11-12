---
id: m03-lockout
module: m03
title: Two locked-out users - unlock one, refuse the other
minutes: 25
prereqs: m03-inspect-identities
---
## Ticket
**HELP-3005** - *From: Service Desk* -
1. "Eli Novak (`enovak`) says he can't log in after typing an old password a few times. The desk verified his identity by calling him back on his registered number. Please investigate and unlock."
2. "Kai Wright (`kwright`) also says his login stopped working and asks us to unlock it."

Record your decisions in `~/lab/m03/lockout.txt`.

## Objective
Tell apart the reasons a login fails (failed-attempt lockout, locked password, expired account), fix the one that is legitimate, and refuse the one that is not.

## Before you start
Linux terminal with `sudo`. Policy: 5 failures in 15 minutes lock an account until an admin resets it.

## Concepts and commands
```linux
sudo faillock --user enovak
```
Lists recorded failures. `V` in the last column means the record counts towards the lock.
```text
enovak:
When                Type  Source                                           Valid
2026-11-11 10:01:02 RHOST 127.0.0.1                                            V
...
```

```linux
sudo grep enovak /var/log/auth.log | tail -5
```
The authentication log shows *why*:
```text
... pam_unix(sshd:auth): authentication failure; ... user=enovak
... pam_faillock(sshd:auth): Consecutive login failures for user enovak account temporarily locked
```

```linux
sudo passwd -S enovak
sudo chage -l kwright
```
Rule out other causes: is the password itself locked (`L`)? Is the **account** expired?
```text
Account expires                                         : Dec 31, 2025
```
An expired account is a business decision (the contract ended), not a technical fault.

```linux
sudo faillock --user enovak --reset
```
Clears the failure records, which unlocks the account. It does **not** change the password.

## Your task
1. Find out why `enovak` cannot log in and fix it with the least change (do not change his password).
2. Find out why `kwright` cannot log in. Decide whether to unlock him.
3. Create `~/lab/m03/lockout.txt`:
```text
enovak_cause=<faillock, password-locked or expired>
kwright_cause=<faillock, password-locked or expired>
kwright_action=<unlock or deny>
```

## Verify
`sudo faillock --user enovak` shows no valid failures. **Check my work** logs in as `enovak` with his real (lab-held) password, and confirms `kwright` is still refused.

## If it fails
- *enovak still locked*: reset with `faillock --reset`; `usermod -U` only helps if the **password** was locked.
- *kwright login now works*: you changed his expiry. The contract ended: set it back with `sudo chage -E 2025-12-31 kwright`.

## Hints
### Hint 1
Check three things for each user: `sudo faillock --user NAME`, `sudo passwd -S NAME`, `sudo chage -l NAME`.
### Hint 2
One user has failure records; the other has an account expiry date in the past. Only one of those is a fault you should fix.
### Hint 3
`sudo faillock --user enovak --reset`; leave `kwright` alone. Answers: `enovak_cause=faillock`, `kwright_cause=expired`, `kwright_action=deny`.

## Walkthrough
```linux
sudo faillock --user enovak
sudo grep -E 'enovak' /var/log/auth.log | tail -5
sudo passwd -S enovak
sudo chage -l enovak | grep 'Account expires'
sudo faillock --user enovak --reset
sudo faillock --user enovak
sudo faillock --user kwright
sudo passwd -S kwright
sudo chage -l kwright | grep 'Account expires'
mkdir -p ~/lab/m03
printf 'enovak_cause=faillock\nkwright_cause=expired\nkwright_action=deny\n' > ~/lab/m03/lockout.txt
lab check m03-lockout
```
**Reply to the desk:** "enovak: locked by 6 failed attempts (faillock), reset after identity verification. kwright: account expired 2025-12-31 at contract end - unlock needs a new approved contract (new ticket), not a helpdesk reset."
