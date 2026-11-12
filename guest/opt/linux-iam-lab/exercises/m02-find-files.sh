# m02-find-files
S2=/srv/lab02/share
do_setup() {
  if [ "$RESET" = 1 ] || [ ! -d "$S2" ]; then
    rm -rf /srv/lab02
    install -d -m 0755 /srv/lab02 "$S2" "$S2/reports" "$S2/tmp" "$S2/hr-exports" "$S2/scripts"
    mk() { printf '%s\n' "$4" > "$1"; chown "$2" "$1"; chmod "$3" "$1"; }
    mk "$S2/reports/q3-summary.txt"       btran:btran     666 "Q3 summary (fictional)"
    mk "$S2/reports/q4-plan.txt"          aokafor:finance 640 "Q4 plan (fictional)"
    mk "$S2/reports/vendor-contacts.csv"  2999:2999       644 "vendor,contact"
    mk "$S2/tmp/upload.sh"                dpatel:dpatel   777 "#!/bin/sh"
    mk "$S2/tmp/readme.txt"               root:root       644 "temporary folder"
    mk "$S2/hr-exports/headcount.csv"     2998:hr         664 "dept,count"
    mk "$S2/hr-exports/old-roster.csv"    2998:2998       646 "name,role"
    mk "$S2/scripts/backup.sh"            svc-backup:svc-backup 755 "#!/bin/sh"
    chmod 1777 "$S2/tmp"   # a world-writable FOLDER (sticky) - not a file, must not be listed
  fi
  student_dir "$SH/lab"; student_dir "$SH/lab/m02"
  if [ "$RESET" = 1 ]; then as_student rm -f -- "$SH/lab/m02/world-writable.txt" "$SH/lab/m02/orphans.txt"; fi
}
do_check() {
  local W="$SH/lab/m02/world-writable.txt" O="$SH/lab/m02/orphans.txt"
  local ew eo
  ew="$(find "$S2" -type f -perm -o+w | sort)"
  eo="$(find "$S2" -type f -nouser | sort)"
  [ "$(stat -c %a "$S2/reports/q3-summary.txt")" = 666 ] && pass "evidence files were left unchanged" || fail "the share's files were changed - this ticket is investigation only (Retry exercise restores them)"
  if [ -f "$W" ]; then
    [ "$(grep -v '^\s*$' "$W" | sort)" = "$ew" ] && pass "world-writable list is complete and correct ($(echo "$ew" | wc -l) files)" || fail "world-writable.txt does not match: expected $(echo "$ew" | wc -l) absolute file paths"
  else fail "$W does not exist yet"; fi
  if [ -f "$O" ]; then
    [ "$(grep -v '^\s*$' "$O" | sort)" = "$eo" ] && pass "orphaned-file list is complete and correct ($(echo "$eo" | wc -l) files)" || fail "orphans.txt does not match: expected $(echo "$eo" | wc -l) absolute file paths"
  else fail "$O does not exist yet"; fi
}
do_solve() {
  as_user student bash -c 'mkdir -p ~/lab/m02; find /srv/lab02/share -type f -perm -o+w | sort > ~/lab/m02/world-writable.txt; find /srv/lab02/share -type f -nouser | sort > ~/lab/m02/orphans.txt'
}
