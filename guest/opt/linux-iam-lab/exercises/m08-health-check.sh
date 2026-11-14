# m08-health-check
S="$SH/lab/m08/check_iam.sh"
# Run the learner's plugin AS THE LEARNER (never as root), with a time limit. Sets OUT and RC.
plugin() {
  OUT="$(cd / && timeout 20 runuser -u student -- env HOME="$SH" USER=student LOGNAME=student "$S" "$@" 2>/dev/null </dev/null)"
  RC=$?
}
# Fabricated auth.log with N failed passwords plus noise that must NOT be counted.
mklog() { # file n
  local i
  {
    echo "Nov 14 09:00:01 iamlab01 sshd[1001]: Accepted publickey for nwalker from 10.0.2.2 port 50100 ssh2: ED25519 SHA256:abc"
    echo "Nov 14 09:00:02 iamlab01 sudo:  nwalker : TTY=pts/0 ; PWD=/home/nwalker ; USER=root ; COMMAND=/usr/bin/true"
    for i in $(seq 1 "$2"); do
      echo "Nov 14 09:0$((i % 10)):1$((i % 10)) iamlab01 sshd[20$i]: Failed password for aokafor from 10.0.2.15 port 4$i ssh2"
    done
    echo "Nov 14 09:30:00 iamlab01 sshd[3001]: Accepted password for mfischer from 10.0.2.2 port 50200 ssh2"
  } > "$1"
  chmod 0644 "$1"
}
do_setup() {
  student_dir "$SH/lab"; student_dir "$SH/lab/m08"
  if [ "$RESET" = 1 ]; then as_student rm -f -- "$S"; fi
}
do_check() {
  as_student test -f "$S" || { fail "$S does not exist yet"; return; }
  as_student test -x "$S" && pass "check_iam.sh is executable" || { fail "make it executable: chmod +x $S"; return; }
  as_student bash -n "$S" 2>/dev/null && pass "bash syntax OK (bash -n)" || { fail "bash -n reports a syntax error"; return; }
  local d; d="$(sandbox_dir)"; chmod 0755 "$d"
  mklog "$d/quiet.log" 0; mklog "$d/some.log" 5; mklog "$d/storm.log" 12
  local SV=(-s sssd -s slapd)

  plugin -l "$d/quiet.log" "${SV[@]}"
  [ "$RC" = 0 ] && [[ "$OUT" == "IAM OK"* ]] && pass "0 failures, services up -> exit 0, 'IAM OK ...'" || fail "0 failures should give exit 0 and a line starting 'IAM OK' (got exit $RC: ${OUT%%$'\n'*})"
  plugin -l "$d/some.log" "${SV[@]}"
  [ "$RC" = 1 ] && [[ "$OUT" == "IAM WARNING"* ]] && pass "5 failures (default -w 3) -> exit 1, 'IAM WARNING ...'" || fail "5 failures should give exit 1 / 'IAM WARNING' (got exit $RC)"
  plugin -l "$d/storm.log" "${SV[@]}"
  [ "$RC" = 2 ] && [[ "$OUT" == "IAM CRITICAL"* ]] && pass "12 failures (default -c 10) -> exit 2, 'IAM CRITICAL ...'" || fail "12 failures should give exit 2 / 'IAM CRITICAL' (got exit $RC)"
  plugin -w 6 -c 20 -l "$d/some.log" "${SV[@]}"
  [ "$RC" = 0 ] && pass "-w 6 -c 20 thresholds are honoured (5 failures -> OK)" || fail "-w/-c options are ignored (5 failures with -w 6 should be OK, got exit $RC)"
  plugin -l "$d/quiet.log" -s sssd -s lab-no-such-service
  [ "$RC" = 2 ] && pass "a service that is not running -> CRITICAL" || fail "-s lab-no-such-service should give exit 2 (got $RC)"
  plugin -l "$d/missing.log" "${SV[@]}"
  [ "$RC" = 3 ] && pass "unreadable log -> exit 3 (UNKNOWN)" || fail "a log that cannot be read should give exit 3 / UNKNOWN (got $RC)"
  plugin -j -l "$d/some.log" "${SV[@]}"
  if [ "$RC" = 1 ] && printf '%s' "$OUT" | jq -e '.status == "WARNING" and .failed_logins == 5 and .services.sssd == "active" and .services.slapd == "active"' >/dev/null 2>&1; then
    pass "-j prints valid JSON (status, failed_logins, services) and keeps the exit code"
  else
    fail "-j should print JSON like {\"status\":\"WARNING\",\"failed_logins\":5,\"services\":{\"sssd\":\"active\",...}} and exit 1"
  fi
  rm -rf -- "$d"
}
do_solve() {
  student_dir "$SH/lab/m08"
  as_student tee "$S" >/dev/null <<'EOF'
#!/bin/bash
# check_iam.sh - Nagios-style health check for the lab's identity services.
# Usage: check_iam.sh [-w WARN] [-c CRIT] [-l LOGFILE] [-s SERVICE]... [-j]
# Exit codes (the Nagios plugin contract): 0 OK, 1 WARNING, 2 CRITICAL, 3 UNKNOWN
set -u
warn=3; crit=10; log=/var/log/auth.log; json=0; services=()
while getopts "w:c:l:s:j" opt; do
  case "$opt" in
    w) warn=$OPTARG ;;
    c) crit=$OPTARG ;;
    l) log=$OPTARG ;;
    s) services+=("$OPTARG") ;;
    j) json=1 ;;
    *) echo "IAM UNKNOWN - usage: $0 [-w N] [-c N] [-l LOG] [-s SERVICE]... [-j]"; exit 3 ;;
  esac
done
[ ${#services[@]} -gt 0 ] || services=(ssh sssd slapd)
[[ "$warn" =~ ^[0-9]+$ && "$crit" =~ ^[0-9]+$ ]] || { echo "IAM UNKNOWN - -w and -c must be numbers"; exit 3; }
[ -r "$log" ] || { echo "IAM UNKNOWN - cannot read $log"; exit 3; }

failed=$(grep -c 'Failed password' "$log")
state=0; down=""; svc='{}'
for s in "${services[@]}"; do
  st=$(systemctl is-active "$s" 2>/dev/null); st=${st:-unknown}
  [ "$st" = active ] || { state=2; down="$down $s"; }
  svc=$(jq -c --arg k "$s" --arg v "$st" '. + {($k): $v}' <<<"$svc")
done
if [ "$state" -lt 2 ]; then
  if [ "$failed" -ge "$crit" ]; then state=2
  elif [ "$failed" -ge "$warn" ]; then state=1
  fi
fi
names=(OK WARNING CRITICAL)
status=${names[$state]}

if [ "$json" = 1 ]; then
  jq -n --arg status "$status" --argjson failed "$failed" --argjson services "$svc" \
    '{status: $status, failed_logins: $failed, services: $services}'
else
  msg="IAM $status - $failed failed password(s) in $log"
  [ -z "$down" ] || msg="$msg; not running:$down"
  echo "$msg | failed_logins=$failed;$warn;$crit"
fi
exit "$state"
EOF
  as_student chmod 0755 "$S"
}
