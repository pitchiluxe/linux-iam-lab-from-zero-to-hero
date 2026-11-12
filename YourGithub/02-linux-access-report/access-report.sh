#!/usr/bin/env bash
# access-report.sh - who can log in, with what groups, and who has sudo. READ-ONLY.
#
# Usage:   sudo ./access-report.sh [output-folder]      (default: ~/reports)
# Output:  access-report-YYYYMMDD-HHMMSS.csv  (never overwritten)
#          access-report-latest.csv           (copy of the newest run)
#          prints the path of the new report
#
# Read-only by design: it only runs getent, id, passwd -S, chage -l and sudo -l -U,
# and writes nothing except the CSV files in the output folder.
# Root is needed because passwd -S and chage -l read /etc/shadow for other users.
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

outdir="${1:-$HOME/reports}"
mkdir -p "$outdir"
out="$outdir/access-report-$(date +%Y%m%d-%H%M%S).csv"

echo "user,uid,primary_group,groups,shell,password_status,account_expires,sudo" > "$out"

# Human accounts only: UID 1000-59999 (system and service accounts live below 1000)
getent passwd | awk -F: '$3>=1000 && $3<60000' | sort -t: -k1,1 |
while IFS=: read -r user _ uid _ _ _ shell; do
  primary=$(id -gn "$user")
  # supplementary groups, without the primary group, sorted, ';'-separated (CSV-safe)
  groups=$(id -nG "$user" | tr ' ' '\n' | grep -vx "$primary" | sort | paste -sd';' - || true)
  pw=$(passwd -S "$user" | awk '{print $2}')          # P = usable password, L = locked, NP = none
  exp=$(chage -l "$user" | awk -F': ' '/Account expires/ {print $2}')
  [ "$exp" = "never" ] || exp=$(date -d "$exp" +%F)  # ISO date, sortable in a spreadsheet
  if sudo -l -U "$user" 2>/dev/null | grep -q 'may run the following'; then s=yes; else s=no; fi
  echo "$user,$uid,$primary,$groups,$shell,$pw,$exp,$s" >> "$out"
done

cp "$out" "$outdir/access-report-latest.csv"
echo "$out"
