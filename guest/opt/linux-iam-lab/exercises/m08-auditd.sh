# m08-auditd
AR=/etc/audit/rules.d/50-iam.rules
do_setup() {
  if [ "$RESET" = 1 ]; then
    rm -f "$AR"
    augenrules --load >/dev/null 2>&1 || true
  fi
  return 0
}
identity_events() { ausearch -k identity 2>/dev/null | grep -c '^type=SYSCALL'; }
do_check() {
  systemctl is-active --quiet auditd && pass "auditd is running" || { fail "auditd is not running (sudo systemctl start auditd)"; return; }
  [ -f "$AR" ] && pass "$AR exists (rules persist after reboot)" || fail "$AR does not exist"
  local rules p; rules="$(auditctl -l 2>/dev/null)"
  for p in /etc/passwd /etc/group /etc/shadow /etc/gshadow; do
    echo "$rules" | grep -qE -- "-w $p -p (wa|aw)[a-z]* -k identity" && pass "active watch on $p (key identity)" || fail "no active watch on $p with -p wa -k identity"
  done
  for p in /etc/sudoers /etc/sudoers.d; do
    echo "$rules" | grep -qE -- "-w $p/? -p (wa|aw)[a-z]* -k privilege" && pass "active watch on $p (key privilege)" || fail "no active watch on $p with -p wa -k privilege"
  done
  if [ -f "$AR" ]; then
    for p in passwd group shadow gshadow; do grep -qE -- "-w /etc/$p -p wa -k identity" "$AR" || { fail "$AR is missing the /etc/$p rule"; break; }; done
  fi
  ausearch -k identity -i --start today 2>/dev/null | grep -q 'auid=student' && pass "found identity events attributed to auid=student (your test)" || fail "no identity event with auid=student yet - create and delete a test user after loading the rules"
  local n1 n2; n1="$(identity_events)"
  chmod 644 /etc/group
  sleep 1
  n2="$(identity_events)"
  [ "$n2" -gt "$n1" ] && pass "a fresh attribute change to /etc/group was recorded just now" || fail "a test change to /etc/group was not recorded"
}
do_solve() {
  printf '## SEC-8002\n-w /etc/passwd -p wa -k identity\n-w /etc/group -p wa -k identity\n-w /etc/shadow -p wa -k identity\n-w /etc/gshadow -p wa -k identity\n-w /etc/sudoers -p wa -k privilege\n-w /etc/sudoers.d/ -p wa -k privilege\n' > "$AR"
  augenrules --load >/dev/null
  # Emulate the learner's sudo test: give this process student's login uid (auid), as a login would.
  bash -c "echo $(id -u student) > /proc/self/loginuid && useradd -M -s /usr/sbin/nologin audit-test-user && userdel audit-test-user"
}
