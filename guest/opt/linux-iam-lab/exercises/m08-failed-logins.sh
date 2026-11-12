# m08-failed-logins
do_setup() {
  student_dir "$SH/lab"; student_dir "$SH/lab/m08"
  if [ "$RESET" = 1 ]; then
    rm -f "$SH/lab/m08/investigation.txt"
    local i
    for i in $(seq 1 15); do pam_login aokafor "Spring2026-$i" || true; done
    faillock --user aokafor --reset   # keep aokafor usable for other exercises; the log keeps the evidence
    persona_set_pw dpatel; faillock --user dpatel --reset 2>/dev/null || true
    sudo_as dpatel /usr/bin/cat /etc/shadow || true
    echo "Scenario started: 15 failed passwords for one account and one blocked sudo command were just logged."
  fi
}
do_check() {
  local F="$SH/lab/m08/investigation.txt"
  [ -f "$F" ] || { fail "$F does not exist yet (Start scenario first)"; return; }
  expect_answer "$F" most_failed_user aokafor "account with the most password failures"
  expect_answer "$F" sudo_denied_user dpatel "user refused by sudo"
  local c; c="$(answer "$F" sudo_denied_command | tr -s ' ')"
  [ "$c" = "/usr/bin/cat /etc/shadow" ] && pass "exact command that was refused" || fail "sudo_denied_command should be copied from the COMMAND= field"
  expect_answer "$F" faillock_deny "$(awk -F= '/^[[:space:]]*deny/{gsub(/ /,"",$2); print $2}' /etc/security/faillock.conf)" "lockout threshold"
}
do_solve() {
  as_user student bash -c "mkdir -p ~/lab/m08; printf 'most_failed_user=aokafor\nsudo_denied_user=dpatel\nsudo_denied_command=/usr/bin/cat /etc/shadow\nfaillock_deny=5\n' > ~/lab/m08/investigation.txt"
}
