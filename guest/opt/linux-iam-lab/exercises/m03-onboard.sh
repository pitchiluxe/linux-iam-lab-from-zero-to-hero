# m03-onboard
do_setup() {
  if [ "$RESET" = 1 ] && user_exists fgarcia; then
    pkill -u fgarcia 2>/dev/null || true
    remove_user fgarcia
  fi
  return 0
}
do_check() {
  user_exists fgarcia || { fail "user fgarcia does not exist yet"; return; }
  local pw sh exp; pw="$(getent passwd fgarcia)"; sh="$(getent shadow fgarcia)"
  [ "$(echo "$pw" | cut -d: -f5)" = "Fatima Garcia - Finance Analyst" ] && pass "comment is 'Fatima Garcia - Finance Analyst'" || fail "comment is '$(echo "$pw" | cut -d: -f5)'"
  [ "$(echo "$pw" | cut -d: -f7)" = "/bin/bash" ] && pass "shell is /bin/bash" || fail "shell should be /bin/bash"
  [ "$(echo "$pw" | cut -d: -f6)" = "/home/fgarcia" ] && [ -d /home/fgarcia ] && pass "home folder /home/fgarcia exists" || fail "home folder /home/fgarcia is missing (useradd -m)"
  [ "$(owner_of /home/fgarcia)" = "fgarcia:fgarcia" ] && pass "home owned by fgarcia" || fail "home should be owned by fgarcia:fgarcia"
  [ "$(perm_of /home/fgarcia)" = 750 ] && pass "home is private (750)" || fail "home mode is $(perm_of /home/fgarcia), expected 750"
  in_group fgarcia finance && pass "member of finance" || fail "fgarcia is not in group finance"
  local extra; extra="$(id -nG fgarcia | tr ' ' '\n' | grep -vxE 'fgarcia|finance' | paste -sd, -)"
  [ -z "$extra" ] && pass "no other roles (least privilege)" || fail "fgarcia has extra groups: $extra"
  exp="$(echo "$sh" | cut -d: -f8)"
  [ -n "$exp" ] && [ "$(date -u -d "@$((exp * 86400))" +%F)" = 2027-12-31 ] && pass "account expires 2027-12-31" || fail "account expiry should be 2027-12-31 (chage -E)"
  case "$(echo "$sh" | cut -d: -f2)" in
    ''|'!'*|'*'*) fail "no usable password yet (sudo passwd fgarcia)";;
    *) pass "temporary password is set";;
  esac
  [ "$(echo "$sh" | cut -d: -f3)" = 0 ] && pass "must change password at first login" || fail "force a password change at first login (chage -d 0, after setting the password)"
  can fgarcia cat /srv/finance/budget-2027.csv && pass "ALLOWED as fgarcia: read /srv/finance/budget-2027.csv" || fail "fgarcia cannot read the finance budget"
  cannot fgarcia ls /srv/hr && pass "DENIED as fgarcia: list /srv/hr" || fail "fgarcia can list /srv/hr - too much access"
  cannot fgarcia sudo -n true && pass "DENIED as fgarcia: sudo" || fail "fgarcia can use sudo"
}
do_solve() {
  user_exists fgarcia || useradd -m -c "Fatima Garcia - Finance Analyst" -s /bin/bash -G finance -e 2027-12-31 fgarcia
  echo "fgarcia:Temp-$(head -c 6 /dev/urandom | od -An -tx1 | tr -d ' \n')-1" | chpasswd
  chage -d 0 fgarcia
  chmod 750 /home/fgarcia
}
