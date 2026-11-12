# m08-access-report
SCRIPT="$SH/bin/access-report.sh"
HEADER="user,uid,primary_group,groups,shell,password_status,account_expires,sudo"
do_setup() {
  student_dir "$SH/bin"
  if [ "$RESET" = 1 ]; then rm -f "$SCRIPT"; rm -rf "$SH/reports"; fi
}
expected_row() { # user -> the row the script should produce
  local user=$1 uid shell primary groups pw exp s
  uid="$(id -u "$user")"; shell="$(getent passwd "$user" | cut -d: -f7)"
  primary="$(id -gn "$user")"
  groups="$(id -nG "$user" | tr ' ' '\n' | grep -vx "$primary" | sort | paste -sd';' - || true)"
  pw="$(passwd -S "$user" | awk '{print $2}')"
  exp="$(chage -l "$user" | awk -F': ' '/Account expires/ {print $2}')"
  [ "$exp" = never ] || exp="$(date -d "$exp" +%F)"
  if sudo -l -U "$user" 2>/dev/null | grep -q 'may run the following'; then s=yes; else s=no; fi
  echo "$user,$uid,$primary,$groups,$shell,$pw,$exp,$s"
}
do_check() {
  [ -f "$SCRIPT" ] || { fail "$SCRIPT does not exist yet"; return; }
  [ -x "$SCRIPT" ] && pass "script is executable" || { fail "script is not executable (chmod +x)"; return; }
  grep -q 'set -euo pipefail' "$SCRIPT" && pass "uses set -euo pipefail" || fail "add set -euo pipefail"
  local tmp; tmp="$(mktemp -d /tmp/lab-ar-XXXX)"
  local before after; before="$(sha256sum /etc/passwd /etc/group /etc/shadow /etc/gshadow | sha256sum)"
  local p1 p2 rc
  p1="$(cd /tmp && HOME=/home/student timeout 120 bash "$SCRIPT" "$tmp" 2>/dev/null)"; rc=$?
  sleep 1.2
  p2="$(cd /tmp && HOME=/home/student timeout 120 bash "$SCRIPT" "$tmp" 2>/dev/null)"
  after="$(sha256sum /etc/passwd /etc/group /etc/shadow /etc/gshadow | sha256sum)"
  [ "$rc" = 0 ] && pass "runs with sudo and exits 0" || fail "script exited with status $rc"
  [ "$before" = "$after" ] && pass "read-only: identity files unchanged after two runs" || fail "the script changed /etc/passwd, group or shadow!"
  local n; n="$(find "$tmp" -maxdepth 1 -name 'access-report-2*.csv' | wc -l)"
  [ "$n" -ge 2 ] && pass "two runs produced $n timestamped reports (nothing overwritten)" || fail "expected 2 timestamped reports after 2 runs, found $n"
  [ -f "$tmp/access-report-latest.csv" ] && pass "access-report-latest.csv updated" || fail "access-report-latest.csv missing"
  [ -n "$p2" ] && [ -f "$p2" ] && pass "prints the path of the new report" || fail "the script should print the path of the report it wrote"
  local L="$tmp/access-report-latest.csv"
  if [ -f "$L" ]; then
    [ "$(head -1 "$L" | tr -d '\r')" = "$HEADER" ] && pass "header row is exact" || fail "header should be: $HEADER"
    local users exp_rows got_rows bad=0 u
    users="$(getent passwd | awk -F: '$3>=1000 && $3<60000 {print $1}' | sort)"
    for u in $users; do
      if ! grep -qxF "$(expected_row "$u")" "$L"; then bad=$((bad+1)); [ $bad -le 3 ] && info "row for $u differs; expected: $(expected_row "$u")"; fi
    done
    local rows; rows="$(($(wc -l < "$L") - 1))"
    [ "$bad" = 0 ] && pass "all $(echo "$users" | wc -w) human-account rows are correct" || fail "$bad row(s) do not match the live system"
    [ "$rows" = "$(echo "$users" | wc -w)" ] && pass "no extra rows (system accounts excluded)" || fail "report has $rows rows, expected $(echo "$users" | wc -w)"
  fi
  rm -rf "$tmp"
}
do_solve() {
  as_user student bash -c 'mkdir -p ~/bin; cat > ~/bin/access-report.sh' <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }
outdir="${1:-$HOME/reports}"
mkdir -p "$outdir"
out="$outdir/access-report-$(date +%Y%m%d-%H%M%S).csv"
echo "user,uid,primary_group,groups,shell,password_status,account_expires,sudo" > "$out"
getent passwd | awk -F: '$3>=1000 && $3<60000' | sort -t: -k1,1 | while IFS=: read -r user _ uid _ _ _ shell; do
  primary=$(id -gn "$user")
  groups=$(id -nG "$user" | tr ' ' '\n' | grep -vx "$primary" | sort | paste -sd';' - || true)
  pw=$(passwd -S "$user" | awk '{print $2}')
  exp=$(chage -l "$user" | awk -F': ' '/Account expires/ {print $2}')
  [ "$exp" = "never" ] || exp=$(date -d "$exp" +%F)
  if sudo -l -U "$user" 2>/dev/null | grep -q 'may run the following'; then s=yes; else s=no; fi
  echo "$user,$uid,$primary,$groups,$shell,$pw,$exp,$s" >> "$out"
done
cp "$out" "$outdir/access-report-latest.csv"
echo "$out"
EOF
  chmod +x "$SCRIPT"
}
