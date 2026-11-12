# m09-capstone - four staged tickets; the check advances the stage when a ticket is done.
CS="$VAR/capstone.state"
RES="$VAR/capstone-results"
CAPD="$DATA/capstone"
RULE=/etc/sudoers.d/70-cap9001-jlee
JAK=/home/jlee/.ssh/authorized_keys
ARCH=/srv/archive/offboarded/jlee-home.tar.gz
EVD="$SH/capstone/evidence"
cs_get() { grep -m1 "^$1=" "$CS" 2>/dev/null | cut -d= -f2-; }
cs_set() { touch "$CS"; sed -i "/^$1=/d" "$CS"; echo "$1=$2" >> "$CS"; }

ticket_text() {
  case "$1" in
    1) cat "$CAPD/CAP-9001.txt";;
    2) cat "$CAPD/CAP-9002.txt";;
    3) cat "$CAPD/CAP-9003.txt";;
    4) cat "$CAPD/CAP-9004.txt";;
    *) echo "Capstone complete. Well done.";;
  esac
}

do_setup() {
  install -d -m 0755 "$CAPD"
  ensure_keypair jlee_laptop
  ensure_keypair jlee_wrongkey
  cp "$DATA/keys/jlee_laptop.pub" "$CAPD/jlee_laptop.pub"
  cat > "$CAPD/CAP-9001.txt" <<EOF
CAP-9001  Onboard contractor Jordan Lee (fictional)
Approved by: Ben Tran (Falcon project lead), Head of IT Operations
- Account jlee, comment "Jordan Lee - Contractor (Falcon) CAP-9001", shell /bin/bash, private home (750)
- Account expires 2027-03-31
- Roles: proj-falcon, ssh-users (nothing else)
- Key-only login, no usable password. Key: $CAPD/jlee_laptop.pub
  Fingerprint: $(key_fpr "$VAR/keys/jlee_laptop.pub")
- sudo: NOPASSWD /usr/bin/systemctl restart falcon-web.service only, in $RULE
- Read/write /srv/projects/falcon. No access to Finance or HR data.
EOF
  cat > "$CAPD/CAP-9002.txt" <<'EOF'
CAP-9002  "Permission denied (publickey)" (fictional)
From: Jordan Lee
"My key login to iamlab01 worked yesterday, now it says Permission denied (publickey). I changed nothing."
Find the root cause from evidence (server log, account state, file permissions, key fingerprint) and fix it
without granting anything extra. Record the root cause for CAP-9004.
EOF
  cat > "$CAPD/CAP-9003.txt" <<'EOF'
CAP-9003  Contract terminated - revoke all access today (fictional)
Approved by: Ben Tran
- Disable jlee completely: password locked, account expired, no login shell, no groups,
  no SSH key, no sudo rule, no running processes or scheduled jobs.
- Keep the account (legal hold). Archive the home folder to /srv/archive/offboarded/jlee-home.tar.gz
EOF
  cat > "$CAPD/CAP-9004.txt" <<'EOF'
CAP-9004  Evidence (fictional)
Write ~/capstone/evidence/notes.md: what you did for CAP-9001, CAP-9002 (with the ROOT CAUSE) and CAP-9003.
Then run:  lab capstone evidence     and finally:  lab check m09-capstone
EOF
  chmod 644 "$CAPD"/*
  if [ "$RESET" = 1 ] || [ ! -f "$CS" ]; then
    remove_user jlee
    rm -rf /home/jlee
    rm -f "$RULE" "$ARCH" /srv/projects/falcon/.cap-check-*
    rm -rf "$RES" "$SH/capstone"
    rm -f "$CS"; cs_set stage 1; cs_set fault ""
  fi
  install -d -m 0750 "$RES"
}

# ------------------------------------------------------------------ test matrices
matrix_active() {
  user_exists jlee || { fail "user jlee does not exist yet"; return; }
  local pw sh exp; pw="$(getent passwd jlee)"; sh="$(getent shadow jlee)"; exp="$(echo "$sh" | cut -d: -f8)"
  [ "$(echo "$pw" | cut -d: -f5)" = "Jordan Lee - Contractor (Falcon) CAP-9001" ] && pass "comment matches CAP-9001" || fail "comment should be 'Jordan Lee - Contractor (Falcon) CAP-9001'"
  [ "$(echo "$pw" | cut -d: -f7)" = /bin/bash ] && pass "shell /bin/bash" || fail "login shell is $(echo "$pw" | cut -d: -f7)"
  [ -n "$exp" ] && [ "$(date -u -d "@$((exp * 86400))" +%F)" = 2027-03-31 ] && pass "account expires 2027-03-31" || fail "account expiry should be 2027-03-31"
  [ "$(perm_of /home/jlee)" = 750 ] && [ "$(owner_of /home/jlee)" = "jlee:jlee" ] && pass "home folder private (750, jlee)" || fail "/home/jlee should be 750 owned by jlee"
  local g; g="$(id -nG jlee | tr ' ' '\n' | grep -vx jlee | sort | paste -sd, -)"
  [ "$g" = "proj-falcon,ssh-users" ] && pass "roles exactly proj-falcon, ssh-users" || fail "groups are '$g', expected proj-falcon,ssh-users"
  case "$(echo "$sh" | cut -d: -f2)" in '!'*|'*'*) pass "no usable password (key-only)";; *) fail "jlee has a usable password - lock it";; esac
  [ -f "$RULE" ] && [ "$(perm_of "$RULE")" = 440 ] && pass "sudo rule file $RULE (0440)" || fail "$RULE missing or not mode 0440"
  visudo -c >/dev/null 2>&1 && pass "visudo -c OK" || fail "visudo -c reports an error"
  # ALLOWED
  ssh_key_login jlee "$VAR/keys/jlee_laptop" && pass "ALLOWED: SSH login with Jordan's key" || fail "SSH login with Jordan's key is refused"
  local t="/srv/projects/falcon/.cap-check-$$"
  can jlee sh -c "echo test > '$t'" && pass "ALLOWED: create a file in /srv/projects/falcon" || fail "jlee cannot write to /srv/projects/falcon"
  rm -f "$t"
  can jlee sudo -n /usr/bin/systemctl restart falcon-web.service && pass "ALLOWED: sudo -n systemctl restart falcon-web.service" || fail "jlee cannot restart falcon-web with sudo -n (NOPASSWD rule)"
  # DENIED
  cannot jlee cat /srv/finance/budget-2027.csv && pass "DENIED: read /srv/finance/budget-2027.csv" || fail "jlee can read Finance data"
  cannot jlee ls /srv/hr && pass "DENIED: list /srv/hr" || fail "jlee can list HR data"
  cannot jlee sudo -n /usr/bin/systemctl stop falcon-web.service && pass "DENIED: sudo systemctl stop falcon-web.service" || fail "jlee can stop falcon-web"
  systemctl is-active --quiet falcon-web || systemctl start falcon-web
  cannot jlee sudo -n /usr/bin/cat /etc/shadow && pass "DENIED: sudo cat /etc/shadow" || fail "jlee can read /etc/shadow via sudo"
  pam_login jlee "Guess-$(date +%s)" && fail "password login possible" || pass "DENIED: password login"
  faillock --user jlee --reset 2>/dev/null || true
}
matrix_revoked() {
  user_exists jlee && pass "account kept for legal hold" || { fail "jlee was deleted - the ticket says keep it (Retry restarts the capstone)"; return; }
  local sh exp today; sh="$(getent shadow jlee)"; exp="$(echo "$sh" | cut -d: -f8)"; today=$(( $(date +%s) / 86400 ))
  case "$(echo "$sh" | cut -d: -f2)" in '!'*|'*'*) pass "password locked";; *) fail "password not locked";; esac
  [ -n "$exp" ] && [ "$exp" -le "$today" ] && pass "account expired" || fail "account not expired"
  case "$(getent passwd jlee | cut -d: -f7)" in */nologin|*/false) pass "no login shell";; *) fail "shell should be nologin";; esac
  local g; g="$(id -nG jlee | tr ' ' '\n' | grep -vx jlee | paste -sd, -)"
  [ -z "$g" ] && pass "no groups" || fail "still in groups: $g"
  [ -e "$RULE" ] && fail "sudo rule $RULE still exists" || pass "sudo rule removed"
  visudo -c >/dev/null 2>&1 && pass "visudo -c OK" || fail "visudo -c reports an error"
  [ -s "$JAK" ] && fail "authorized_keys still contains keys" || pass "SSH key removed"
  pgrep -u jlee >/dev/null && fail "jlee still has processes" || pass "no running processes"
  crontab -l -u jlee >/dev/null 2>&1 && fail "jlee still has a crontab" || pass "no scheduled jobs"
  [ -f "$ARCH" ] && tar -tzf "$ARCH" 2>/dev/null | grep -q '^jlee/' && pass "home archived to $ARCH" || fail "$ARCH missing or not a jlee/ archive"
  ssh_key_login jlee "$VAR/keys/jlee_laptop" && fail "SSH key login still WORKS" || pass "DENIED: SSH login with Jordan's key"
  sudo -l -U jlee 2>/dev/null | grep -q 'may run the following' && fail "jlee still has sudo rules" || pass "DENIED: any sudo for jlee"
  cannot jlee sh -c "echo x > /srv/projects/falcon/.cap-check-$$" && pass "DENIED: write to /srv/projects/falcon" || { fail "jlee can still write to the Falcon share"; rm -f "/srv/projects/falcon/.cap-check-$$"; }
}

inject_fault() {
  local faults=(keyperms expired shell wrongkey) f
  f="${faults[$((RANDOM % 4))]}"
  case "$f" in
    keyperms) chown root:root "$JAK"; chmod 666 "$JAK"; chmod 777 /home/jlee/.ssh ;;
    expired) chage -E "$(date -d yesterday +%F)" jlee ;;
    shell) usermod -s /usr/sbin/nologin jlee ;;
    wrongkey) sed "s/ [^ ]*$/ jlee_laptop/" "$VAR/keys/jlee_wrongkey.pub" > "$JAK"; chown jlee:jlee "$JAK"; chmod 600 "$JAK" ;;
  esac
  cs_set fault "$f"
  ssh_key_login jlee "$VAR/keys/jlee_laptop" || true   # leaves the failure in the server log
}

record() { # stage, output-file
  install -d -m 0750 "$RES"
  { echo "=== Stage $1 passed $(date -Is) ==="; cat "$2"; } > "$RES/stage$1.txt"
}

advance() { # from-stage
  local next=$(( $1 + 1 ))
  cs_set stage "$next"
  [ "$next" = 2 ] && inject_fault
  echo
  echo "NEW TICKET ------------------------------------------------------------"
  ticket_text "$next"
  echo "-----------------------------------------------------------------------"
  echo "RESULT: ticket CAP-900$1 complete and its test results were recorded. Work on CAP-900$next, then Check again."
  exit 3
}

do_check() {
  local stage; stage="$(cs_get stage)"; stage="${stage:-1}"
  local out; out="$(mktemp)"
  info "Capstone stage $stage of 4 (CAP-900$stage)"
  case "$stage" in
    1|2)
      matrix_active > "$out"; cat "$out"
      grep -q '^FAIL' "$out" && FAILED=1
      if [ "$FAILED" = 0 ]; then record "$stage" "$out"; rm -f "$out"; advance "$stage"; fi
      [ "$stage" = 2 ] && hint "Start from the server log: sudo journalctl -u ssh -n 30 --no-pager | grep jlee"
      ;;
    3)
      matrix_revoked > "$out"; cat "$out"
      grep -q '^FAIL' "$out" && FAILED=1
      if [ "$FAILED" = 0 ]; then record 3 "$out"; rm -f "$out"; advance 3; fi
      ;;
    4)
      local N="$EVD/notes.md" f; f="$(cs_get fault)"
      if [ -f "$N" ]; then
        pass "notes.md exists"
        local id; for id in CAP-9001 CAP-9002 CAP-9003; do grep -q "$id" "$N" && pass "notes mention $id" || fail "notes.md should describe $id"; done
        local kw
        case "$f" in keyperms) kw='permission|owner|mode|strictmodes|chmod|chown';; expired) kw='expir|chage';; shell) kw='shell|nologin';; wrongkey) kw='fingerprint|wrong key|different key|key mismatch|replaced';; *) kw='.';; esac
        grep -qiE "$kw" "$N" && pass "CAP-9002 root cause is described" || fail "notes.md should state the CAP-9002 root cause (what the evidence showed)"
      else fail "$N does not exist yet"; fi
      ls "$EVD"/CAP-9001-test-report-*.txt >/dev/null 2>&1 && pass "test report generated (lab capstone evidence)" || fail "run: lab capstone evidence"
      [ "$FAILED" = 0 ] && echo "INFO: Capstone complete - you onboarded, troubleshot, revoked and evidenced a contractor's access."
      ;;
  esac
  rm -f "$out"
}

do_stage() {
  local stage; stage="$(cs_get stage)"; stage="${stage:-1}"
  case "$1" in
    status|"")
      echo "INFO: current stage $stage of 4"; ticket_text "$stage"
      for s in 1 2 3; do [ -f "$RES/stage$s.txt" ] && echo "PASS: CAP-900$s completed ($(head -1 "$RES/stage$s.txt" | sed 's/=== //;s/ ===//'))"; done
      ;;
    next) do_check; finish ;;
    evidence)
      if [ "$stage" -lt 4 ]; then echo "FAIL: finish CAP-9001 to CAP-9003 first (current stage $stage)"; return 1; fi
      install -d -o student -g student "$SH/capstone" "$EVD"
      local r="$EVD/CAP-9001-test-report-$(date +%Y%m%d-%H%M%S).txt"
      {
        echo "Linux IAM Lab - Capstone test report (fictional contractor Jordan Lee, jlee)"
        echo "Generated: $(date -Is) on $(hostname) by the lab agent for learner 'student'"
        echo "CAP-9002 injected fault (for the reviewer): $(cs_get fault)"
        echo
        for s in 1 2 3; do cat "$RES/stage$s.txt" 2>/dev/null; echo; done
        echo "=== Re-test of revocation at report time ==="
        FAILED=0; matrix_revoked
        echo
        [ -f "$EVD/notes.md" ] && echo "notes.md sha256: $(sha256sum "$EVD/notes.md" | cut -d' ' -f1)"
      } > "$r"
      chown student:student "$r"
      echo "PASS: report written to $r"
      ;;
    *) echo "use: status | next | evidence"; return 2;;
  esac
}

do_solve() {
  local stage; stage="$(cs_get stage)"; stage="${stage:-1}"
  case "$stage" in
    1)
      user_exists jlee || useradd -m -c "Jordan Lee - Contractor (Falcon) CAP-9001" -s /bin/bash -G proj-falcon,ssh-users -e 2027-03-31 jlee
      usermod -L jlee; chmod 750 /home/jlee
      install -d -m 700 -o jlee -g jlee /home/jlee/.ssh
      install -m 600 -o jlee -g jlee "$CAPD/jlee_laptop.pub" "$JAK"
      echo 'jlee ALL=(root) NOPASSWD: /usr/bin/systemctl restart falcon-web.service' > /tmp/70-cap; visudo -cf /tmp/70-cap >/dev/null && install -m 440 -o root -g root /tmp/70-cap "$RULE"; rm -f /tmp/70-cap
      ;;
    2)
      chown -R jlee:jlee /home/jlee/.ssh; chmod 700 /home/jlee/.ssh
      install -m 600 -o jlee -g jlee "$CAPD/jlee_laptop.pub" "$JAK"
      chage -E 2027-03-31 jlee; usermod -s /bin/bash jlee
      ;;
    3)
      usermod -L -e 1 -s /usr/sbin/nologin jlee; usermod -G "" jlee
      rm -f "$RULE" "$JAK"; crontab -r -u jlee 2>/dev/null || true; pkill -KILL -u jlee || true
      mkdir -p /srv/archive/offboarded; tar -czf "$ARCH" -C /home jlee
      ;;
    4)
      install -d -o student -g student "$SH/capstone" "$EVD"
      printf '# Evidence\nCAP-9001 onboarding done and tested.\nCAP-9002 root cause: %s (permission/expiry/shell/fingerprint checked) fixed.\nCAP-9003 revocation done, home archived.\n' "$(cs_get fault)" > "$EVD/notes.md"
      chown student:student "$EVD/notes.md"
      do_stage evidence >/dev/null
      ;;
  esac
}
