# m04-traversal
FD=/srv/lab04/falcon
SPEC=$FD/specs/spec-v2.txt
do_setup() {
  install -d -m 0755 /srv/lab04
  if [ "$RESET" = 1 ] || [ ! -f "$SPEC" ]; then
    rm -rf "$FD"
    install -d -o root -g proj-falcon -m 0760 "$FD"
    install -d -o root -g proj-falcon -m 2770 "$FD/specs"
    echo "Falcon spec v2 (fictional)" > "$SPEC"
    chown root:proj-falcon "$SPEC"; chmod 640 "$SPEC"
    chmod 0760 "$FD"
  fi
}
do_check() {
  can btran cat "$SPEC" && pass "ALLOWED as btran (proj-falcon): read spec-v2.txt" || fail "btran still cannot read $SPEC"
  cannot dpatel cat "$SPEC" && pass "DENIED as dpatel (not in proj-falcon): read spec-v2.txt" || fail "dpatel can read the spec - too open"
  local o; o="$(stat -c %a "$FD")"; o="${o: -1}"
  [ "$o" = 0 ] && pass "others have no permissions on $FD" || fail "others have permissions on $FD (mode $(stat -c %a "$FD"))"
  [ "$(owner_of "$SPEC")" = "root:proj-falcon" ] && [ "$(perm_of "$SPEC")" = 640 ] && pass "file permissions unchanged (640 root:proj-falcon)" || fail "the file itself did not need changing"
}
do_solve() { chmod g+x "$FD"; }
