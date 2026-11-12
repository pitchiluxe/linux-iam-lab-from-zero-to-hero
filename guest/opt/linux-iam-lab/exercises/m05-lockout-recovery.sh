# m05-lockout-recovery
AUD=/etc/sudoers.d/60-auditors-logs
do_setup() {
  # Breaking sudo is on-demand only (Start scenario / lab reset); provisioning never does it.
  if [ "$RESET" = 1 ]; then
    printf '# AUD-5003: auditors may read the SSH service log\n%%auditors ALL=(root /usr/bin/journalctl -u ssh.service --no-pager\n' > "$AUD"
    chmod 440 "$AUD"
    echo "Scenario started: $AUD now contains a syntax error. Try: sudo -v"
  fi
  persona_set_pw rmorgan
  faillock --user rmorgan --reset 2>/dev/null || true
}
do_check() {
  visudo -c >/dev/null 2>&1 && pass "visudo -c: every sudo policy file parses OK" || { fail "visudo -c still reports an error"; return; }
  [ -f "$AUD" ] && pass "$AUD exists" || { fail "$AUD is missing - re-create the intended rule with visudo -f"; return; }
  [ "$(perm_of "$AUD")" = 440 ] && pass "file mode 0440" || fail "file mode is $(perm_of "$AUD"), expected 0440"
  sudo -l -U student >/dev/null 2>&1 && sudo -l -U student 2>/dev/null | grep -q '(ALL : ALL) ALL' && pass "student's administrator rights work again" || fail "student's sudo rights are not intact"
  sudo -l -U rmorgan /usr/bin/journalctl -u ssh.service --no-pager >/dev/null 2>&1 && pass "policy: auditors may run journalctl -u ssh.service --no-pager" || fail "rmorgan (auditors) may not run the intended command"
  sudo -l -U rmorgan /usr/bin/journalctl >/dev/null 2>&1 && fail "rmorgan may run journalctl with ANY arguments - list the exact arguments" || pass "policy: auditors may not read the whole journal"
  grep -q NOPASSWD "$AUD" && fail "NOPASSWD is not part of the request" || pass "password required"
  sudo_as rmorgan /usr/bin/journalctl -u ssh.service --no-pager -n 1 && fail "rmorgan could add extra arguments (-n 1)" || pass "DENIED as rmorgan (real test): journalctl with extra arguments"
  sudo_as rmorgan /usr/bin/journalctl -u ssh.service --no-pager && pass "ALLOWED as rmorgan (real test with his password): read the SSH log" || fail "rmorgan could not run the allowed command"
}
do_solve() {
  printf '# AUD-5003: auditors may read the SSH service log\n%%auditors ALL=(root) /usr/bin/journalctl -u ssh.service --no-pager\n' > "$AUD.tmp"
  chmod 440 "$AUD.tmp"; visudo -cf "$AUD.tmp" >/dev/null && mv "$AUD.tmp" "$AUD"
}
