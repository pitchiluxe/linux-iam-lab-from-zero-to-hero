# m02-pipes-logs
LOGF=/opt/lab-data/logs/auth-2026-11-10.log
do_setup() {
  install -d -m 0755 /opt/lab-data/logs
  if [ ! -s "$LOGF" ]; then
    python3 - "$LOGF" <<'EOF'
import random, sys
random.seed(20261110)
lines = []
fails = [("root", "203.0.113.45", 41), ("oracle*", "198.51.100.7", 12), ("admin*", "203.0.113.45", 8),
         ("btran", "192.0.2.77", 3), ("svc-backup", "198.51.100.23", 2), ("test*", "198.51.100.7", 4)]
ok = [("btran", "192.0.2.10", "publickey"), ("hlopez", "192.0.2.11", "publickey"), ("btran", "192.0.2.10", "publickey"), ("aokafor", "192.0.2.12", "password")]
events = []
for user, ip, n in fails:
    for _ in range(n):
        events.append(("F", user, ip))
for user, ip, how in ok:
    events.append(("A", user, ip, how))
random.shuffle(events)
t = 3600
pid = 2100
for ev in events:
    t += random.randint(3, 400)
    pid += random.randint(1, 9)
    hh, mm, ss = t // 3600, (t % 3600) // 60, t % 60
    stamp = f"Nov 10 {hh:02d}:{mm:02d}:{ss:02d} web01 sshd[{pid}]:"
    port = random.randint(30000, 65000)
    if ev[0] == "F":
        u = ev[1]
        who = f"invalid user {u[:-1]}" if u.endswith("*") else u
        lines.append(f"{stamp} Failed password for {who} from {ev[2]} port {port} ssh2")
        if random.random() < 0.3:
            lines.append(f"{stamp} Connection closed by {ev[2]} port {port} [preauth]")
    else:
        lines.append(f"{stamp} Accepted {ev[3]} for {ev[1]} from {ev[2]} port {port} ssh2")
        lines.append(f"{stamp} pam_unix(sshd:session): session opened for user {ev[1]}(uid=2003) by (uid=0)")
open(sys.argv[1], "w").write("\n".join(lines) + "\n")
EOF
    chmod 644 "$LOGF"
  fi
  student_dir "$SH/lab"; student_dir "$SH/lab/m02"
  if [ "$RESET" = 1 ]; then rm -f "$SH/lab/m02/failed-logins.txt"; fi
}
m02_expected() {
  E_TOTAL=$(grep -c "Failed password" "$LOGF")
  E_USER=$(grep "Failed password" "$LOGF" | grep -oE 'for (invalid user )?[^ ]+' | awk '{print $NF}' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
  E_IP=$(grep "Failed password" "$LOGF" | grep -oE 'from [0-9.]+' | awk '{print $2}' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
  E_ACC=$(grep "Accepted" "$LOGF" | awk '{print $9}' | sort -u | paste -sd, -)
}
do_check() {
  local F="$SH/lab/m02/failed-logins.txt"
  [ -f "$F" ] || { fail "$F does not exist yet"; return; }
  m02_expected
  expect_answer "$F" total_failed "$E_TOTAL" "total number of failed password attempts"
  expect_answer "$F" top_user "$E_USER" "most targeted username"
  expect_answer "$F" top_ip "$E_IP" "noisiest source IP"
  local acc; acc="$(answer "$F" accepted_users | tr -d ' ')"
  [ "$acc" = "$E_ACC" ] && pass "users with successful logins" || fail "accepted_users should list each user with an Accepted login once, sorted, comma-separated"
}
do_solve() {
  m02_expected
  as_user student bash -c "mkdir -p ~/lab/m02; printf 'total_failed=%s\ntop_user=%s\ntop_ip=%s\naccepted_users=%s\n' '$E_TOTAL' '$E_USER' '$E_IP' '$E_ACC' > ~/lab/m02/failed-logins.txt"
}
