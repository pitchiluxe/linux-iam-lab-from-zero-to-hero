---
id: m02-bash-script
module: m02
title: Script - list accounts that can log in
minutes: 30
prereqs: m02-pipes-logs
---
## Ticket
**AUD-2004** - *From: Internal Audit* - "Every month we ask which local accounts have an interactive shell. Write a reusable script `~/bin/login-accounts.sh` that prints one line per account in `/etc/passwd` whose shell is **not** `nologin` or `false`, as `username shell`, sorted by username."

## Objective
Write, make executable and run a small, safe Bash script that answers an access question.

## Before you start
Linux terminal. `~/bin` is on your `PATH` (create it if it does not exist; open a new terminal tab if `login-accounts.sh` is "not found" after creating `~/bin`).

## Concepts and commands
```linux
head -3 /etc/passwd
```
```text
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
```
Seven fields separated by `:`: name, password placeholder (`x` = stored in `/etc/shadow`), UID, GID, comment, home, **shell** (field 7). A shell of `/usr/sbin/nologin` or `/bin/false` blocks interactive logins - typical for service accounts.

```linux
awk -F: '$7 !~ /(nologin|false)$/ {print $1, $7}' /etc/passwd | sort
```
- `-F:` splits fields on `:`.
- `$7 !~ /(nologin|false)$/` keeps lines whose 7th field does **not** end with `nologin` or `false` (`~` = matches, `!~` = does not match, `$` = end of text).
- `{print $1, $7}` prints name and shell separated by a space.

```linux
mkdir -p ~/bin
nano ~/bin/login-accounts.sh
chmod +x ~/bin/login-accounts.sh
~/bin/login-accounts.sh
```
`chmod +x` adds the execute permission so you can run the file as a program.

A good script skeleton:
```linux
#!/usr/bin/env bash
# login-accounts.sh - list local accounts with an interactive shell
set -euo pipefail
awk -F: '$7 !~ /(nologin|false)$/ {print $1, $7}' /etc/passwd | sort
```
- `#!/usr/bin/env bash` - run with Bash.
- `set -euo pipefail` - stop on the first error instead of printing a half-true report.
- Comments start with `#` and explain *why*.

## Your task
1. Create `~/bin/login-accounts.sh`, starting with a shebang line and `set -euo pipefail`.
2. It prints `username shell` for every account in `/etc/passwd` whose shell does not end in `nologin` or `false`, sorted by username, nothing else.
3. Make it executable and run it.
4. Look at the result. Is anything surprising there (for example `sync`)? Note it in a comment in your script.

## Verify
Run it twice: same output both times, and it changes nothing. Then **Check my work** - the check runs your script and compares its output with `/etc/passwd`.

## If it fails
- *Permission denied when running*: `chmod +x ~/bin/login-accounts.sh`.
- *`bash: login-accounts.sh: command not found`*: run it with its path `~/bin/login-accounts.sh`.
- *Output differs*: run the script and the `awk` line by hand and compare. Watch for extra `echo` lines or headers.
- *`$'\r': command not found`*: the file has Windows line endings (pasted from Windows). Fix with `sed -i 's/\r$//' ~/bin/login-accounts.sh`.

## Hints
### Hint 1
The shell is field 7 of `/etc/passwd`. `awk -F:` splits on colons.
### Hint 2
Keep lines where `$7` does not end with `nologin` or `false`: `$7 !~ /(nologin|false)$/`. Print `$1, $7`, then `| sort`.
### Hint 3
The whole script is three lines: the shebang, `set -euo pipefail`, and `awk -F: '$7 !~ /(nologin|false)$/ {print $1, $7}' /etc/passwd | sort`.

## Walkthrough
```linux
mkdir -p ~/bin
cat > ~/bin/login-accounts.sh <<'EOF'
#!/usr/bin/env bash
# login-accounts.sh - local accounts that have an interactive shell (AUD-2004)
# Note: 'sync' has /bin/sync as its shell - a legacy account worth flagging.
set -euo pipefail
awk -F: '$7 !~ /(nologin|false)$/ {print $1, $7}' /etc/passwd | sort
EOF
chmod +x ~/bin/login-accounts.sh
~/bin/login-accounts.sh
lab check m02-bash-script
```
`cat > FILE <<'EOF' ... EOF` (a *here-document*) writes several lines into a file without an editor; the quotes around `EOF` stop the shell from expanding `$7` while writing.
```text
aokafor /bin/bash
btran /bin/bash
...
student /bin/bash
sync /bin/sync
```
