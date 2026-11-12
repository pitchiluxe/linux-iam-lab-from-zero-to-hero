---
title: Command dictionary
---
Every command used in the course: what it does, the flags you will use most, and an example. All run in the **Linux VM** unless marked otherwise. `sudo` in front means it needs administrator rights.

### ls - list files
`-l` long format, `-a` include hidden, `-h` human sizes, `-d` the folder itself not its content, `-R` recursive, `-t` newest first.
```linux
ls -lah ~/lab
ls -ld /srv/hr
```

### cd / pwd - change / print folder
`cd DIR`, `cd ..` up, `cd ~` home, `cd -` previous. `pwd` prints where you are.

### mkdir / rmdir - make / remove folders
`mkdir -p a/b/c` creates parents, no error if it exists. `rmdir` removes only empty folders.

### cp / mv / rm - copy, move/rename, remove
`cp -r` folders, `cp -p` keep mode/owner/time, `mv -i` / `rm -i` ask first, `rm -r` folder tree, `--` ends options (`rm -- -file`).
```linux
cp /opt/lab-data/handbook/welcome.txt ~/
mv old.txt new.txt
rm -i 'draft.txt~'
```

### cat / less / head / tail - read files
`cat FILE`; `less FILE` (`q` quit, `/` search); `head -n 5`; `tail -n 20`; `tail -f` follow a growing log.

### nano - edit text
`Ctrl+O` save, `Ctrl+X` exit, `Ctrl+W` search. `sudo nano FILE` for system files (prefer `sudoedit FILE`).

### man / --help / apropos - documentation
`man ls`, `man 5 passwd` (file formats), `man -k keyword` search titles, `CMD --help` short usage.

### echo / printf - print text
`echo "text" > file` write, `>> file` append. `printf 'a=%s\n' "$x"` formatted, reliable newlines.

### grep - search text
`-i` ignore case, `-v` invert, `-c` count, `-n` line numbers, `-r` recursive, `-E` extended regex, `-o` only the match, `-q` quiet (just exit code), `-l` file names only, `-x` whole line.
```linux
sudo grep -c 'authentication failure' /var/log/auth.log
grep -E '^(passwd|group):' /etc/nsswitch.conf
```

### sort / uniq / wc / cut / tr / paste - shape text
`sort -n` numeric, `-r` reverse, `-u` unique, `-t: -k3,3n` by field 3; `uniq -c` count adjacent duplicates; `wc -l` lines; `cut -d: -f1,7` fields; `tr ' ' '\n'` translate characters; `paste -sd, -` join lines with commas.
```linux
cut -d: -f1,7 /etc/passwd | sort | head
```

### awk - fields and conditions
`-F:` field separator, `$1..$NF` fields, `NF` number of fields, conditions before `{...}`.
```linux
awk -F: '$3>=1000 && $3<60000 {print $1, $3}' /etc/passwd
```

### find - find files by attributes
`-type f|d`, `-name '*.csv'`, `-user U`, `-group G`, `-nouser`, `-perm -o+w`, `-perm -4000` (setuid), `-mtime -1`, `-exec CMD {} +`, `-ls`.
```linux
sudo find /srv -type f -perm -o+w -ls
sudo find /srv/hr -user cdiaz -exec chown hlopez {} +
```

### tar - archive
`-c` create, `-x` extract, `-t` list, `-z` gzip, `-f FILE`, `-C DIR` change folder first.
```linux
sudo tar -czf /srv/archive/offboarded/u-home.tar.gz -C /home u
tar -tzf archive.tar.gz | head
```

### sha256sum - checksums
`sha256sum files > SHA256SUMS`, verify with `sha256sum -c SHA256SUMS`.

### whoami / id / groups - who am I, which groups
`id USER` UID, GID and groups; `id -nG USER` group names; `id -u` numeric UID.

### getent - look up identities (all sources)
`getent passwd USER`, `getent group GROUP`, `getent -s files passwd USER` (one source), `sudo getent shadow USER`.

### useradd - create a user
`-m` home, `-c "comment"`, `-s SHELL`, `-G g1,g2` supplementary groups, `-g GROUP` primary, `-e YYYY-MM-DD` expiry, `-u UID`, `--system` service account, `-d DIR` home path, `-M` no home.
```linux
sudo useradd -m -c "Jane Doe - Analyst" -s /bin/bash -G finance -e 2027-12-31 jdoe
```

### usermod - change a user
`-aG g` **append** group (without `-a`, `-G` replaces all), `-G ""` remove all supplementary groups, `-L`/`-U` lock/unlock password, `-e DATE` expiry (`-e 1` expired), `-s SHELL`, `-c COMMENT`, `-l NEW` rename.

### userdel - delete a user
`-r` also delete home and mail. Prefer disabling first; delete after retention.

### groupadd / groupdel / gpasswd - groups
`sudo groupadd webops`; `sudo gpasswd -a USER GROUP` add, `-d USER GROUP` remove.

### passwd - passwords
`sudo passwd USER` set; `-l`/`-u` lock/unlock; `-S USER` status (`P` usable, `L` locked, `NP` none); `-e USER` expire now.

### chage - password and account ageing
`-l USER` show; `-E YYYY-MM-DD` account expiry (`-E -1` none, `-E 0` now); `-d 0` must change at next login; `-M DAYS` max password age.
```linux
sudo chage -l kwright
```

### faillock - failed-login counter
`sudo faillock --user USER` show, `--reset` clear. Policy in `/etc/security/faillock.conf`.

### su / sudo - act as another user
`sudo CMD` as root; `sudo -u USER CMD` as USER; `sudo -i` root shell; `sudo -l` your rights; `sudo -l -U USER [CMD]` someone else's rights; `sudo -n` never prompt; `sudo -k` forget cached credentials. `su - USER` full login as USER (needs their password, or root).

### visudo - edit sudo policy safely
`sudo visudo` main file; `-f /etc/sudoers.d/NAME` a drop-in; `-c` check all; `-cf FILE` check one file.

### chmod - change permissions
Octal `640`, `2770`; symbolic `u+x`, `g-w`, `o=`, `g+s`, `+t`; `-R` recursive; `X` execute only on folders.
```linux
sudo chmod 640 payroll.csv
sudo chmod -R g+rX /srv/team
```

### chown / chgrp - change owner / group
`sudo chown USER:GROUP FILE`, `-R` recursive, `chgrp GROUP FILE`.

### umask - default permission mask
`umask` show (`0022`), `umask 027` set for this shell.

### stat / namei - inspect a path
`stat -c '%A %a %U:%G %n' FILE`; `namei -l /full/path` owners and modes of every component.

### getfacl / setfacl - ACLs
`setfacl -m u:USER:rX FILE`, `-x u:USER` remove entry, `-b` remove all, `-R` recursive, `-d` default (inherited) ACL. `getfacl -p PATH`.

### ps / pgrep / pkill - processes
`ps aux`, `ps -o user,pid,cmd -p PID`, `pgrep -u USER -l`, `sudo pkill -KILL -u USER`.

### systemctl - services
`status NAME`, `start|stop|restart|reload NAME`, `enable|disable NAME`, `is-active NAME`, `show -p User,MainPID NAME`, `list-units --type=service`.

### journalctl - system journal
`-u UNIT`, `_COMM=sudo`, `-t TAG`, `--since "1 hour ago"`, `-n 50`, `-f` follow, `-p warning`, `--no-pager`, `-o short-iso`.
```linux
sudo journalctl -u ssh -n 30 --no-pager
```

### ss - sockets and ports
`sudo ss -ltnp` listening TCP ports with processes; `ss -tn` established connections.

### ssh - connect
`ssh USER@HOST`, `-p PORT`, `-i KEY`, `-v` verbose diagnostics, `-o BatchMode=yes` never prompt. From Windows: `ssh linux-iam-lab`.

### ssh-keygen - keys and fingerprints
`-t ed25519` create, `-C comment`, `-f FILE`, `-N ''` empty passphrase (lab only), `-lf FILE` fingerprint(s), `-R HOST` remove a known host entry.

### sshd - SSH server checks
`sudo sshd -t` validate config; `sudo sshd -T` effective config; `sudo sshd -T -C user=U,host=H,addr=A` with Match evaluation.

### install - copy with mode and owner
`sudo install -m 600 -o U -g G SRC DEST`; `install -d -m 700 -o U -g G DIR`.

### crontab - scheduled jobs
`crontab -l` list yours; `sudo crontab -l -u USER`; `sudo crontab -r -u USER` remove.

### ldapsearch / ldapmodify - directory
`-x` simple bind, `-ZZ` require StartTLS, `-H ldap://ldap.iamlab.test`, `-b BASE`, `-D BINDDN -y PWFILE`, filter `'(uid=pshah)'`, `-f FILE.ldif` (ldapmodify).

### sssctl / sss_cache - SSSD
`sudo sssctl domain-status iamlab.test`, `sudo sssctl user-checks USER`, `sudo sss_cache -E` (expire all cached entries).

### auditctl / augenrules / ausearch / aureport - audit
`sudo auditctl -l` active rules; `sudo augenrules --load` load `/etc/audit/rules.d/`; `sudo ausearch -k KEY -i --start today`; `sudo aureport -au` / `-m` / `--summary`.

### last / lastlog - login history
`last -n 10` recent logins; `sudo lastb` failed logins (sshd); `lastlog` last login per user.

### lab - this course's helper (Linux)
`lab list`, `lab show ID`, `lab hint ID [1-3]`, `lab check ID`, `lab reset ID`, `lab rescue sudoers|sshd|faillock|sssd|terminal`, `lab capstone status|evidence`, `lab where`.

### Start/Stop/Reset scripts (Windows host)
Desktop shortcuts run these in Windows PowerShell; you can also run them directly:
```powershell
& "$env:LOCALAPPDATA\LinuxIAMLab\app\windows\Start-LinuxIAMLab.ps1"
& "$env:LOCALAPPDATA\LinuxIAMLab\app\windows\Export-LinuxIAMLabWork.ps1"
```
