# m01-help-mistakes
M="$SH/lab/m01/messy"
do_setup() {
  student_dir "$SH/lab"; student_dir "$SH/lab/m01"
  if [ "$RESET" = 1 ] || [ ! -d "$M" ]; then
    rm -rf "$M"; rm -f "$SH/lab/m01/help.txt"
    student_dir "$M"
    echo 'Q4 numbers: draft (fictional)' > "$M/quarterly report.txt"
    echo 'old notes, safe to delete' > "$M/-old-notes.txt"
    echo 'do not delete me' > "$M/keep-me.txt"
    chown student:student "$M"/*  "$M/-old-notes.txt"
  fi
}
do_check() {
  [ -f "$M/quarterly-report.txt" ] && pass "quarterly-report.txt exists" || fail "rename 'quarterly report.txt' to quarterly-report.txt"
  [ -e "$M/quarterly report.txt" ] && fail "'quarterly report.txt' (with a space) still exists"
  [ -e "$M/-old-notes.txt" ] && fail "-old-notes.txt still exists (hint: rm -- NAME)" || pass "-old-notes.txt deleted"
  [ -f "$M/keep-me.txt" ] && pass "keep-me.txt untouched" || fail "keep-me.txt is gone - press Retry exercise"
  local F="$SH/lab/m01/help.txt"
  [ -f "$F" ] || { fail "$F does not exist yet"; return; }
  expect_answer "$F" human -h "ls option for human-readable sizes"
  expect_answer "$F" hidden -a "ls option to show hidden files"
  expect_answer "$F" interactive -i "rm option to ask before removing"
  expect_answer "$F" passwd_section 5 "man section for the /etc/passwd file format"
  local c; c="$(answer "$F" cancel | tr -d ' ' | sed 's/-/+/; s/\^c/ctrl+c/')"
  [ "$c" = "ctrl+c" ] && pass "Ctrl+C cancels a running command" || fail "cancel= should be the key combination that interrupts a command"
}
do_solve() {
  as_user student bash -c 'cd ~/lab/m01/messy && mv "quarterly report.txt" quarterly-report.txt && rm -- -old-notes.txt
    printf "human=-h\nhidden=-a\ninteractive=-i\npasswd_section=5\ncancel=ctrl+c\n" > ~/lab/m01/help.txt'
}
