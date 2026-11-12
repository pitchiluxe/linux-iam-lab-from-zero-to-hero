# m08-evidence
ARC="$SH/evidence/access-review-2026Q4.tar.gz"
do_setup() {
  student_dir "$SH/evidence"
  if [ "$RESET" = 1 ]; then as_student rm -rf -- "$SH/evidence/access-review-2026Q4" "$ARC"; fi
}
do_check() {
  [ -f "$ARC" ] || { fail "$ARC does not exist yet"; return; }
  pass "archive exists"
  # The archive is the learner's: unpack and read it AS the learner, never as root.
  local tmp; tmp="$(as_student mktemp -d /tmp/lab-ev-XXXXXX)"
  rd() { as_student cat -- "$D/$1" 2>/dev/null; }
  if ! as_student tar -xzf "$ARC" -C "$tmp" 2>/dev/null; then fail "archive cannot be extracted"; as_student rm -rf -- "$tmp"; return; fi
  local D="$tmp/access-review-2026Q4" f
  [ -d "$D" ] && pass "contains the folder access-review-2026Q4/" || { fail "archive must contain the folder access-review-2026Q4/ (relative path)"; as_student rm -rf -- "$tmp"; return; }
  for f in access-report.csv sudo-rules.txt group-members.txt ssh-keys.txt SHA256SUMS; do
    [ -n "$(rd "$f" | head -c1)" ] && pass "$f present" || fail "$f missing or empty"
  done
  as_student bash -c 'cd "$1" && sha256sum -c SHA256SUMS' _ "$D" >/dev/null 2>&1 && pass "sha256sum -c SHA256SUMS: all files verify" || fail "checksums do not verify"
  local listed; listed="$(rd SHA256SUMS | awk '{print $2}' | sed 's/^\*//' | sort | paste -sd, -)"
  [ "$listed" = "access-report.csv,group-members.txt,ssh-keys.txt,sudo-rules.txt" ] && pass "SHA256SUMS covers the four evidence files" || fail "SHA256SUMS should list exactly the four evidence files"
  [ "$(rd access-report.csv | head -1 | tr -d '\r')" = "user,uid,primary_group,groups,shell,password_status,account_expires,sudo" ] && pass "access report has the AUD-8003 header" || fail "access-report.csv does not have the AUD-8003 header"
  rd group-members.txt | grep -q '^finance:' && rd group-members.txt | grep -q '^ssh-users:' && pass "group membership captured" || fail "group-members.txt should contain getent group lines (finance, ssh-users, ...)"
  rd ssh-keys.txt | grep -q 'SHA256:' && pass "SSH key fingerprints captured" || fail "ssh-keys.txt should contain fingerprints (ssh-keygen -lf)"
  rd sudo-rules.txt | grep -q '%sudo' && ! rd sudo-rules.txt | grep -q '^\s*#' && pass "sudo rules captured without comments" || fail "sudo-rules.txt should contain the rules (e.g. %sudo ...) and no comment lines"
  as_student rm -rf -- "$tmp"
}
do_solve() {
  [ -x "$SH/bin/access-report.sh" ] || /opt/linux-iam-lab/lib/exrun.sh m08-access-report solve >/dev/null
  local D="$SH/evidence/access-review-2026Q4"
  rm -rf "$D"; mkdir -p "$D"
  HOME=/home/student bash "$SH/bin/access-report.sh" /tmp/q4-solve >/dev/null
  cp /tmp/q4-solve/access-report-latest.csv "$D/access-report.csv"; rm -rf /tmp/q4-solve
  grep -hv '^\s*#' /etc/sudoers /etc/sudoers.d/* | grep -v '^\s*$' > "$D/sudo-rules.txt"
  getent group finance hr engineering helpdesk auditors proj-falcon webops ssh-users sudo > "$D/group-members.txt"
  for f in /home/*/.ssh/authorized_keys; do echo "## $f"; ssh-keygen -lf "$f"; done > "$D/ssh-keys.txt" 2>/dev/null
  (cd "$D" && sha256sum access-report.csv sudo-rules.txt group-members.txt ssh-keys.txt > SHA256SUMS)
  (cd "$SH/evidence" && tar -czf access-review-2026Q4.tar.gz access-review-2026Q4)
  chown -R student:student "$SH/evidence"
}
