# m03-service-account
do_setup() {
  if [ "$RESET" = 1 ] && user_exists svc-reports; then
    remove_user svc-reports
    rm -rf /var/lib/svc-reports
  fi
  return 0
}
do_check() {
  user_exists svc-reports || { fail "svc-reports does not exist yet"; return; }
  local uid pw sh; uid="$(id -u svc-reports)"; pw="$(getent passwd svc-reports)"; sh="$(getent shadow svc-reports | cut -d: -f2)"
  [ "$uid" -lt 1000 ] && pass "system UID ($uid < 1000)" || fail "UID $uid is in the human range; create it with --system"
  [ "$(echo "$pw" | cut -d: -f7)" = /usr/sbin/nologin ] && pass "shell is /usr/sbin/nologin" || fail "shell should be /usr/sbin/nologin"
  [ "$(echo "$pw" | cut -d: -f6)" = /var/lib/svc-reports ] && [ -d /var/lib/svc-reports ] && pass "home is /var/lib/svc-reports" || fail "home should be /var/lib/svc-reports and must exist"
  [ "$(owner_of /var/lib/svc-reports 2>/dev/null)" = "svc-reports:svc-reports" ] && pass "home owned by svc-reports" || fail "home should be owned by svc-reports"
  [ "$(perm_of /var/lib/svc-reports 2>/dev/null)" = 750 ] && pass "home is private (750)" || fail "home mode should be 750"
  case "$sh" in '!'*|'*'*) pass "password locked (no usable password)";; *) fail "svc-reports has a usable password - lock it (usermod -L)";; esac
  in_group svc-reports finance && pass "member of finance" || fail "svc-reports should be in finance"
  local extra; extra="$(id -nG svc-reports | tr ' ' '\n' | grep -vxE 'svc-reports|finance' | paste -sd, -)"
  [ -z "$extra" ] && pass "no other groups" || fail "extra groups: $extra"
  can svc-reports cat /srv/finance/budget-2027.csv && pass "ALLOWED as svc-reports: read finance budget" || fail "svc-reports cannot read the finance budget"
  cannot svc-reports ls /srv/hr && pass "DENIED as svc-reports: list /srv/hr" || fail "svc-reports can list /srv/hr"
  local out; out="$(su - svc-reports -c true 2>&1)";
  echo "$out" | grep -qi 'not available' && pass "DENIED: interactive login (nologin shell)" || fail "su - svc-reports did not refuse the login"
}
do_solve() {
  user_exists svc-reports || useradd --system --home-dir /var/lib/svc-reports --create-home --shell /usr/sbin/nologin --comment "Finance reporting job (OPS-3004)" svc-reports
  usermod -aG finance svc-reports
  chmod 750 /var/lib/svc-reports
}
