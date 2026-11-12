# m04-shared-dir
FT=/srv/finance-team
do_setup() {
  if [ "$RESET" = 1 ]; then rm -rf "$FT"; fi
  return 0
}
do_check() {
  [ -d "$FT" ] || { fail "$FT does not exist yet"; return; }
  [ "$(stat -c %G "$FT")" = finance ] && pass "group owner is finance" || fail "group owner should be finance"
  [ "$(perm_of "$FT")" = 2770 ] && pass "mode 2770 (setgid, no access for others)" || fail "mode is $(perm_of "$FT"), expected 2770"
  getfacl -p "$FT" 2>/dev/null | grep -qE '^default:group:finance:rw[x-]' && pass "default ACL gives finance read/write on new files" || fail "no default ACL for group finance (setfacl -d -m g:finance:rwX)"
  local t="$FT/.lab-check-$$.txt"
  if as_user aokafor sh -c "umask 022; echo created-by-aokafor > '$t'" 2>/dev/null; then
    pass "ALLOWED as aokafor: create a file"
    [ "$(stat -c %G "$t")" = finance ] && pass "new file belongs to group finance (setgid)" || fail "new file's group is $(stat -c %G "$t")"
    can jkim sh -c "echo edited-by-jkim >> '$t'" && pass "ALLOWED as jkim: edit aokafor's new file" || fail "jkim cannot edit a file aokafor created (umask problem - default ACL?)"
  else
    fail "aokafor cannot create files in $FT"
  fi
  cannot btran ls "$FT" && pass "DENIED as btran: list the folder" || fail "btran can list $FT"
  cannot btran cat "$t" && pass "DENIED as btran: read a team file" || fail "btran can read team files"
  rm -f "$t"
}
do_solve() {
  mkdir -p "$FT"; chown root:finance "$FT"; chmod 2770 "$FT"; setfacl -d -m g:finance:rwX "$FT"
}
