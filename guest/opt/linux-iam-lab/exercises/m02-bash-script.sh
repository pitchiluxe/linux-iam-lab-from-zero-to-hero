# m02-bash-script
SCRIPT="$SH/bin/login-accounts.sh"
do_setup() {
  student_dir "$SH/bin"
  if [ "$RESET" = 1 ]; then rm -f "$SCRIPT"; fi
}
do_check() {
  [ -f "$SCRIPT" ] || { fail "$SCRIPT does not exist yet"; return; }
  [ -x "$SCRIPT" ] && pass "script is executable" || fail "script is not executable (chmod +x)"
  head -1 "$SCRIPT" | grep -qE '^#!.*(bash|sh)' && pass "has a shebang line" || fail "first line should be a shebang like #!/usr/bin/env bash"
  grep -qE 'set -[a-z]*e[a-z]*u[a-z]*o pipefail|set -euo pipefail' "$SCRIPT" && pass "uses set -euo pipefail" || fail "add 'set -euo pipefail' near the top"
  grep -q $'\r' "$SCRIPT" && fail "Windows line endings found (sed -i 's/\\r\$//' $SCRIPT)"
  local expected got1 got2 before after
  expected="$(awk -F: '$7 !~ /(nologin|false)$/ {print $1, $7}' /etc/passwd | sort)"
  before="$(sha256sum /etc/passwd /etc/group | sha256sum)"
  got1="$(as_user student timeout 20 "$SCRIPT" 2>/dev/null)"; local rc=$?
  got2="$(as_user student timeout 20 "$SCRIPT" 2>/dev/null)"
  after="$(sha256sum /etc/passwd /etc/group | sha256sum)"
  [ $rc = 0 ] && pass "script exits with status 0" || fail "script exited with status $rc"
  [ "$got1" = "$expected" ] && pass "output matches /etc/passwd ($(echo "$expected" | wc -l) accounts)" || fail "output differs from the expected 'username shell' list (run it and compare with the awk command)"
  [ "$got1" = "$got2" ] && pass "safe to rerun: same output twice" || fail "two runs gave different output"
  [ "$before" = "$after" ] && pass "script changed nothing on the system" || fail "the system account files changed while the script ran"
}
do_solve() {
  as_user student bash -c 'mkdir -p ~/bin; cat > ~/bin/login-accounts.sh <<"EOF"
#!/usr/bin/env bash
set -euo pipefail
awk -F: '"'"'$7 !~ /(nologin|false)$/ {print $1, $7}'"'"' /etc/passwd | sort
EOF
chmod +x ~/bin/login-accounts.sh'
}
