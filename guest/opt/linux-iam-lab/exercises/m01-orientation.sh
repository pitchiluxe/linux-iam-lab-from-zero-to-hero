# m01-orientation - sourced by lib/exrun.sh (common.sh already loaded)
do_setup() {
  student_dir "$SH/lab"; student_dir "$SH/lab/m01"
  if [ "$RESET" = 1 ]; then as_student rm -f -- "$SH/lab/m01/orientation.txt"; fi
}
do_check() {
  local F="$SH/lab/m01/orientation.txt"
  [ -f "$F" ] || { fail "$F does not exist yet"; return; }
  [ "$(stat -c %U "$F")" = student ] && pass "file is owned by student" || fail "file should be created by student (without sudo)"
  expect_answer "$F" user student "user= is your account name"
  expect_answer "$F" host "$(hostname)" "host= is this server's name"
  expect_answer "$F" home /home/student "home= is your home folder"
  expect_answer "$F" uid "$(id -u student)" "uid= is your numeric user ID"
  expect_answer "$F" shell "$(getent passwd student | cut -d: -f7)" "shell= is your login shell"
  expect_answer "$F" kernel "$(uname -r)" "kernel= is the kernel release"
}
do_solve() {
  as_user student bash -c 'mkdir -p ~/lab/m01; printf "user=%s\nhost=%s\nhome=%s\nuid=%s\nshell=%s\nkernel=%s\n" "$(whoami)" "$(hostname)" "$HOME" "$(id -u)" "$(getent passwd student | cut -d: -f7)" "$(uname -r)" > ~/lab/m01/orientation.txt'
}
