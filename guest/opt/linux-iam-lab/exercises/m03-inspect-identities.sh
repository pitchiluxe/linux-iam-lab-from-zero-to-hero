# m03-inspect-identities
m03i_expected() {
  E_UID="$(id -u btran)"
  E_PG="$(id -gn btran)"
  E_G="$(id -nG btran | tr ' ' '\n' | grep -vx "$E_PG" | sort | paste -sd, -)"
  E_FIN="$(getent group finance | cut -d: -f4 | tr ',' '\n' | grep -v '^$' | sort | paste -sd, -)"
  local d; d="$(getent shadow kwright | cut -d: -f8)"
  if [ -n "$d" ]; then E_EXP="$(date -u -d "@$((d * 86400))" +%F)"; else E_EXP="never"; fi
  E_SH="$(getent passwd svc-falcon | cut -d: -f7)"
}
do_setup() {
  student_dir "$SH/lab"; student_dir "$SH/lab/m03"
  if [ "$RESET" = 1 ]; then
    rm -f "$SH/lab/m03/identity-answers.txt"
    chage -E 2025-12-31 kwright
  fi
}
do_check() {
  local F="$SH/lab/m03/identity-answers.txt"
  [ -f "$F" ] || { fail "$F does not exist yet"; return; }
  m03i_expected
  expect_answer "$F" btran_uid "$E_UID" "btran's UID"
  expect_answer "$F" btran_primary_group "$E_PG" "btran's primary group"
  local g; g="$(answer "$F" btran_groups | tr -d ' ')"
  [ "$g" = "$E_G" ] && pass "btran's supplementary groups" || fail "btran_groups should be the supplementary groups only, sorted, comma-separated"
  local f; f="$(answer "$F" finance_members | tr -d ' ')"
  [ "$f" = "$E_FIN" ] && pass "members of finance" || fail "finance_members should list the supplementary members, sorted, comma-separated"
  expect_answer "$F" kwright_expires "$E_EXP" "kwright's account expiry (YYYY-MM-DD)"
  expect_answer "$F" svc_falcon_shell "$E_SH" "svc-falcon's login shell"
  local r="no"; as_user student test -r /etc/shadow && r="yes"
  expect_answer "$F" shadow_readable_by_student "$r" "can student read /etc/shadow"
}
do_solve() {
  m03i_expected
  as_user student bash -c "mkdir -p ~/lab/m03; printf 'btran_uid=%s\nbtran_primary_group=%s\nbtran_groups=%s\nfinance_members=%s\nkwright_expires=%s\nsvc_falcon_shell=%s\nshadow_readable_by_student=no\n' '$E_UID' '$E_PG' '$E_G' '$E_FIN' '$E_EXP' '$E_SH' > ~/lab/m03/identity-answers.txt"
}
