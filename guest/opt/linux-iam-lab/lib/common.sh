#!/bin/bash
# Shared helpers for exercise setup / check / solve scripts. Source this file. Runs as root.
LAB=/opt/linux-iam-lab
VAR=/var/lib/linux-iam-lab
ETC=/etc/linux-iam-lab
DATA=/opt/lab-data
SH=/home/student
FAILED=0

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; FAILED=1; }
info() { echo "INFO: $*"; }
hint() { echo "HINT: $*"; }
finish() {
  if [ "$FAILED" != 0 ]; then echo "RESULT: not yet - fix the FAIL lines above"; exit 1; fi
  echo "RESULT: all checks passed"; exit 0
}

# ---- identities -----------------------------------------------------------
ensure_group() { # name gid
  getent group "$1" >/dev/null || groupadd -g "$2" "$1"
}
ensure_user() { # name uid "comment" "groups,csv" [shell]
  local n=$1 uid=$2 c=$3 g=$4 sh=${5:-/bin/bash}
  if ! id "$n" >/dev/null 2>&1; then
    useradd -m -u "$uid" -U -c "$c" -s "$sh" ${g:+-G "$g"} "$n"
    persona_set_pw "$n"
  fi
  # repair: an interrupted run may have created the account before its lab password was recorded
  [ -n "$(persona_pw "$n")" ] || persona_set_pw "$n"
}
persona_pw() { { grep -m1 "^$1=" "$VAR/secrets/personas.env" 2>/dev/null || true; } | cut -d= -f2-; }
persona_set_pw() { # user -> sets (or re-applies) the lab-only random password
  local u=$1 pw
  pw="$(persona_pw "$u")"
  if [ -z "$pw" ]; then
    pw="Lab-$(openssl rand -base64 12 | tr -dc 'A-Za-z0-9' | cut -c1-10)-9"
    touch "$VAR/secrets/personas.env"; chmod 600 "$VAR/secrets/personas.env"
    echo "$u=$pw" >> "$VAR/secrets/personas.env"
  fi
  echo "$u:$pw" | chpasswd
}
user_exists() { id "$1" >/dev/null 2>&1; }
# Delete a lab account reliably: end its processes and login sessions first (a test 'su -' can leave
# a systemd user session behind, and userdel then refuses with exit 8 "user is logged in").
remove_user() {
  local u=$1
  user_exists "$u" || return 0
  crontab -r -u "$u" 2>/dev/null || true
  loginctl terminate-user "$u" 2>/dev/null || true
  pkill -KILL -u "$u" 2>/dev/null || true
  sleep 1
  userdel -f -r "$u" 2>/dev/null || userdel -f "$u"
}
in_group() { id -nG "$1" 2>/dev/null | tr ' ' '\n' | grep -qx "$2"; }

# ---- acting as another user ---------------------------------------------
# Run a command as a user with that user's real groups (fresh login groups).
as_user() {
  local u=$1 h; shift
  h="$(getent passwd "$u" | cut -d: -f6)"
  (cd / && runuser -u "$u" -- env HOME="${h:-/}" USER="$u" LOGNAME="$u" "$@")
}
can() { local u=$1; shift; as_user "$u" "$@" >/dev/null 2>&1; }
cannot() { ! can "$@"; }

# Password authentication through PAM (same stack sshd uses). Exit 0 = authenticated + account ok.
pam_login() { # user password
  printf '%s\n' "$2" | timeout 20 pamtester -v sshd "$1" authenticate acct_mgmt >/dev/null 2>&1
}

# Key-based SSH login to this VM. Exit 0 = the key was accepted and a command ran.
ssh_key_login() { # user private-key-path
  timeout 20 ssh -i "$2" -o BatchMode=yes -o IdentitiesOnly=yes -o PasswordAuthentication=no \
    -o KbdInteractiveAuthentication=no -o StrictHostKeyChecking=accept-new \
    -o UserKnownHostsFile="$VAR/keys/known_hosts" -o ConnectTimeout=5 -o LogLevel=ERROR \
    "$1@127.0.0.1" true >/dev/null 2>&1
}

# sudo as a user, password fed on stdin, cached credentials ignored. Exit 0 = allowed.
sudo_as() { # user command...
  local u=$1; shift
  printf '%s\n' "$(persona_pw "$u")" | as_user "$u" sudo -S -k -p '' "$@" >/dev/null 2>&1
}

# Lab test key pairs held by the agent (private) and published to learners (public).
ensure_keypair() { # name -> creates $VAR/keys/<name> + $DATA/keys/<name>.pub
  local n=$1
  mkdir -p "$DATA/keys"
  if [ ! -f "$VAR/keys/$n" ]; then
    ssh-keygen -q -t ed25519 -N '' -C "$n" -f "$VAR/keys/$n"
  fi
  install -m 0644 "$VAR/keys/$n.pub" "$DATA/keys/$n.pub"
}
key_fpr() { ssh-keygen -lf "$1" | awk '{print $2}'; }

# ---- learner answer files (key=value) -------------------------------------
answer() { # file key -> value (trimmed, lowercased)
  [ -f "$1" ] || return 1
  grep -iE "^[[:space:]]*$2[[:space:]]*=" "$1" | tail -1 | cut -d= -f2- | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr 'A-Z' 'a-z'
}
expect_answer() { # file key expected "label"
  local got; got="$(answer "$1" "$2" || true)"
  if [ -z "$got" ]; then fail "$4: no line '$2=...' in $1"; return; fi
  if [ "$got" = "$(echo "$3" | tr 'A-Z' 'a-z')" ]; then pass "$4"; else fail "$4: '$2=$got' is not right yet"; fi
}

student_dir() { # make a learner-owned folder
  install -d -o student -g student -m 0755 "$1"
}

perm_of() { stat -c '%a' "$1" 2>/dev/null; }
owner_of() { stat -c '%U:%G' "$1" 2>/dev/null; }
