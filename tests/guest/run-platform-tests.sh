#!/bin/bash
# Platform tests - run INSIDE the lab VM / WSL test distro as root.
# Portal auth and API, agent socket permissions, web terminal, Ollama privacy + tutor, rescue paths,
# and "learner broke things" recovery.
set -uo pipefail
P=http://127.0.0.1:8080
TOK="$(cat /etc/linux-iam-lab/portal.token)"
TT="$(cat /etc/linux-iam-lab/terminal.token)"
J=/tmp/lab-cookies.txt
OUT=/var/log/linux-iam-lab/platform-results.txt; : > "$OUT"
pass=0; failn=0
ok() { pass=$((pass+1)); echo "ok   - $*" | tee -a "$OUT"; }
bad() { failn=$((failn+1)); echo "FAIL - $*" | tee -a "$OUT"; }
t() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

# --- portal auth
t "health endpoint answers without auth" "curl -fs $P/api/health | grep -q true"
t "API refuses requests without the session cookie (401)" "[ \"\$(curl -s -o /dev/null -w '%{http_code}' $P/api/course)\" = 401 ]"
t "wrong token is rejected (403)" "[ \"\$(curl -s -o /dev/null -w '%{http_code}' '$P/?token=wrong')\" = 403 ]"
t "foreign Host header is rejected (DNS-rebinding guard)" "[ \"\$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: evil.example' $P/api/health)\" = 403 ]"
rm -f "$J"
t "correct token sets an HttpOnly SameSite=Strict cookie" "curl -s -D - -o /dev/null -c $J '$P/?token=$TOK' | grep -qi 'set-cookie: labsession=.*HttpOnly; SameSite=Strict'"
t "course API returns 9 modules / 35 exercises" "curl -fs -b $J $P/api/course | python3 -c 'import json,sys; d=json.load(sys.stdin); m=d[\"modules\"]; assert len(m)==9 and sum(len(x[\"exercises\"]) for x in m)==35'"
t "reference API returns 4 documents" "curl -fs -b $J $P/api/reference | python3 -c 'import json,sys; assert len(json.load(sys.stdin)[\"docs\"])==4'"
t "POST without the X-Lab header is refused (CSRF guard)" "[ \"\$(curl -s -o /dev/null -w '%{http_code}' -b $J -X POST $P/api/check/m01-orientation)\" = 401 ]"
t "check via portal -> agent works and returns PASS/FAIL lines" "curl -fs -b $J -H 'X-Lab: 1' -X POST $P/api/check/m01-orientation | grep -q 'RESULT'"
t "unknown exercise id is rejected by the agent" "curl -fs -b $J -H 'X-Lab: 1' -X POST $P/api/check/m99-nope | grep -q 'unknown exercise'"
t "path traversal in exercise id is rejected" "curl -s -b $J -H 'X-Lab: 1' -X POST '$P/api/check/..%2f..%2fetc' | grep -qv RESULT"
t "progress records the check attempt" "curl -fs -b $J $P/api/progress | grep -q m01-orientation"
t "static portal page is served after login" "curl -fs -b $J $P/ | grep -q 'Linux IAM Lab'"
t "portal shows the locked page without a session" "curl -fs $P/ | grep -q 'Start Linux IAM Lab'"

# --- agent socket permissions
t "agent socket is root:labagent 0660" "[ \"\$(stat -c '%U:%G %a' /run/linux-iam-lab/agent.sock)\" = 'root:labagent 660' ]"
t "student can use the agent (lab status)" "runuser -u student -- /opt/linux-iam-lab/bin/lab status --brief"
t "other users cannot use the agent" "! runuser -u btran -- /opt/linux-iam-lab/bin/lab status"
t "lab check works as student through the agent" "runuser -u student -- /opt/linux-iam-lab/bin/lab check m01-orientation; [ \$? -le 1 ]"

# --- web terminal
t "web terminal served at the secret path" "[ \"\$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:7681/t/$TT/)\" = 200 ]"
t "web terminal NOT served without the secret path" "[ \"\$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:7681/)\" != 200 ]"
t "web terminal runs as student" "ps -o user= -C ttyd | grep -qx student"
t "terminal URL handed out by the portal matches" "curl -fs -b $J $P/api/terminal | grep -q '/t/$TT/'"

# --- Ollama privacy and tutor
t "Ollama listens on 127.0.0.1:11434 only" "ss -ltnH 'sport = :11434' | awk '{print \$4}' | grep -qx '127.0.0.1:11434' && ! ss -ltnH 'sport = :11434' | awk '{print \$4}' | grep -qv '^127.0.0.1:'"
t "Ollama service override binds loopback" "grep -q 'OLLAMA_HOST=127.0.0.1:11434' /etc/systemd/system/ollama.service.d/10-linux-iam-lab.conf"
start=$(date +%s.%N)
curl -s -N -b $J -H 'X-Lab: 1' -H 'Content-Type: application/json' -X POST $P/api/tutor \
  -d '{"mode":"explain","message":"Explain this before I run it: sudo usermod -aG webops btran","exerciseId":"m03-mover","shared":"","history":[]}' > /tmp/tutor1.ndjson
secs=$(python3 -c "print(round($(date +%s.%N)-$start,1))")
text=$(python3 -c 'import json; print("".join(json.loads(l).get("t","") for l in open("/tmp/tutor1.ndjson") if l.strip()))')
if [ ${#text} -gt 40 ]; then ok "tutor answered an explain request (${secs}s, ${#text} chars)"; else bad "tutor gave no answer: $(head -c 300 /tmp/tutor1.ndjson)"; fi
echo "$text" > /var/log/linux-iam-lab/tutor-sample-explain.txt
echo "$text" | grep -qiE '\-a|append' && ok "tutor explanation mentions -a/append" || bad "tutor explanation did not mention -a/append"
curl -s -N -b $J -H 'X-Lab: 1' -H 'Content-Type: application/json' -X POST $P/api/tutor \
  -d "{\"mode\":\"error\",\"message\":\"why does this fail?\",\"exerciseId\":\"m06-broken-ssh\",\"shared\":\"password=Hunter2\\n-----BEGIN OPENSSH PRIVATE KEY-----\\nb3BlbnNzaC1rZXk\\n-----END OPENSSH PRIVATE KEY-----\\nroot:\$6\$abcdefgh\$hashhashhashhash:20000:0:99999:7:::\\nAuthentication refused: bad ownership or modes for directory /home/hlopez\",\"history\":[]}" > /tmp/tutor2.ndjson
red=$(head -1 /tmp/tutor2.ndjson | python3 -c 'import json,sys; print(json.loads(sys.stdin.readline()).get("redacted",0))')
[ "${red:-0}" -ge 3 ] && ok "secrets in shared terminal output were redacted before reaching the model ($red items)" || bad "redaction count $red"
grep -q 'Hunter2\|b3BlbnNzaC1rZXk\|hashhashhash' /tmp/tutor2.ndjson && bad "a secret appears in the tutor stream" || ok "no secret echoed back by the tutor"
python3 -c 'import json; print("".join(json.loads(l).get("t","") for l in open("/tmp/tutor2.ndjson") if l.strip()))' > /var/log/linux-iam-lab/tutor-sample-error.txt

# --- tutor offline fallback (portal keeps working)
systemctl stop ollama
curl -s -N -b $J -H 'X-Lab: 1' -H 'Content-Type: application/json' -X POST $P/api/tutor -d '{"mode":"chat","message":"hi"}' | grep -q 'offline' && ok "tutor offline: friendly message, no crash" || bad "tutor offline handling"
t "with Ollama stopped, exercise checks still work" "curl -fs -b $J -H 'X-Lab: 1' -X POST $P/api/check/m01-orientation | grep -q RESULT"
t "with Ollama stopped, course content still loads" "curl -fs -b $J $P/api/course | grep -q m09-capstone"
systemctl start ollama

# --- learner breaks things, recovery paths work
printf '%%sudo ALL=(ALL:ALL ALL\n' > /etc/sudoers.d/99-learner-typo; chmod 440 /etc/sudoers.d/99-learner-typo
! visudo -c >/dev/null 2>&1 && ok "simulated broken sudo policy (visudo -c fails)" || bad "could not simulate broken sudoers"
t "lab rescue sudoers (as student, via agent) repairs sudo policy" "runuser -u student -- /opt/linux-iam-lab/bin/lab rescue sudoers && visudo -c"
printf 'AllowUsers nobody-at-all\nBadOption yes\n' > /etc/ssh/sshd_config.d/05-learner-mistake.conf
! sshd -t 2>/dev/null && ok "simulated broken sshd config" || bad "could not simulate broken sshd"
t "lab rescue sshd quarantines the bad file and sshd -t passes" "runuser -u student -- /opt/linux-iam-lab/bin/lab rescue sshd && sshd -t && [ ! -e /etc/ssh/sshd_config.d/05-learner-mistake.conf ]"
systemctl stop sssd
t "lab rescue sssd restores directory lookups" "runuser -u student -- /opt/linux-iam-lab/bin/lab rescue sssd && sleep 2 && getent passwd nwalker"
for i in 1 2 3 4 5 6; do printf 'wrong\n' | timeout 10 pamtester sshd student authenticate >/dev/null 2>&1; done
faillock --user student | awk 'NR>2 && $NF=="V"' | wc -l | grep -qE '^[5-9]' && ok "simulated student lockout (faillock)" || bad "could not simulate student lockout"
t "lab rescue faillock unlocks student" "/opt/linux-iam-lab/bin/lab rescue faillock && [ \$(faillock --user student | awk 'NR>2 && \$NF==\"V\"' | wc -l) = 0 ]"
chmod 000 /srv/lab04 2>/dev/null; chmod 777 /srv/finance
t "exercise reset repairs learner-broken permissions (m04-traversal)" "/opt/linux-iam-lab/lib/exrun.sh m04-traversal reset >/dev/null; chmod 755 /srv/lab04; /opt/linux-iam-lab/lib/exrun.sh m04-traversal solve && /opt/linux-iam-lab/lib/exrun.sh m04-traversal check >/dev/null"
chmod 2770 /srv/finance
t "selftest passes after all the breakage and recovery" "/opt/linux-iam-lab/bin/lab selftest"

echo "" | tee -a "$OUT"
echo "SUMMARY: $pass ok, $failn failed" | tee -a "$OUT"
[ "$failn" = 0 ]
