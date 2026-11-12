# Runbook: contractor access on Linux

Every command was run on the lab VM (Ubuntu Server 24.04). **Lab only, never on a production server.**

## 1. Onboard (CAP-9001)

```bash
# Verify the key you were given is the key in the ticket
ssh-keygen -lf jlee_laptop.pub

sudo useradd -m -c "Jordan Lee - Contractor (Falcon) CAP-9001" -s /bin/bash \
     -G proj-falcon,ssh-users -e 2027-03-31 jlee
sudo usermod -L jlee                      # key-only: no usable password
sudo chmod 750 /home/jlee                 # private home
sudo install -d -m 700 -o jlee -g jlee /home/jlee/.ssh
sudo install -m 600 -o jlee -g jlee jlee_laptop.pub /home/jlee/.ssh/authorized_keys

# One sudo rule, validated before it goes live
echo 'jlee ALL=(root) NOPASSWD: /usr/bin/systemctl restart falcon-web.service' | sudo tee /tmp/70-cap9001-jlee
sudo visudo -cf /tmp/70-cap9001-jlee && sudo install -m 440 -o root -g root /tmp/70-cap9001-jlee /etc/sudoers.d/70-cap9001-jlee
sudo visudo -c
```

## 2. Prove it, as Jordan (allowed AND denied)

```bash
sudo -u jlee touch /srv/projects/falcon/jlee-test.txt                    # allowed
sudo -u jlee sudo -n /usr/bin/systemctl restart falcon-web.service       # allowed
sudo -u jlee cat /srv/finance/budget-2027.csv                            # denied
sudo -u jlee sudo -n /usr/bin/systemctl stop falcon-web.service          # denied
sudo -l -U jlee                                                          # what sudo will allow
```

`sudo -n` fails instead of prompting, which proves the rule needs no password and covers only that command.

## 3. Troubleshoot a broken key login (CAP-9002)

```bash
sudo journalctl -u ssh -n 30 --no-pager | grep -i jlee     # read the log first
sudo namei -l /home/jlee/.ssh/authorized_keys              # ownership and modes on every folder
sudo chage -l jlee | grep 'Account expires'                # expiry
getent passwd jlee | cut -d: -f7                           # login shell
sudo ssh-keygen -lf /home/jlee/.ssh/authorized_keys        # installed key ...
ssh-keygen -lf jlee_laptop.pub                             # ... vs approved key
```

| Finding | Fix |
| --- | --- |
| `bad ownership or modes` | `chown -R jlee:jlee ~jlee/.ssh; chmod 700 ~jlee/.ssh; chmod 600 ~jlee/.ssh/authorized_keys` |
| `User account has expired` | `chage -E 2027-03-31 jlee` |
| shell is `/usr/sbin/nologin` | `usermod -s /bin/bash jlee` |
| fingerprints differ | reinstall the approved key |

## 4. Revoke on the last day (CAP-9003)

```bash
sudo usermod -L -e 1 -s /usr/sbin/nologin jlee   # lock, expire, no shell
sudo usermod -G "" jlee                           # no groups
sudo rm /etc/sudoers.d/70-cap9001-jlee && sudo visudo -c
sudo rm -f /home/jlee/.ssh/authorized_keys
sudo crontab -r -u jlee 2>/dev/null; sudo pkill -KILL -u jlee
sudo mkdir -p /srv/archive/offboarded
sudo tar -czf /srv/archive/offboarded/jlee-home.tar.gz -C /home jlee
sudo -l -U jlee                                   # expect: not allowed to run sudo
```

The account is **kept** (locked) for the legal hold. Delete it only when the retention period ends.
