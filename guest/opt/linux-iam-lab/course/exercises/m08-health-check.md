---
id: m08-health-check
module: m08
title: Write a monitoring check for identity services
minutes: 50
prereqs: m08-access-report
---
## Ticket
**IAM-8005** - *From: Operations* - "Last month SSSD died on a server and nobody noticed until people could not log in. Write us a monitoring check, `~/lab/m08/check_iam.sh`, that our monitoring system (Nagios-compatible) can run: it must tell us when the identity services are down or when failed passwords pile up, and give JSON for our dashboard."

## Objective
Write a script that follows the **Nagios plugin contract** (exit codes and one status line), checks services with `systemctl`, counts failed logins in a log, honours warning/critical thresholds, and prints JSON built with `jq`.

## Before you start
Linux terminal. Exercise `m08-access-report` showed safe bash scripting; reuse those habits (`set -u`, quote variables).

## Concepts and commands
**The plugin contract.** Nagios, Icinga, Zabbix agents, Checkmk and many others run *any* program and read two things:

| Exit code | Meaning |
|---|---|
| `0` | OK |
| `1` | WARNING |
| `2` | CRITICAL |
| `3` | UNKNOWN (the check itself could not run) |

and **one line** of output: `IAM WARNING - 5 failed password(s) in /var/log/auth.log | failed_logins=5;3;10`. The part after `|` is *performance data* (`value;warn;crit`) that monitoring tools graph. The monitoring server only schedules the check and alerts; the real logic lives in small scripts like yours.

Is a service running?
```linux
systemctl is-active sssd slapd
systemctl is-active lab-no-such-service; echo "exit=$?"
```
```text
active
active
inactive
exit=3
```
Only the word `active` means healthy.

How many failed passwords?
```linux
grep -c 'Failed password' /var/log/auth.log
journalctl -u ssh --since '1 hour ago' --no-pager | grep -c 'Failed password'
```
`grep -c` counts matching lines. The journal version can limit to a time window; the log-file version is easier to test, because you can point it at a sample file.

Read options with `getopts`:
```bash
warn=3; crit=10
while getopts "w:c:j" opt; do
  case "$opt" in
    w) warn=$OPTARG ;;
    c) crit=$OPTARG ;;
    j) json=1 ;;
  esac
done
```
`w:` means `-w` takes a value; `j` (no colon) is a plain switch. To collect several `-s` options into an array: `s) services+=("$OPTARG") ;;`.

Build JSON safely with `jq` (never by gluing strings - a quote in a value breaks hand-made JSON):
```linux
jq -n --arg status WARNING --argjson failed 5 '{status: $status, failed_logins: $failed}'
svc='{}'; svc=$(jq -c --arg k sssd --arg v active '. + {($k): $v}' <<<"$svc"); echo "$svc"
```
- `--arg` passes a **string**, `--argjson` passes a number/object.
- `jq -e '.status == "OK"'` sets its exit code from the result - handy in tests.

## Your task
Create an executable `~/lab/m08/check_iam.sh`:
1. Options: `-w N` (default `3`), `-c N` (default `10`), `-l LOGFILE` (default `/var/log/auth.log`), `-s SERVICE` (repeatable; default `ssh sssd slapd`), `-j` (JSON output).
2. Log not readable (or `-w`/`-c` not numbers) -> print `IAM UNKNOWN - ...`, exit `3`.
3. Any service not `active` -> CRITICAL.
4. Otherwise count lines containing `Failed password`: `>= crit` CRITICAL, `>= warn` WARNING, else OK.
5. Normal output: one line starting `IAM OK`, `IAM WARNING` or `IAM CRITICAL`. With `-j`: only JSON, `{"status":"...","failed_logins":N,"services":{"NAME":"active",...}}`.
6. Exit code `0`/`1`/`2` matching the status, also with `-j`.

## Verify
```linux
~/lab/m08/check_iam.sh -s sssd -s slapd; echo "exit=$?"
~/lab/m08/check_iam.sh -j -s sssd -s slapd | jq .
~/lab/m08/check_iam.sh -l /nope; echo "exit=$?"
```
No `sudo` needed: you are in the `adm` group, which may read `/var/log/auth.log`. **Check my work** runs your script as you against sample logs with 0, 5 and 12 failures, a missing service and a missing log, and validates the JSON with `jq`.

## If it fails
- *exit code always 0*: the last command decides the exit code - end with `exit "$state"`.
- *JSON check fails*: with `-j` print **only** JSON (no status line), and make `failed_logins` a number (`--argjson`), not a string.
- *`-w 6` ignored*: `getopts` string needs `w:` with a colon.
- *`Permission denied`*: `chmod +x ~/lab/m08/check_iam.sh`.

## Hints
### Hint 1
Order of decisions: UNKNOWN (cannot check) first, then CRITICAL for a dead service, then compare the count with `crit`, then with `warn`.
### Hint 2
Keep the state as a number 0/1/2 and map it to a word at the end: `names=(OK WARNING CRITICAL); status=${names[$state]}`.
### Hint 3
See the Walkthrough for a complete script.

## Walkthrough
```linux
mkdir -p ~/lab/m08
cat > ~/lab/m08/check_iam.sh <<'EOF'
#!/bin/bash
# check_iam.sh - Nagios-style health check for the lab's identity services.
# Exit codes: 0 OK, 1 WARNING, 2 CRITICAL, 3 UNKNOWN
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
chmod +x ~/lab/m08/check_iam.sh
~/lab/m08/check_iam.sh -s sssd -s slapd; echo "exit=$?"
~/lab/m08/check_iam.sh -j -s sssd -s slapd | jq .
lab check m08-health-check
```
**In production** the monitoring server would run this every few minutes (Nagios: a `command` and a `service` definition pointing at the script). Note what the check does **not** need: no root, no write access. Run monitoring checks with the least privilege that can read what they measure.
