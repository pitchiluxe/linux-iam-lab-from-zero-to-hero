#!/usr/bin/python3
"""Linux IAM Lab agent (runs as root).

Listens on a Unix socket (/run/linux-iam-lab/agent.sock, mode 0660, group labagent) and runs
ONLY the lab's own exercise scripts and a fixed set of rescue actions. It never runs a command
string supplied by a client. Callers are identified with SO_PEERCRED and must be root, the
learner account or the portal account.
"""
import datetime
import json
import os
import pwd
import grp
import shutil
import socket
import socketserver
import struct
import subprocess
import sys
import threading

sys.path.insert(0, "/opt/linux-iam-lab/lib")
import labcourse  # noqa: E402

SOCK_DIR = "/run/linux-iam-lab"
SOCK = os.path.join(SOCK_DIR, "agent.sock")
VAR = "/var/lib/linux-iam-lab"
PROGRESS = os.path.join(VAR, "progress.json")
CAPSTONE = os.path.join(VAR, "capstone.json")
LOG = "/var/log/linux-iam-lab/agent.log"
EX = "/opt/linux-iam-lab/exercises"
EXRUN = "/opt/linux-iam-lab/lib/exrun.sh"
RUN_LOCK = threading.Lock()
STATE_LOCK = threading.Lock()


def now():
    return datetime.datetime.now().isoformat(timespec="seconds")


def log(msg):
    with open(LOG, "a", encoding="utf-8") as fh:
        fh.write(f"{now()} {msg}\n")


def allowed_uids():
    uids = {0}
    for name in ("student", "labportal"):
        try:
            uids.add(pwd.getpwnam(name).pw_uid)
        except KeyError:
            pass
    return uids


def read_json(path, default):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return default


def write_json(path, data):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=1)
    os.chmod(tmp, 0o640)
    try:
        os.chown(tmp, 0, grp.getgrnam("labagent").gr_gid)
    except KeyError:
        pass
    os.replace(tmp, path)


def progress():
    p = read_json(PROGRESS, {})
    p.setdefault("exercises", {})
    p.setdefault("lessons", {})
    p.setdefault("events", [])
    return p


def record(ex_id, result, hint_level=None):
    with STATE_LOCK:
        p = progress()
        e = p["exercises"].setdefault(ex_id, {"status": "not_started", "attempts": 0, "everPassed": False, "hintsUsed": 0})
        if result == "pass":
            e["status"] = "passed"
            e["attempts"] = e.get("attempts", 0) + 1
            e["everPassed"] = True
            e["passedAt"] = now()
        elif result == "fail":
            e["status"] = "in_progress"
            e["attempts"] = e.get("attempts", 0) + 1
        elif result == "reset":
            e["status"] = "not_started"
        elif result == "hint" and hint_level is not None:
            e["hintsUsed"] = max(int(e.get("hintsUsed", 0)), int(hint_level))
        p["events"] = (p["events"] + [{"at": now(), "exercise": ex_id, "event": result}])[-300:]
        write_json(PROGRESS, p)
        return e


def run_script(path, args=(), timeout=180, env_extra=None):
    env = {"PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", "LANG": "C.UTF-8", "HOME": "/root"}
    if env_extra:
        env.update(env_extra)
    try:
        cp = subprocess.run([path, *args], capture_output=True, text=True, timeout=timeout, env=env, cwd="/")
        return cp.returncode, (cp.stdout + cp.stderr)
    except subprocess.TimeoutExpired:
        return 124, f"Timed out after {timeout}s"


def valid_exercise(ex_id):
    return bool(ex_id) and bool(labcourse.ID_RE.match(ex_id)) and os.path.isfile(os.path.join(EX, ex_id + ".sh"))


# ------------------------------------------------------------------------------ operations
def op_check(req):
    ex_id = req.get("id", "")
    if not valid_exercise(ex_id):
        return {"ok": False, "error": "unknown exercise"}
    with RUN_LOCK:
        code, out = run_script(EXRUN, [ex_id, "check"])
    e = record(ex_id, "pass" if code == 0 else "fail")
    log(f"check {ex_id} uid={req['_uid']} -> {code}")
    return {"ok": True, "passed": code == 0, "code": code, "output": out, "progress": e}


def op_reset(req):
    ex_id = req.get("id", "")
    if not valid_exercise(ex_id):
        return {"ok": False, "error": "unknown exercise"}
    with RUN_LOCK:
        code, out = run_script(EXRUN, [ex_id, "reset"], timeout=300)
    if code == 0:
        record(ex_id, "reset")
    log(f"reset {ex_id} uid={req['_uid']} -> {code}")
    return {"ok": code == 0, "code": code, "output": out}


def op_progress(req):
    return {"ok": True, "progress": progress()}


def op_lesson(req):
    mid = req.get("id", "")
    if not (len(mid) == 3 and mid.startswith("m") and mid[1:].isdigit()):
        return {"ok": False, "error": "bad module id"}
    with STATE_LOCK:
        p = progress()
        p["lessons"][mid] = {"readAt": now()}
        write_json(PROGRESS, p)
    return {"ok": True}


def op_hint(req):
    ex_id = req.get("id", "")
    if not valid_exercise(ex_id):
        return {"ok": False, "error": "unknown exercise"}
    return {"ok": True, "progress": record(ex_id, "hint", int(req.get("level", 1)))}


def quarantine(path):
    qdir = os.path.join(VAR, "quarantine")
    os.makedirs(qdir, exist_ok=True)
    dest = os.path.join(qdir, datetime.datetime.now().strftime("%Y%m%d-%H%M%S-") + os.path.basename(path))
    shutil.move(path, dest)
    return dest


def sh(cmd, timeout=60):
    cp = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    return cp.returncode, (cp.stdout + cp.stderr).strip()


def rescue_sudoers():
    lines = ["Break-glass: checking sudo policy files with visudo -c (this is what an admin with console/root access would do)."]
    for name in sorted(os.listdir("/etc/sudoers.d")):
        path = os.path.join("/etc/sudoers.d", name)
        if name in ("README",) or not os.path.isfile(path):
            continue
        code, out = sh(["visudo", "-cf", path])
        if code != 0:
            dest = quarantine(path)
            lines.append(f"QUARANTINED {path} -> {dest}  ({out.splitlines()[-1] if out else 'syntax error'})")
    code, out = sh(["visudo", "-c"])
    if code != 0 and os.path.exists(os.path.join(VAR, "backup", "sudoers")):
        shutil.copy2(os.path.join(VAR, "backup", "sudoers"), "/etc/sudoers")
        os.chmod("/etc/sudoers", 0o440)
        lines.append("Restored /etc/sudoers from the install-time backup.")
        code, out = sh(["visudo", "-c"])
    with open("/etc/sudoers.d/00-labctl", "w") as fh:
        fh.write("labctl ALL=(ALL) NOPASSWD:ALL\n")
    os.chmod("/etc/sudoers.d/00-labctl", 0o440)
    sh(["usermod", "-aG", "sudo", "student"])
    lines.append("visudo -c now reports: " + ("OK" if code == 0 else out))
    lines.append("student is in the 'sudo' group again. Open a NEW terminal tab for group changes to apply.")
    return lines


def rescue_sshd():
    lines = ["Break-glass: validating the SSH server configuration with sshd -t."]
    keep = {"50-linux-iam-lab.conf", "60-cloudimg-settings.conf"}
    code, out = sh(["sshd", "-t"])
    if code != 0:
        ddir = "/etc/ssh/sshd_config.d"
        candidates = [n for n in sorted(os.listdir(ddir)) if n not in keep and os.path.isfile(os.path.join(ddir, n))]
        # find the single file whose removal makes the config valid; only that one is quarantined
        culprit = None
        for name in candidates:
            path = os.path.join(ddir, name)
            hold = path + ".lab-hold"
            os.rename(path, hold)
            c, _ = sh(["sshd", "-t"])
            os.rename(hold, path)
            if c == 0:
                culprit = name
                break
        targets = [culprit] if culprit else candidates
        for name in targets:
            path = os.path.join(ddir, name)
            lines.append(f"QUARANTINED {path} -> {quarantine(path)}")
        code, out = sh(["sshd", "-t"])
    if code != 0 and os.path.exists(os.path.join(VAR, "backup", "sshd_config")):
        shutil.copy2(os.path.join(VAR, "backup", "sshd_config"), "/etc/ssh/sshd_config")
        lines.append("Restored /etc/ssh/sshd_config from the install-time backup.")
        code, out = sh(["sshd", "-t"])
    # make sure the lab's own accounts can still get in
    code2, eff = sh(["sshd", "-T", "-C", "user=labctl,host=host,addr=10.0.2.2"])
    for line in eff.splitlines():
        if line.startswith("allowgroups ") and "ssh-users" in line.split():
            for u in ("labctl", "student"):
                sh(["usermod", "-aG", "ssh-users", u])
            lines.append("AllowGroups ssh-users is set: made sure labctl and student are members.")
    sh(["systemctl", "restart", "ssh"])
    lines.append("sshd -t now reports: " + ("OK" if code == 0 else out))
    return lines


def op_rescue(req):
    what = req.get("what", "")
    with RUN_LOCK:
        if what == "sudoers":
            lines = rescue_sudoers()
        elif what == "sshd":
            lines = rescue_sshd()
        elif what == "faillock":
            for u in ("student", "labctl"):
                sh(["faillock", "--user", u, "--reset"])
            sh(["passwd", "-u", "student"])
            lines = ["Cleared failed-login counters for student and labctl (faillock --reset) and unlocked student's password."]
        elif what == "sssd":
            sh(["/opt/linux-iam-lab/lib/directory-baseline.sh"], timeout=120)
            code, out = sh(["systemctl", "restart", "sssd"])
            sh(["sss_cache", "-E"])
            lines = ["Directory baseline ensured, SSSD cache flushed and restarted: " + ("OK" if code == 0 else out)]
        elif what == "terminal":
            code, out = sh(["systemctl", "restart", "lab-terminal"])
            lines = ["Web terminal restarted: " + ("OK" if code == 0 else out)]
        else:
            return {"ok": False, "error": "rescue target must be one of: sudoers, sshd, faillock, sssd, terminal"}
    log(f"rescue {what} uid={req['_uid']}")
    return {"ok": True, "output": "\n".join(lines)}


def op_capstone(req):
    action = req.get("action", "status")
    if action not in ("status", "next", "evidence"):
        return {"ok": False, "error": "bad capstone action"}
    with RUN_LOCK:
        code, out = run_script(EXRUN, ["m09-capstone", "stage", action], timeout=240)
    log(f"capstone {action} uid={req['_uid']} -> {code}")
    return {"ok": code == 0, "code": code, "output": out, "state": read_json(CAPSTONE, {})}


def op_status(req):
    svc = {}
    for s in ("ssh", "sssd", "slapd", "auditd", "falcon-web", "ollama", "lab-portal", "lab-terminal"):
        code, out = sh(["systemctl", "is-active", s])
        svc[s] = out or "unknown"
    return {"ok": True, "services": svc}


OPS = {"check": op_check, "reset": op_reset, "progress": op_progress, "lesson": op_lesson,
       "hint": op_hint, "rescue": op_rescue, "capstone": op_capstone, "status": op_status,
       "ping": lambda r: {"ok": True, "pong": True}}


class Handler(socketserver.StreamRequestHandler):
    def handle(self):
        creds = self.request.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, struct.calcsize("3i"))
        pid, uid, gid = struct.unpack("3i", creds)
        try:
            line = self.rfile.readline(65536)
            req = json.loads(line.decode("utf-8"))
            if uid not in allowed_uids():
                resp = {"ok": False, "error": "caller not allowed"}
            else:
                req["_uid"] = uid
                fn = OPS.get(req.get("op"))
                resp = fn(req) if fn else {"ok": False, "error": "unknown op"}
        except Exception as exc:  # report, never crash the agent
            log(f"error uid={uid}: {exc!r}")
            resp = {"ok": False, "error": str(exc)}
        self.wfile.write((json.dumps(resp) + "\n").encode("utf-8"))


class Server(socketserver.ThreadingMixIn, socketserver.UnixStreamServer):
    daemon_threads = True


def main():
    os.makedirs(SOCK_DIR, exist_ok=True)
    # The service runs with UMask=0027, so the folder would be root:root 0750 and nobody else
    # could reach the socket. Members of labagent (student, labportal) need to traverse it.
    os.chown(SOCK_DIR, 0, grp.getgrnam("labagent").gr_gid)
    os.chmod(SOCK_DIR, 0o750)
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    if os.path.exists(SOCK):
        os.unlink(SOCK)
    srv = Server(SOCK, Handler)
    os.chown(SOCK, 0, grp.getgrnam("labagent").gr_gid)
    os.chmod(SOCK, 0o660)
    log("agent started")
    threading.Thread(target=boot_hooks, daemon=True).start()
    srv.serve_forever()


def boot_hooks():
    """Re-create scenario state that does not survive a reboot (e.g. a running user session)
    for exercises the learner has not passed yet."""
    status = progress().get("exercises", {})
    for name in sorted(os.listdir(EX)):
        if not name.endswith(".sh"):
            continue
        ex_id = name[:-3]
        try:
            with open(os.path.join(EX, name), encoding="utf-8") as fh:
                if "do_boot()" not in fh.read():
                    continue
        except OSError:
            continue
        if status.get(ex_id, {}).get("status") == "passed":
            continue
        with RUN_LOCK:
            code, _ = run_script(EXRUN, [ex_id, "boot"], timeout=120)
        log(f"boot hook {ex_id} -> {code}")


if __name__ == "__main__":
    main()
