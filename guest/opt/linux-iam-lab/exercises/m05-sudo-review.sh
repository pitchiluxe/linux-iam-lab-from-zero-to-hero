# m05-sudo-review
LEGACY=/etc/sudoers.d/40-legacy-helpdesk
put_legacy_rule() {
  printf '# Legacy rule from 2019 - "helpdesk needs to edit hosts" (fictional)\ndpatel ALL=(root) NOPASSWD: /usr/bin/vim /etc/hosts\n' > "$LEGACY.tmp"
  chmod 440 "$LEGACY.tmp"
  visudo -cf "$LEGACY.tmp" >/dev/null && mv "$LEGACY.tmp" "$LEGACY"
}
do_setup() {
  student_dir "$SH/lab"; student_dir "$SH/lab/m05"
  if [ "$RESET" = 1 ]; then rm -f "$SH/lab/m05/sudo-review.txt"; fi
  # The rule is part of the scenario. Recreate it on first setup or on retry.
  if [ "$RESET" = 1 ] || [ ! -f "$VAR/m05-sudo-review.ready" ]; then put_legacy_rule; touch "$VAR/m05-sudo-review.ready"; fi
}
do_check() {
  local F="$SH/lab/m05/sudo-review.txt"
  [ -f "$F" ] || { fail "$F does not exist yet"; return; }
  local members got
  members="$(getent group sudo | cut -d: -f4 | tr ',' '\n' | grep -v '^$' | sort | paste -sd, -)"
  got="$(answer "$F" sudo_group_members | tr -d ' ')"
  [ "$got" = "$members" ] && pass "members of the sudo group" || fail "sudo_group_members should be '$(echo "$members" | sed 's/./?/g')' - read getent group sudo"
  expect_answer "$F" dpatel_command /usr/bin/vim "program dpatel may run as root"
  expect_answer "$F" dpatel_needs_password no "NOPASSWD means no password"
  expect_answer "$F" risky_rule_file "$LEGACY" "file containing the rule"
  answer "$F" why_risky | grep -qE 'shell|escape|root|:!' && pass "risk explained (shell escape = full root)" || fail "why_risky should explain that the editor can start a root shell"
}
do_solve() {
  local members; members="$(getent group sudo | cut -d: -f4 | tr ',' '\n' | grep -v '^$' | sort | paste -sd, -)"
  as_user student bash -c "mkdir -p ~/lab/m05; printf 'sudo_group_members=%s\ndpatel_command=/usr/bin/vim\ndpatel_needs_password=no\nrisky_rule_file=$LEGACY\nwhy_risky=vim shell escape gives root\n' '$members' > ~/lab/m05/sudo-review.txt"
}
