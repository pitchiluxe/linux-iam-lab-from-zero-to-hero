# m01-files
HB=/opt/lab-data/handbook
do_setup() {
  install -d -m 0755 "$HB"
  cat > "$HB/welcome.txt" <<'EOF'
Welcome to Northwind Labs (a fictional company used for training).
Read the onboarding checklist and the acceptable use policy before requesting access.
EOF
  cat > "$HB/onboarding-checklist.txt" <<'EOF'
Northwind Labs - IAM onboarding checklist (fictional)
[ ] Manager approval recorded in the ticket
[ ] Account created with the correct role groups only
[ ] Account expiry set for contractors
[ ] Access tested as the user (allowed AND denied)
[ ] Evidence attached to the ticket
EOF
  cat > "$HB/acceptable-use.txt" <<'EOF'
Use only the access you were granted. Never share passwords or private keys. Report lost devices at once.
EOF
  chmod 644 "$HB"/*.txt
  student_dir "$SH/lab"; student_dir "$SH/lab/m01"
  if [ "$RESET" = 1 ] || [ ! -e "$SH/lab/m01/.m01-files-ready" ]; then
    rm -rf "$SH/lab/m01/inbox" "$SH/lab/m01/tickets" "$SH/lab/m01/onboarding-checklist.txt"
    student_dir "$SH/lab/m01/inbox"
    printf 'Ticket: HELP-1001\nRequester: Jae Kim\nSummary: Printer mapping on finance laptop\nStatus: CLOSED\n' > "$SH/lab/m01/inbox/ticket-1001.txt"
    printf 'Ticket: HELP-1002\nRequester: Ben Tran\nSummary: Cannot open the Falcon project share\nStatus: OPEN\n' > "$SH/lab/m01/inbox/ticket-1002.txt"
    printf 'Ticket: HELP-1003\nRequester: Hana Lopez\nSummary: New starter in HR needs an account next Monday\nStatus: OPEN\n' > "$SH/lab/m01/inbox/ticket-1003.txt"
    echo 'unsaved draft' > "$SH/lab/m01/inbox/draft.txt~"
    chown -R student:student "$SH/lab/m01/inbox"
    touch "$SH/lab/m01/.m01-files-ready"; chown student:student "$SH/lab/m01/.m01-files-ready"
  fi
}
do_check() {
  local T="$SH/lab/m01/tickets"
  [ -f "$T/closed/ticket-1001.txt" ] && pass "HELP-1001 (CLOSED) is in tickets/closed" || fail "HELP-1001 is CLOSED and belongs in $T/closed/"
  for n in 1002 1003; do
    [ -f "$T/open/ticket-$n.txt" ] && pass "HELP-$n (OPEN) is in tickets/open" || fail "HELP-$n is OPEN and belongs in $T/open/"
  done
  [ -e "$T/open/ticket-1001.txt" ] && fail "HELP-1001 should not be in open/"
  [ -e "$SH/lab/m01/inbox" ] && fail "the inbox folder still exists (remove it when it is empty)" || pass "inbox removed"
  find "$SH/lab/m01" -name 'draft.txt~' | grep -q . && fail "the junk file draft.txt~ still exists" || pass "junk file deleted"
  if cmp -s "$SH/lab/m01/onboarding-checklist.txt" "$HB/onboarding-checklist.txt"; then pass "checklist copied"; else fail "copy $HB/onboarding-checklist.txt into ~/lab/m01/"; fi
  [ -f "$HB/onboarding-checklist.txt" ] && pass "original checklist still in the handbook" || fail "the handbook original is missing (use cp, not mv)"
}
do_solve() {
  as_user student bash -c 'set -e; cd ~/lab/m01/inbox; mkdir -p ~/lab/m01/tickets/open ~/lab/m01/tickets/closed
    mv ticket-1001.txt ~/lab/m01/tickets/closed/; mv ticket-1002.txt ticket-1003.txt ~/lab/m01/tickets/open/
    rm -f "draft.txt~"; cp /opt/lab-data/handbook/onboarding-checklist.txt ~/lab/m01/; cd ~/lab/m01; rmdir inbox'
}
