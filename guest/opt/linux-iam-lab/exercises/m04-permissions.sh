# m04-permissions
PF=/srv/lab04/payroll-2026-11.csv
do_setup() {
  install -d -m 0755 /srv/lab04
  if [ "$RESET" = 1 ] || [ ! -f "$PF" ]; then
    printf 'employee_id,name,net_pay\nE100,Fictional Person A,4200\nE101,Fictional Person B,3900\n' > "$PF"
    chown root:root "$PF"; chmod 644 "$PF"; setfacl -b "$PF" 2>/dev/null || true
  fi
}
do_check() {
  [ "$(owner_of "$PF")" = "aokafor:finance" ] && pass "owner aokafor, group finance" || fail "owner:group is $(owner_of "$PF"), expected aokafor:finance"
  [ "$(perm_of "$PF")" = 640 ] && pass "mode 640 (rw-r-----)" || fail "mode is $(perm_of "$PF"), expected 640"
  can aokafor cat "$PF" && pass "ALLOWED as aokafor: read" || fail "aokafor cannot read"
  can aokafor sh -c "test -w '$PF'" && pass "ALLOWED as aokafor: write" || fail "aokafor cannot write"
  can jkim cat "$PF" && pass "ALLOWED as jkim (finance): read" || fail "jkim cannot read"
  cannot jkim sh -c "test -w '$PF'" && pass "DENIED as jkim: write" || fail "jkim can write"
  cannot btran cat "$PF" && pass "DENIED as btran (not finance): read" || fail "btran can read the payroll file"
}
do_solve() { chown aokafor:finance "$PF"; chmod 640 "$PF"; }
