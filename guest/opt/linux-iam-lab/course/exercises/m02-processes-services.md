---
id: m02-processes-services
module: m02
title: Which account runs the Falcon web app?
minutes: 20
prereqs: m02-pipes-logs
---
## Ticket
**OPS-2003** - *From: Application owner* - "For the service-account inventory, tell us which Linux account runs the **falcon-web** service, its main process ID, the TCP port it listens on, whether it is running, and whether it starts at boot. Answers in `~/lab/m02/falcon.txt`."

## Objective
Inspect services with `systemctl`, processes with `ps`, ports with `ss`, and service logs with `journalctl`.

## Before you start
Linux terminal. `falcon-web` is a small demo web app installed by the lab.

## Concepts and commands
```linux
systemctl status falcon-web
```
Shows whether the service is `active (running)`, whether it is `enabled` (starts at boot), its **Main PID** and recent log lines. Press `q` if it opens in a pager.
```text
● falcon-web.service - Falcon web demo app (Linux IAM Lab)
     Loaded: loaded (/etc/systemd/system/falcon-web.service; enabled; preset: enabled)
     Active: active (running) since Tue 2026-11-11 09:00:01 UTC; 1h ago
   Main PID: 1234 (python3)
```

```linux
systemctl show -p User,MainPID,ActiveState,UnitFileState falcon-web
```
`show -p` prints selected properties as `Name=value` - easy to read and to script.
```text
User=svc-falcon
MainPID=1234
ActiveState=active
UnitFileState=enabled
```

```linux
ps -o user,pid,cmd -p 1234
```
`ps -o` chooses columns; `-p` selects a PID. Confirms the process really runs as that user.

```linux
sudo ss -ltnp | grep python3
```
`ss -l` listening sockets, `-t` TCP, `-n` numeric ports, `-p` owning process (needs `sudo` for other users' processes). Look at the *Local Address:Port* column.
```text
LISTEN 0 5 127.0.0.1:8000 0.0.0.0:* users:(("python3",pid=1234,fd=3))
```
`127.0.0.1` means only programs on this server can connect - a good default.

```linux
journalctl -u falcon-web -n 10 --no-pager
```
The service's last 10 log lines.

```linux
cat /etc/systemd/system/falcon-web.service
```
The unit file shows the `User=` setting that makes systemd drop root privileges before starting the app.

## Your task
Create `~/lab/m02/falcon.txt`:
```text
user=<account the service runs as>
pid=<its current main PID>
port=<TCP port it listens on>
state=<active or inactive>
boot=<enabled or disabled>
```

## Verify
Compare each line with `systemctl show -p User,MainPID,ActiveState,UnitFileState falcon-web`. Then **Check my work**. (If you restart the service, its PID changes: update the file.)

## If it fails
- *pid is not right*: the PID changes on every restart. Re-read it.
- *ss shows nothing*: add `sudo`, or check the service is running.
- *Unit not found*: the service name is `falcon-web` (with a dash).

## Hints
### Hint 1
`systemctl status falcon-web` answers most questions at once.
### Hint 2
`systemctl show -p User,MainPID falcon-web` gives exact values; `sudo ss -ltnp` shows the port next to the PID.
### Hint 3
`user=svc-falcon`, `port=8000`, `state=active`, `boot=enabled`, and `pid=` is the `MainPID` value on your VM.

## Walkthrough
```linux
systemctl status falcon-web --no-pager
systemctl show -p User,MainPID,ActiveState,UnitFileState falcon-web
sudo ss -ltnp | grep 8000
PID=$(systemctl show -p MainPID --value falcon-web)
ps -o user,pid,cmd -p "$PID"
mkdir -p ~/lab/m02
printf 'user=svc-falcon\npid=%s\nport=8000\nstate=active\nboot=enabled\n' "$PID" > ~/lab/m02/falcon.txt
lab check m02-processes-services
```
`--value` prints just the value without `MainPID=`.

**Why it matters:** service accounts are identities too. Knowing which account a service runs as, and that it is not `root`, is the core of a non-human identity inventory.
