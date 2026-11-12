# m07-authn-authz
do_setup() {
  student_dir "$SH/lab"; student_dir "$SH/lab/m07"
  if [ "$RESET" = 1 ]; then as_student rm -f -- "$SH/lab/m07/stack.txt"; fi
  # leave an authorization denial for tcole in the log
  pam_login tcole "$(persona_pw tcole)" || true
}
do_check() {
  local F="$SH/lab/m07/stack.txt"
  [ -f "$F" ] || { fail "$F does not exist yet"; return; }
  local src; src="$(grep -E '^passwd:' /etc/nsswitch.conf | sed 's/^passwd:[[:space:]]*//' | tr -s ' \t' ' ' | sed 's/ *$//')"
  local got; got="$(answer "$F" passwd_sources | tr -s ' ')"
  [ "$got" = "$src" ] && pass "passwd sources in nsswitch.conf" || fail "passwd_sources should be the words after 'passwd:' in /etc/nsswitch.conf"
  local s; s="$(answer "$F" nwalker_source)"
  case "$s" in sss|ldap|sssd) pass "nwalker comes from the directory via SSSD";; *) fail "nwalker_source: is nwalker in /etc/passwd (files) or provided by sss?";; esac
  expect_answer "$F" nwalker_uid "$(getent passwd nwalker | cut -d: -f3)" "nwalker's UID"
  local inc; inc="$(grep -E '^@include common-auth' /etc/pam.d/sshd >/dev/null && echo common-auth)"
  expect_answer "$F" sshd_auth_stack "$inc" "auth stack included by /etc/pam.d/sshd"
  case "$(answer "$F" lockout_module)" in pam_faillock|pam_faillock.so|faillock) pass "lockout module";; *) fail "lockout_module: which module in common-auth counts failures?";; esac
  case "$(answer "$F" tcole_failure)" in authorization|authorisation|authz|account) pass "tcole's problem is authorization (account phase)";; *) fail "tcole_failure: his password is accepted - so which phase denies him?";; esac
  expect_answer "$F" tcole_rule simple_allow_groups "the SSSD access rule"
}
do_solve() {
  local src; src="$(grep -E '^passwd:' /etc/nsswitch.conf | sed 's/^passwd:[[:space:]]*//' | tr -s ' \t' ' ' | sed 's/ *$//')"
  as_user student bash -c "mkdir -p ~/lab/m07; printf 'passwd_sources=%s\nnwalker_source=sss\nnwalker_uid=10001\nsshd_auth_stack=common-auth\nlockout_module=pam_faillock\ntcole_failure=authorization\ntcole_rule=simple_allow_groups\n' '$src' > ~/lab/m07/stack.txt"
}
