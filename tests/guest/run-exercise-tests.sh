#!/bin/bash
# Exercise test harness - runs INSIDE the lab VM (or the disposable WSL test distro) as root.
# For every exercise: reset -> check must FAIL (negative control) -> solve -> check must PASS
# -> reset -> check must FAIL again (reset really restores the scenario). The capstone is walked
# through all four stages, including the injected CAP-9002 fault.
# Usage: run-exercise-tests.sh [exercise-id ...]
set -uo pipefail
LAB=/opt/linux-iam-lab
EXRUN=$LAB/lib/exrun.sh
OUT=/var/log/linux-iam-lab/test-results.txt
: > "$OUT"
pass=0; failn=0; skip=0
log() { echo "$*" | tee -a "$OUT"; }
ok() { pass=$((pass+1)); log "ok   - $*"; }
bad() { failn=$((failn+1)); log "FAIL - $*"; }
skp() { skip=$((skip+1)); log "skip - $*"; }
run() { "$EXRUN" "$@" > /tmp/lab-test-last.txt 2>&1; echo $?; }
lastfails() { grep -E '^(FAIL|INFO: row)' /tmp/lab-test-last.txt | head -5 | sed 's/^/        /' | tee -a "$OUT"; }

IN_WSL=0; grep -qi microsoft /proc/version && IN_WSL=1
ids=("$@")
if [ ${#ids[@]} = 0 ]; then
  mapfile -t ids < <(python3 -c 'import sys; sys.path.insert(0,"/opt/linux-iam-lab/lib"); import labcourse; print("\n".join(labcourse.exercise_ids()))')
fi

for id in "${ids[@]}"; do
  start=$(date +%s)
  if [ "$id" = m08-auditd ] && ! auditctl -s >/dev/null 2>&1; then skp "$id (kernel audit not available here - WSL test harness; runs in the VM)"; continue; fi
  if [ "$id" = m09-capstone ]; then
    [ "$(run "$id" reset)" = 0 ] && ok "$id reset" || bad "$id reset"
    c=$(run "$id" check); [ "$c" != 0 ] && ok "$id stage1 check fails before work (exit $c)" || bad "$id stage1 check passed with no work"
    for stage in 1 2 3; do
      s=$(run "$id" solve); [ "$s" = 0 ] || bad "$id solve stage $stage (exit $s)"
      c=$(run "$id" check)
      if [ "$c" = 3 ] && grep -q "CAP-900$stage complete" /tmp/lab-test-last.txt; then ok "$id stage $stage passes and advances"; else bad "$id stage $stage check exit $c"; lastfails; fi
      if [ "$stage" = 1 ]; then
        fault=$(grep '^fault=' /var/lib/linux-iam-lab/capstone.state | cut -d= -f2)
        c=$(run "$id" check); [ "$c" != 0 ] && grep -q '^FAIL' /tmp/lab-test-last.txt && ok "$id CAP-9002 injected fault '$fault' breaks the login (check fails)" || bad "$id injected fault '$fault' not detected"
      fi
    done
    s=$(run "$id" solve)
    c=$(run "$id" check); [ "$c" = 0 ] && ok "$id stage 4 (evidence) passes - capstone complete" || { bad "$id final check exit $c"; lastfails; }
    ls /home/student/capstone/evidence/CAP-9001-test-report-*.txt >/dev/null 2>&1 && ok "$id evidence report generated" || bad "$id no evidence report"
    [ "$(run "$id" reset)" = 0 ] && ! id jlee >/dev/null 2>&1 && ok "$id reset removes jlee and restarts at CAP-9001" || bad "$id reset"
    continue
  fi
  r=$(run "$id" reset); [ "$r" = 0 ] && ok "$id reset/start scenario" || { bad "$id reset exit $r"; cat /tmp/lab-test-last.txt | tail -3; }
  c=$(run "$id" check); [ "$c" != 0 ] && ok "$id check FAILS on the untouched scenario (negative control)" || bad "$id check passed without any work"
  s=$(run "$id" solve); [ "$s" = 0 ] || { bad "$id solve exit $s"; tail -3 /tmp/lab-test-last.txt; }
  c=$(run "$id" check); [ "$c" = 0 ] && ok "$id check PASSES after the walkthrough ($(grep -c '^PASS' /tmp/lab-test-last.txt) assertions)" || { bad "$id check after solve exit $c"; lastfails; }
  cp /tmp/lab-test-last.txt "/var/log/linux-iam-lab/test-$id.txt"
  r=$(run "$id" reset); c=$(run "$id" check)
  [ "$r" = 0 ] && [ "$c" != 0 ] && ok "$id retry (exercise reset) restores the starting state" || bad "$id reset did not restore the scenario (reset $r, check $c)"
  if grep -q '^start: yes' "$LAB/course/exercises/$id.md"; then run "$id" solve >/dev/null; fi   # leave on-demand breakage fixed
  log "        ($(( $(date +%s) - start ))s)"
done
log ""
log "SUMMARY: $pass ok, $failn failed, $skip skipped"
[ "$failn" = 0 ]
