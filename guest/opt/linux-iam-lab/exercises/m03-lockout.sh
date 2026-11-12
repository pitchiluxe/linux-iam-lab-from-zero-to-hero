# m03-lockout
valid_failures() { faillock --user "$1" 2>/dev/null | awk 'NR>2 && $NF=="V"' | wc -l; }
do_setup() {
  if [ "$RESET" = 1 ] || [ ! -f "$VAR/m03-lockout.ready" ]; then
    chage -E -1 enovak; usermod -U enovak 2>/dev/null || true; persona_set_pw enovak
    faillock --user enovak --reset
    local i; for i in 1 2 3 4 5 6; do pam_login enovak "OldPassword-$i" || true; done
    chage -E 2025-12-31 kwright
    rm -f "$SH/lab/m03/lockout.txt"
    touch "$VAR/m03-lockout.ready"
  fi
  student_dir "$SH/lab"; student_dir "$SH/lab/m03"
}
do_check() {
  local n; n="$(valid_failures enovak)"
  [ "$n" -lt 5 ] && pass "enovak no longer locked (valid failures: $n)" || fail "enovak still has $n valid failures recorded (faillock)"
  case "$(getent shadow enovak | cut -d: -f2)" in '!'*) fail "enovak's password is now locked";; *) pass "enovak's password was not locked";; esac
  if [ "$n" -lt 5 ]; then
    pam_login enovak "$(persona_pw enovak)" && pass "ALLOWED: enovak can log in with his password" || fail "enovak still cannot authenticate"
  fi
  local exp; exp="$(getent shadow kwright | cut -d: -f8)"
  [ -n "$exp" ] && [ "$exp" -le "$(( $(date +%s) / 86400 ))" ] && pass "kwright's account is still expired" || fail "kwright's expiry was changed - the contract ended; set it back (chage -E 2025-12-31 kwright)"
  pam_login kwright "$(persona_pw kwright)" && fail "kwright can log in - he must stay blocked" || pass "DENIED: kwright cannot log in"
  local F="$SH/lab/m03/lockout.txt"
  [ -f "$F" ] || { fail "$F does not exist yet"; return; }
  expect_answer "$F" enovak_cause faillock "cause for enovak"
  expect_answer "$F" kwright_cause expired "cause for kwright"
  expect_answer "$F" kwright_action deny "decision for kwright"
}
do_solve() {
  faillock --user enovak --reset
  as_user student bash -c "mkdir -p ~/lab/m03; printf 'enovak_cause=faillock\nkwright_cause=expired\nkwright_action=deny\n' > ~/lab/m03/lockout.txt"
}
