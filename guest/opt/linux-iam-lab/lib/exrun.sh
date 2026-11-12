#!/bin/bash
# Runs one action of one exercise script (root only).
#   exrun.sh <exercise-id> setup|reset|check|solve|stage <arg>
# Each exercises/<id>.sh defines do_setup, do_check and do_solve (and m09-capstone also do_stage).
# do_setup sees RESET=1 when the learner asked to retry the exercise.
set -u   # no pipefail: checks use "cmd | grep -q", which pipefail can turn into false failures
id="${1:-}"; action="${2:-}"
[[ "$id" =~ ^m[0-9][0-9]-[a-z0-9-]+$ ]] || { echo "bad exercise id"; exit 2; }
f="/opt/linux-iam-lab/exercises/$id.sh"
[ -f "$f" ] || { echo "unknown exercise $id"; exit 2; }
[ "$(id -u)" = 0 ] || { echo "exrun must run as root"; exit 2; }
. /opt/linux-iam-lab/lib/common.sh
RESET=0
# shellcheck disable=SC1090
. "$f"
case "$action" in
  setup) set -e; do_setup ;;
  reset) set -e; RESET=1; do_setup; echo "Exercise $id reset to its starting state." ;;
  check) do_check; finish ;;
  solve) set -e; do_solve ;;
  stage) do_stage "${3:-status}" ;;
  boot) if declare -F do_boot >/dev/null; then do_boot; fi ;;
  *) echo "unknown action $action"; exit 2 ;;
esac
