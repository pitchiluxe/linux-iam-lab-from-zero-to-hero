#!/bin/bash
# Lab self-test (root). Prints PASS/FAIL lines; exit 0 only if every required check passes.
. /opt/linux-iam-lab/lib/common.sh
IN_WSL=0; grep -qi microsoft /proc/version 2>/dev/null && IN_WSL=1

for s in ssh sssd slapd falcon-web lab-agent lab-portal lab-terminal ollama; do
  if systemctl is-active --quiet "$s"; then pass "service $s is active"; else fail "service $s is not active"; fi
done
if [ "$IN_WSL" = 0 ]; then
  systemctl is-active --quiet auditd && pass "service auditd is active" || fail "service auditd is not active"
else
  info "auditd not required inside the WSL test harness"
fi

sshd -t 2>/dev/null && pass "sshd configuration valid (sshd -t)" || fail "sshd -t reports an error"
visudo -c >/dev/null 2>&1 && pass "sudo policy valid (visudo -c)" || fail "visudo -c reports an error"

# Ollama must be private to the VM
if ss -ltnH 'sport = :11434' | awk '{print $4}' | grep -qvE '^(127\.0\.0\.1|\[::1\]):11434$'; then
  fail "Ollama listens on a non-loopback address"
elif ss -ltnH 'sport = :11434' | grep -q .; then
  pass "Ollama listens on 127.0.0.1 only"
else
  fail "Ollama is not listening"
fi
MODEL="$(grep '^OLLAMA_MODEL=' "$ETC/settings.env" | cut -d= -f2)"
SKIP="$(grep '^SKIP_TUTOR_MODEL=' "$ETC/settings.env" | cut -d= -f2)"
if ollama list 2>/dev/null | awk '{print $1}' | grep -qx "$MODEL"; then pass "tutor model $MODEL installed"
elif [ "$SKIP" = 1 ]; then info "tutor model download was skipped (run: sudo lab tutor-pull)"
else fail "tutor model $MODEL missing"; fi

ss -ltnH 'sport = :8080' | grep -q . && pass "portal listening on :8080" || fail "portal not listening"
ss -ltnH 'sport = :7681' | grep -q . && pass "web terminal listening on :7681" || fail "web terminal not listening"
curl -fs http://127.0.0.1:8080/api/health | grep -q '"ok": *true' && pass "portal health endpoint OK" || fail "portal health endpoint failed"

getent passwd nwalker >/dev/null && pass "directory user resolves through SSSD (getent passwd nwalker)" || fail "SSSD cannot resolve nwalker"
pam_login nwalker "$(persona_pw nwalker)" && pass "directory login allowed for nwalker (in linux-login)" || fail "directory login for nwalker failed"
pam_login tcole "$(persona_pw tcole)" && fail "tcole should be denied (not in linux-login)" || pass "directory login denied for tcole (authorization works)"
pam_login dpatel "$(persona_pw dpatel)" && pass "local password login works (dpatel)" || fail "local password login failed for dpatel"
faillock --user dpatel --reset >/dev/null 2>&1

python3 - <<'EOF' && pass "course content loads (modules, exercises, reference)" || fail "course content failed to load"
import sys; sys.path.insert(0, "/opt/linux-iam-lab/lib"); import labcourse
mods = labcourse.load_course(full=True); refs = labcourse.load_reference()
n = sum(len(m["exercises"]) for m in mods)
assert len(mods) == 9 and n >= 25 and len(refs) >= 4, (len(mods), n, len(refs))
for m in mods:
    for e in m["exercises"]:
        assert e["hints"] and e["walkthrough"], e["id"]
print(f"INFO: {len(mods)} modules, {n} exercises, {len(refs)} reference documents")
EOF
python3 - <<'EOF' && pass "every listed exercise has a script with do_setup/do_check/do_solve" || fail "an exercise script is missing"
import os, sys; sys.path.insert(0, "/opt/linux-iam-lab/lib"); import labcourse
for eid in labcourse.exercise_ids():
    src = open(f"/opt/linux-iam-lab/exercises/{eid}.sh").read()
    for fn in ("do_setup", "do_check", "do_solve"):
        assert fn + "()" in src, (eid, fn)
EOF
finish
