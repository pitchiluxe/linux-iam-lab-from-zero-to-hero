# m07-directory-lookup
LS() { ldapsearch -LLL -x -ZZ -H ldap://ldap.iamlab.test -b dc=iamlab,dc=test "$@" 2>/dev/null; }
do_setup() {
  student_dir "$SH/lab"; student_dir "$SH/lab/m07"
  if [ "$RESET" = 1 ]; then rm -f "$SH/lab/m07/pshah.txt"; fi
}
do_check() {
  local F="$SH/lab/m07/pshah.txt"
  [ -f "$F" ] || { fail "$F does not exist yet"; return; }
  sss_cache -u pshah 2>/dev/null || true
  expect_answer "$F" uid pshah "username"
  expect_answer "$F" uidnumber "$(LS '(uid=pshah)' uidNumber | sed -n 's/^uidNumber: //p')" "UID from the directory"
  expect_answer "$F" title "$(LS '(uid=pshah)' title | sed -n 's/^title: //p')" "title from the directory"
  local exp got; exp="$(id -nG pshah | tr ' ' '\n' | sort | paste -sd, -)"; got="$(answer "$F" groups | tr -d ' ')"
  [ "$got" = "$exp" ] && pass "groups (primary + supplementary)" || fail "groups should be all groups from 'id pshah', sorted, comma-separated"
  expect_answer "$F" dn "$(LS '(uid=pshah)' dn | sed -n 's/^dn: //p')" "distinguished name"
}
do_solve() {
  local g; g="$(id -nG pshah | tr ' ' '\n' | sort | paste -sd, -)"
  as_user student bash -c "mkdir -p ~/lab/m07; printf 'uid=pshah\nuidnumber=10002\ntitle=Finance Systems Analyst\ngroups=$g\ndn=uid=pshah,ou=people,dc=iamlab,dc=test\n' > ~/lab/m07/pshah.txt"
}
